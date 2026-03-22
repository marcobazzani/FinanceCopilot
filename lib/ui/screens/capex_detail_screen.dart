import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../services/providers.dart';
import '../../l10n/app_strings.dart';
import '../../utils/formatters.dart' as fmt;
import 'capex_edit_screen.dart';
import 'dashboard_screen.dart' show currencySymbol;

class CapexDetailScreen extends ConsumerWidget {
  final int scheduleId;
  const CapexDetailScreen({super.key, required this.scheduleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final scheduleAsync = ref.watch(capexScheduleProvider(scheduleId));

    return scheduleAsync.when(
      data: (schedule) => _DetailBody(schedule: schedule),
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
  final DepreciationSchedule schedule;
  const _DetailBody({required this.schedule});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final entriesAsync = ref.watch(capexEntriesProvider(schedule.id));
    final locale = ref.watch(appLocaleProvider).value ?? 'en_US';
    final sym = currencySymbol(schedule.currency);
    final dateFmt = fmt.shortDateFormat(locale);
    final amtFmt = fmt.currencyFormat(locale, sym);

    final bufferTxnAsync = schedule.bufferId != null
        ? ref.watch(bufferTransactionsProvider(schedule.bufferId!))
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(schedule.assetName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: s.edit,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CapexEditScreen(schedule: schedule),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: s.tooltipRegenerateEntries,
            onPressed: () async {
              await ref.read(capexServiceProvider).generateEntries(schedule.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(s.entriesRegenerated)),
                );
              }
            },
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
                      Chip(label: Text(schedule.currency)),
                      const SizedBox(width: 8),
                      Chip(label: Text(schedule.stepFrequency.name)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _infoRow('Total', amtFmt.format(schedule.totalAmount)),
                  if (schedule.expenseDate != null)
                    _infoRow('Expense', dateFmt.format(schedule.expenseDate!)),
                  _infoRow('Spread', '${dateFmt.format(schedule.startDate)} → ${dateFmt.format(schedule.endDate)}'),
                ],
              ),
            ),
          ),

          // Saving Events header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(s.savingEvents, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                if (schedule.bufferId != null)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: s.tooltipAddReimbursement,
                    onPressed: () => _addReimbursement(context, ref),
                  )
                else
                  FilledButton.tonal(
                    onPressed: () async {
                      await ref.read(capexServiceProvider).createLinkedBuffer(schedule.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(s.reimbursementEnabled)),
                        );
                      }
                    },
                    child: Text(s.enableReimbursements),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Unified list: spread entries + reimbursements sorted by date
          _buildUnifiedEventList(entriesAsync, bufferTxnAsync, dateFmt, amtFmt, context, ref),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildUnifiedEventList(
    AsyncValue<List<DepreciationEntry>> entriesAsync,
    AsyncValue<List<BufferTransaction>>? bufferTxnAsync,
    dynamic dateFmt,
    dynamic amtFmt,
    BuildContext context,
    WidgetRef ref,
  ) {
    final entries = entriesAsync.value ?? [];
    final reimbursements = (bufferTxnAsync?.value ?? [])
        .where((t) => t.isReimbursement)
        .toList();

    if (entriesAsync.isLoading || (bufferTxnAsync != null && bufferTxnAsync.isLoading)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (entries.isEmpty && reimbursements.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(child: Text(ref.read(appStringsProvider).noEventsCapex, style: const TextStyle(color: Colors.grey))),
      );
    }

    // Build unified list of (date, isReimbursement, entry/txn)
    final items = <({DateTime date, bool isReimbursement, DepreciationEntry? entry, BufferTransaction? txn})>[];
    for (final e in entries) {
      items.add((date: e.date, isReimbursement: false, entry: e, txn: null));
    }
    for (final t in reimbursements) {
      items.add((date: t.operationDate, isReimbursement: true, entry: null, txn: t));
    }
    items.sort((a, b) => a.date.compareTo(b.date));

    // Track entry index for numbering spread entries
    var entryIdx = 0;
    final totalReimbursed = reimbursements.fold(0.0, (sum, t) => sum + t.amount.abs());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reimbursements.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text('Total reimbursed: ${amtFmt.format(totalReimbursed)}',
                style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600)),
          ),
        for (final item in items)
          if (item.isReimbursement)
            ListTile(
              dense: true,
              leading: const Icon(Icons.arrow_back, color: Colors.green, size: 20),
              title: Text(
                '${dateFmt.format(item.txn!.operationDate)} — ${item.txn!.description.isNotEmpty ? item.txn!.description : "Reimbursement"}',
                style: const TextStyle(fontSize: 13),
              ),
              trailing: Text(
                '+${amtFmt.format(item.txn!.amount.abs())}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
              ),
              onLongPress: () => _confirmDeleteReimbursement(context, ref, item.txn!.id),
            )
          else
            Builder(builder: (_) {
              entryIdx++;
              final e = item.entry!;
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.teal.withValues(alpha: 0.15),
                  child: Text(
                    '$entryIdx',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                ),
                title: Text(
                  dateFmt.format(e.date),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'Cumulative: ${amtFmt.format(e.cumulative)} · Remaining: ${amtFmt.format(e.remaining)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                trailing: Text(
                  amtFmt.format(e.amount),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              );
            }),
      ],
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
          title: Text(s.addReimbursementTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountCtrl,
                decoration: InputDecoration(labelText: s.amount),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: descCtrl,
                decoration: InputDecoration(labelText: s.description, hintText: s.reimbursementFromHint),
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
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.add),
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
    final s = ref.read(appStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteReimbursementTitle),
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
      await ref.read(bufferServiceProvider).deleteTransaction(txnId);
      await ref.read(capexServiceProvider).generateEntries(schedule.id);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final s = ref.read(appStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteAdjustmentTitle),
        content: Text(s.deleteAdjustmentConfirm(schedule.assetName)),
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
      await ref.read(capexServiceProvider).delete(schedule.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}
