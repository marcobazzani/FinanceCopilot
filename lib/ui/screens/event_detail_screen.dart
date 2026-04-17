import 'package:drift/drift.dart' hide Column;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database.dart';
import '../../database/providers.dart';
import '../../database/tables.dart';
import '../../l10n/app_strings.dart';
import '../../services/providers/providers.dart';
import '../../utils/formatters.dart' as fmt;
import 'dashboard/dashboard_screen.dart' show currencySymbol;
import 'event_edit_screen.dart';

class EventDetailScreen extends ConsumerWidget {
  final int eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final eventAsync = ref.watch(extraordinaryEventProvider(eventId));
    return eventAsync.when(
      data: (event) => _DetailBody(event: event),
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text(s.error(e)))),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  final ExtraordinaryEvent event;
  const _DetailBody({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final entriesAsync = ref.watch(extraordinaryEventEntriesProvider(event.id));
    final locale = ref.watch(appLocaleProvider).value ?? Platform.localeName;
    final sym = currencySymbol(event.currency);
    final dateFmt = fmt.shortDateFormat(locale);
    final amtFmt = fmt.amountFormat(locale);

    // Buffer reimbursements (spread outflow only).
    final bufferTxnAsync = event.bufferId != null
        ? ref.watch(bufferTransactionsProvider(event.bufferId!))
        : null;

    final isSpread = event.treatment == EventTreatment.spread;
    final isOutflow = event.direction == EventDirection.outflow;

    return Scaffold(
      appBar: AppBar(
        title: Text(event.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: s.edit,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => EventEditScreen(event: event)),
            ),
          ),
          if (isSpread)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: s.regenerateEntries,
              onPressed: () async {
                await ref.read(extraordinaryEventServiceProvider).generateScheduledEntries(event.id);
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
                      _directionChip(context, s, isOutflow),
                      const SizedBox(width: 8),
                      Chip(label: Text(isSpread ? s.eventTreatmentSpread : s.eventTreatmentInstant)),
                      const SizedBox(width: 8),
                      Chip(label: Text(event.currency)),
                      if (isSpread && event.stepFrequency != null) ...[
                        const SizedBox(width: 8),
                        Chip(label: Text(_freqLabel(s, event.stepFrequency!))),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  _infoRow(s.totalLabel, '${amtFmt.format(event.totalAmount)} $sym'),
                  _infoRow(s.eventDateLabel, dateFmt.format(event.eventDate)),
                  if (isSpread && event.spreadStart != null && event.spreadEnd != null)
                    _infoRow(
                      s.spreadLabel,
                      '${dateFmt.format(event.spreadStart!)} → ${dateFmt.format(event.spreadEnd!)}',
                    ),
                  if (event.notes != null && event.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      event.notes!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Entries header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Text(s.savingEvents, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                if (isSpread && event.bufferId == null && isOutflow)
                  TextButton.icon(
                    icon: const Icon(Icons.account_balance_wallet),
                    label: Text(s.enableReimbursements),
                    onPressed: () async {
                      await ref.read(extraordinaryEventServiceProvider).createLinkedBuffer(event.id);
                    },
                  ),
                if (isSpread && event.bufferId != null)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: s.tooltipAddReimbursement,
                    onPressed: () => _addReimbursement(context, ref),
                  ),
              ],
            ),
          ),

          // Unified entries list
          entriesAsync.when(
            data: (entries) {
              final reimbTxns = bufferTxnAsync?.value?.where((t) => t.isReimbursement).toList() ?? [];
              final items = <_TimelineItem>[];
              for (final e in entries) {
                items.add(_TimelineItem.entry(e));
              }
              for (final r in reimbTxns) {
                items.add(_TimelineItem.reimbursement(r));
              }
              items.sort((a, b) => a.date.compareTo(b.date));

              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(child: Text(s.noEntriesYet)),
                );
              }

              return Column(
                children: [
                  for (var i = 0; i < items.length; i++)
                    _TimelineTile(
                      item: items[i],
                      index: i,
                      locale: locale,
                      sym: sym,
                      onDelete: items[i].isReimbursement
                          ? () => _deleteReimbursement(ref, items[i].reimbursement!)
                          : (items[i].entry!.entryKind == EventEntryKind.manual
                              ? () => _deleteEntry(ref, items[i].entry!.id)
                              : null),
                    ),
                ],
              );
            },
            loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text(s.error(e))),
          ),

          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: (event.treatment == EventTreatment.instant)
          ? FloatingActionButton.extended(
              onPressed: () => _addManualEntry(context, ref),
              icon: const Icon(Icons.add),
              label: Text(s.addEventEntryTitle),
            )
          : null,
    );
  }

  Widget _directionChip(BuildContext context, AppStrings s, bool isOutflow) {
    final theme = Theme.of(context);
    return Chip(
      avatar: Icon(
        isOutflow ? Icons.trending_down : Icons.trending_up,
        size: 16,
        color: isOutflow ? theme.colorScheme.error : theme.colorScheme.primary,
      ),
      label: Text(isOutflow ? s.eventDirectionOutflow : s.eventDirectionInflow),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: TextStyle(color: Colors.grey.shade600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _freqLabel(AppStrings s, StepFrequency f) => switch (f) {
        StepFrequency.weekly => s.freqWeekly,
        StepFrequency.monthly => s.freqMonthly,
        StepFrequency.quarterly => s.freqQuarterly,
        StepFrequency.yearly => s.freqYearly,
      };

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final s = ref.read(appStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteAdjustmentTitle),
        content: Text(s.deleteAdjustmentConfirm(event.name)),
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
      await ref.read(extraordinaryEventServiceProvider).delete(event.id);
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<void> _addManualEntry(BuildContext context, WidgetRef ref) async {
    final s = ref.read(appStringsProvider);
    final locale = ref.read(appLocaleProvider).value ?? Platform.localeName;
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var date = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(s.addEventEntryTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                decoration: InputDecoration(labelText: s.amount),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                decoration: InputDecoration(labelText: s.descriptionOptional),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setDialogState(() => date = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(labelText: s.dateLabel),
                  child: Text(fmt.shortDateFormat(locale).format(date)),
                ),
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
    if (result != true) return;
    final amount = fmt.tryParseLocalized(amountCtrl.text, locale: locale);
    if (amount == null) return;
    await ref.read(extraordinaryEventServiceProvider).addManualEntry(
          eventId: event.id,
          date: date,
          amount: amount,
          description: descCtrl.text.trim(),
        );
  }

  Future<void> _addReimbursement(BuildContext context, WidgetRef ref) async {
    final s = ref.read(appStringsProvider);
    final locale = ref.read(appLocaleProvider).value ?? Platform.localeName;
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var date = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(s.addReimbursementTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                decoration: InputDecoration(labelText: s.amount),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                decoration: InputDecoration(labelText: s.descriptionOptional),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setDialogState(() => date = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(labelText: s.dateLabel),
                  child: Text(fmt.shortDateFormat(locale).format(date)),
                ),
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
    if (result != true) return;
    final amount = fmt.tryParseLocalized(amountCtrl.text, locale: locale);
    if (amount == null) return;
    final db = ref.read(databaseProvider);
    await db.into(db.bufferTransactions).insert(
          BufferTransactionsCompanion.insert(
            bufferId: event.bufferId!,
            operationDate: date,
            valueDate: date,
            amount: amount,
            balanceAfter: 0,
            currency: Value(event.currency),
            description: Value(descCtrl.text.trim()),
            isReimbursement: const Value(true),
          ),
        );
    await ref.read(extraordinaryEventServiceProvider).generateScheduledEntries(event.id);
  }

  Future<void> _deleteEntry(WidgetRef ref, int entryId) async {
    await ref.read(extraordinaryEventServiceProvider).deleteEntry(entryId);
  }

  Future<void> _deleteReimbursement(WidgetRef ref, BufferTransaction txn) async {
    final db = ref.read(databaseProvider);
    await (db.delete(db.bufferTransactions)..where((t) => t.id.equals(txn.id))).go();
    await ref.read(extraordinaryEventServiceProvider).generateScheduledEntries(event.id);
  }
}

// ── Timeline item union ──

class _TimelineItem {
  final ExtraordinaryEventEntry? entry;
  final BufferTransaction? reimbursement;

  _TimelineItem.entry(this.entry) : reimbursement = null;
  _TimelineItem.reimbursement(this.reimbursement) : entry = null;

  bool get isReimbursement => reimbursement != null;
  DateTime get date => entry?.date ?? reimbursement!.operationDate;
}

class _TimelineTile extends StatelessWidget {
  final _TimelineItem item;
  final int index;
  final String locale;
  final String sym;
  final VoidCallback? onDelete;

  const _TimelineTile({
    required this.item,
    required this.index,
    required this.locale,
    required this.sym,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = fmt.shortDateFormat(locale);
    final amtFmt = fmt.amountFormat(locale);

    if (item.isReimbursement) {
      final r = item.reimbursement!;
      return ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: Icon(Icons.call_received, size: 16, color: Colors.green.shade800),
        ),
        title: Text('${amtFmt.format(r.amount.abs())} $sym'),
        subtitle: Text('${dateFmt.format(r.operationDate)}${r.description.isNotEmpty ? ' · ${r.description}' : ''}'),
        trailing: onDelete != null
            ? IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete)
            : null,
      );
    }

    final e = item.entry!;
    final isScheduled = e.entryKind == EventEntryKind.scheduled;
    final color = isScheduled ? theme.colorScheme.tertiaryContainer : theme.colorScheme.primaryContainer;
    final icon = isScheduled ? Icons.event_repeat : Icons.adjust;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color,
        child: Icon(icon, size: 16, color: theme.colorScheme.onTertiaryContainer),
      ),
      title: Text('${amtFmt.format(e.amount.abs())} $sym'),
      subtitle: Text(
        '${dateFmt.format(e.date)}${e.description.isNotEmpty ? ' · ${e.description}' : ''}',
      ),
      trailing: onDelete != null
          ? IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete)
          : null,
    );
  }
}
