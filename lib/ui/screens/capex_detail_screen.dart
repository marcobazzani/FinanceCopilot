import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../database/database.dart';
import '../../services/providers.dart';
import 'capex_edit_screen.dart';
import 'dashboard_screen.dart' show currencySymbol;

final _dateFmt = DateFormat('dd/MM/yyyy');

class CapexDetailScreen extends ConsumerWidget {
  final int scheduleId;
  const CapexDetailScreen({super.key, required this.scheduleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(capexScheduleProvider(scheduleId));

    return scheduleAsync.when(
      data: (schedule) => _DetailBody(schedule: schedule),
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  final DepreciationSchedule schedule;
  const _DetailBody({required this.schedule});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(capexEntriesProvider(schedule.id));
    final sym = currencySymbol(schedule.currency);
    final amtFmt = NumberFormat.currency(locale: 'it_IT', symbol: sym);

    final bufferTxnAsync = schedule.bufferId != null
        ? ref.watch(bufferTransactionsProvider(schedule.bufferId!))
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(schedule.assetName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CapexEditScreen(schedule: schedule),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Regenerate Entries',
            onPressed: () async {
              await ref.read(capexServiceProvider).generateEntries(schedule.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Entries regenerated.')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Delete',
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
                      Chip(label: Text(schedule.currency)),
                      const SizedBox(width: 8),
                      Chip(label: Text(schedule.stepFrequency.name)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _infoRow('Total', amtFmt.format(schedule.totalAmount)),
                  if (schedule.expenseDate != null)
                    _infoRow('Expense', _dateFmt.format(schedule.expenseDate!)),
                  _infoRow('Spread', '${_dateFmt.format(schedule.startDate)} → ${_dateFmt.format(schedule.endDate)}'),
                ],
              ),
            ),
          ),

          // Entries header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Text('Spread Entries', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                entriesAsync.when(
                  data: (entries) => Text('${entries.length} entries', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Entries list
          entriesAsync.when(
            data: (entries) {
              if (entries.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: Text('No entries generated yet.', style: TextStyle(color: Colors.grey))),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < entries.length; i++)
                    ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.teal.withValues(alpha: 0.15),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                      ),
                      title: Text(
                        _dateFmt.format(entries[i].date),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        'Cumulative: ${amtFmt.format(entries[i].cumulative)} · Remaining: ${amtFmt.format(entries[i].remaining)}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      trailing: Text(
                        amtFmt.format(entries[i].amount),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),

          const Divider(height: 32),

          // Reimbursements section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Text('Reimbursements', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                if (schedule.bufferId != null)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Add Reimbursement',
                    onPressed: () => _addReimbursement(context, ref),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          if (schedule.bufferId == null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.tonal(
                onPressed: () async {
                  await ref.read(capexServiceProvider).createLinkedBuffer(schedule.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reimbursement tracking enabled.')),
                    );
                  }
                },
                child: const Text('Enable Reimbursement Tracking'),
              ),
            )
          else if (bufferTxnAsync != null)
            bufferTxnAsync.when(
              data: (txns) {
                final reimbursements = txns.where((t) => t.isReimbursement).toList();
                if (reimbursements.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: Text('No reimbursements yet.', style: TextStyle(color: Colors.grey))),
                  );
                }
                final totalReimbursed = reimbursements.fold(0.0, (sum, t) => sum + t.amount.abs());
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          Text('Total reimbursed: ${amtFmt.format(totalReimbursed)}',
                              style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    for (final txn in reimbursements)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.arrow_back, color: Colors.green, size: 20),
                        title: Text(
                          '${_dateFmt.format(txn.operationDate)} — ${txn.description.isNotEmpty ? txn.description : "Reimbursement"}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        trailing: Text(
                          '+${amtFmt.format(txn.amount.abs())}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                        ),
                        onLongPress: () => _confirmDeleteReimbursement(context, ref, txn.id),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
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

  Future<void> _addReimbursement(BuildContext context, WidgetRef ref) async {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var date = DateTime.now();
    final dateFmt = DateFormat('dd/MM/yyyy');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Reimbursement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountCtrl,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description', hintText: 'e.g. From John'),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Date: ${dateFmt.format(date)}'),
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
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final amount = double.tryParse(amountCtrl.text);
      if (amount == null || amount <= 0) return;

      await ref.read(bufferServiceProvider).createTransaction(
        bufferId: schedule.bufferId!,
        operationDate: date,
        amount: amount,
        description: descCtrl.text.trim(),
        currency: schedule.currency,
        isReimbursement: true,
      );
      await ref.read(capexServiceProvider).generateEntries(schedule.id);
    }
  }

  Future<void> _confirmDeleteReimbursement(BuildContext context, WidgetRef ref, int txnId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reimbursement?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(bufferServiceProvider).deleteTransaction(txnId);
      await ref.read(capexServiceProvider).generateEntries(schedule.id);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Adjustment?'),
        content: Text('Delete "${schedule.assetName}" and all its entries?\nThis cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(capexServiceProvider).delete(schedule.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}
