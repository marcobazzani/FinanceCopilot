part of 'account_detail_screen.dart';

extension _AccountDetailBalanceDialog on _AccountDetailScreenState {
  Future<void> _showBalanceDialog(BuildContext context) async {
    final s = ref.read(appStringsProvider);
    // Get all transactions with rawMetadata to discover available columns
    final txs = await ref.read(transactionServiceProvider).getByAccount(widget.account.id);
    if (txs.isEmpty) {
      if (context.mounted) {
        showInfoSnack(context, s.noTransactionsToRecalc);
      }
      return;
    }

    // Discover columns from rawMetadata (a row whose data cannot be read has none)
    final metas = [for (final tx in txs) ?decodeRawMetadata(tx.rawMetadata)];
    final columns = {for (final meta in metas) ...meta.keys}.toList()..sort();

    // Load saved config for current balance mode. Settings that cannot be
    // read (logged) are not offered: the user applies a mode explicitly.
    final savedConfig = await ref.read(importConfigServiceProvider).getByAccount(widget.account.id);
    final saved = savedConfig != null ? SavedImportMappings.decode(savedConfig.mappingsJson) : SavedImportMappings(const {});

    var balanceMode = saved.balanceMode ?? BalanceMode.byDefault;
    // The saved filter, offered when the filtered sum is picked.
    final savedFilter = saved.balanceFor(BalanceMode.filtered);
    String? filterColumn = savedFilter?.filterColumn;
    if (filterColumn != null && !columns.contains(filterColumn)) filterColumn = null;
    final filterInclude = <String>{...?savedFilter?.filterInclude};
    final hasBalanceColumn = saved.balanceFor(BalanceMode.column)?.balanceColumn != null;
    // Get unique values for filter column from rawMetadata
    List<String> uniqueValues(String col) {
      final vals = <String>{};
      for (final meta in metas) {
        final v = (meta[col]?.toString() ?? '').trim();
        if (v.isNotEmpty) vals.add(v);
      }
      return vals.toList()..sort();
    }

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(s.recalcBalanceTitle),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.recalcBalanceHelp, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 12),
                  SegmentedButton<BalanceMode>(
                    segments: [
                      ButtonSegment(value: BalanceMode.cumulative, label: Text(s.recalcCumulative)),
                      ButtonSegment(value: BalanceMode.column, label: Text(s.recalcColumn)),
                      ButtonSegment(value: BalanceMode.filtered, label: Text(s.recalcFiltered)),
                    ],
                    selected: {balanceMode},
                    onSelectionChanged: (v) => setDialogState(() {
                      balanceMode = v.first;
                      if (balanceMode != BalanceMode.filtered) {
                        filterColumn = null;
                        filterInclude.clear();
                      }
                    }),
                  ),
                  const SizedBox(height: 12),

                  if (balanceMode == BalanceMode.column)
                    Text(
                      s.balanceFromColumnHelp,
                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),

                  if (balanceMode == BalanceMode.cumulative)
                    Text(
                      s.balanceCumulativeHelp,
                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),

                  if (balanceMode == BalanceMode.filtered) ...[
                    Text(s.filterColumnLabel, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: filterColumn,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text('\u2014 ${s.none} \u2014', style: const TextStyle(color: Colors.grey)),
                        ),
                        ...columns.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                      ],
                      onChanged: (v) => setDialogState(() {
                        filterColumn = v;
                        filterInclude.clear();
                        if (v != null) filterInclude.addAll(uniqueValues(v));
                      }),
                    ),
                    if (filterColumn != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(s.includeValues, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          const Spacer(),
                          TextButton(
                            onPressed: () => setDialogState(() => filterInclude.addAll(uniqueValues(filterColumn!))),
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            child: Text(s.all, style: const TextStyle(fontSize: 11)),
                          ),
                          TextButton(
                            onPressed: () => setDialogState(() => filterInclude.clear()),
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            child: Text(s.none, style: const TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 4,
                        runSpacing: 0,
                        children: uniqueValues(filterColumn!).map((val) {
                          final selected = filterInclude.contains(val);
                          return FilterChip(
                            label: Text(val, style: const TextStyle(fontSize: 12)),
                            selected: selected,
                            onSelected: (v) => setDialogState(() {
                              if (v) {
                                filterInclude.add(val);
                              } else {
                                filterInclude.remove(val);
                              }
                            }),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
            FilledButton(
              onPressed:
                  (balanceMode == BalanceMode.filtered && filterColumn == null) || (balanceMode == BalanceMode.column && !hasBalanceColumn)
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      // The settings shown are the ones applied and saved — both
                      // or neither: a mode applied but not saved is reverted by
                      // the next automatic recalculation, and settings that
                      // could not be read are never rewritten.
                      final updatedMappings = Map<String, dynamic>.from(saved.values);
                      updatedMappings[SavedImportMappings.balanceModeKey] = balanceMode.name;
                      if (filterColumn != null) {
                        updatedMappings[SavedImportMappings.balanceFilterColumnKey] = filterColumn;
                      } else {
                        updatedMappings.remove(SavedImportMappings.balanceFilterColumnKey);
                      }
                      if (filterInclude.isNotEmpty) {
                        updatedMappings[SavedImportMappings.balanceFilterIncludeKey] = jsonEncode(filterInclude.toList());
                      } else {
                        updatedMappings.remove(SavedImportMappings.balanceFilterIncludeKey);
                      }
                      final formula = savedConfig != null ? SavedImportMappings.formulaTerms(savedConfig.formulaJson) : <Map<String, String>>[];
                      final hashColumns = savedConfig != null ? SavedImportMappings.textListOf(savedConfig.hashColumnsJson) : <String>[];
                      if (saved.corrupt ||
                          formula == null ||
                          hashColumns == null ||
                          updatedMappings.values.any((v) => v != null && v is! String)) {
                        _log.warning('balanceRecalc: saved import config unreadable - nothing recalculated nor overwritten');
                        if (context.mounted) showInfoSnack(context, s.balanceSettingsUnreadable);
                        return;
                      }
                      // Read before awaiting: the screen may be gone when the
                      // recalculation ends, and the mode must still be saved.
                      final configs = ref.read(importConfigServiceProvider);
                      await _executeBalanceRecalc(txs, balanceMode, filterColumn, filterInclude, updatedMappings, savedConfig?.numberLocale);
                      await configs.save(
                        accountId: widget.account.id,
                        skipRows: savedConfig?.skipRows ?? 0,
                        mappings: updatedMappings.map((k, v) => MapEntry(k, v as String?)),
                        formula: formula,
                        hashColumns: hashColumns,
                        // Keep the account's number format: it describes the stored text.
                        numberLocale: savedConfig?.numberLocale,
                      );
                    },
              child: Text(s.recalculate),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeBalanceRecalc(
    List<Transaction> transactions,
    BalanceMode balanceMode,
    String? filterColumn,
    Set<String> filterInclude,
    Map<String, dynamic> mappings,
    // The number format of the stored statement text (column mode reads it).
    String? numberLocale,
  ) async {
    _log.info('balanceRecalc: mode=${balanceMode.name}, filterCol=$filterColumn, include=$filterInclude, ${transactions.length} txs');
    final s = ref.read(appStringsProvider);
    final txSvc = ref.read(transactionServiceProvider);
    final result = await txSvc.recalculateBalancesDetailed(
      widget.account.id,
      balanceMode: balanceMode.name,
      savedMappings: mappings,
      numberLocale: numberLocale,
    );
    if (!mounted) return;
    var msg = s.recalculatedBalances(result.updated);
    var figures = const <String>[];
    // Column mode reconciliation: say what the bank closing implied, never
    // absorb it silently.
    if (result.anchored == false) {
      msg = '$msg ${s.balanceNotAnchored}';
    } else if (result.anchored == true && (result.opening ?? 0).abs() >= 0.005) {
      final locale = ref.read(appLocaleProvider).value ?? Platform.localeName;
      final f = fmt.amountFormat(locale);
      // Both are balances: masked in privacy mode, the explanation is not.
      msg = '$msg ${s.balanceAnchoredOpening(privacySlot(0), privacySlot(1))}';
      figures = [f.format(result.opening), f.format(result.bankClosing)];
    }
    showInfoSnack(context, msg, maskedFigures: figures);
  }
}
