part of 'import_screen.dart';

// ──────────────────────────────────────────────
// Step 2: Select target + confirm
// ──────────────────────────────────────────────

extension _ConfirmStep on _ImportScreenState {
  /// Collect all unique exchange names across all ISIN lookup results.
  List<String> _allExchanges() {
    if (_isinLookupResults == null) return [];
    final exchanges = <String>{};
    for (final result in _isinLookupResults!.values) {
      for (final o in result.options) {
        if (o.exchange.isNotEmpty) exchanges.add(o.exchange);
      }
    }
    return exchanges.toList()..sort();
  }

  Future<void> _lookupIsins() async {
    if (_preview == null || _mappings['isin'] == null) return;
    // Read before awaiting: the screen may be gone when the rows arrive.
    final lookup = _maybeIsinLookupService();

    // Use full rows (not capped preview) to find ALL unique ISINs.
    // The preview is capped to first 5 + last 5 rows for display;
    // ISINs in middle rows would be invisible without this.
    var source = _preview!;
    if (source.rows.length < source.totalRows) {
      source = await _loadCompletePreview();
      if (!mounted) return;
    }

    final isinCol = _mappings['isin']!;
    final counts = <String, int>{};
    for (final row in source.rows) {
      final isin = (row[isinCol] ?? '').trim().toUpperCase();
      if (isin.isNotEmpty) counts[isin] = (counts[isin] ?? 0) + 1;
    }
    _fullIsinSummary = counts;

    final isins = counts.keys.toList();
    if (isins.isEmpty) return;
    _setState(() => _lookingUpIsins = true);
    try {
      if (lookup == null) {
        if (mounted) {
          _setState(() {
            _isinLookupResults = {for (final isin in isins) isin: const IsinLookupResult()};
          });
        }
        return;
      }
      final results = await lookup.lookupBatch(isins);
      if (mounted) {
        _setState(() {
          _isinLookupResults = results;
          // Auto-select best option per ISIN based on default exchange
          for (final entry in results.entries) {
            if (!_selectedExchanges.containsKey(entry.key)) {
              final best = entry.value.bestFor(_defaultExchange);
              if (best != null) _selectedExchanges[entry.key] = best;
            }
          }
        });
      }
    } catch (e) {
      _log.warning('_lookupIsins: $e');
    } finally {
      if (mounted) _setState(() => _lookingUpIsins = false);
    }
  }

  Map<String, int> _getIsinSummary() {
    return _fullIsinSummary ?? const {};
  }

  /// Show a modal hosting the shared URL-paste recovery widget for [isin].
  /// On a successful resolve we synthesise an [IsinExchangeOption] from the
  /// returned [ProviderSearchResult] and inject it into the lookup map so
  /// the row in the confirm screen now shows the resolved listing.
  Future<void> _openUrlPasteDialog(String isin) async {
    final s = ref.read(appStringsProvider);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.instrumentNotFoundHeadline),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: IsinUrlPasteRecovery(
            userQuery: isin,
            cacheKey: isin,
            defaultExchange: _defaultExchange ?? 'Milan',
            onResolved: (result) {
              final option = IsinExchangeOption(
                cid: result.cid,
                ticker: result.symbol,
                name: result.description,
                exchange: result.exchange,
                url: result.url,
                typeName: result.type.split(' - ').first,
              );
              _setState(() {
                _isinLookupResults![isin] = IsinLookupResult(options: [option]);
                _selectedExchanges[isin] = option;
              });
              Navigator.of(ctx).pop();
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.cancel),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirm() {
    final s = ref.watch(appStringsProvider);
    final isAssetImport = _target == ImportTarget.assetEvent;
    final isIncomeImport = _target == ImportTarget.income;
    return Column(
      children: [
        // Scrollable content area
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isAssetImport) ...[
                  Text(s.selectIntermediary, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildIntermediarySelector(),
                  const SizedBox(height: 24),
                ],

                _buildNumberLocalePicker(),
                const SizedBox(height: 16),

                // Summary
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.importSummary, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(_fromStoredRows ? s.sourceStoredRows : s.sourceFile(_filePath?.split('/').last ?? s.clipboard)),
                        Text(s.rowCount(_preview?.totalRows ?? 0)),
                        if (_target == ImportTarget.transaction && _balance == BalanceMode.column)
                          Text(s.balancesOnValueDateTimeline, key: const Key('balancesTimelineNote'), style: const TextStyle(fontSize: 12)),
                        Text(
                          s.targetLabel(
                            isAssetImport
                                ? s.targetAssetEvents
                                : isIncomeImport
                                ? s.importTypeIncome
                                : s.targetTransactions,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(s.mappingsLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Padding(padding: const EdgeInsets.only(left: 8), child: _buildMappingLines()),
                        if (isAssetImport) ...[
                          const SizedBox(height: 12),
                          Text(s.assetsAndExchange, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          if (_lookingUpIsins)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                  const SizedBox(width: 8),
                                  Text(s.lookingUpExchanges, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            )
                          else ...[
                            // Default exchange selector
                            if (_isinLookupResults != null) ...[
                              Row(
                                children: [
                                  Text(s.defaultExchange, style: const TextStyle(fontSize: 12)),
                                  const SizedBox(width: 4),
                                  DropdownButton<String>(
                                    value: _defaultExchange,
                                    hint: Text(s.auto, style: const TextStyle(fontSize: 12)),
                                    isDense: true,
                                    items: _allExchanges()
                                        .map(
                                          (ex) => DropdownMenuItem(
                                            value: ex,
                                            child: Text(ex, style: const TextStyle(fontSize: 12)),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) => _setState(() {
                                      _defaultExchange = v;
                                      // Re-apply default to all ISINs
                                      for (final entry in _isinLookupResults!.entries) {
                                        final best = entry.value.bestFor(v);
                                        if (best != null) _selectedExchanges[entry.key] = best;
                                      }
                                    }),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                            ],
                            // Per-ISIN exchange picker with exclude checkbox
                            ..._getIsinSummary().entries.map((e) {
                              final isin = e.key;
                              final count = e.value;
                              final options = _isinLookupResults?[isin]?.options ?? [];
                              final selected = _selectedExchanges[isin];
                              final excluded = _excludedIsins.contains(isin);
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: !excluded,
                                        onChanged: (v) => _setState(() {
                                          if (v == true) {
                                            _excludedIsins.remove(isin);
                                          } else {
                                            _excludedIsins.add(isin);
                                          }
                                        }),
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    SizedBox(
                                      width: 130,
                                      child: Text(
                                        isin,
                                        style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: excluded ? Colors.grey : null),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(s.nEvents(count), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    const SizedBox(width: 8),
                                    if (options.length > 1)
                                      Expanded(
                                        child: DropdownButton<int>(
                                          value: selected?.cid,
                                          isDense: true,
                                          isExpanded: true,
                                          items: options
                                              .map(
                                                (o) => DropdownMenuItem(
                                                  value: o.cid,
                                                  child: Text('${o.ticker} — ${o.exchange}', style: const TextStyle(fontSize: 12)),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: excluded
                                              ? null
                                              : (cid) => _setState(() {
                                                  _selectedExchanges[isin] = options.firstWhere((o) => o.cid == cid);
                                                }),
                                        ),
                                      )
                                    else if (options.length == 1)
                                      Expanded(
                                        child: Text(
                                          '${options.first.ticker} — ${options.first.exchange}',
                                          style: TextStyle(fontSize: 12, color: excluded ? Colors.grey : null),
                                        ),
                                      )
                                    else
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Text(s.notFound, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                            const SizedBox(width: 8),
                                            TextButton.icon(
                                              icon: const Icon(Icons.link, size: 14),
                                              label: Text(s.pasteUrlShort, style: const TextStyle(fontSize: 11)),
                                              style: TextButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              onPressed: excluded ? null : () => _openUrlPasteDialog(isin),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),

                // ── Import Preview ──────────────────────────────
                if (!isIncomeImport) ...[
                  const SizedBox(height: 16),
                  _buildImportPreview(),
                ],
              ],
            ),
          ),
        ),

        // Pinned bottom: error / progress / import button
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        if (_importing) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      s.importingProgress(_importedSoFar, _importTotal),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _importTotal > 0 ? _importedSoFar / _importTotal : null,
                ),
              ],
            ),
          ),
        ] else
          WizardNavBar(
            leading: switch (_missingMappingReason()) {
              final reason? => Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: Colors.red.shade300),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      reason,
                      style: TextStyle(fontSize: 12, color: Colors.red.shade300),
                    ),
                  ),
                ],
              ),
              null => null,
            },
            primaryIcon: Icons.check,
            primaryLabel: s.importButton,
            onPrimary: _canImport(isAssetImport, isIncomeImport) ? _executeImport : null,
          ),
      ],
    );
  }

  /// Human-readable reason the Import button is disabled due to a missing
  /// required mapping, or null when all mandatory fields are mapped. Lets the
  /// confirm step explain *why* it's blocked instead of a silently-disabled
  /// button (which previously let all-zero-amount imports slip through).
  String? _missingMappingReason() {
    final s = ref.read(appStringsProvider);
    if (_numberLocaleMissing) return s.numberFormatRequiredForRerun;
    final needsDate = !(_target == ImportTarget.assetEvent && _assetImportMode == 'current');
    if (needsDate && _mappings['date'] == null) return s.missingDateMapping;
    if (_mappings['amount'] == null && _amountFormula.isEmpty && _balanceDiffColumn == null && !_autoCalcAmount) {
      return s.missingAmountMapping;
    }
    return null;
  }

  /// Asset imports require an intermediary selection. Income imports don't.
  /// Transaction imports require a target account.
  bool _canImport(bool isAssetImport, bool isIncomeImport) {
    // Re-validate the full mapping gate at import time, not just the target.
    // The step-1 "Next" gate can be satisfied and then invalidated (e.g. a
    // refine-panel edit drops the amount mapping), so the final Import button
    // must independently require every mandatory mapping — otherwise an import
    // with no amount column silently writes all-zero events.
    if (!_canProceedToConfirm()) return false;
    if (_numberLocaleMissing) return false;
    // Incomes and asset events are recorded in the stored base currency, and
    // asset rates quoted against it: the button comes on once it has loaded,
    // as the create-account dialog's does. Watched, so it does.
    if ((isAssetImport || isIncomeImport) && ref.watch(baseCurrencyProvider).value == null) return false;
    if (isAssetImport) return _selectedIntermediaryId != null;
    if (isIncomeImport) return true;
    return _targetId != null;
  }

  Widget _buildIntermediarySelector() {
    final s = ref.watch(appStringsProvider);
    final intermediariesAsync = ref.watch(intermediariesProvider);
    return intermediariesAsync.when(
      data: (intermediaries) {
        if (intermediaries.isEmpty) {
          // Empty state: give the user an inline CTA to create one.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.selectIntermediaryEmpty, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: Text(s.addIntermediary),
                onPressed: _createIntermediaryInline,
              ),
            ],
          );
        }
        return RadioGroup<int?>(
          groupValue: _selectedIntermediaryId,
          onChanged: (v) async {
            _setState(() => _selectedIntermediaryId = v);
            // Pre-load this intermediary's persisted number-format locale.
            if (v != null) {
              final all = await ref.read(intermediaryServiceProvider).getAll();
              final inter = all.where((i) => i.id == v).firstOrNull;
              if (mounted && inter != null) {
                _setState(() => _selectedNumberLocale = inter.defaultImportLocale);
              }
            }
          },
          child: Column(
            children: [
              ...intermediaries.map(
                (i) => RadioListTile<int?>(
                  title: Text(i.name),
                  value: i.id,
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(s.addIntermediary),
                  onPressed: _createIntermediaryInline,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text(s.error(e)),
    );
  }

  /// The intermediary list's Add Intermediary form; the one it creates is
  /// selected at once.
  Future<void> _createIntermediaryInline() async {
    final id = await showIntermediaryEditDialog(context, ref);
    if (id != null) _setState(() => _selectedIntermediaryId = id);
  }

  Widget _buildImportPreview() {
    final s = ref.watch(appStringsProvider);
    final locale = ref.watch(appLocaleProvider).value ?? Platform.localeName;
    final amtFmt = fmt.amountFormat(locale);

    if (_previewing) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Text(s.computingPreview, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    if (_target == ImportTarget.transaction && _txPreview != null) {
      final p = _txPreview!;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.importPreviewTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _previewRow(s.parsedRowsLabel, '${p.parsedRows}'),
              if (p.errorRows > 0) _previewRow(s.skippedLabel, '${p.errorRows}', color: Colors.red),
              if (p.rowsToReplace > 0) _previewRow(s.rowsToReplace, '${p.rowsToReplace}', color: Colors.orange),
              _previewRow(s.importAmountSum, amtFmt.format(p.importSum), masked: true),
              if (p.predictedBalance != null)
                _previewRow(
                  s.predictedBalance,
                  amtFmt.format(p.predictedBalance!),
                  color: Theme.of(context).colorScheme.primary,
                  bold: true,
                  masked: true,
                )
              else if (p.openingBalanceUnknown)
                _previewRow(s.predictedBalance, s.predictedBalanceUnknown, color: Colors.orange),
              if (p.issues.isNotEmpty) ...[
                const SizedBox(height: 4),
                ...p.issues
                    .take(3)
                    .map(
                      (i) => Text(
                        importIssueText(s, i, locale: locale),
                        style: const TextStyle(fontSize: 11, color: Colors.red),
                      ),
                    ),
              ],
            ],
          ),
        ),
      );
    }

    if (_target == ImportTarget.assetEvent && _assetPreview != null) {
      final p = _assetPreview!;
      final totalBuys = p.assetSummary.values.fold(0, (sum, e) => sum + e.buyCount);
      final totalSells = p.assetSummary.values.fold(0, (sum, e) => sum + e.sellCount);
      // No currency column: what is recorded in the base currency is said,
      // naming it, while a currency column can still be mapped.
      final assumedBase = p.baseCurrencyAssumed ? ref.watch(baseCurrencyProvider).value : null;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.importPreviewTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _previewRow(s.parsedRowsLabel, '${p.parsedRows}'),
              if (p.errorRows > 0) _previewRow(s.skippedLabel, '${p.errorRows}', color: Colors.red),
              _previewRow(s.assetLabel, '${p.assetSummary.length}'),
              _previewRow(s.buysLabel, '$totalBuys', color: Colors.green),
              if (totalSells > 0) _previewRow(s.sellsLabel, '$totalSells', color: Colors.red),
              if (assumedBase != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    s.importBaseCurrencyAssumed(assumedBase),
                    key: const Key('baseCurrencyAssumedNote'),
                    style: const TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),
              if (p.issues.isNotEmpty) ...[
                const SizedBox(height: 4),
                ...p.issues
                    .take(3)
                    .map(
                      (i) => Text(
                        importIssueText(s, i, locale: locale),
                        style: const TextStyle(fontSize: 11, color: Colors.red),
                      ),
                    ),
              ],
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  /// [masked]: [value] is position size (an amount, a balance) and blurs in
  /// privacy mode; row counts stay readable.
  Widget _previewRow(String label, String value, {Color? color, bool bold = false, bool masked = false}) {
    final style = TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : null, color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 180, child: Text(label, style: const TextStyle(fontSize: 12))),
          Flexible(
            child: PrivacyText(value, style: style, masked: masked),
          ),
        ],
      ),
    );
  }

  /// The Accounts screen's New Account form (the account is created in the
  /// stored base currency); the account picker lists the new account.
  Future<void> _showCreateAccountDialog() => showCreateAccountDialog(context);

  Future<void> _executeImport() async {
    _log.info('_executeImport: starting import - target=${_target.name}, targetId=$_targetId');
    final s = ref.read(appStringsProvider);
    // Hard stop: never run an import with a missing required mapping (the
    // button gate should already prevent this, but guard the entry point so
    // a regression can't silently produce all-zero events).
    final missing = _missingMappingReason();
    if (missing != null) {
      _log.warning('_executeImport: blocked — $missing');
      _setState(() => _error = missing);
      return;
    }
    // The mapping check above says nothing about the import TARGET, and
    // _executeImport is the single entry point for both the full and the quick
    // flow. Without this, `intermediaryId: _selectedIntermediaryId!` below is a
    // null-check crash instead of a message the user can act on.
    if (_target == ImportTarget.assetEvent && _selectedIntermediaryId == null) {
      _log.warning('_executeImport: blocked — asset import with no intermediary selected');
      _setState(() => _error = s.selectIntermediary);
      return;
    }
    // Incomes and asset events are recorded in the stored base currency, and
    // an asset's rate is quoted against it: never in a guessed one. The
    // Import button waits for it (_canImport); this guards the entry point.
    final baseCurrency = ref.read(baseCurrencyProvider).value;
    if (_target != ImportTarget.transaction && baseCurrency == null) {
      _log.warning('_executeImport: blocked — the base currency has not loaded');
      _setState(() => _error = s.importBaseCurrencyLoading);
      return;
    }
    // Everything the import and its bookkeeping use is read now, before the
    // first await: `ref` is unusable once the screen is gone, and the config
    // save, balance recalculation and classification must still run then —
    // skipping them would leave the imported rows with stale balances.
    final importer = ref.read(importServiceProvider);
    final configSvc = ref.read(importConfigServiceProvider);
    final txSvc = ref.read(transactionServiceProvider);
    final classifier = ref.read(transactionClassifierServiceProvider);
    final appLocale = ref.read(appLocaleProvider).value;
    // The number format the file is read in (explicit choice, else the app's).
    final fileLocale = _effectiveNumberLocale();
    final isAssetImport = _target == ImportTarget.assetEvent;
    // ISIN lookup is available only when the market data service is the
    // web-backed implementation. Test/no-op services still import assets
    // using the raw ISIN data.
    final isinLookup = isAssetImport ? _maybeIsinLookupService() : null;
    final rateService = isAssetImport ? ref.read(exchangeRateServiceProvider) : null;
    final targetId = _targetId;
    _setState(() {
      _importing = true;
      _importedSoFar = 0;
      _importTotal = _preview?.totalRows ?? 0;
      _error = null;
    });

    try {
      final mappings = _buildColumnMappings();

      _log.info('_executeImport: ${mappings.length} column mappings built');

      // Re-parse full file if the on-screen preview was capped (large
      // files). Locale mismatches are handled inside ImportService —
      // re-parsing here would also fire for CSV (locale-agnostic), adding
      // pointless Isolate work.
      var fullPreview = _preview!;
      if (fullPreview.rows.length < fullPreview.totalRows) {
        _log.info('_executeImport: re-parsing full file (${fullPreview.totalRows} rows)...');
        fullPreview = await _loadCompletePreview();
        _log.info('_executeImport: re-parsed ${fullPreview.rows.length} rows');
      }

      void onProgress(int processed, int total) {
        _setState(() {
          _importedSoFar = processed;
          _importTotal = total;
        });
      }

      final ImportResult result;
      if (_target == ImportTarget.transaction) {
        result = await importer.importTransactions(
          preview: fullPreview,
          mappings: mappings,
          accountId: targetId!,
          onProgress: onProgress,
          balanceMode: _balance.name,
          balanceFilterColumn: _balanceFilterColumn,
          balanceFilterInclude: _balanceFilterInclude.isNotEmpty ? _balanceFilterInclude : null,
          numberLocaleOverride: _selectedNumberLocale,
          replaceOnlyImportedRows: _fromStoredRows,
          derivedColumns: _transforms.derivedColumns,
          appLocale: appLocale,
        );
      } else if (_target == ImportTarget.income) {
        result = await importer.importIncomes(
          preview: fullPreview,
          mappings: mappings,
          defaultCurrency: baseCurrency!, // non-null: gated by _canImport AND re-checked in _executeImport
          onProgress: onProgress,
          incomeValues: _incomeValues.isNotEmpty ? _incomeValues : null,
          refundValues: _refundValues.isNotEmpty ? _refundValues : null,
          pensionContributionValues: _pensionContributionValues.isNotEmpty ? _pensionContributionValues : null,
          numberLocaleOverride: _selectedNumberLocale,
          appLocale: appLocale,
        );
      } else {
        // Remove type mapping if using sign-based detection
        if (_typeMode == 'sign') {
          mappings.removeWhere((m) => m.targetField == 'type');
        }
        final assetResult = await importer.importAssetEventsGrouped(
          preview: fullPreview,
          mappings: mappings,
          onProgress: onProgress,
          computeFee: _feeMode == 'computed',
          isinLookup: isinLookup,
          buyValues: _buyValues.isNotEmpty ? _buyValues : null,
          sellValues: _sellValues.isNotEmpty ? _sellValues : null,
          feeValues: _feeValues.isNotEmpty ? _feeValues : null,
          negativeIsBuy: _typeMode == 'sign' && _negativeIsBuy,
          revalueValues: _revalueValues.isNotEmpty ? _revalueValues : null,
          selectedExchanges: _selectedExchanges.isNotEmpty ? _selectedExchanges : null,
          excludedIsins: _excludedIsins.isNotEmpty ? _excludedIsins : null,
          rateService: rateService,
          baseCurrency: baseCurrency!, // non-null: gated by _canImport AND re-checked in _executeImport
          intermediaryId: _selectedIntermediaryId!, // non-null: gated by _canImport AND re-checked in _executeImport
          numberLocaleOverride: _selectedNumberLocale,
          appLocale: appLocale,
          targetAssetId: _assetEventMode == 'singleAsset' ? _singleAssetTargetId : null,
          revalueAmountColumn: _revalueValues.isNotEmpty ? _revalueAmountColumn : null,
          autoCalcPrice: _autoCalcPrice,
        );
        result = assetResult.result;
      }

      _log.info('_executeImport: complete - imported=${result.importedRows}, deleted=${result.deletedRows}, errors=${result.errorRows}');
      if (result.errors.isNotEmpty) {
        _log.warning('_executeImport: first error: ${result.errors.first}');
      }

      // Save import config for this account
      await _saveConfig(configSvc);

      // Auto-recalculate balances for the entire account after transaction import
      if (_target == ImportTarget.transaction && targetId != null) {
        final savedConfig = await configSvc.getByAccount(targetId);
        final saved = savedConfig != null ? SavedImportMappings.decode(savedConfig.mappingsJson) : SavedImportMappings(const {});
        final mode = saved.balanceMode;
        // The stored statement text is re-read in the account's number
        // format: read as en_US, an it_IT "1.100,00" is no balance at all and
        // a column-mode account would lose its anchor on the bank's closing.
        if (mode == null) {
          _log.warning('_executeImport: saved balance settings unreadable - account balances not recalculated');
        } else {
          await txSvc.recalculateBalances(
            targetId,
            balanceMode: mode.name,
            savedMappings: saved.values,
            numberLocale: savedConfig?.numberLocale ?? fileLocale,
          );
        }
        // Apply the user's rules to the freshly imported rows (never
        // overwrites an existing category).
        try {
          _classifyResult = await classifier.classifyAll(accountId: targetId, overwrite: false);
        } catch (e) {
          _log.warning('_executeImport: post-import classification failed: $e');
          _classifyResult = null;
        }
      }

      _setState(() {
        _result = result;
        _step = 3;
        _importing = false;
      });
    } catch (e, stack) {
      _log.severe('_executeImport: failed', e, stack);
      _setState(() {
        _error = s.importFailed(e);
        _importing = false;
      });
    }
  }

  /// The number formats the user can pick (the ones Settings offers), after
  /// "Auto" (`null`: resolve from the saved format or the app locale at import
  /// time).
  Widget _buildNumberLocalePicker() {
    final s = ref.watch(appStringsProvider);
    final appLocale = ref.watch(appLocaleProvider).value;
    final autoLabel = appLocale != null && appLocale.isNotEmpty ? '${s.auto} ($appLocale)' : s.auto;
    final items = [
      // Stored rows: no "Auto" — the text has one format and it must be named.
      if (!_fromStoredRows) DropdownMenuItem<String?>(value: null, child: Text(autoLabel)),
      for (final (locale, label) in s.numberLocaleOptions) DropdownMenuItem<String?>(value: locale, child: Text(label)),
    ];
    final missing = _numberLocaleMissing;
    return Card(
      key: const Key('numberLocalePicker'),
      color: missing ? Theme.of(context).colorScheme.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.numberFormatLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (missing)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        s.numberFormatRequiredForRerun,
                        key: const Key('numberLocaleMissingNote'),
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onErrorContainer),
                      ),
                    ),
                ],
              ),
            ),
            DropdownButton<String?>(
              key: const Key('numberLocaleDropdown'),
              value: _selectedNumberLocale,
              hint: Text(_fromStoredRows ? s.numberFormatChoose : autoLabel),
              items: items,
              onChanged: (v) {
                _setState(() => _selectedNumberLocale = v);
                _clearFullPreviewCache();
                _computePreview();
              },
            ),
          ],
        ),
      ),
    );
  }
}
