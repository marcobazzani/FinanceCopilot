part of '../account_detail_screen.dart';

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

    // Discover columns from rawMetadata
    final allColumns = <String>{};
    for (final tx in txs) {
      if (tx.rawMetadata != null) {
        final meta = jsonDecode(tx.rawMetadata!) as Map<String, dynamic>;
        allColumns.addAll(meta.keys);
      }
    }
    final columns = allColumns.toList()..sort();

    // Load saved config for current balance mode
    final savedConfig = await ref.read(importConfigServiceProvider).getByAccount(widget.account.id);
    Map<String, dynamic> savedMappings = {};
    if (savedConfig != null) {
      savedMappings = jsonDecode(savedConfig.mappingsJson) as Map<String, dynamic>;
    }

    var balanceMode = (savedMappings['__balanceMode'] as String?) ?? 'cumulative';
    String? filterColumn = savedMappings['__balanceFilterColumn'] as String?;
    if (filterColumn != null && !columns.contains(filterColumn)) filterColumn = null;
    final filterInclude = <String>{};
    if (savedMappings.containsKey('__balanceFilterInclude')) {
      filterInclude.addAll(
        (jsonDecode(savedMappings['__balanceFilterInclude'] as String) as List<dynamic>).cast<String>(),
      );
    }
    // Get unique values for filter column from rawMetadata
    List<String> uniqueValues(String col) {
      final vals = <String>{};
      for (final tx in txs) {
        if (tx.rawMetadata == null) continue;
        final meta = jsonDecode(tx.rawMetadata!) as Map<String, dynamic>;
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
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'cumulative', label: Text(s.recalcCumulative)),
                      ButtonSegment(value: 'column', label: Text(s.recalcColumn)),
                      ButtonSegment(value: 'filtered', label: Text(s.recalcFiltered)),
                    ],
                    selected: {balanceMode},
                    onSelectionChanged: (v) => setDialogState(() {
                      balanceMode = v.first;
                      if (balanceMode != 'filtered') {
                        filterColumn = null;
                        filterInclude.clear();
                      }
                    }),
                  ),
                  const SizedBox(height: 12),

                  if (balanceMode == 'column')
                    Text(
                      s.balanceFromColumnHelp,
                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),

                  if (balanceMode == 'cumulative')
                    Text(
                      s.balanceCumulativeHelp,
                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),

                  if (balanceMode == 'filtered') ...[
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
                  (balanceMode == 'filtered' && filterColumn == null) || (balanceMode == 'column' && savedMappings['balanceAfter'] == null)
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await _executeBalanceRecalc(txs, balanceMode, filterColumn, filterInclude, savedMappings);
                      // Update saved config with new balance mode
                      final updatedMappings = Map<String, dynamic>.from(savedMappings);
                      updatedMappings['__balanceMode'] = balanceMode;
                      if (filterColumn != null) {
                        updatedMappings['__balanceFilterColumn'] = filterColumn;
                      } else {
                        updatedMappings.remove('__balanceFilterColumn');
                      }
                      if (filterInclude.isNotEmpty) {
                        updatedMappings['__balanceFilterInclude'] = jsonEncode(filterInclude.toList());
                      } else {
                        updatedMappings.remove('__balanceFilterInclude');
                      }
                      await ref
                          .read(importConfigServiceProvider)
                          .save(
                            accountId: widget.account.id,
                            skipRows: savedConfig?.skipRows ?? 0,
                            mappings: updatedMappings.map((k, v) => MapEntry(k, v as String?)),
                            formula: savedConfig != null
                                ? (jsonDecode(savedConfig.formulaJson) as List<dynamic>)
                                      .map((e) => (e as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String)))
                                      .toList()
                                : [],
                            hashColumns: savedConfig != null ? (jsonDecode(savedConfig.hashColumnsJson) as List<dynamic>).cast<String>() : [],
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
    String balanceMode,
    String? filterColumn,
    Set<String> filterInclude,
    Map<String, dynamic> mappings,
  ) async {
    _log.info('balanceRecalc: mode=$balanceMode, filterCol=$filterColumn, include=$filterInclude, ${transactions.length} txs');
    final s = ref.read(appStringsProvider);
    final txSvc = ref.read(transactionServiceProvider);
    final updated = await txSvc.recalculateBalances(
      widget.account.id,
      balanceMode: balanceMode,
      savedMappings: mappings,
    );
    if (mounted) {
      showInfoSnack(context, s.recalculatedBalances(updated));
    }
  }
}
