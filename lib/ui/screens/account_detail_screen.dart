import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../database/tables.dart';
import '../../services/providers/providers.dart';
import '../../utils/formatters.dart' as fmt;
import '../../utils/logger.dart';
import 'import/import_screen.dart';
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
                          ? s.noTransactionsImport
                          : s.noMatchingTransactions,
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
                        tx.description.isNotEmpty ? tx.description : s.noDescription,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(dateFmt.format(tx.operationDate), style: const TextStyle(fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${isPositive ? '+' : ''}${amtFmt.format(tx.amount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
                              fontSize: 14,
                            ),
                          ),
                          if (isPositive) ...[
                            const SizedBox(width: 4),
                            PopupMenuButton<String>(
                              iconSize: 18,
                              padding: EdgeInsets.zero,
                              tooltip: s.flagAsIncomeTooltip,
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'flag_income',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.label_important_outline, size: 18),
                                      const SizedBox(width: 8),
                                      Text(s.flagAsIncomeTooltip),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (v) {
                                if (v == 'flag_income') _flagAsIncome(tx);
                              },
                            ),
                          ],
                        ],
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
                    Text('${transactions.length} ${s.transactions}', style: const TextStyle(fontSize: 13)),
                    Text(
                      balance != null
                          ? '${s.balance}: ${balance >= 0 ? '+' : ''}${amtFmt.format(balance)}'
                          : '${transactions.length} ${s.records}',
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

  Future<void> _flagAsIncome(Transaction tx) async {
    final s = ref.read(appStringsProvider);
    var selectedType = IncomeType.salary;

    String typeLabel(IncomeType t) => switch (t) {
      IncomeType.income   => s.incomeTypeIncome,
      IncomeType.refund   => s.incomeTypeRefund,
      IncomeType.salary   => s.incomeTypeSalary,
      IncomeType.donation => s.incomeTypeDonation,
      IncomeType.coupon   => s.incomeTypeCoupon,
      IncomeType.other    => s.incomeTypeOther,
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(s.flagAsIncomeTitle),
          content: DropdownButtonFormField<IncomeType>(
            value: selectedType,
            decoration: InputDecoration(labelText: s.incomeTypeLabel),
            items: IncomeType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(typeLabel(t))))
                .toList(),
            onChanged: (v) => setDialogState(() => selectedType = v!),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.add)),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    await ref.read(incomeServiceProvider).create(
      date: tx.operationDate,
      amount: tx.amount,
      type: selectedType,
      currency: tx.currency,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.incomeFlaggedSnack)),
      );
    }
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
          '${s.wipeTransactionsBody(widget.account.name)}${s.cannotBeUndone}',
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
                      value: filterColumn,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(value: null, child: Text('\u2014 ${s.none} \u2014', style: const TextStyle(color: Colors.grey))),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.recalculatedBalances(updated))),
      );
    }
  }
}
