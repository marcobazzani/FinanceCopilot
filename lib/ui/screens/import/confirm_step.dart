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

    // Use full rows (not capped preview) to find ALL unique ISINs.
    // The preview is capped to first 5 + last 5 rows for display;
    // ISINs in middle rows would be invisible without this.
    var source = _preview!;
    if (source.rows.length < source.totalRows) {
      final importer = ref.read(importServiceProvider);
      source = await importer.getFullRows(source);
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
      final lookup = ref.read(isinLookupServiceProvider);
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

  Widget _buildConfirm() {
    final s = ref.watch(appStringsProvider);
    final isAssetImport = _target == ImportTarget.assetEvent;
    final isIncomeImport = _target == ImportTarget.income;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isAssetImport && !isIncomeImport && widget.preselectedAccountId == null) ...[
          Text(s.selectAccount, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildAccountSelector(),
          const SizedBox(height: 24),
        ],
        if (isAssetImport) ...[
          Text(s.selectIntermediary, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildIntermediarySelector(),
          const SizedBox(height: 24),
        ],

        // Summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.importSummary, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(s.sourceFile(_filePath?.split('/').last ?? s.clipboard)),
                Text(s.rowCount(_preview?.totalRows ?? 0)),
                Text('Target: ${isAssetImport ? s.targetAssetEvents : isIncomeImport ? s.importTypeIncome : s.targetTransactions}'),
                const SizedBox(height: 8),
                Text(s.mappingsLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                ..._mappings.entries
                    .where((e) => e.value != null && !(e.key == 'amount' && _amountFormula.isNotEmpty))
                    .map((e) => Text('  ${e.key} ← ${e.value}')),
                if (_amountFormula.isNotEmpty)
                  Text('  amount ← ${_amountFormula.map((t) => '${t.operator} ${t.sourceColumn}').join(' ').replaceFirst('+ ', '')}'),
                if (isAssetImport) ...[
                  const SizedBox(height: 12),
                  Text(s.assetsAndExchange, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  if (_lookingUpIsins)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(children: [
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 8),
                        Text(s.lookingUpExchanges, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ]),
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
                            items: _allExchanges().map((ex) => DropdownMenuItem(value: ex, child: Text(ex, style: const TextStyle(fontSize: 12)))).toList(),
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
                              width: 24, height: 24,
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
                            SizedBox(width: 130, child: Text(isin, style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: excluded ? Colors.grey : null))),
                            const SizedBox(width: 4),
                            Text(s.nEventsCount(count), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(width: 8),
                            if (options.length > 1)
                              Expanded(
                                child: DropdownButton<int>(
                                  value: selected?.cid,
                                  isDense: true,
                                  isExpanded: true,
                                  items: options.map((o) => DropdownMenuItem(
                                    value: o.cid,
                                    child: Text('${o.ticker} — ${o.exchange}', style: const TextStyle(fontSize: 12)),
                                  )).toList(),
                                  onChanged: excluded ? null : (cid) => _setState(() {
                                    _selectedExchanges[isin] = options.firstWhere((o) => o.cid == cid);
                                  }),
                                ),
                              )
                            else if (options.length == 1)
                              Expanded(child: Text('${options.first.ticker} — ${options.first.exchange}', style: TextStyle(fontSize: 12, color: excluded ? Colors.grey : null)))
                            else
                              Expanded(child: Text(s.notFound, style: const TextStyle(fontSize: 12, color: Colors.grey))),
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

        const Spacer(),
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
                      width: 16, height: 16,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.check),
                label: Text(s.importButton),
                onPressed: (isAssetImport || isIncomeImport || _targetId != null) ? _executeImport : null,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildAccountSelector() {
    final s = ref.watch(appStringsProvider);
    final accountsAsync = ref.watch(accountsProvider);
    return accountsAsync.when(
      data: (accounts) {
        if (accounts.isEmpty) {
          return Column(
            children: [
              Text(s.noAccountsCreate),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _showCreateAccountDialog(),
                child: Text(s.createAccount),
              ),
            ],
          );
        }
        return RadioGroup<int>(
          groupValue: _targetId,
          onChanged: (v) => _setState(() => _targetId = v),
          child: Column(
            children: [
              ...accounts.map((a) {
                final account = a;
                return RadioListTile<int>(
                  title: Text(account.name),
                  subtitle: Text('${account.type.name} · ${account.currency}'),
                  value: account.id,
                );
              }),
              OutlinedButton(
                onPressed: () => _showCreateAccountDialog(),
                child: Text(s.newAccount),
              ),
            ],
          ),
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text(ref.watch(appStringsProvider).error(e)),
    );
  }

  Widget _buildIntermediarySelector() {
    final s = ref.watch(appStringsProvider);
    final intermediariesAsync = ref.watch(intermediariesProvider);
    return intermediariesAsync.when(
      data: (intermediaries) {
        if (intermediaries.isEmpty) {
          return Text(s.unassigned, style: const TextStyle(color: Colors.grey));
        }
        return RadioGroup<int?>(
          groupValue: _selectedIntermediaryId,
          onChanged: (v) => _setState(() => _selectedIntermediaryId = v),
          child: Column(
            children: [
              ...intermediaries.map((i) => RadioListTile<int?>(
                title: Text(i.name),
                value: i.id,
              )),
              RadioListTile<int?>(
                title: Text(s.unassigned),
                value: null,
              ),
            ],
          ),
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text(s.error(e)),
    );
  }

  Future<void> _showCreateAccountDialog() async {
    final s = ref.read(appStringsProvider);
    final nameCtrl = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.newAccountTitle),
        content: TextField(
          controller: nameCtrl,
          decoration: InputDecoration(labelText: s.name, hintText: s.accountNameHint),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await ref.read(accountServiceProvider).create(
                    name: nameCtrl.text.trim(),
                    currency: ref.read(baseCurrencyProvider).value ?? 'EUR',
                  );
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: Text(s.create),
          ),
        ],
      ),
    );
    if (created == true) _setState(() {});
  }

  Future<void> _executeImport() async {
    _log.info('_executeImport: starting import - target=${_target.name}, targetId=$_targetId');
    _setState(() {
      _importing = true;
      _importedSoFar = 0;
      _importTotal = _preview?.totalRows ?? 0;
      _error = null;
    });

    try {
      final importer = ref.read(importServiceProvider);
      final mappings = <ColumnMapping>[];
      for (final e in _mappings.entries) {
        if (e.value == null) continue;
        if (e.key == 'amount' && (_amountFormula.isNotEmpty || _balanceDiffColumn != null)) continue;
        mappings.add(ColumnMapping(sourceColumn: e.value!, targetField: e.key));
      }
      // If settlement date = operation date, copy the date mapping
      if (_sameSettlementDate && _mappings['date'] != null) {
        mappings.removeWhere((m) => m.targetField == 'valueDate');
        mappings.add(ColumnMapping(sourceColumn: _mappings['date']!, targetField: 'valueDate'));
      }
      // Multi-column mappings (override single mappings for same field)
      for (final e in _multiMappings.entries) {
        if (e.value.length < 2) continue;
        mappings.removeWhere((m) => m.targetField == e.key);
        mappings.add(ColumnMapping(targetField: e.key, multiColumns: List.of(e.value), multiDelimiter: _multiDelimiters[e.key] ?? ' '));
      }
      // Amount: balance-diff, formula, or simple mapping
      if (_balanceDiffColumn != null) {
        _log.info('_executeImport: amount from balance-diff column=$_balanceDiffColumn');
        mappings.add(ColumnMapping(targetField: 'amount', balanceDiffColumn: _balanceDiffColumn));
      } else if (_amountFormula.isNotEmpty) {
        final formulaDesc = _amountFormula.map((t) => '${t.operator}${t.sourceColumn}').join(' ');
        _log.info('_executeImport: amount formula=$formulaDesc');
        mappings.add(ColumnMapping(targetField: 'amount', formulaTerms: List.of(_amountFormula)));
      } else if (_mappings['amount'] != null) {
        mappings.add(ColumnMapping(sourceColumn: _mappings['amount']!, targetField: 'amount'));
      }

      _log.info('_executeImport: ${mappings.length} column mappings built');

      // Re-parse full file if preview was capped (large files)
      var fullPreview = _preview!;
      if (fullPreview.rows.length < fullPreview.totalRows) {
        _log.info('_executeImport: re-parsing full file (${fullPreview.totalRows} rows)...');
        fullPreview = await importer.getFullRows(fullPreview);
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
          accountId: _targetId!,
          onProgress: onProgress,
          balanceMode: _balanceMode,
          balanceFilterColumn: _balanceFilterColumn,
          balanceFilterInclude: _balanceFilterInclude.isNotEmpty ? _balanceFilterInclude : null,
        );
      } else if (_target == ImportTarget.income) {
        final baseCurrency = ref.read(baseCurrencyProvider).value ?? 'EUR';
        result = await importer.importIncomes(
          preview: fullPreview,
          mappings: mappings,
          defaultCurrency: baseCurrency,
          onProgress: onProgress,
        );
      } else {
        // Remove type mapping if using sign-based detection
        if (_typeMode == 'sign') {
          mappings.removeWhere((m) => m.targetField == 'type');
        }
        // ISIN lookup may not be available (e.g. stubbed market price service)
        IsinLookupService? isinLookup;
        try { isinLookup = ref.read(isinLookupServiceProvider); } catch (_) {}
        final assetResult = await importer.importAssetEventsGrouped(
          preview: fullPreview,
          mappings: mappings,
          onProgress: onProgress,
          computeFee: _feeMode == 'computed',
          isinLookup: isinLookup,
          buyValues: _buyValues.isNotEmpty ? _buyValues : null,
          sellValues: _sellValues.isNotEmpty ? _sellValues : null,
          selectedExchanges: _selectedExchanges.isNotEmpty ? _selectedExchanges : null,
          excludedIsins: _excludedIsins.isNotEmpty ? _excludedIsins : null,
          rateService: ref.read(exchangeRateServiceProvider),
          baseCurrency: ref.read(baseCurrencyProvider).value ?? 'EUR',
          intermediaryId: _selectedIntermediaryId,
        );
        result = assetResult.result;
      }

      _log.info('_executeImport: complete - imported=${result.importedRows}, deleted=${result.deletedRows}, errors=${result.errorRows}');
      if (result.errors.isNotEmpty) {
        _log.warning('_executeImport: first error: ${result.errors.first}');
      }

      // Save import config for this account
      await _saveConfig();

      // Auto-recalculate balances for the entire account after transaction import
      if (_target == ImportTarget.transaction && _targetId != null) {
        final txSvc = ref.read(transactionServiceProvider);
        final configSvc = ref.read(importConfigServiceProvider);
        final savedConfig = await configSvc.getByAccount(_targetId!);
        final mappings = savedConfig != null
            ? jsonDecode(savedConfig.mappingsJson) as Map<String, dynamic>
            : <String, dynamic>{};
        final mode = (mappings['__balanceMode'] as String?) ?? 'cumulative';
        await txSvc.recalculateBalances(_targetId!, balanceMode: mode, savedMappings: mappings);
      }

      _setState(() {
        _result = result;
        _step = 3;
        _importing = false;
      });
    } catch (e, stack) {
      _log.severe('_executeImport: failed', e, stack);
      _setState(() {
        _error = 'Import failed: $e';
        _importing = false;
      });
    }
  }
}
