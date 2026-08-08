// Asset-event import flow — extracted from import_service.dart to keep
// each file under ~1000 LoC. Lives in the same library via `part`, so the
// extension can access ImportService's private fields and helpers directly.

part of 'import_service.dart';

class AssetImportResult {
  final ImportResult result;
  final Map<String, int> assetsByIsin; // ISIN → asset ID
  const AssetImportResult({required this.result, required this.assetsByIsin});
}

class AssetPreviewSummary {
  final String isin;
  final String? name;
  final int buyCount;
  final int sellCount;
  final double netQuantity;
  final String? currency;

  const AssetPreviewSummary({
    required this.isin,
    this.name,
    required this.buyCount,
    required this.sellCount,
    required this.netQuantity,
    this.currency,
  });
}

class AssetEventImportPreview {
  final int parsedRows;
  final int errorRows;
  final List<String> errors;
  final Map<String, AssetPreviewSummary> assetSummary;

  /// External fee rows that would be folded into a parent's commission
  /// during the real import.
  final int attachedFees;

  /// External fee rows that did not match any parent Buy/Sell.
  final int unmatchedFees;

  const AssetEventImportPreview({
    required this.parsedRows,
    required this.errorRows,
    this.errors = const [],
    required this.assetSummary,
    this.attachedFees = 0,
    this.unmatchedFees = 0,
  });
}

/// Amount for a row whose amount column is unmapped — the wizard's "Auto calc"
/// derives it from quantity x price. Bonds are quoted as a percentage of face
/// value, so the money amount divides by 100.
///
/// Shared by the real import and the dry-run preview: the preview used to
/// ignore `price` entirely and infer buy/sell from the quantity sign alone, so
/// it could classify a row differently from the import it was previewing.
/// Returns 0 when either input is missing — never a guess.
double autoCalcAmountFor({required double? qty, required double? price, required bool isBond}) {
  if (qty == null || price == null) return 0;
  return isBond ? qty * price / 100 : qty * price;
}

extension AssetImportFlow on ImportService {
  Future<AssetImportResult> importAssetEventsGrouped({
    required FilePreview preview,
    required List<ColumnMapping> mappings,
    void Function(int processed, int total)? onProgress,
    bool computeFee = false,
    IsinLookupService? isinLookup,
    Set<String>? buyValues,
    Set<String>? sellValues,

    /// Type-column values that mark a row as an *external fee* (e.g.
    /// "Commissioni" / "Bollo" in Directa-style exports). When the
    /// `orderRef` field is also mapped, fee rows are joined to their parent
    /// Buy/Sell on `(isin, orderRef)` and folded into the parent's
    /// `commission`. When `orderRef` is unmapped (or its cell is empty),
    /// the fee row is dropped silently — no DB write, no error.
    Set<String>? feeValues,

    /// Sign-based detection (when no type column is mapped): when true, a
    /// negative cash-flow amount is treated as a BUY (Directa-style:
    /// negative = money out = bought). Default false keeps the historical
    /// behavior (negative = sell).
    bool negativeIsBuy = false,

    /// Wizard-tagged values for `revalue` and `contribute` event types.
    /// Take priority over built-in aliases. See `_parseEventType`.
    Set<String>? revalueValues,
    Set<String>? contributeValues,

    /// ISIN → selected exchange option (from UI picker). If null, uses first result.
    Map<String, IsinExchangeOption>? selectedExchanges,

    /// ISINs to skip during import (unchecked by user in exchange picker).
    Set<String>? excludedIsins,

    /// If provided, fills missing exchange rates from historical data after import.
    ExchangeRateService? rateService,
    required String baseCurrency,

    /// New assets are assigned to this intermediary; deletion is scoped to
    /// ALL assets under this intermediary. Required — unassigned was removed
    /// in schema v29.
    required int intermediaryId,

    /// User's per-import locale choice from the wizard. Persisted to
    /// `Intermediaries.defaultImportLocale` for this intermediary when
    /// non-null. NULL means "Auto — fall back to saved or [appLocale]".
    String? numberLocaleOverride,

    /// App's configured locale (e.g. `it_IT`). Final fallback.
    String? appLocale,

    /// Single-asset mode: when set, every parsed row routes to this asset
    /// and the `isin` column mapping becomes optional. Used for pension
    /// imports (PPP, Riester, UK SIPP) where the user pre-creates the
    /// asset and feeds it events without per-row ISINs. ISIN-grouped
    /// mode (the existing path) remains the default for multi-sub-fund
    /// statements like 401(k) / Group RRSP.
    int? targetAssetId,

    /// Optional per-type amount source: when a row resolves to
    /// [EventType.revalue] and this column is set, the amount is read from
    /// it instead of the primary `amount` mapping. Pension statements put
    /// contribution values in one column (Entrate) and the absolute
    /// position-snapshot value in another (Saldo); a Revalue row's value is
    /// the snapshot, not the (empty) contribution cell. Mirrors the
    /// `awk`-style "use column 6 for total rows, column 5 otherwise".
    String? revalueAmountColumn,

    /// Opt-in inverse of the Amount auto-calc: derive the per-unit `price`
    /// from `amount` and `quantity` when the source has no price column
    /// (issue #96 — several broker exports report only Quantity + Amount).
    /// Explicit rather than implicit-on-unmapped because the derived price
    /// absorbs any commission baked into `amount`, so it is an approximation
    /// of the execution price and must be a user decision.
    bool autoCalcPrice = false,
  }) async {
    await _setLocaleForIntermediary(
      intermediaryId: intermediaryId,
      override: numberLocaleOverride,
      appLocale: appLocale,
    );
    _log.info(
      'importAssetEventsGrouped: ${preview.totalRows} rows, ${mappings.length} mappings, '
      'locale=$_activeLocale, autoCalcPrice=$autoCalcPrice',
    );
    final mappingByField = {for (final m in mappings) m.targetField: m};
    final dateMapping = mappingByField['date'];
    final amountMapping = mappingByField['amount'];
    final isinMapping = mappingByField['isin'];

    // Either the wizard maps an ISIN column (multi-sub-fund / per-row
    // ISIN — the existing 401(k)/Group RRSP path) OR the caller passes
    // `targetAssetId` to route everything to one pre-existing asset
    // (the pension / Riester / UK SIPP path). Reject the call when
    // neither is present.
    if (isinMapping == null && targetAssetId == null) {
      _log.severe('importAssetEventsGrouped: neither ISIN mapping nor targetAssetId provided');
      return AssetImportResult(
        result: const ImportResult(
          totalRows: 0,
          importedRows: 0,
          errorRows: 0,
          errors: ['ISIN column is required (or pass targetAssetId for single-asset import)'],
        ),
        assetsByIsin: {},
      );
    }

    // Pre-resolve field mappings once
    final typeMapping = mappingByField['type'];
    final qtyMapping = mappingByField['quantity'];
    final priceMapping = mappingByField['price'];
    final currencyMapping = mappingByField['currency'];
    final exchangeRateMapping = mappingByField['exchangeRate'];
    final commMapping = mappingByField['commission'];
    final descMapping = mappingByField['description'];
    final orderRefMapping = mappingByField['orderRef'];

    var imported = 0;
    var errorCount = 0;
    var attachedFees = 0;
    var unmatchedFees = 0;
    final errors = <String>[];

    // Pre-pass: collect external fee rows by (isin, orderRef) so the main
    // loop can fold them into the parent Buy/Sell's commission. When
    // orderRefMapping is null, fee rows are dropped silently — matching
    // the prior Skip behavior. When the type column isn't mapped or
    // feeValues is empty, this pre-pass is a no-op. Disabled in
    // single-asset mode (no per-row ISIN to key against).
    final externalFeeByKey = <String, double>{};
    final externalFeeUsed = <String, bool>{};
    if (targetAssetId == null && typeMapping != null && feeValues != null && feeValues.isNotEmpty) {
      for (final row in preview.rows) {
        final typeStr = _resolveMapping(typeMapping, row) ?? '';
        final normalized = typeStr.trim().toUpperCase().replaceAll(' ', '_');
        final isFee = feeValues.any((v) => v.trim().toUpperCase().replaceAll(' ', '_') == normalized);
        if (!isFee) continue;
        if (orderRefMapping == null) continue; // drop silently
        final orderRef = (_resolveMapping(orderRefMapping, row) ?? '').trim();
        if (orderRef.isEmpty) continue; // drop silently
        final isin = (_resolveMapping(isinMapping!, row) ?? '').trim().toUpperCase();
        if (isin.isEmpty) continue;
        final amountStr = amountMapping == null ? '' : (_resolveMapping(amountMapping, row) ?? '');
        final amt = _tryParseAmount(amountStr);
        if (amt == null) continue;
        final key = '$isin|$orderRef';
        externalFeeByKey[key] = (externalFeeByKey[key] ?? 0) + amt.abs();
        externalFeeUsed[key] = false;
      }
    }

    // First pass: collect unique ISINs and find/create assets.
    // Skipped entirely in single-asset (`targetAssetId`) mode — every
    // row routes to the pre-existing asset, no per-row ISIN to inspect.
    final isinToRows = <String, List<int>>{};
    if (targetAssetId == null) {
      for (var i = 0; i < preview.rows.length; i++) {
        final row = preview.rows[i];
        final isin = (_resolveMapping(isinMapping!, row) ?? '').trim().toUpperCase();
        if (isin.isEmpty) {
          errorCount++;
          errors.add('Skipped line ${i + 1}: empty ISIN');
          continue;
        }
        if (excludedIsins != null && excludedIsins.contains(isin)) {
          continue;
        }
        isinToRows.putIfAbsent(isin, () => []).add(i);
      }
      _log.info('importAssetEventsGrouped: found ${isinToRows.length} unique ISINs');
    } else {
      _log.info('importAssetEventsGrouped: single-asset mode, targetAssetId=$targetAssetId');
    }

    // Find or create asset for each ISIN. Scope the lookup to this
    // intermediary so the same ISIN held at two brokers produces two
    // independent asset rows (one per broker, each with its own events).
    // In single-asset mode, this loop is empty (isinToRows is empty).
    final assetsByIsin = <String, int>{};
    final existingByIsin = <String, int>{};
    if (targetAssetId == null) {
      final existingRows = await _db
          .customSelect(
            "SELECT id, isin FROM assets WHERE isin IS NOT NULL AND isin != '' "
            "AND intermediary_id = ?",
            variables: [Variable.withInt(intermediaryId)],
            readsFrom: {_db.assets},
          )
          .get();
      for (final row in existingRows) {
        existingByIsin[row.read<String>('isin').toUpperCase()] = row.read<int>('id');
      }
    }

    // Resolve new ISINs — use selected exchanges from UI if provided
    for (final isin in isinToRows.keys) {
      if (existingByIsin.containsKey(isin)) {
        assetsByIsin[isin] = existingByIsin[isin]!;
        _log.fine('importAssetEventsGrouped: reusing asset id=${existingByIsin[isin]} for ISIN=$isin');
      } else {
        // Use selected exchange from UI picker, or lookup first result
        final selected = selectedExchanges?[isin];
        String name;
        String? ticker;
        String? exchange;

        InstrumentType instrumentType = InstrumentType.etf;
        AssetClass assetClassValue = AssetClass.equity;

        if (selected != null) {
          name = selected.name;
          ticker = selected.ticker;
          exchange = selected.exchange;
          final (inst, cls) = selected.classification;
          instrumentType = inst;
          assetClassValue = cls;
        } else if (isinLookup != null) {
          final lookup = await isinLookup.lookup(isin);
          final best = lookup.bestFor(null);
          name = best?.name ?? isin;
          ticker = best?.ticker;
          exchange = best?.exchange;
          if (best != null) {
            final (inst, cls) = best.classification;
            instrumentType = inst;
            assetClassValue = cls;
          }
        } else {
          name = isin;
        }

        final currency = currencyMapping != null
            ? (_resolveMapping(currencyMapping, preview.rows[isinToRows[isin]!.first]) ?? baseCurrency)
            : baseCurrency;
        final assetId = await _db
            .into(_db.assets)
            .insert(
              AssetsCompanion.insert(
                name: name.length > 200 ? name.substring(0, 200) : name,
                assetType: AssetType.stockEtf,
                instrumentType: Value(instrumentType),
                assetClass: Value(assetClassValue),
                valuationMethod: ValuationMethod.marketPrice,
                ticker: Value(ticker),
                isin: Value(isin),
                currency: Value(currency),
                exchange: Value(exchange),
                intermediaryId: intermediaryId,
              ),
            );
        assetsByIsin[isin] = assetId;
        _log.info('importAssetEventsGrouped: created asset id=$assetId for ISIN=$isin, name=$name, ticker=$ticker, exchange=$exchange');
      }
    }

    // Build set of bond ISINs for price divisor
    final bondIsinRows = await _db
        .customSelect(
          "SELECT isin FROM assets WHERE instrument_type = 'bond' AND isin IS NOT NULL",
          readsFrom: {_db.assets},
        )
        .get();
    final bondIsins = <String>{};
    for (final row in bondIsinRows) {
      bondIsins.add(row.read<String>('isin').toUpperCase());
    }

    // Second pass: build event companions
    final companions = <AssetEventsCompanion>[];
    // Parallel income companions for pension contributions — one per
    // event row that A3 auto-fills (cash-only buy on an eventDriven
    // asset). Routed to the Income ledger so the user can audit
    // employer/state/voluntary cashflows; excluded from income totals
    // by `WHERE type NOT IN ('refund','pensionContribution')`.
    final incomeCompanions = <IncomesCompanion>[];
    const progressInterval = 100;

    // Look up the target asset once for single-asset mode, so we can
    // honor its valuationMethod when applying the contribute auto-fill
    // (A3 — qty=amount, price=1.0 fallback for cash-only event-driven
    // assets).
    Asset? targetAsset;
    if (targetAssetId != null) {
      targetAsset = await (_db.select(_db.assets)..where((a) => a.id.equals(targetAssetId))).getSingleOrNull();
    }

    for (var i = 0; i < preview.rows.length; i++) {
      final row = preview.rows[i];
      final String isin;
      final int? assetId;
      if (targetAssetId != null) {
        isin = '';
        assetId = targetAssetId;
      } else {
        isin = (_resolveMapping(isinMapping!, row) ?? '').trim().toUpperCase();
        assetId = assetsByIsin[isin];
      }
      if (assetId == null) {
        if (i % progressInterval == 0) onProgress?.call(i + 1, preview.rows.length);
        continue; // already counted as error in first pass
      }

      try {
        var valueDate = _tryParseDateMapping(mappingByField['valueDate'], row);
        late final DateTime date;
        if (dateMapping != null) {
          date = _parseDateWithFallback(_resolveMapping(dateMapping, row) ?? '', valueDate);
        } else {
          final now = DateTime.now();
          date = DateTime(now.year, now.month, now.day);
        }
        valueDate ??= date;

        final rawMetadata = <String, String>{};
        for (final col in preview.columns) {
          rawMetadata[col] = row[col] ?? '';
        }

        final qty = qtyMapping != null ? _tryParseAmount(_resolveMapping(qtyMapping, row)) : null;
        final price = priceMapping != null ? _tryParseAmount(_resolveMapping(priceMapping, row)) : null;

        // Amount: from column, or auto-calculated as quantity * price
        // For bonds, prices are quoted as % of face value → divide by 100
        final isBond = bondIsins.contains(isin);
        double amount;
        if (amountMapping != null) {
          final amountStr = _resolveMapping(amountMapping, row) ?? '';
          // Defer the strict parse when a per-type override column is
          // configured AND the primary cell is empty: a Revalue row's value
          // lives in the override column (e.g. Saldo), so the empty primary
          // amount (e.g. Entrate) must not abort the row here. The actual
          // value is resolved after the type is known (below). Non-revalue
          // rows with an empty amount still hit the strict parse there.
          if (amountStr.trim().isEmpty && revalueAmountColumn != null) {
            amount = 0;
          } else {
            amount = _parseAmount(amountStr);
          }
        } else {
          amount = autoCalcAmountFor(qty: qty, price: price, isBond: isBond);
        }
        final rate = exchangeRateMapping != null ? _tryParseAmount(_resolveMapping(exchangeRateMapping, row)) : null;

        // Event type: from column with custom mappings, or inferred from sign
        final EventType eventType;
        if (typeMapping != null) {
          final typeStr = _resolveMapping(typeMapping, row) ?? 'BUY';
          final parsed = _parseEventType(
            typeStr,
            buyValues: buyValues,
            sellValues: sellValues,
            feeValues: feeValues,
            revalueValues: revalueValues,
            contributeValues: contributeValues,
          );
          if (parsed == null) {
            // Fee row — already collected in the pre-pass. Skip from main
            // event creation; matching/attaching happens below per parent.
            continue;
          }
          eventType = parsed;
        } else if (negativeIsBuy) {
          // Cash-flow convention: only the amount sign matters. Quantity is
          // typically positive in these exports (e.g. Directa).
          eventType = amount < 0 ? EventType.buy : EventType.sell;
        } else {
          // Historical convention: a negative quantity OR a negative amount
          // indicates a sell.
          final isNeg = (qty != null && qty < 0) || amount < 0;
          eventType = isNeg ? EventType.sell : EventType.buy;
        }

        // Per-type amount source: a Revalue row's value is the absolute
        // position snapshot, which lives in a different column (e.g. Saldo)
        // than the per-row contribution amount (e.g. Entrate). When the
        // wizard maps a revalue amount column, re-read the amount from it for
        // revalue rows only.
        if (revalueAmountColumn != null && amountMapping != null) {
          if (eventType == EventType.revalue) {
            final raw = (row[revalueAmountColumn] ?? '').trim();
            // The snapshot value is required for a revalue row; parse strictly
            // so a missing position is surfaced, not silently zeroed.
            amount = _parseAmount(raw);
          } else {
            // Non-revalue row: the primary amount parse was deferred above
            // only to let revalue rows through. Enforce it now so a genuinely
            // empty contribution amount still errors instead of becoming 0.
            final primary = _resolveMapping(amountMapping, row) ?? '';
            if (primary.trim().isEmpty) {
              amount = _parseAmount(primary); // throws FormatException(Empty amount)
            }
          }
        }

        // A3 — Pension cash-only fallback: when the source has no
        // quantity/price columns AND this is a buy on an event-driven
        // asset, synthesize quantity=amount, price=1.0 so the resync's
        // qty-at-revalue anchor works (resyncRevaluePricesForAsset sums
        // buy.quantity into qty). When the user maps explicit
        // quantity/price columns (401(k), Group RRSP, planes de
        // pensiones), those win — no synthesis. Narrowly conditional so
        // it never overrides real data.
        double? effectiveQty = qty;
        double? effectivePrice = price;
        if (eventType == EventType.buy &&
            qtyMapping == null &&
            priceMapping == null &&
            targetAsset?.valuationMethod == ValuationMethod.eventDriven) {
          effectiveQty = amount;
          effectivePrice = 1.0;
        }

        // Price auto-calc (issue #96) — exact inverse of the Amount auto-calc
        // above (`amount = qty * price / bondDivisor`), and the same formula
        // the revalue anchor uses in `resyncRevaluePricesForAsset`
        // (`amount / qty * bondDivisor`). Without it, exports that carry only
        // Quantity + Amount leave `price` NULL, which drops the position from
        // `getAverageBuyPrice` (it filters on `price IS NOT NULL`).
        //
        // Buy/sell only: a revalue's amount is a TOTAL position snapshot, not
        // `qty * price`, and `rescaleBondEventAmounts` depends on that
        // invariant holding for the rows it rescales.
        //
        // Never invent a value: a missing/zero quantity or a zero amount
        // leaves the price NULL instead of writing a meaningless 0.
        if (autoCalcPrice &&
            effectivePrice == null &&
            (eventType == EventType.buy || eventType == EventType.sell) &&
            effectiveQty != null &&
            effectiveQty != 0 &&
            amount != 0) {
          effectivePrice = amount.abs() / effectiveQty.abs() * (isBond ? 100 : 1);
        }

        // External-row fee takes precedence over inline/computed:
        // when a Commissioni row matched this trade's (isin, orderRef),
        // those paths are ignored. They're independent in the wizard
        // but mutually exclusive per row — no broker emits both.
        double? commission;
        String? extKey;
        if (orderRefMapping != null && externalFeeByKey.isNotEmpty) {
          final orderRef = (_resolveMapping(orderRefMapping, row) ?? '').trim();
          if (orderRef.isNotEmpty) {
            final candidate = '$isin|$orderRef';
            if (externalFeeByKey.containsKey(candidate) && externalFeeUsed[candidate] != true) {
              commission = externalFeeByKey[candidate];
              extKey = candidate;
            }
          }
        }
        if (commission == null) {
          // Fall through to the existing inline paths.
          if (computeFee && qty != null && price != null) {
            if (exchangeRateMapping == null) {
              commission = (amount.abs() - qty.abs() * price).abs();
            } else if (rate != null && rate > 0) {
              commission = (amount.abs() - qty.abs() * price / rate).abs();
            }
          } else if (commMapping != null) {
            commission = _tryParseAmount(_resolveMapping(commMapping, row));
          }
        }
        if (extKey != null) {
          externalFeeUsed[extKey] = true;
          attachedFees++;
        }

        // Normalize qty to its absolute value. event.type carries direction;
        // some broker exports (Directa, Fineco, IB) store sells with negative
        // quantity, which would double-negate in the stats aggregation. See
        // issue #77.
        companions.add(
          AssetEventsCompanion.insert(
            assetId: assetId,
            date: date,
            valueDate: valueDate,
            type: eventType,
            amount: amount,
            quantity: Value(effectiveQty?.abs()),
            price: Value(effectivePrice),
            currency: Value(currencyMapping != null ? (_resolveMapping(currencyMapping, row) ?? baseCurrency) : baseCurrency),
            exchangeRate: Value(rate),
            commission: Value(commission),
            notes: Value(descMapping != null ? _resolveMapping(descMapping, row) : null),
            rawMetadata: Value(jsonEncode(rawMetadata)),
          ),
        );
        // Pension-contribution mirror: same condition as A3 auto-fill.
        // When the cash-only synthesis triggered, this row represents a
        // contribution to a pension fund — replicate it as an Income
        // entry so the Accounts → Income tab shows the cashflow.
        if (eventType == EventType.buy &&
            qtyMapping == null &&
            priceMapping == null &&
            targetAsset?.valuationMethod == ValuationMethod.eventDriven &&
            targetAssetId != null) {
          incomeCompanions.add(
            IncomesCompanion.insert(
              date: date,
              valueDate: valueDate,
              amount: amount,
              type: const Value(IncomeType.pensionContribution),
              currency: Value(currencyMapping != null ? (_resolveMapping(currencyMapping, row) ?? baseCurrency) : baseCurrency),
              assetId: Value(targetAssetId),
            ),
          );
        }
        imported++;
      } catch (e, stack) {
        errorCount++;
        errors.add('Skipped line ${i + 1}: $e');
        _log.warning('importAssetEventsGrouped: skipped line ${i + 1}: $e', e, stack);
      }
      if (i % progressInterval == 0) onProgress?.call(i + 1, preview.rows.length);
    }

    onProgress?.call(preview.rows.length, preview.rows.length);

    // Every row failed to parse — return an explicit error result instead of
    // continuing into the wipe step (which would `reduce` an empty list).
    if (companions.isEmpty) {
      _log.warning('importAssetEventsGrouped: no rows parsed (errors=$errorCount)');
      return AssetImportResult(
        result: ImportResult(
          totalRows: preview.totalRows,
          importedRows: 0,
          errorRows: errorCount,
          errors: errors,
        ),
        assetsByIsin: const {},
      );
    }

    // Wipe-and-replace: for spot imports (no date column) delete ALL existing
    // events for the scope; for transaction imports keep the date-based cutoff.
    final isSpot = dateMapping == null;
    var totalDeleted = 0;
    // Group companions by assetId (needed for rate backfill later)
    final byAsset = <int, List<AssetEventsCompanion>>{};
    for (final c in companions) {
      (byAsset[c.assetId.value] ??= []).add(c);
    }

    if (isSpot) {
      // Spot import: scope wipe to the assets we just touched. In
      // ISIN-grouped mode that's everything under this intermediary
      // (existing behavior). In single-asset mode (`targetAssetId`)
      // it's that one asset only — re-importing a pension statement
      // must NOT wipe events on unrelated assets that happen to share
      // the intermediary.
      if (targetAssetId != null) {
        totalDeleted = await _db.customUpdate(
          'DELETE FROM asset_events WHERE asset_id = ?',
          variables: [Variable.withInt(targetAssetId)],
          updates: {_db.assetEvents},
        );
        _log.info('importAssetEventsGrouped: spot wipe targetAssetId $targetAssetId - deleted $totalDeleted events');
      } else {
        totalDeleted = await _db.customUpdate(
          'DELETE FROM asset_events WHERE asset_id IN '
          '(SELECT id FROM assets WHERE intermediary_id = ?)',
          variables: [Variable.withInt(intermediaryId)],
          updates: {_db.assetEvents},
        );
        _log.info('importAssetEventsGrouped: spot wipe intermediary $intermediaryId - deleted $totalDeleted events');
      }
    } else {
      // Transaction import: date-based wipe-and-replace. Scope to the
      // single asset in single-asset mode; otherwise to the
      // intermediary's assets.
      final globalOldest = companions.map((c) => c.date.value).reduce((a, b) => a.isBefore(b) ? a : b);
      final globalCutoff = DateTime(globalOldest.year, globalOldest.month, globalOldest.day);
      final cutoffEpoch = globalCutoff.millisecondsSinceEpoch ~/ 1000;
      if (targetAssetId != null) {
        totalDeleted = await _db.customUpdate(
          'DELETE FROM asset_events WHERE asset_id = ? AND date >= ?',
          variables: [Variable.withInt(targetAssetId), Variable.withInt(cutoffEpoch)],
          updates: {_db.assetEvents},
        );
        _log.info('importAssetEventsGrouped: targetAssetId $targetAssetId - deleted $totalDeleted events from ${formatYmd(globalCutoff)}');
      } else {
        totalDeleted = await _db.customUpdate(
          'DELETE FROM asset_events WHERE asset_id IN '
          '(SELECT id FROM assets WHERE intermediary_id = ?) AND date >= ?',
          variables: [Variable.withInt(intermediaryId), Variable.withInt(cutoffEpoch)],
          updates: {_db.assetEvents},
        );
        _log.info('importAssetEventsGrouped: intermediary $intermediaryId - deleted $totalDeleted events from ${formatYmd(globalCutoff)}');
      }
    }

    _log.info('importAssetEventsGrouped: batch-inserting ${companions.length} events (deleted $totalDeleted old)');
    await _db.batch((batch) {
      batch.insertAll(_db.assetEvents, companions);
    });

    // Mirror pension-contribution income rows. Wipe any prior rows
    // attached to this asset (idempotent re-imports); then bulk-insert
    // the new ones. Scoped by `(asset_id, type='pensionContribution')`
    // so unrelated income entries on the same intermediary stay intact.
    if (incomeCompanions.isNotEmpty && targetAssetId != null) {
      final wiped = await _db.customUpdate(
        "DELETE FROM incomes WHERE asset_id = ? AND type = 'pensionContribution'",
        variables: [Variable.withInt(targetAssetId)],
        updates: {_db.incomes},
      );
      await _db.batch((batch) {
        batch.insertAll(_db.incomes, incomeCompanions);
      });
      _log.info('importAssetEventsGrouped: pension-contribution income rows: wiped=$wiped, inserted=${incomeCompanions.length}');
    }

    // Materialize revalue events into `market_prices` for every touched
    // asset. The batch insert above bypasses AssetEventService.create's
    // post-CRUD resync, so without this loop a freshly-imported pension
    // statement leaves manual assets with zero market_prices rows — the
    // single-asset chart provider returns null in that state and no
    // graph renders. See asset_event_service.resyncRevaluePricesForAsset.
    final eventService = AssetEventService(_db);
    final assetIdsToResync = <int>{
      ...byAsset.keys,
      ?targetAssetId,
    };
    for (final aid in assetIdsToResync) {
      await eventService.resyncRevaluePricesForAsset(aid);
    }
    if (assetIdsToResync.isNotEmpty) {
      _log.info('importAssetEventsGrouped: resynced market_prices for ${assetIdsToResync.length} asset(s)');
    }

    // Fill missing exchange rates from historical data
    if (rateService != null) {
      var filled = 0;
      for (final assetId in byAsset.keys) {
        final events = await (_db.select(
          _db.assetEvents,
        )..where((e) => e.assetId.equals(assetId) & e.exchangeRate.isNull() & e.currency.equals(baseCurrency).not())).get();
        for (final ev in events) {
          final rate = await rateService.getRate(baseCurrency, ev.currency, ev.date);
          if (rate != null) {
            await (_db.update(_db.assetEvents)..where((e) => e.id.equals(ev.id))).write(AssetEventsCompanion(exchangeRate: Value(rate)));
            filled++;
          }
        }
      }
      if (filled > 0) _log.info('importAssetEventsGrouped: filled $filled missing exchange rates');
    }

    // Tally external fee rows that found no matching parent in this batch.
    for (final used in externalFeeUsed.values) {
      if (!used) unmatchedFees++;
    }
    if (unmatchedFees > 0) {
      _log.warning('importAssetEventsGrouped: $unmatchedFees external fee row(s) had no matching parent (isin, orderRef)');
    }
    _log.info(
      'importAssetEventsGrouped: done - imported=$imported, deleted=$totalDeleted, errors=$errorCount, assets=${assetsByIsin.length}, attachedFees=$attachedFees, unmatchedFees=$unmatchedFees',
    );
    return AssetImportResult(
      result: ImportResult(
        totalRows: preview.totalRows,
        importedRows: imported,
        errorRows: errorCount,
        errors: errors,
        attachedFees: attachedFees,
        unmatchedFees: unmatchedFees,
      ),
      assetsByIsin: assetsByIsin,
    );
  }

  Future<AssetEventImportPreview> previewAssetEventImport({
    required FilePreview preview,
    required List<ColumnMapping> mappings,
    Set<String>? buyValues,
    Set<String>? sellValues,
    Set<String>? feeValues,
    bool negativeIsBuy = false,
    Set<String>? revalueValues,
    Set<String>? contributeValues,
    Set<String>? excludedIsins,
    Map<String, IsinExchangeOption>? selectedExchanges,

    /// Locale used for parsing during preview only — NOT persisted.
    /// Caller resolves to whatever the wizard selection is right now.
    String? numberLocale,
    String? appLocale,

    /// Single-asset mode mirror of `importAssetEventsGrouped` — when set,
    /// the ISIN column is optional and the per-asset summary is keyed by
    /// a synthetic placeholder so the wizard's preview block can still
    /// render row counts.
    int? targetAssetId,

    /// Mirror of `importAssetEventsGrouped.revalueAmountColumn`: read a
    /// Revalue row's amount from this column instead of the primary amount
    /// mapping. Kept in sync so the dry-run preview matches the real import.
    String? revalueAmountColumn,
  }) async {
    _activeLocale = amt.resolveImportLocale(
      saved: numberLocale,
      appLocale: appLocale,
    );
    _log.info('previewAssetEventImport: ${preview.totalRows} rows, locale=$_activeLocale');
    final mappingByField = {for (final m in mappings) m.targetField: m};
    final isinMapping = mappingByField['isin'];

    // Either ISIN-grouped (existing) or single-asset target — same gate
    // as importAssetEventsGrouped.
    if (isinMapping == null && targetAssetId == null) {
      return const AssetEventImportPreview(
        parsedRows: 0,
        errorRows: 0,
        assetSummary: {},
        errors: ['ISIN column is required (or pass targetAssetId for single-asset import)'],
      );
    }

    // Synthetic key used as the asset-summary bucket in single-asset mode.
    // Real ISIN-mode keys come straight from the row; this key never
    // collides with a real ISIN because it isn't 12 chars uppercase.
    final singleAssetKey = '_target_$targetAssetId';

    final typeMapping = mappingByField['type'];
    final qtyMapping = mappingByField['quantity'];
    final amountMapping = mappingByField['amount'];
    final previewPriceMapping = mappingByField['price'];
    final currencyMapping = mappingByField['currency'];
    final orderRefMapping = mappingByField['orderRef'];
    final dateMapping = mappingByField['date'];
    final valueDateMapping = mappingByField['valueDate'];

    var parsed = 0;
    var errorCount = 0;
    var attachedFees = 0;
    var unmatchedFees = 0;
    final errors = <String>[];

    // Accumulate per-ISIN: buyCount, sellCount, netQty
    final buyCountByIsin = <String, int>{};
    final sellCountByIsin = <String, int>{};
    final netQtyByIsin = <String, double>{};
    final currencyByIsin = <String, String>{};

    // Pre-pass: tally external fee rows by (isin, orderRef) so the main
    // loop can mark them as attached when their parent appears. Mirrors
    // the live-import pre-pass exactly.
    final feeKeysSeen = <String, bool>{}; // key → "matched in main pass?"
    if (isinMapping != null && typeMapping != null && feeValues != null && feeValues.isNotEmpty) {
      for (final row in preview.rows) {
        final typeStr = _resolveMapping(typeMapping, row) ?? '';
        final normalized = typeStr.trim().toUpperCase().replaceAll(' ', '_');
        final isFee = feeValues.any((v) => v.trim().toUpperCase().replaceAll(' ', '_') == normalized);
        if (!isFee) continue;
        if (orderRefMapping == null) continue;
        final orderRef = (_resolveMapping(orderRefMapping, row) ?? '').trim();
        if (orderRef.isEmpty) continue;
        final isin = (_resolveMapping(isinMapping, row) ?? '').trim().toUpperCase();
        if (isin.isEmpty) continue;
        feeKeysSeen.putIfAbsent('$isin|$orderRef', () => false);
      }
    }

    for (var i = 0; i < preview.rows.length; i++) {
      final row = preview.rows[i];
      try {
        final String isin;
        if (targetAssetId != null) {
          isin = singleAssetKey;
        } else {
          isin = (_resolveMapping(isinMapping!, row) ?? '').trim().toUpperCase();
          if (isin.isEmpty) {
            errorCount++;
            if (errors.length < 5) errors.add('Line ${i + 1}: empty ISIN');
            continue;
          }
          if (excludedIsins != null && excludedIsins.contains(isin)) continue;
        }

        final qty = qtyMapping != null ? _tryParseAmount(_resolveMapping(qtyMapping, row)) : null;
        // Mirror the import's Auto-calc: with no amount column the amount comes
        // from quantity x price, and its SIGN decides buy vs sell below. The
        // bond divisor is irrelevant here (it cannot flip a sign) so instrument
        // types are not looked up for the dry run.
        final price = previewPriceMapping != null ? _tryParseAmount(_resolveMapping(previewPriceMapping, row)) : null;
        final amount = amountMapping != null
            ? _tryParseAmount(_resolveMapping(amountMapping, row))
            : autoCalcAmountFor(qty: qty, price: price, isBond: false);

        // Determine event type
        final EventType eventType;
        if (typeMapping != null) {
          final typeStr = _resolveMapping(typeMapping, row) ?? 'BUY';
          final parsed = _parseEventType(
            typeStr,
            buyValues: buyValues,
            sellValues: sellValues,
            feeValues: feeValues,
            revalueValues: revalueValues,
            contributeValues: contributeValues,
          );
          if (parsed == null) continue; // fee row — counted in pre-pass
          eventType = parsed;
        } else if (negativeIsBuy) {
          eventType = (amount != null && amount < 0) ? EventType.buy : EventType.sell;
        } else {
          final isNeg = (qty != null && qty < 0) || (amount != null && amount < 0);
          eventType = isNeg ? EventType.sell : EventType.buy;
        }

        // Validate date + amount with the SAME strict rules the real import
        // uses, so the dry-run preview surfaces "Empty date" / "Empty amount"
        // errors here (where the user can still fix the config) instead of
        // only at import time. Honors the per-type revalue overrides.
        if (dateMapping != null) {
          final dateStr = _resolveMapping(dateMapping, row) ?? '';
          final vd = _tryParseDateMapping(valueDateMapping, row);
          _parseDateWithFallback(dateStr, vd); // throws on empty/unparseable
        }
        if (amountMapping != null) {
          final primaryStr = _resolveMapping(amountMapping, row) ?? '';
          if (eventType == EventType.revalue && revalueAmountColumn != null) {
            _parseAmount((row[revalueAmountColumn] ?? '').trim());
          } else {
            _parseAmount(primaryStr);
          }
        }

        final absQty = qty?.abs() ?? 0;
        buyCountByIsin[isin] = (buyCountByIsin[isin] ?? 0) + (eventType == EventType.buy ? 1 : 0);
        sellCountByIsin[isin] = (sellCountByIsin[isin] ?? 0) + (eventType == EventType.sell ? 1 : 0);
        netQtyByIsin[isin] = (netQtyByIsin[isin] ?? 0) + (eventType == EventType.sell ? -absQty : absQty);

        if (currencyMapping != null && !currencyByIsin.containsKey(isin)) {
          currencyByIsin[isin] = (_resolveMapping(currencyMapping, row) ?? '').trim();
        }

        // Mark a matching external fee row as "attached" so the unmatched
        // tally below is accurate.
        if (orderRefMapping != null && feeKeysSeen.isNotEmpty) {
          final orderRef = (_resolveMapping(orderRefMapping, row) ?? '').trim();
          if (orderRef.isNotEmpty) {
            final key = '$isin|$orderRef';
            if (feeKeysSeen.containsKey(key) && feeKeysSeen[key] == false) {
              feeKeysSeen[key] = true;
              attachedFees++;
            }
          }
        }

        parsed++;
      } catch (e) {
        errorCount++;
        if (errors.length < 5) errors.add('Line ${i + 1}: $e');
      }
    }
    for (final used in feeKeysSeen.values) {
      if (!used) unmatchedFees++;
    }

    // Look up existing asset names for known ISINs
    final existingNames = <String, String>{};
    final existingRows = await _db
        .customSelect(
          "SELECT isin, name FROM assets WHERE isin IS NOT NULL AND isin != ''",
          readsFrom: {_db.assets},
        )
        .get();
    for (final row in existingRows) {
      existingNames[row.read<String>('isin').toUpperCase()] = row.read<String>('name');
    }

    final summary = <String, AssetPreviewSummary>{};
    for (final isin in netQtyByIsin.keys) {
      final name = existingNames[isin] ?? selectedExchanges?[isin]?.name;
      summary[isin] = AssetPreviewSummary(
        isin: isin,
        name: name,
        buyCount: buyCountByIsin[isin] ?? 0,
        sellCount: sellCountByIsin[isin] ?? 0,
        netQuantity: netQtyByIsin[isin] ?? 0,
        currency: currencyByIsin[isin],
      );
    }

    _log.info(
      'previewAssetEventImport: parsed=$parsed, errors=$errorCount, assets=${summary.length}, attachedFees=$attachedFees, unmatchedFees=$unmatchedFees',
    );
    return AssetEventImportPreview(
      parsedRows: parsed,
      errorRows: errorCount,
      errors: errors,
      assetSummary: summary,
      attachedFees: attachedFees,
      unmatchedFees: unmatchedFees,
    );
  }
}
