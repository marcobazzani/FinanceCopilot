import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finance_copilot/utils/dialogs.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/utils/formatters.dart' as fmt;
import 'package:finance_copilot/utils/visualization_clock.dart' show dateOnly;
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show currencySymbol;
import 'package:finance_copilot/ui/screens/events/event_edit_screen.dart';
import 'package:finance_copilot/ui/widgets/edit_form_fields.dart';
import 'package:finance_copilot/ui/widgets/empty_state.dart';
import 'package:finance_copilot/ui/widgets/global_app_bar_actions.dart';
import 'package:finance_copilot/ui/widgets/mobile_pull_to_refresh.dart';
import 'package:finance_copilot/ui/widgets/privacy_text.dart';
import 'package:finance_copilot/ui/widgets/swipe_to_delete.dart';

/// Asks, then deletes [event] with its entries and linked buffer; says
/// whether it did. Behind the detail view's trashcan and the swipe of the
/// adjustments list.
Future<bool> confirmAndDeleteAdjustment(BuildContext context, WidgetRef ref, ExtraordinaryEvent event) async {
  final s = ref.read(appStringsProvider);
  final events = ref.read(extraordinaryEventServiceProvider);
  final confirmed = await showConfirmDialog(
    context,
    title: s.deleteAdjustmentTitle,
    content: s.deleteAdjustmentConfirm(event.name),
    confirmLabel: s.delete,
    cancelLabel: s.cancel,
    confirmColor: Colors.red,
  );
  if (!confirmed) return false;
  await events.delete(event.id);
  return true;
}

class EventDetailScreen extends ConsumerWidget {
  final int eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final eventAsync = ref.watch(extraordinaryEventProvider(eventId));
    return eventAsync.when(
      data: (event) => _DetailBody(event: event),
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
    final bufferTxnAsync = event.bufferId != null ? ref.watch(bufferTransactionsProvider(event.bufferId!)) : null;

    final isSpread = event.treatment == EventTreatment.spread;
    final isOutflow = event.direction == EventDirection.outflow;

    return Scaffold(
      appBar: AppBar(
        title: Text(event.name),
        actions: globalAppBarActions(
          context,
          ref,
          local: [
            AppBarAction(
              icon: Icons.edit,
              tooltip: s.edit,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EventEditScreen(event: event)),
              ),
            ),
            if (isSpread)
              AppBarAction(
                icon: Icons.refresh,
                tooltip: s.regenerateEntries,
                onPressed: () async {
                  await ref.read(extraordinaryEventServiceProvider).generateScheduledEntries(event.id);
                  if (context.mounted) {
                    showInfoSnack(context, s.entriesRegenerated);
                  }
                },
              ),
            AppBarAction(
              icon: Icons.delete_outline,
              color: Colors.red,
              tooltip: s.delete,
              onPressed: () async {
                if (await confirmAndDeleteAdjustment(context, ref, event) && context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: MobilePullToRefresh(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                          Chip(label: Text(s.freqLabel(event.stepFrequency!))),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    _infoRow(
                      s.totalLabel,
                      PrivacyText('${amtFmt.format(event.totalAmount)} $sym'),
                    ),
                    _infoRow(s.eventDateLabel, Text(dateFmt.format(event.eventDate))),
                    if (isSpread && event.spreadStart != null && event.spreadEnd != null)
                      _infoRow(
                        s.spreadLabel,
                        Text(
                          '${dateFmt.format(event.spreadStart!)} → ${dateFmt.format(event.spreadEnd!)}',
                        ),
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
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: EmptyState(icon: Icons.event_note, message: s.noEntriesYet),
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
                        s: s,
                        onDelete: items[i].isReimbursement
                            ? () => _deleteReimbursement(context, ref, items[i].reimbursement!)
                            : (items[i].entry!.entryKind == EventEntryKind.manual ? () => _deleteEntry(context, ref, items[i].entry!.id) : null),
                      ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text(s.error(e))),
            ),

            const SizedBox(height: 80),
          ],
        ),
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

  Widget _infoRow(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ),
          Expanded(child: value),
        ],
      ),
    );
  }

  /// Asks for an amount, a description and a day: null when cancelled, or
  /// when the amount does not read in the locale (reported).
  Future<({double amount, String desc, DateTime date})?> _promptAmountDescDate(
    BuildContext context,
    WidgetRef ref, {
    required String title,
  }) async {
    final s = ref.read(appStringsProvider);
    final locale = ref.read(appLocaleProvider).value ?? Platform.localeName;
    final result = await showDialog<_EntryFormResult>(
      context: context,
      builder: (_) => _EntryFormDialog(title: title),
    );
    if (result == null) return null;
    final amount = fmt.tryParseLocalized(result.amountText, locale: locale);
    if (amount == null) {
      // Reported, never dropped without a word.
      if (context.mounted) showInfoSnack(context, s.invalidNumber);
      return null;
    }
    return (amount: amount, desc: result.desc, date: result.date);
  }

  Future<void> _addManualEntry(BuildContext context, WidgetRef ref) async {
    final s = ref.read(appStringsProvider);
    final entry = await _promptAmountDescDate(context, ref, title: s.addEventEntryTitle);
    // The screen, and its ref, may be gone by then (the event was deleted
    // while the dialog was open): nothing to add to.
    if (entry == null || !context.mounted) return;
    final service = ref.read(extraordinaryEventServiceProvider);
    // Same-day, same-amount manual entries are usually an accidental re-add;
    // confirm rather than block (identical entries can be legitimate).
    final duplicates = await service.countIdenticalManualEntries(
      eventId: event.id,
      date: entry.date,
      amount: entry.amount,
    );
    if (duplicates > 0) {
      if (!context.mounted) return;
      final locale = ref.read(appLocaleProvider).value ?? Platform.localeName;
      final amtFmt = fmt.currencyFormat(locale, event.currency);
      final addAnyway = await showConfirmDialog(
        context,
        title: s.duplicateAdjustmentTitle,
        content: s.duplicateAdjustmentBody(duplicates, privacySlot(0)),
        maskedFigures: [amtFmt.format(entry.amount.abs())],
        confirmLabel: s.addAnyway,
        cancelLabel: s.cancel,
      );
      if (!addAnyway) return;
    }
    await service.addManualEntry(
      eventId: event.id,
      date: entry.date,
      amount: entry.amount,
      description: entry.desc,
    );
  }

  Future<void> _addReimbursement(BuildContext context, WidgetRef ref) async {
    final s = ref.read(appStringsProvider);
    final entry = await _promptAmountDescDate(context, ref, title: s.addReimbursementTitle);
    // As for a manual entry: the screen may be gone by then.
    if (entry == null || !context.mounted) return;
    final buffers = ref.read(bufferServiceProvider);
    final events = ref.read(extraordinaryEventServiceProvider);
    // One transaction: nobody reads the reimbursement next to a schedule that
    // does not spread it yet. The buffer service books it with the running
    // balance.
    await ref.read(databaseProvider).transaction(() async {
      await buffers.createTransaction(
        bufferId: event.bufferId!,
        operationDate: entry.date,
        amount: entry.amount,
        currency: event.currency,
        description: entry.desc,
        isReimbursement: true,
      );
      await events.generateScheduledEntries(event.id);
    });
  }

  /// A timeline row's delete asks first, like every delete in the app.
  Future<bool> _confirmDeleteRow(BuildContext context, WidgetRef ref) {
    final s = ref.read(appStringsProvider);
    return showConfirmDialog(
      context,
      title: s.delete,
      content: s.cannotBeUndone,
      confirmLabel: s.delete,
      cancelLabel: s.cancel,
      confirmColor: Colors.red,
    );
  }

  /// Deletes a manual entry once confirmed; says whether it did (a swiped
  /// row stays when it did not).
  Future<bool> _deleteEntry(BuildContext context, WidgetRef ref, int entryId) async {
    final events = ref.read(extraordinaryEventServiceProvider);
    if (!await _confirmDeleteRow(context, ref)) return false;
    await events.deleteEntry(entryId);
    return true;
  }

  /// As [_deleteEntry], for a reimbursement.
  Future<bool> _deleteReimbursement(BuildContext context, WidgetRef ref, BufferTransaction txn) async {
    final db = ref.read(databaseProvider);
    final buffers = ref.read(bufferServiceProvider);
    final events = ref.read(extraordinaryEventServiceProvider);
    if (!await _confirmDeleteRow(context, ref)) return false;
    // One transaction with the schedule regeneration, as when it was added.
    await db.transaction(() async {
      await buffers.deleteTransaction(txn.id);
      await events.generateScheduledEntries(event.id);
    });
    return true;
  }
}

/// What the add-entry form hands back: the raw amount text (parsed by the
/// caller, so an unreadable amount is reported instead of guessed), the
/// trimmed description and the picked day.
typedef _EntryFormResult = ({String amountText, String desc, DateTime date});

/// The add-entry / add-reimbursement form. Owns its text controllers and
/// disposes them with the dialog, once its closing animation is over (the
/// closing dialog still rebuilds its fields).
class _EntryFormDialog extends ConsumerStatefulWidget {
  const _EntryFormDialog({required this.title});

  final String title;

  @override
  ConsumerState<_EntryFormDialog> createState() => _EntryFormDialogState();
}

class _EntryFormDialogState extends ConsumerState<_EntryFormDialog> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  // Today's calendar day, never the clock time.
  var _date = dateOnly(DateTime.now());

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amountCtrl,
            decoration: InputDecoration(labelText: s.amount),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descCtrl,
            decoration: InputDecoration(labelText: s.descriptionOptional),
          ),
          const SizedBox(height: 8),
          DateFormField(
            date: _date,
            onPicked: (picked) => setState(() => _date = picked),
            label: s.dateLabel,
            firstYear: 2000,
            outlined: false,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop<_EntryFormResult>(context, (amountText: _amountCtrl.text, desc: _descCtrl.text.trim(), date: _date)),
          child: Text(s.add),
        ),
      ],
    );
  }
}

// ── Timeline item union ──

class _TimelineItem {
  final ExtraordinaryEventEntry? entry;
  final BufferTransaction? reimbursement;

  _TimelineItem.entry(this.entry) : reimbursement = null;
  _TimelineItem.reimbursement(this.reimbursement) : entry = null;

  bool get isReimbursement => reimbursement != null;
  // valueDate per AGENTS.md (canonical "money moved" date for ordering/display).
  // ExtraordinaryEventEntry has only a single date column; BufferTransaction
  // has both, and we always want valueDate.
  DateTime get date => entry?.date ?? reimbursement!.valueDate;
}

class _TimelineTile extends StatelessWidget {
  final _TimelineItem item;
  final int index;
  final String locale;
  final String sym;
  final AppStrings s;

  /// Confirms, deletes and says whether it did: behind the trash icon and the
  /// swipe of the row. Null for a row that cannot be deleted.
  final Future<bool> Function()? onDelete;

  const _TimelineTile({
    required this.item,
    required this.index,
    required this.locale,
    required this.sym,
    required this.s,
    this.onDelete,
  });

  /// The canonical list delete: besides the trash icon, the row swipes away,
  /// asking the same confirmation first.
  Widget _deletable(Key key, Widget tile) {
    final delete = onDelete;
    if (delete == null) return tile;
    return SwipeToDelete.custom(key: key, confirmAndDelete: delete, child: tile);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = fmt.shortDateFormat(locale);
    final amtFmt = fmt.amountFormat(locale);
    final trash = onDelete == null ? null : IconButton(icon: const Icon(Icons.delete_outline), tooltip: s.delete, onPressed: onDelete);

    if (item.isReimbursement) {
      final r = item.reimbursement!;
      return _deletable(
        ValueKey('dismiss_reimb_${r.id}'),
        ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.green.shade100,
            child: Icon(Icons.call_received, size: 16, color: Colors.green.shade800),
          ),
          title: PrivacyText('${amtFmt.format(r.amount.abs())} $sym'),
          subtitle: Text('${dateFmt.format(r.valueDate)}${r.description.isNotEmpty ? ' · ${r.description}' : ''}'),
          trailing: trash,
        ),
      );
    }

    final e = item.entry!;
    final isScheduled = e.entryKind == EventEntryKind.scheduled;
    final color = isScheduled ? theme.colorScheme.tertiaryContainer : theme.colorScheme.primaryContainer;
    final icon = isScheduled ? Icons.event_repeat : Icons.adjust;

    return _deletable(
      ValueKey('dismiss_entry_${e.id}'),
      ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, size: 16, color: theme.colorScheme.onTertiaryContainer),
        ),
        title: PrivacyText('${amtFmt.format(e.amount.abs())} $sym'),
        subtitle: Text(
          '${dateFmt.format(e.date)}${e.description.isNotEmpty ? ' · ${e.description}' : ''}',
        ),
        trailing: trash,
      ),
    );
  }
}
