import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database.dart';
import '../../services/providers/providers.dart';
import '../../l10n/app_strings.dart';
import '../../utils/formatters.dart' as fmt;
import 'dashboard/dashboard_screen.dart' show currencySymbol;
import 'income_adj_edit_screen.dart';

class IncomeAdjDetailScreen extends ConsumerWidget {
  final int adjustmentId;
  const IncomeAdjDetailScreen({super.key, required this.adjustmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final adjAsync = ref.watch(incomeAdjustmentProvider(adjustmentId));

    return adjAsync.when(
      data: (adj) => _DetailBody(adjustment: adj),
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(s.error(e))),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  final IncomeAdjustment adjustment;
  const _DetailBody({required this.adjustment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final expensesAsync = ref.watch(incomeAdjustmentExpensesProvider(adjustment.id));
    final locale = ref.watch(appLocaleProvider).value ?? 'en_US';
    final sym = currencySymbol(adjustment.currency);
    final amtFmt = fmt.currencyFormat(locale, sym);
    final dateFmt = fmt.shortDateFormat(locale);

    return Scaffold(
      appBar: AppBar(
        title: Text(adjustment.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: s.edit,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => IncomeAdjEditScreen(adjustment: adjustment),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: s.delete,
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: ListView(
        children: [
          // Summary card
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Chip(label: Text(adjustment.currency)),
                      const SizedBox(width: 8),
                      Chip(label: Text(s.incomeChip)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _infoRow(s.totalLabel, amtFmt.format(adjustment.totalAmount)),
                  _infoRow(s.incomeDateFieldLabel, dateFmt.format(adjustment.incomeDate)),
                  expensesAsync.when(
                    data: (expenses) {
                      final totalSpent = expenses.fold(0.0, (sum, e) => sum + e.amount);
                      final remaining = adjustment.totalAmount - totalSpent;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoRow(s.spentLabel, amtFmt.format(totalSpent)),
                          _infoRow(s.remainingLabel, amtFmt.format(remaining)),
                        ],
                      );
                    },
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  ),
                ],
              ),
            ),
          ),

          // Expenses header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(s.expensesLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: s.tooltipAddExpense,
                  onPressed: () => _addExpense(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Expenses list
          expensesAsync.when(
            data: (expenses) {
              if (expenses.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(child: Text(s.noExpensesYet,
                      style: const TextStyle(color: Colors.grey))),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < expenses.length; i++)
                    ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.orange.withValues(alpha: 0.15),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
                        ),
                      ),
                      title: Text(
                        '${dateFmt.format(expenses[i].date)}${expenses[i].description.isNotEmpty ? ' — ${expenses[i].description}' : ''}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      trailing: Text(
                        amtFmt.format(expenses[i].amount),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onLongPress: () => _confirmDeleteExpense(context, ref, expenses[i].id),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(s.error(e))),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Future<void> _addExpense(BuildContext context, WidgetRef ref) async {
    final s = ref.read(appStringsProvider);
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var date = DateTime.now();
    final locale = ref.read(appLocaleProvider).value ?? 'en_US';
    final dateFmt = fmt.shortDateFormat(locale);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(s.addExpenseTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountCtrl,
                decoration: InputDecoration(labelText: s.amount),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: descCtrl,
                decoration: InputDecoration(labelText: s.description, hintText: s.expenseHint),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.datePrefix(dateFmt.format(date))),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2050),
                  );
                  if (picked != null) setDialogState(() => date = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.add)),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
      if (amount == null || amount <= 0) return;

      await ref.read(incomeAdjustmentServiceProvider).addExpense(
        adjustmentId: adjustment.id,
        date: date,
        amount: amount,
        description: descCtrl.text.trim(),
      );
    }
  }

  Future<void> _confirmDeleteExpense(BuildContext context, WidgetRef ref, int expenseId) async {
    final s = ref.read(appStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteExpenseTitle),
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
      await ref.read(incomeAdjustmentServiceProvider).deleteExpense(expenseId);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final s = ref.read(appStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteIncomeAdjTitle),
        content: Text(s.deleteIncomeAdjConfirm(adjustment.name)),
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
      await ref.read(incomeAdjustmentServiceProvider).delete(adjustment.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}
