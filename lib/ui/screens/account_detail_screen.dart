import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../services/providers.dart';
import '../../utils/amount_parser.dart' as amt;
import '../../utils/formatters.dart' as fmt;
import '../../utils/logger.dart';
import 'import_screen.dart';
import 'transaction_edit_screen.dart';

final _log = getLogger('AccountDetailScreen');

/// Shows transactions for a single account, with search/filter and edit/delete.
class AccountDetailScreen extends ConsumerStatefulWidget {
  final Account account;
  const AccountDetailScreen({super.key, required this.account});

  @override
  ConsumerState<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final txStream = ref.watch(accountTransactionsProvider(widget.account.id));
    final locale = ref.watch(appLocaleProvider).value ?? 'en_US';
    final dateFmt = fmt.shortDateFormat(locale);
    final amtFmt = fmt.currencyFormat(locale, widget.account.currency);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: s.tooltipImportFile,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ImportScreen(preselectedAccountId: widget.account.id)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            tooltip: s.tooltipRecalcBalance,
            onPressed: () => _showBalanceDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: s.tooltipAddTransaction,
            onPressed: () => _addTransaction(),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: s.tooltipEditAccount,
            onPressed: () => _editAccount(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: s.tooltipWipeTransactions,
            onPressed: () => _confirmWipeTransactions(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: s.tooltipDeleteAccount,
            color: Colors.red,
            onPressed: () => _confirmDeleteAccount(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: s.searchTransactions,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),
          // Transaction list
          Expanded(
            child: txStream.when(
              data: (transactions) {
                final filtered = _searchQuery.isEmpty
                    ? transactions
                    : transactions.where((t) {
                        return t.description.toLowerCase().contains(_searchQuery) ||
                            (t.descriptionFull?.toLowerCase().contains(_searchQuery) ?? false) ||
                            t.amount.toString().contains(_searchQuery);
                      }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      transactions.isEmpty
                          ? 'No transactions yet.\nImport a file to add transactions.'
                          : 'No matching transactions.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final tx = filtered[i];
                    final isPositive = tx.amount >= 0;
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: isPositive
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                        child: Icon(
                          isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                          size: 16,
                          color: isPositive ? Colors.green : Colors.red,
                        ),
                      ),
                      title: Text(
                        tx.description.isNotEmpty ? tx.description : '(no description)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(dateFmt.format(tx.operationDate), style: const TextStyle(fontSize: 12)),
                      trailing: Text(
                        amtFmt.format(tx.amount),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
                          fontSize: 14,
                        ),
                      ),
                      onTap: () => _openTransaction(tx),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(s.error(e))),
            ),
          ),
          // Summary bar
          txStream.when(
            data: (transactions) {
              if (transactions.isEmpty) return const SizedBox();
              // Use the last transaction in chronological order (latest date, then highest id)
              // to match balance computation order.
              final lastTx = transactions.reduce((a, b) {
                final cmp = a.operationDate.compareTo(b.operationDate);
                if (cmp != 0) return cmp > 0 ? a : b;
                return a.id > b.id ? a : b;
              });
              final balance = lastTx.balanceAfter;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${transactions.length} transactions', style: const TextStyle(fontSize: 13)),
                    Text(
                      balance != null
                          ? 'Balance: ${amtFmt.format(balance)}'
                          : '${transactions.length} records',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: balance != null && balance >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
    );
  }

  void _openTransaction(Transaction tx) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionEditScreen(
          transaction: tx,
          account: widget.account,
        ),
      ),
    );
  }

  void _addTransaction() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionEditScreen(account: widget.account),
      ),
    );
  }

  Future<void> _confirmWipeTransactions(BuildContext context) async {
    final s = ref.read(appStringsProvider);
    final txCount = ref.read(accountTransactionsProvider(widget.account.id)).value?.length ?? 0;
    if (txCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.noTransactionsToWipe)),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.wipeAllTransactionsTitle),
        content: Text(
          'This will delete all $txCount transactions from "${widget.account.name}" '
          'but keep the account and its import configuration (column mappings, '
          'dedup keys, balance settings).\n\n${s.cannotBeUndone}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.wipe),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _log.warning('wiping transactions for account ${widget.account.id}');
      final deleted = await ref.read(transactionServiceProvider).deleteByAccount(widget.account.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.wipedTransactions(deleted))),
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final s = ref.read(appStringsProvider);
    final txCount = ref.read(accountTransactionsProvider(widget.account.id)).value?.length ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteAccountTitle),
        content: Text(s.deleteAccountConfirm(widget.account.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _log.warning('deleting account id=${widget.account.id} name=${widget.account.name}');
      await ref.read(accountServiceProvider).delete(widget.account.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _editAccount(BuildContext context) async {
    final s = ref.read(appStringsProvider);
    final nameCtrl = TextEditingController(text: widget.account.name);
    var currencyCtrl = TextEditingController(text: widget.account.currency);
    var institutionCtrl = TextEditingController(text: widget.account.institution);
    var isActive = widget.account.isActive;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(s.editAccountTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: s.name),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: currencyCtrl,
                  decoration: InputDecoration(labelText: s.currency, hintText: 'EUR'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: institutionCtrl,
                  decoration: InputDecoration(labelText: s.institution),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: Text(s.active),
                  value: isActive,
                  onChanged: (v) => setDialogState(() => isActive = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await ref.read(accountServiceProvider).update(
                  widget.account.id,
                  AccountsCompanion(
                    name: Value(nameCtrl.text.trim()),
                    currency: Value(currencyCtrl.text.trim()),
                    institution: Value(institutionCtrl.text.trim()),
                    isActive: Value(isActive),
                    updatedAt: Value(DateTime.now()),
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(s.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBalanceDialog(BuildContext context) async {
    final s = ref.read(appStringsProvider);
    // Get all transactions with rawMetadata to discover available columns
    final txs = await ref.read(transactionServiceProvider).getByAccount(widget.account.id);
    if (txs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.noTransactionsToRecalc)),
        );
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

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(s.recalcBalanceTitle),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.recalcBalanceHelp,
                      style: const TextStyle(fontSize: 13, color: Colors.grey)),
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
                    const Text(
                      'Balance is read from the imported CSV column (set during import)',
                      style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),

                  if (balanceMode == 'cumulative')
                    const Text(
                      'Balance = running sum of amount from oldest to newest',
                      style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),

                  if (balanceMode == 'filtered') ...[
                    const Text('Filter column:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: filterColumn,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— None —', style: TextStyle(color: Colors.grey))),
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
                          const Text('Include values:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          const Spacer(),
                          TextButton(
                            onPressed: () => setDialogState(() => filterInclude.addAll(uniqueValues(filterColumn!))),
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            child: const Text('All', style: TextStyle(fontSize: 11)),
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
                              if (v) { filterInclude.add(val); } else { filterInclude.remove(val); }
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
              onPressed: (balanceMode == 'filtered' && filterColumn == null) ||
                      (balanceMode == 'column' && savedMappings['balanceAfter'] == null)
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
                      await ref.read(importConfigServiceProvider).save(
                        accountId: widget.account.id,
                        skipRows: savedConfig?.skipRows ?? 0,
                        mappings: updatedMappings.map((k, v) => MapEntry(k, v as String?)),
                        formula: savedConfig != null
                            ? (jsonDecode(savedConfig.formulaJson) as List<dynamic>)
                                .map((e) => (e as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String)))
                                .toList()
                            : [],
                        hashColumns: savedConfig != null
                            ? (jsonDecode(savedConfig.hashColumnsJson) as List<dynamic>).cast<String>()
                            : [],
                      );
                    },
              child: const Text('Recalculate'),
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
    final txSvc = ref.read(transactionServiceProvider);

    // Sort chronologically (date ASC, id ASC) so cumulative balance
    // accumulates from oldest to newest, regardless of CSV import order.
    final sorted = List.of(transactions)..sort((a, b) {
      final cmp = a.operationDate.compareTo(b.operationDate);
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });

    // All arithmetic in integer cents to avoid floating point errors
    int toCents(double v) => (v * 100).round();
    double fromCents(int c) => c / 100;

    int balanceCents = 0;
    final updates = <int, double?>{}; // id → newBalance
    final balanceColumn = mappings['balanceAfter'] as String?;

    for (final tx in sorted) {
      double? newBalance;

      if (balanceMode == 'column') {
        // Read balance from the original CSV column stored in rawMetadata
        if (balanceColumn != null && tx.rawMetadata != null) {
          final meta = jsonDecode(tx.rawMetadata!) as Map<String, dynamic>;
          final raw = meta[balanceColumn]?.toString() ?? '';
          newBalance = amt.tryParseAmount(raw);
        }
      } else if (balanceMode == 'cumulative') {
        balanceCents += toCents(tx.amount);
        newBalance = fromCents(balanceCents);
      } else if (balanceMode == 'filtered') {
        String filterVal = '';
        if (filterColumn != null && tx.rawMetadata != null) {
          final meta = jsonDecode(tx.rawMetadata!) as Map<String, dynamic>;
          filterVal = (meta[filterColumn]?.toString() ?? '').trim();
        }
        final included = filterInclude.isEmpty || filterInclude.contains(filterVal);
        if (included) {
          balanceCents += toCents(tx.amount);
        }
        newBalance = fromCents(balanceCents);
      }

      if (newBalance != tx.balanceAfter) {
        updates[tx.id] = newBalance;
      }
    }

    // Batch update
    await txSvc.batchUpdateBalances(updates);

    _log.info('balanceRecalc: updated ${updates.length} transactions, final balance=${fromCents(balanceCents)}');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recalculated ${updates.length} balances. Final: ${fromCents(balanceCents)}')),
      );
    }
  }
}
