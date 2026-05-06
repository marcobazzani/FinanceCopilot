import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:intl/intl.dart';

import '../database/database.dart';
import '../database/tables.dart';
import 'asset_event_service.dart';
import '../utils/amount_parser.dart' as amt;
import '../utils/date_parser.dart' as date_parse;
import '../utils/formatters.dart' show formatYmd;
import '../utils/logger.dart';
import 'exchange_rate_service.dart';
import 'file_parser_service.dart';
import 'isin_lookup_service.dart';
import 'market_price_service.dart' show investingExchangeToCode;

final _log = getLogger('ImportService');

/// A single term in a formula: an operator (+/-) and a source column.
class FormulaTerm {
  final String operator; // '+' or '-'
  final String sourceColumn;

  const FormulaTerm({required this.operator, required this.sourceColumn});
}

/// Column mapping: user picks which source column maps to which target field.
/// For simple mappings, [sourceColumn] is set.
/// For formula mappings (e.g. amount = ColA + ColB), [formulaTerms] is set instead.
/// For balance-diff mode, [balanceDiffColumn] is set — amount is computed as
/// the difference between consecutive balance values.
class ColumnMapping {
  final String? sourceColumn;
  final String targetField; // e.g. 'date', 'amount', 'description', etc.
  final List<FormulaTerm>? formulaTerms;
  final String? balanceDiffColumn;
  final List<String>? multiColumns; // combine multiple columns (concat strings, sum numbers)
  final String multiDelimiter; // delimiter for string concatenation (default: space)

  const ColumnMapping({this.sourceColumn, required this.targetField, this.formulaTerms, this.balanceDiffColumn, this.multiColumns, this.multiDelimiter = ' '});

  bool get isFormula => formulaTerms != null && formulaTerms!.isNotEmpty;
  bool get isBalanceDiff => balanceDiffColumn != null;
  bool get isMultiColumn => multiColumns != null && multiColumns!.length > 1;
}

/// Result of parsing a file before column mapping.
class FilePreview {
  final List<String> columns;
  /// Preview rows for UI display (first 5 + last 5 = max 10).
  /// For full row access during import, re-parse the file.
  final List<Map<String, String>> rows;
  final int totalRows;

  /// Source file metadata for re-parsing during import.
  final String? filePath;
  final String? clipboardText;
  final int skipRows;
  final bool noHeader;
  final String? sheetName;
  /// Locale used to format numeric XLSX cells when stringifying. Stored so
  /// `getFullRows` can detect when a locale change requires re-parsing.
  final String? numberLocale;

  const FilePreview({
    required this.columns,
    required this.rows,
    required this.totalRows,
    this.filePath,
    this.clipboardText,
    this.skipRows = 0,
    this.noHeader = false,
    this.sheetName,
    this.numberLocale,
  });
}

/// Result of an import operation.
class ImportResult {
  final int totalRows;
  final int importedRows;
  final int deletedRows;
  final int errorRows;
  final List<String> errors;
  /// External fee rows (asset imports) whose `(isin, orderRef)` key matched
  /// no parent Buy/Sell. The fee amount was discarded; the count is
  /// surfaced so the user can investigate. Always 0 for transaction imports.
  final int unmatchedFees;
  /// External fee rows successfully folded into a parent's `commission`.
  final int attachedFees;

  const ImportResult({
    required this.totalRows,
    required this.importedRows,
    this.deletedRows = 0,
    required this.errorRows,
    this.errors = const [],
    this.unmatchedFees = 0,
    this.attachedFees = 0,
  });
}

/// Target entity type for import.
enum ImportTarget { transaction, assetEvent, income }

/// Result of an asset import that groups by ISIN.
class AssetImportResult {
  final ImportResult result;
  final Map<String, int> assetsByIsin; // ISIN → asset ID
  const AssetImportResult({required this.result, required this.assetsByIsin});
}

/// Preview of a transaction import (dry run, no DB writes).
class TransactionImportPreview {
  final int parsedRows;
  final int errorRows;
  final List<String> errors;
  final double importSum;
  final double? predictedBalance;
  final int rowsToReplace;

  const TransactionImportPreview({
    required this.parsedRows,
    required this.errorRows,
    this.errors = const [],
    required this.importSum,
    this.predictedBalance,
    required this.rowsToReplace,
  });
}

/// Summary of a single asset in an asset event import preview.
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

/// Preview of an asset event import (dry run, no DB writes).
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

/// Generic file importer: applies user column mapping, hashes rows for dedup,
/// and inserts. File parsing is delegated to [FileParserService].
class ImportService {
  final AppDatabase _db;
  final FileParserService _parser = FileParserService();

  /// Locale used for the current import call. Set by each public import
  /// method before any number parsing happens, then read by `_parseAmount`
  /// and `_tryParseAmount`. Defaults to en_US for safety.
  // ignore: prefer_final_fields  // mutated per import call
  String _activeLocale = 'en_US';

  ImportService(this._db);

  // ──────────────────────────────────────────────
  // Step 1: Parse file → FilePreview (delegates to FileParserService)
  // ──────────────────────────────────────────────

  Future<FilePreview> parseFile(String filePath, {String? sheetName, int skipRows = 0, bool noHeader = false, String? numberLocale}) =>
      _parser.parseFile(filePath, sheetName: sheetName, skipRows: skipRows, noHeader: noHeader, numberLocale: numberLocale);

  Future<List<String>> listSheets(String filePath) => _parser.listSheets(filePath);

  Future<FilePreview> parseClipboard(String text, {int skipRows = 0, bool noHeader = false}) =>
      _parser.parseClipboard(text, skipRows: skipRows, noHeader: noHeader);

  Future<FilePreview> getFullRows(FilePreview preview, {String? numberLocale}) =>
      _parser.getFullRows(preview, numberLocale: numberLocale);

  // ──────────────────────────────────────────────
  // Helpers: mapping resolution
  // ──────────────────────────────────────────────

  /// Resolve a mapping value from a row: simple column lookup, formula, or multi-column.
  String? _resolveMapping(ColumnMapping mapping, Map<String, String> row) {
    if (mapping.isFormula) {
      return _evaluateFormula(mapping.formulaTerms!, row);
    }
    if (mapping.isMultiColumn) {
      return _resolveMultiColumn(mapping.multiColumns!, row, mapping.multiDelimiter);
    }
    return row[mapping.sourceColumn];
  }

  /// Combine multiple columns: if all values are numeric → sum, otherwise concatenate with delimiter.
  String _resolveMultiColumn(List<String> columns, Map<String, String> row, String delimiter) {
    final values = columns.map((c) => (row[c] ?? '').trim()).where((v) => v.isNotEmpty).toList();
    if (values.isEmpty) return '';

    // Try numeric sum
    final nums = values.map((v) => _tryParseAmount(v)).toList();
    if (nums.every((n) => n != null)) {
      return _formatAmount(nums.fold(0.0, (a, b) => a + b!));
    }

    // String concatenation with delimiter
    return values.join(delimiter);
  }

  /// Evaluate a formula: sum of terms (each term is +/- a column's numeric value).
  ///
  /// Empty cells contribute 0 (a missing optional column is fine). A non-empty
  /// cell that fails to parse signals bad data — return an empty string so the
  /// Build per-row amounts from running balances: each amount is the
  /// difference between this row's balance and the most recent prior valid
  /// balance. The first row has no prior balance and contributes 0; rows
  /// with missing/garbage cells also contribute 0 but do NOT clear the
  /// last-known balance, so a single bad cell doesn't cause the next row
  /// to look like a huge transaction.
  List<double> _computeBalanceDiffs(
      List<Map<String, String>> rows, String balCol) {
    final out = <double>[];
    double? prevBalance;
    for (final row in rows) {
      final balance = _tryParseAmount(row[balCol] ?? '');
      if (balance != null && prevBalance != null) {
        out.add(balance - prevBalance);
      } else {
        out.add(0);
      }
      if (balance != null) prevBalance = balance;
    }
    return out;
  }

  /// row's amount surfaces as missing rather than producing a half-correct sum.
  String _evaluateFormula(List<FormulaTerm> terms, Map<String, String> row) {
    double result = 0;
    for (final term in terms) {
      final raw = (row[term.sourceColumn] ?? '').trim();
      if (raw.isEmpty) continue;
      final value = _tryParseAmount(raw);
      if (value == null) {
        _log.warning('formula: unparseable value "$raw" in column ${term.sourceColumn} - row dropped');
        return '';
      }
      if (term.operator == '-') {
        result -= value;
      } else {
        result += value;
      }
    }
    return _formatAmount(result);
  }

  /// Format a numeric result so it round-trips through `_parseAmount`. Plain
  /// `toString()` always emits '.' as decimal — which it_IT (and other EU
  /// locales) then re-parse as a thousands separator, multiplying the value.
  String _formatAmount(double v) =>
      NumberFormat.decimalPattern(_activeLocale).format(v);

  /// Re-parse the underlying file when the preview's `numberLocale` no
  /// longer matches `_activeLocale`. Only matters for XLSX (numeric cells
  /// are formatted at parse time). CSV/clipboard text is locale-agnostic
  /// at the row-string level, so it's a no-op there.
  ///
  /// If the source file is unavailable (e.g. integration tests that copy
  /// to a tmp dir and delete it), fall back to re-formatting the in-memory
  /// row strings: numeric-looking dot-decimal values get rewritten in the
  /// active locale's format. CSV columns with text content are never
  /// numeric-shaped so this is safe.
  Future<FilePreview> _ensurePreviewLocale(FilePreview preview) async {
    if (preview.numberLocale == _activeLocale) return preview;
    if (preview.filePath == null) return _reformatPreviewInPlace(preview);
    final ext = preview.filePath!.toLowerCase().split('.').last;
    if (ext != 'xlsx' && ext != 'xls') return preview;
    if (!await File(preview.filePath!).exists()) {
      return _reformatPreviewInPlace(preview);
    }
    // Inline re-parse (no Isolate.run): test environments pump a handful
    // of frames and would otherwise time out waiting for an isolate.
    return _parser.getFullRowsInProcess(preview, numberLocale: _activeLocale);
  }

  /// Rewrite strings that look like a Dart-default `double.toString()`
  /// (e.g. "7707.97", "-42.5") so they round-trip through the active
  /// locale's parser. Invariant: only digits, optional sign, exactly one
  /// dot — that's the shape XLSX cells produce when no locale is given.
  static final _dotDecimal = RegExp(r'^-?\d+\.\d+$');
  FilePreview _reformatPreviewInPlace(FilePreview preview) {
    final fmt = NumberFormat.decimalPattern(_activeLocale);
    final newRows = preview.rows.map((row) {
      final out = <String, String>{};
      row.forEach((k, v) {
        if (_dotDecimal.hasMatch(v)) {
          out[k] = fmt.format(double.parse(v));
        } else {
          out[k] = v;
        }
      });
      return out;
    }).toList();
    return FilePreview(
      columns: preview.columns,
      rows: newRows,
      totalRows: preview.totalRows,
      filePath: preview.filePath,
      clipboardText: preview.clipboardText,
      skipRows: preview.skipRows,
      noHeader: preview.noHeader,
      sheetName: preview.sheetName,
      numberLocale: _activeLocale,
    );
  }

  // ──────────────────────────────────────────────
  // Step 3: Import with mapping + dedup
  // ──────────────────────────────────────────────

  /// Import rows as Transactions.
  /// Algorithm: find the oldest date in the CSV, delete all DB rows for this
  /// account from that date onward, then insert all CSV rows. This guarantees
  /// no orphan rows from previous imports with changed data.
  Future<ImportResult> importTransactions({
    required FilePreview preview,
    required List<ColumnMapping> mappings,
    required int accountId,
    void Function(int processed, int total)? onProgress,
    String balanceMode = 'cumulative',
    String? balanceFilterColumn,
    Set<String>? balanceFilterInclude,
    /// User's per-import locale choice from the wizard. Persisted to
    /// `ImportConfigs.numberLocale` for this account when non-null.
    /// NULL means "Auto — fall back to the saved value or [appLocale]".
    String? numberLocaleOverride,
    /// App's configured locale (e.g. `it_IT`). Used as the final fallback
    /// when no per-source override or saved value exists.
    String? appLocale,
  }) async {
    await _setLocaleForAccount(
      accountId: accountId,
      override: numberLocaleOverride,
      appLocale: appLocale,
    );
    preview = await _ensurePreviewLocale(preview);
    _log.info('importTransactions: accountId=$accountId, ${preview.totalRows} rows, ${mappings.length} mappings, locale=$_activeLocale');
    final mappingByField = {for (final m in mappings) m.targetField: m};
    final dateMapping = mappingByField['date'];
    final amountMapping = mappingByField['amount'];

    if (dateMapping == null || amountMapping == null) {
      _log.severe('importTransactions: missing required mappings');
      return const ImportResult(
        totalRows: 0, importedRows: 0, errorRows: 0,
        errors: ['date and amount columns are required'],
      );
    }

    // Pre-compute balance-diff amounts if needed.
    List<double>? balanceDiffAmounts;
    if (amountMapping.isBalanceDiff) {
      _log.info('importTransactions: balance-diff mode, column=${amountMapping.balanceDiffColumn}');
      balanceDiffAmounts = _computeBalanceDiffs(
          preview.rows, amountMapping.balanceDiffColumn!);
    }

    // Fetch account's currency for fallback
    final account = await (_db.select(_db.accounts)..where((a) => a.id.equals(accountId))).getSingle();
    final accountCurrency = account.currency;

    // Pre-resolve field mappings once
    final descMapping = mappingByField['description'];
    final balanceMapping = mappingByField['balanceAfter'];
    final currencyMapping = mappingByField['currency'];
    final valueDateMapping = mappingByField['valueDate'];
    final statusMapping = mappingByField['status'];

    // Parse all rows
    var imported = 0;
    var errorCount = 0;
    final errors = <String>[];
    final parsedRows = <_ParsedTransactionRow>[];
    const progressInterval = 100;

    for (var i = 0; i < preview.rows.length; i++) {
      final row = preview.rows[i];
      try {
        final dateStr = _resolveMapping(dateMapping, row) ?? '';
        final double amount;
        if (balanceDiffAmounts != null) {
          amount = balanceDiffAmounts[i];
        } else {
          final amountStr = _resolveMapping(amountMapping, row) ?? '';
          amount = _parseAmount(amountStr);
        }

        var valueDate = _tryParseDateMapping(valueDateMapping, row);
        final date = _parseDateWithFallback(dateStr, valueDate);
        valueDate ??= date;

        final rawMetadata = <String, String>{};
        for (final col in preview.columns) {
          rawMetadata[col] = row[col] ?? '';
        }

        TransactionStatus? txStatus;
        if (statusMapping != null) {
          final sStr = (_resolveMapping(statusMapping, row) ?? '').toLowerCase().trim();
          txStatus = TransactionStatus.values.where((s) => s.name.toLowerCase() == sStr).firstOrNull;
        }

        parsedRows.add(_ParsedTransactionRow(
          date: date,
          valueDate: valueDate,
          amount: amount,
          description: descMapping != null ? (_resolveMapping(descMapping, row) ?? '') : '',
          balanceAfterFromColumn: balanceMapping != null ? _tryParseAmount(_resolveMapping(balanceMapping, row)) : null,
          currency: currencyMapping != null ? (_resolveMapping(currencyMapping, row) ?? accountCurrency) : accountCurrency,
          status: txStatus,
          rawMetadata: rawMetadata,
          hash: null,
          filterColumnValue: balanceFilterColumn != null ? (row[balanceFilterColumn] ?? '').trim() : null,
          csvIndex: i,
        ));
        imported++;
      } catch (e, stack) {
        errorCount++;
        errors.add('Skipped line ${i + 1}: $e');
        _log.warning('importTransactions: skipped line ${i + 1}: $e', e, stack);
      }
      if (i % progressInterval == 0) onProgress?.call(i + 1, preview.rows.length);
    }

    if (parsedRows.isEmpty) {
      return ImportResult(totalRows: preview.totalRows, importedRows: 0, errorRows: errorCount, errors: errors);
    }

    // Find the oldest date in the parsed rows
    final oldestDate = parsedRows.map((r) => r.date).reduce((a, b) => a.isBefore(b) ? a : b);
    final cutoffEpoch = DateTime(oldestDate.year, oldestDate.month, oldestDate.day).millisecondsSinceEpoch ~/ 1000;

    // Seed cumulative balance from the true pre-cutoff sum so newly inserted
    // rows continue from the existing account balance instead of restarting at 0.
    final preCutoffBalance = await _preCutoffBalance(accountId, cutoffEpoch, balanceMode: balanceMode);

    // Compute balanceAfter
    _computeBalances(parsedRows, balanceMode, balanceFilterInclude, preCutoffBalance);

    // Delete all DB rows for this account from oldest CSV date onward
    final deleted = await _db.customUpdate(
      'DELETE FROM transactions WHERE account_id = ? AND operation_date >= ?',
      variables: [Variable.withInt(accountId), Variable.withInt(cutoffEpoch)],
      updates: {_db.transactions},
    );
    _log.info('importTransactions: deleted $deleted rows from ${formatYmd(oldestDate)} onward');

    // Report parsing complete, starting DB write
    onProgress?.call(preview.rows.length, preview.rows.length);

    // Batch insert all parsed rows
    final companions = parsedRows.map((r) => TransactionsCompanion.insert(
      accountId: accountId,
      operationDate: r.date,
      valueDate: r.valueDate ?? r.date,
      amount: r.amount,
      description: Value(r.description),
      balanceAfter: Value(r.balanceAfter),
      currency: Value(r.currency),
      status: r.status != null ? Value(r.status!) : const Value.absent(),
      rawMetadata: Value(jsonEncode(r.rawMetadata)),
    )).toList();

    _log.info('importTransactions: batch-inserting ${companions.length} rows');
    await _db.batch((batch) {
      batch.insertAll(_db.transactions, companions);
    });

    _log.info('importTransactions: done - imported=$imported, deleted=$deleted, errors=$errorCount');
    return ImportResult(
      totalRows: preview.totalRows,
      importedRows: imported,
      deletedRows: deleted,
      errorRows: errorCount,
      errors: errors,
    );
  }

  /// Import rows as AssetEvents, grouped by ISIN.
  /// Auto-creates Asset entries for each unique ISIN found in the data.
  /// Returns the import result plus a map of created/reused asset IDs by ISIN.
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
  }) async {
    await _setLocaleForIntermediary(
      intermediaryId: intermediaryId,
      override: numberLocaleOverride,
      appLocale: appLocale,
    );
    _log.info('importAssetEventsGrouped: ${preview.totalRows} rows, ${mappings.length} mappings, locale=$_activeLocale');
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
          totalRows: 0, importedRows: 0, errorRows: 0,
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
        final isFee = feeValues.any((v) => v.toUpperCase() == normalized);
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
      final existingRows = await _db.customSelect(
        "SELECT id, isin FROM assets WHERE isin IS NOT NULL AND isin != '' "
        "AND intermediary_id = ?",
        variables: [Variable.withInt(intermediaryId)],
        readsFrom: {_db.assets},
      ).get();
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
          exchange = investingExchangeToCode[selected.exchange] ?? selected.exchange;
          final (inst, cls) = selected.classification;
          instrumentType = inst;
          assetClassValue = cls;
        } else if (isinLookup != null) {
          final lookup = await isinLookup.lookup(isin);
          final best = lookup.bestFor(null);
          name = best?.name ?? isin;
          ticker = best?.ticker;
          exchange = best?.exchange != null ? (investingExchangeToCode[best!.exchange] ?? best.exchange) : null;
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
        final assetId = await _db.into(_db.assets).insert(AssetsCompanion.insert(
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
        ));
        assetsByIsin[isin] = assetId;
        _log.info('importAssetEventsGrouped: created asset id=$assetId for ISIN=$isin, name=$name, ticker=$ticker, exchange=$exchange');
      }
    }

    // Build set of bond ISINs for price divisor
    final bondIsinRows = await _db.customSelect(
      "SELECT isin FROM assets WHERE instrument_type = 'bond' AND isin IS NOT NULL",
      readsFrom: {_db.assets},
    ).get();
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
      targetAsset = await (_db.select(_db.assets)
            ..where((a) => a.id.equals(targetAssetId)))
          .getSingleOrNull();
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
        final double amount;
        if (amountMapping != null) {
          amount = _parseAmount(_resolveMapping(amountMapping, row) ?? '');
        } else if (qty != null && price != null) {
          amount = isBond ? qty * price / 100 : qty * price;
        } else {
          amount = 0;
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
            if (externalFeeByKey.containsKey(candidate) &&
                externalFeeUsed[candidate] != true) {
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

        companions.add(AssetEventsCompanion.insert(
          assetId: assetId,
          date: date,
          valueDate: valueDate,
          type: eventType,
          amount: amount,
          quantity: Value(effectiveQty),
          price: Value(effectivePrice),
          currency: Value(currencyMapping != null ? (_resolveMapping(currencyMapping, row) ?? baseCurrency) : baseCurrency),
          exchangeRate: Value(rate),
          commission: Value(commission),
          notes: Value(descMapping != null ? _resolveMapping(descMapping, row) : null),
          rawMetadata: Value(jsonEncode(rawMetadata)),
        ));
        // Pension-contribution mirror: same condition as A3 auto-fill.
        // When the cash-only synthesis triggered, this row represents a
        // contribution to a pension fund — replicate it as an Income
        // entry so the Accounts → Income tab shows the cashflow.
        if (eventType == EventType.buy &&
            qtyMapping == null &&
            priceMapping == null &&
            targetAsset?.valuationMethod == ValuationMethod.eventDriven &&
            targetAssetId != null) {
          incomeCompanions.add(IncomesCompanion.insert(
            date: date,
            valueDate: valueDate,
            amount: amount,
            type: const Value(IncomeType.pensionContribution),
            currency: Value(currencyMapping != null ? (_resolveMapping(currencyMapping, row) ?? baseCurrency) : baseCurrency),
            assetId: Value(targetAssetId),
          ));
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
        final events = await (_db.select(_db.assetEvents)
              ..where((e) => e.assetId.equals(assetId) & e.exchangeRate.isNull() & e.currency.equals(baseCurrency).not()))
            .get();
        for (final ev in events) {
          final rate = await rateService.getRate(baseCurrency, ev.currency, ev.date);
          if (rate != null) {
            await (_db.update(_db.assetEvents)..where((e) => e.id.equals(ev.id)))
                .write(AssetEventsCompanion(exchangeRate: Value(rate)));
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
    _log.info('importAssetEventsGrouped: done - imported=$imported, deleted=$totalDeleted, errors=$errorCount, assets=${assetsByIsin.length}, attachedFees=$attachedFees, unmatchedFees=$unmatchedFees');
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

  /// Import rows as Income records.
  Future<ImportResult> importIncomes({
    required FilePreview preview,
    required List<ColumnMapping> mappings,
    required String defaultCurrency,
    void Function(int processed, int total)? onProgress,
    /// User's per-import locale choice. Persisted to the
    /// `IMPORT_INCOME_LOCALE` AppConfigs key when non-null.
    String? numberLocaleOverride,
    /// App's configured locale (e.g. `it_IT`). Final fallback.
    String? appLocale,
  }) async {
    await _setLocaleForIncome(
      override: numberLocaleOverride,
      appLocale: appLocale,
    );
    _log.info('importIncomes: ${preview.totalRows} rows, ${mappings.length} mappings, defaultCurrency=$defaultCurrency, locale=$_activeLocale');
    final mappingByField = {for (final m in mappings) m.targetField: m};
    final dateMapping = mappingByField['date'];
    final amountMapping = mappingByField['amount'];

    if (dateMapping == null || amountMapping == null) {
      return const ImportResult(
        totalRows: 0, importedRows: 0, errorRows: 0,
        errors: ['date and amount columns are required'],
      );
    }

    final typeMapping = mappingByField['type'];
    final currencyMapping = mappingByField['currency'];

    var imported = 0;
    var errorCount = 0;
    final errors = <String>[];
    final companions = <IncomesCompanion>[];
    const progressInterval = 100;

    for (var i = 0; i < preview.rows.length; i++) {
      final row = preview.rows[i];
      try {
        final amountStr = _resolveMapping(amountMapping, row) ?? '';
        final amount = _parseAmount(amountStr);

        var valueDate = _tryParseDateMapping(mappingByField['valueDate'], row);
        final date = _parseDateWithFallback(_resolveMapping(dateMapping, row) ?? '', valueDate);
        valueDate ??= date;
        final typeStr = typeMapping != null ? (_resolveMapping(typeMapping, row) ?? '') : '';
        final currency = currencyMapping != null ? (_resolveMapping(currencyMapping, row) ?? defaultCurrency) : defaultCurrency;
        final type = typeStr.toLowerCase().contains('rimborso') || typeStr.toLowerCase().contains('refund')
            ? IncomeType.refund
            : IncomeType.income;

        companions.add(IncomesCompanion.insert(
          date: date,
          valueDate: valueDate,
          amount: amount,
          type: Value(type),
          currency: Value(currency.isNotEmpty ? currency : defaultCurrency),
        ));
        imported++;
      } catch (e, stack) {
        errorCount++;
        errors.add('Skipped line ${i + 1}: $e');
        _log.warning('importIncomes: skipped line ${i + 1}: $e', e, stack);
      }
      if (i % progressInterval == 0) onProgress?.call(i + 1, preview.rows.length);
    }

    onProgress?.call(preview.rows.length, preview.rows.length);

    _log.info('importIncomes: batch-inserting ${companions.length} rows');
    await _db.batch((batch) {
      batch.insertAll(_db.incomes, companions);
    });

    _log.info('importIncomes: done - imported=$imported, errors=$errorCount');
    return ImportResult(
      totalRows: preview.totalRows,
      importedRows: imported,
      errorRows: errorCount,
      errors: errors,
    );
  }

  // ──────────────────────────────────────────────
  // Preview (dry-run) methods
  // ──────────────────────────────────────────────

  /// Dry-run a transaction import: parse all rows, compute predicted balance,
  /// and count rows that would be replaced — without touching the DB.
  Future<TransactionImportPreview> previewTransactionImport({
    required FilePreview preview,
    required List<ColumnMapping> mappings,
    required int accountId,
    String balanceMode = 'cumulative',
    String? balanceFilterColumn,
    Set<String>? balanceFilterInclude,
    /// Locale used for parsing during preview only — NOT persisted.
    String? numberLocale,
    String? appLocale,
  }) async {
    final saved = numberLocale ??
        (await (_db.select(_db.importConfigs)
                  ..where((c) => c.accountId.equals(accountId)))
                .getSingleOrNull())
            ?.numberLocale;
    _activeLocale = amt.resolveImportLocale(saved: saved, appLocale: appLocale);
    preview = await _ensurePreviewLocale(preview);
    _log.info('previewTransactionImport: accountId=$accountId, ${preview.totalRows} rows, locale=$_activeLocale');
    final mappingByField = {for (final m in mappings) m.targetField: m};
    final dateMapping = mappingByField['date'];
    final amountMapping = mappingByField['amount'];

    if (dateMapping == null || amountMapping == null) {
      return const TransactionImportPreview(
        parsedRows: 0, errorRows: 0, importSum: 0, rowsToReplace: 0,
        errors: ['date and amount columns are required'],
      );
    }

    // Pre-compute balance-diff amounts if needed
    List<double>? balanceDiffAmounts;
    if (amountMapping.isBalanceDiff) {
      balanceDiffAmounts = _computeBalanceDiffs(
          preview.rows, amountMapping.balanceDiffColumn!);
    }

    final valueDateMapping = mappingByField['valueDate'];

    var parsed = 0;
    var errorCount = 0;
    final errors = <String>[];
    double importSum = 0;
    DateTime? oldestDate;

    for (var i = 0; i < preview.rows.length; i++) {
      final row = preview.rows[i];
      try {
        final dateStr = _resolveMapping(dateMapping, row) ?? '';
        final double amount;
        if (balanceDiffAmounts != null) {
          amount = balanceDiffAmounts[i];
        } else {
          final amountStr = _resolveMapping(amountMapping, row) ?? '';
          amount = _parseAmount(amountStr);
        }

        final valueDate = _tryParseDateMapping(valueDateMapping, row);
        final date = _parseDateWithFallback(dateStr, valueDate);

        // Check filtered mode
        if (balanceMode == 'filtered' && balanceFilterColumn != null) {
          final filterVal = (row[balanceFilterColumn] ?? '').trim();
          final included = balanceFilterInclude == null ||
              balanceFilterInclude.isEmpty ||
              balanceFilterInclude.contains(filterVal);
          if (included) importSum += amount;
        } else {
          importSum += amount;
        }

        if (oldestDate == null || date.isBefore(oldestDate)) oldestDate = date;
        parsed++;
      } catch (e) {
        errorCount++;
        if (errors.length < 5) errors.add('Line ${i + 1}: $e');
      }
    }

    // Count rows that would be deleted (replaced)
    var rowsToReplace = 0;
    double? predictedBalance;
    if (oldestDate != null) {
      final cutoffEpoch = DateTime(oldestDate.year, oldestDate.month, oldestDate.day)
          .millisecondsSinceEpoch ~/ 1000;

      final countResult = await _db.customSelect(
        'SELECT COUNT(*) AS cnt FROM transactions WHERE account_id = ? AND operation_date >= ?',
        variables: [Variable.withInt(accountId), Variable.withInt(cutoffEpoch)],
      ).getSingle();
      rowsToReplace = countResult.read<int>('cnt');

      // Predicted balance = balance before cutoff + sum of CSV amounts.
      // The pre-cutoff balance source depends on balanceMode — see
      // _preCutoffBalance for why cumulative uses SUM and filtered uses
      // stored balance_after.
      if (balanceMode == 'column') {
        // In column mode, the balance comes from the CSV — just show the import sum
        predictedBalance = null;
      } else {
        final balanceBefore = await _preCutoffBalance(accountId, cutoffEpoch, balanceMode: balanceMode);
        predictedBalance = balanceBefore + importSum;
      }
    }

    _log.info('previewTransactionImport: parsed=$parsed, errors=$errorCount, sum=$importSum, '
        'predicted=$predictedBalance, toReplace=$rowsToReplace');
    return TransactionImportPreview(
      parsedRows: parsed,
      errorRows: errorCount,
      errors: errors,
      importSum: importSum,
      predictedBalance: predictedBalance,
      rowsToReplace: rowsToReplace,
    );
  }

  /// Dry-run an asset event import: parse all rows, compute per-ISIN summaries
  /// — without touching the DB.
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
        parsedRows: 0, errorRows: 0, assetSummary: {},
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
    final currencyMapping = mappingByField['currency'];
    final orderRefMapping = mappingByField['orderRef'];

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
        final isFee = feeValues.any((v) => v.toUpperCase() == normalized);
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
        final amount = amountMapping != null ? _tryParseAmount(_resolveMapping(amountMapping, row)) : null;

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

        final absQty = qty?.abs() ?? 0;
        buyCountByIsin[isin] = (buyCountByIsin[isin] ?? 0) + (eventType == EventType.buy ? 1 : 0);
        sellCountByIsin[isin] = (sellCountByIsin[isin] ?? 0) + (eventType == EventType.sell ? 1 : 0);
        netQtyByIsin[isin] = (netQtyByIsin[isin] ?? 0) +
            (eventType == EventType.sell ? -absQty : absQty);

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
    final existingRows = await _db.customSelect(
      "SELECT isin, name FROM assets WHERE isin IS NOT NULL AND isin != ''",
      readsFrom: {_db.assets},
    ).get();
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

    _log.info('previewAssetEventImport: parsed=$parsed, errors=$errorCount, assets=${summary.length}, attachedFees=$attachedFees, unmatchedFees=$unmatchedFees');
    return AssetEventImportPreview(
      parsedRows: parsed,
      errorRows: errorCount,
      errors: errors,
      assetSummary: summary,
      attachedFees: attachedFees,
      unmatchedFees: unmatchedFees,
    );
  }

  // ──────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────

  /// Parse a date string. Delegates to shared [date_parse.parseDate].
  DateTime _parseDate(String s) => date_parse.parseDate(s);

  /// Try to parse a date column from [mapping] in [row]; returns null on missing/invalid.
  DateTime? _tryParseDateMapping(ColumnMapping? mapping, Map<String, String> row) {
    if (mapping == null) return null;
    final s = _resolveMapping(mapping, row);
    if (s == null || s.isEmpty) return null;
    try { return _parseDate(s); } catch (_) { return null; }
  }

  /// Parse [dateStr] with fallback to [fallback] when parsing fails.
  /// If both fail (parse error and no fallback), rethrows the parse error.
  DateTime _parseDateWithFallback(String dateStr, DateTime? fallback) {
    try { return _parseDate(dateStr); }
    catch (_) {
      if (fallback != null) return fallback;
      rethrow;
    }
  }

  double _parseAmount(String s) => amt.parseAmount(s, locale: _activeLocale);
  double? _tryParseAmount(String? s) => amt.tryParseAmount(s, locale: _activeLocale);

  // ──────────────────────────────────────────────
  // Number-locale persistence (per-flow)
  // ──────────────────────────────────────────────

  /// Resolve the effective locale for a transaction import on [accountId]:
  /// 1. wizard `override` (also persists it to ImportConfigs)
  /// 2. previously-saved `ImportConfigs.numberLocale[accountId]`
  /// 3. `appLocale`
  /// 4. `en_US` (final fallback in [amt.resolveImportLocale])
  Future<void> _setLocaleForAccount({
    required int accountId,
    required String? override,
    required String? appLocale,
  }) async {
    final saved = override ??
        (await (_db.select(_db.importConfigs)
                  ..where((c) => c.accountId.equals(accountId)))
                .getSingleOrNull())
            ?.numberLocale;
    _activeLocale = amt.resolveImportLocale(saved: saved, appLocale: appLocale);

    if (override != null) {
      // Upsert into ImportConfigs. If no row exists yet, create one with
      // sensible defaults so future opens of the wizard show the choice.
      final existing = await (_db.select(_db.importConfigs)
            ..where((c) => c.accountId.equals(accountId)))
          .getSingleOrNull();
      if (existing == null) {
        await _db.into(_db.importConfigs).insert(ImportConfigsCompanion.insert(
              accountId: accountId,
              numberLocale: Value(override),
            ));
      } else {
        await (_db.update(_db.importConfigs)
              ..where((c) => c.accountId.equals(accountId)))
            .write(ImportConfigsCompanion(
          numberLocale: Value(override),
          updatedAt: Value(DateTime.now()),
        ));
      }
    }
  }

  /// Resolve the effective locale for an asset-event import on
  /// [intermediaryId]. Same priority order as [_setLocaleForAccount];
  /// persistence target is `Intermediaries.defaultImportLocale`.
  Future<void> _setLocaleForIntermediary({
    required int intermediaryId,
    required String? override,
    required String? appLocale,
  }) async {
    final saved = override ??
        (await (_db.select(_db.intermediaries)
                  ..where((i) => i.id.equals(intermediaryId)))
                .getSingleOrNull())
            ?.defaultImportLocale;
    _activeLocale = amt.resolveImportLocale(saved: saved, appLocale: appLocale);

    if (override != null) {
      await (_db.update(_db.intermediaries)
            ..where((i) => i.id.equals(intermediaryId)))
          .write(IntermediariesCompanion(
        defaultImportLocale: Value(override),
        updatedAt: Value(DateTime.now()),
      ));
    }
  }

  static const _incomeLocaleConfigKey = 'IMPORT_INCOME_LOCALE';

  /// Resolve the effective locale for an income import. Persistence target
  /// is the `IMPORT_INCOME_LOCALE` AppConfigs row (single global value;
  /// income imports don't have a per-source key today).
  Future<void> _setLocaleForIncome({
    required String? override,
    required String? appLocale,
  }) async {
    String? saved = override;
    if (saved == null) {
      final row = await _db.customSelect(
        'SELECT value FROM app_configs WHERE key = ?',
        variables: [Variable.withString(_incomeLocaleConfigKey)],
      ).getSingleOrNull();
      final v = row?.read<String?>('value');
      if (v != null && v.isNotEmpty) saved = v;
    }
    _activeLocale = amt.resolveImportLocale(saved: saved, appLocale: appLocale);

    if (override != null) {
      await _db.into(_db.appConfigs).insertOnConflictUpdate(
            AppConfigsCompanion.insert(
              key: _incomeLocaleConfigKey,
              value: override,
              description: const Value('Number-format locale for income imports'),
            ),
          );
    }
  }

  /// Returns `null` when the row is an external fee row (the type value
  /// matched [feeValues] — e.g. "Commissioni" / "Bollo" in cash-flow-style
  /// broker exports). Fee rows are handled by the caller's two-pass loop
  /// (matched by orderRef and folded into the parent's commission, or
  /// dropped when no match). Throws when the type value is genuinely
  /// unrecognized.
  EventType? _parseEventType(
    String s, {
    Set<String>? buyValues,
    Set<String>? sellValues,
    Set<String>? feeValues,
    Set<String>? revalueValues,
    /// Kept for wizard-API compatibility — these values map to
    /// `EventType.buy`. Pension contributions are accounting-equivalent
    /// to a discounted-NAV purchase: same effect on cost basis and
    /// qty-at-revalue. Collapsing them to `buy` keeps the event model
    /// lean (3 types) and avoids two SQL paths everywhere.
    Set<String>? contributeValues,
  }) {
    final normalized = s.trim().toUpperCase().replaceAll(' ', '_');
    // Custom user-defined mappings take priority — wizard chip tags win
    // over built-in aliases so users can override surprising defaults.
    if (feeValues != null && feeValues.any((v) => v.toUpperCase() == normalized)) return null;
    if (buyValues != null && buyValues.any((v) => v.toUpperCase() == normalized)) return EventType.buy;
    if (sellValues != null && sellValues.any((v) => v.toUpperCase() == normalized)) return EventType.sell;
    if (revalueValues != null && revalueValues.any((v) => v.toUpperCase() == normalized)) return EventType.revalue;
    if (contributeValues != null && contributeValues.any((v) => v.toUpperCase() == normalized)) return EventType.buy;
    // Direct enum match
    final direct = EventType.values.where((e) => e.name.toUpperCase() == normalized).firstOrNull;
    if (direct != null) return direct;
    // Common aliases per language / source format. Pension-statement
    // dialect (TOTALEP, POSIZIONE, CONTRIBUTO, BEITRAG, COTISATION) is
    // included so common formats classify correctly without the user
    // having to tag every label via the wizard chips.
    const sellAliases = {'SELL', 'VENDITA', 'VENDI', 'S', 'V', 'VERKAUF', 'VENTE'};
    const buyAliases = {
      'BUY', 'ACQUISTO', 'COMPRA', 'B', 'A', 'KAUF', 'ACHAT',
      // Contribute-flavored words collapse to buy.
      'CONTRIBUTE', 'CONTRIBUTO', 'CONTRIBUTION', 'BEITRAG', 'COTISATION',
    };
    const revalueAliases = {'REVALUE', 'REVAL', 'POSITION', 'POSIZIONE', 'TOTALEP', 'TOTALE_PERIODO', 'BALANCE', 'SALDO'};
    if (sellAliases.contains(normalized)) return EventType.sell;
    if (buyAliases.contains(normalized)) return EventType.buy;
    if (revalueAliases.contains(normalized)) return EventType.revalue;
    // Unknown type — fail loudly so the user knows to either add a custom
    // buyValues/sellValues/revalueValues mapping via the wizard, or omit
    // the type column. The previous silent fallback to BUY turned
    // dividends/taxes/transfers into phantom buys and inflated the
    // asset's cost basis.
    throw FormatException('Unknown event type "$s" (normalized: "$normalized")');
  }

  /// Pre-cutoff balance for the account at [cutoffEpoch].
  ///
  /// In `cumulative` mode every transaction contributes to the running
  /// balance, so SUM(amount) is the source of truth (immune to per-batch
  /// `balance_after` drift from older partial-period imports).
  ///
  /// In `filtered` mode some rows are excluded by a CSV-only filter column
  /// that doesn't exist in the DB, so SUM(amount) over-counts. We instead
  /// trust the stored `balance_after` of the latest pre-cutoff row, which
  /// previous imports wrote as the *filtered* cumulative.
  Future<double> _preCutoffBalance(
    int accountId,
    int cutoffEpoch, {
    String balanceMode = 'cumulative',
  }) async {
    if (balanceMode == 'filtered') {
      final row = await _db.customSelect(
        'SELECT balance_after FROM transactions '
        'WHERE account_id = ? AND operation_date < ? '
        'ORDER BY operation_date DESC, id DESC LIMIT 1',
        variables: [Variable.withInt(accountId), Variable.withInt(cutoffEpoch)],
      ).getSingleOrNull();
      return row?.readNullable<double>('balance_after') ?? 0.0;
    }
    final row = await _db.customSelect(
      'SELECT COALESCE(SUM(amount), 0) AS s FROM transactions '
      'WHERE account_id = ? AND operation_date < ?',
      variables: [Variable.withInt(accountId), Variable.withInt(cutoffEpoch)],
    ).getSingle();
    return row.read<double>('s');
  }

  /// Compute balanceAfter for parsed rows based on the selected mode.
  /// [startingBalance] seeds cumulative/filtered modes so newly imported rows
  /// continue from the account's existing balance instead of restarting at 0.
  void _computeBalances(
    List<_ParsedTransactionRow> rows,
    String balanceMode,
    Set<String>? balanceFilterInclude,
    double startingBalance,
  ) {
    if (rows.isEmpty || balanceMode == 'none') return;

    if (balanceMode == 'column') {
      // Already set from CSV column in balanceAfterFromColumn
      for (final r in rows) {
        r.balanceAfter = r.balanceAfterFromColumn;
      }
      return;
    }

    // Sort chronologically by valueDate (the canonical "money moved" date,
    // per CLAUDE.md), with csvIndex as a stable tiebreaker. Sorting by
    // operationDate here would disagree with the later recalc path which
    // uses valueDate, producing different balanceAfter values for the same
    // set of transactions.
    final indexed = List.generate(rows.length, (i) => i);
    indexed.sort((a, b) {
      final aDate = rows[a].valueDate ?? rows[a].date;
      final bDate = rows[b].valueDate ?? rows[b].date;
      final cmp = aDate.compareTo(bDate);
      if (cmp != 0) return cmp;
      return rows[a].csvIndex.compareTo(rows[b].csvIndex);
    });

    // All arithmetic in integer cents to avoid floating point errors
    int toCents(double v) => (v * 100).round();
    double fromCents(int c) => c / 100;

    if (balanceMode == 'cumulative') {
      int balanceCents = toCents(startingBalance);
      for (final i in indexed) {
        balanceCents += toCents(rows[i].amount);
        rows[i].balanceAfter = fromCents(balanceCents);
      }
      _log.info('_computeBalances: cumulative - done (seed=$startingBalance)');
    } else if (balanceMode == 'filtered') {
      int balanceCents = toCents(startingBalance);
      for (final i in indexed) {
        final filterVal = rows[i].filterColumnValue ?? '';
        final included = balanceFilterInclude == null ||
            balanceFilterInclude.isEmpty ||
            balanceFilterInclude.contains(filterVal);
        if (included) {
          balanceCents += toCents(rows[i].amount);
        }
        rows[i].balanceAfter = fromCents(balanceCents);
      }
      _log.info('_computeBalances: filtered - done (seed=$startingBalance)');
    }
  }
}

/// Internal data class for a parsed transaction row before building companion.
class _ParsedTransactionRow {
  final DateTime date;
  final DateTime? valueDate;
  final double amount;
  final String description;
  final double? balanceAfterFromColumn;
  final String currency;
  final TransactionStatus? status;
  final Map<String, String> rawMetadata;
  final String? hash;
  final String? filterColumnValue;
  final int csvIndex;

  double? balanceAfter;

  _ParsedTransactionRow({
    required this.date,
    this.valueDate,
    required this.amount,
    required this.description,
    this.balanceAfterFromColumn,
    required this.currency,
    this.status,
    required this.rawMetadata,
    required this.hash,
    this.filterColumnValue,
    required this.csvIndex,
  });
}
