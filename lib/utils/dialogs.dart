import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../services/providers/providers.dart';
import '../ui/widgets/privacy_text.dart';
import '../ui/widgets/swipe_to_delete.dart';

/// [maskedFigures] fills the [privacySlot] markers in [content]: amounts that
/// are position size, blurred in privacy mode while the rest of the message
/// stays readable.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  required String confirmLabel,
  required String cancelLabel,
  Color? confirmColor,
  List<String> maskedFigures = const [],
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: _message(content, maskedFigures),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelLabel)),
        FilledButton(
          style: confirmColor == null ? null : FilledButton.styleFrom(backgroundColor: confirmColor),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}

/// [maskedFigures]: as for [showConfirmDialog]. [duration] and [action] go to
/// the [SnackBar] as they are; left out, the snack bar keeps its own defaults.
void showInfoSnack(
  BuildContext context,
  String message, {
  List<String> maskedFigures = const [],
  Duration? duration,
  SnackBarAction? action,
}) {
  final content = _message(message, maskedFigures);
  ScaffoldMessenger.of(context).showSnackBar(
    duration == null ? SnackBar(content: content, action: action) : SnackBar(content: content, duration: duration, action: action),
  );
}

/// Plain text, unless [message] quotes position-size [maskedFigures].
Widget _message(String message, List<String> maskedFigures) =>
    maskedFigures.isEmpty ? Text(message) : PrivacySentence(message, figures: maskedFigures);

/// Confirm and delete an intermediary. Shared across screens that manage
/// intermediaries (assets and accounts). Its accounts are unassigned; while
/// assets still belong to it the service refuses, and the user is told why:
/// through [onRefused] when given (a caller that is itself a dialog shows the
/// reason in place: a snack bar would sit under its modal barrier), else in a
/// snack bar. Says whether it deleted.
Future<bool> confirmAndDeleteIntermediary(
  BuildContext context,
  WidgetRef ref,
  Intermediary intermediary, {
  void Function(String reason)? onRefused,
}) async {
  final s = ref.read(appStringsProvider);
  final service = ref.read(intermediaryServiceProvider);
  final confirmed = await showConfirmDialog(
    context,
    title: s.deleteIntermediary,
    content: s.deleteIntermediaryConfirmUnlinks(intermediary.name),
    confirmLabel: s.delete,
    cancelLabel: s.cancel,
  );
  if (!confirmed) return false;
  try {
    await service.delete(intermediary.id);
    return true;
  } on StateError catch (e) {
    final assets = _assetsBlockingDelete(e);
    if (assets == null) rethrow;
    final reason = s.intermediaryHasAssets(intermediary.name, assets);
    if (onRefused != null) {
      onRefused(reason);
    } else if (context.mounted) {
      showInfoSnack(context, reason);
    }
    return false;
  }
}

/// How many assets [IntermediaryService.delete] reported as still attached
/// (`intermediary_has_assets:<n>`), or null for any other state error.
int? _assetsBlockingDelete(StateError e) {
  const prefix = 'intermediary_has_assets:';
  return e.message.startsWith(prefix) ? int.tryParse(e.message.substring(prefix.length)) : null;
}

/// Show the add/edit intermediary dialog. Shared by the assets and accounts
/// screens and the import wizard. Pressing Enter in the name field saves
/// (same logic as the FilledButton). Completes with the id of the
/// intermediary it saved (the new one when adding), or null when cancelled.
Future<int?> showIntermediaryEditDialog(
  BuildContext context,
  WidgetRef ref, {
  Intermediary? intermediary,
}) => showDialog<int>(
  context: context,
  builder: (_) => _IntermediaryEditDialog(intermediary: intermediary),
);

/// The add/edit intermediary form. Owns its name controller, disposed with the
/// dialog once its closing animation is over, and saves at most once: Enter and
/// the button share one in-flight guard. Editing, its title row carries the
/// intermediary's trashcan; a refused delete is explained in the form.
class _IntermediaryEditDialog extends ConsumerStatefulWidget {
  const _IntermediaryEditDialog({this.intermediary});

  final Intermediary? intermediary;

  @override
  ConsumerState<_IntermediaryEditDialog> createState() => _IntermediaryEditDialogState();
}

class _IntermediaryEditDialogState extends ConsumerState<_IntermediaryEditDialog> {
  late final _nameCtrl = TextEditingController(text: widget.intermediary?.name ?? '');
  bool _saving = false;

  /// Why the last delete was refused; cleared by the next one.
  String? _refusal;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _canSave => _nameCtrl.text.trim().isNotEmpty && !_saving;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      final name = _nameCtrl.text.trim();
      final svc = ref.read(intermediaryServiceProvider);
      final existing = widget.intermediary;
      final int id;
      if (existing != null) {
        await svc.update(existing.id, IntermediariesCompanion(name: Value(name)));
        id = existing.id;
      } else {
        id = await svc.create(name: name);
      }
      if (mounted) Navigator.pop(context, id);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Closes the form once the intermediary is deleted (nothing saved).
  Future<void> _delete() async {
    setState(() => _refusal = null);
    final deleted = await confirmAndDeleteIntermediary(
      context,
      ref,
      widget.intermediary!,
      onRefused: (reason) {
        if (mounted) setState(() => _refusal = reason);
      },
    );
    if (deleted && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final isEdit = widget.intermediary != null;
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(isEdit ? s.editIntermediary : s.addIntermediary)),
          if (isEdit)
            IconButton(
              key: const Key('intermediaryDeleteButton'),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: s.delete,
              onPressed: _delete,
            ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(labelText: s.intermediaryName),
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
          ),
          if (_refusal case final reason?) ...[
            const SizedBox(height: 8),
            Text(reason, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          onPressed: _canSave ? _save : null,
          child: Text(isEdit ? s.save : s.create),
        ),
      ],
    );
  }
}

/// Show the New Account form. Shared by the accounts screen and the import
/// wizard. Completes with the id of the account it created, or null when
/// cancelled.
Future<int?> showCreateAccountDialog(BuildContext context) => showDialog<int>(
  context: context,
  builder: (_) => const _CreateAccountDialog(),
);

/// The New Account form. Owns its name controller, disposed with the dialog
/// once its closing animation is over, and creates at most one account: Enter
/// and the Create button share one in-flight guard. The account gets the
/// stored base currency: nothing is created until it has loaded.
class _CreateAccountDialog extends ConsumerStatefulWidget {
  const _CreateAccountDialog();

  @override
  ConsumerState<_CreateAccountDialog> createState() => _CreateAccountDialogState();
}

class _CreateAccountDialogState extends ConsumerState<_CreateAccountDialog> {
  final _nameCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  /// The stored base currency; null until it has loaded.
  String? get _baseCurrency => ref.read(baseCurrencyProvider).value;

  bool get _canCreate => _nameCtrl.text.trim().isNotEmpty && !_saving && _baseCurrency != null;

  Future<void> _create() async {
    final currency = _baseCurrency;
    if (!_canCreate || currency == null) return;
    setState(() => _saving = true);
    try {
      final id = await ref
          .read(accountServiceProvider)
          .create(
            name: _nameCtrl.text.trim(),
            currency: currency,
          );
      if (mounted) Navigator.pop(context, id);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    // Rebuilds once the base currency has loaded, which turns Create on.
    ref.watch(baseCurrencyProvider);
    return AlertDialog(
      title: Text(s.newAccountTitle),
      content: TextField(
        controller: _nameCtrl,
        decoration: InputDecoration(labelText: s.name, hintText: s.accountNameHint),
        autofocus: true,
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _create(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          onPressed: _canCreate ? _create : null,
          child: Text(s.create),
        ),
      ],
    );
  }
}

/// Show the reorderable intermediary management dialog. Add/edit sub-dialogs
/// stack on top of this dialog without popping it first, so the list
/// refreshes naturally when the sub-dialog closes. A row swipes to delete; a
/// refused delete is explained inside the dialog.
Future<void> showManageIntermediariesDialog(BuildContext context, WidgetRef ref) async {
  final s = ref.read(appStringsProvider);
  // Why the last delete was refused; cleared by the next delete.
  String? refusal;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => Consumer(
        builder: (ctx, ref, _) {
          final intermediaries = ref.watch(intermediariesProvider).value ?? const <Intermediary>[];
          final theme = Theme.of(ctx);
          return AlertDialog(
            title: Text(s.intermediaries),
            // Fixed-size box with explicit dimensions avoids intrinsic-width
            // recursion that AlertDialog triggers on shrink-wrapped lists.
            content: SizedBox(
              width: 320,
              height: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: intermediaries.isEmpty
                        ? Center(
                            child: Text(s.selectIntermediaryEmpty, style: const TextStyle(color: Colors.grey)),
                          )
                        : ReorderableListView.builder(
                            buildDefaultDragHandles: false,
                            itemCount: intermediaries.length,
                            // onReorderItem already delivers the post-removal newIndex.
                            onReorderItem: (oldIndex, newIndex) {
                              final reordered = List<Intermediary>.from(intermediaries);
                              final item = reordered.removeAt(oldIndex);
                              reordered.insert(newIndex, item);
                              // The list follows the stream: it shows the new order once saved.
                              unawaited(ref.read(intermediaryServiceProvider).reorder(reordered.map((i) => i.id).toList()));
                            },
                            itemBuilder: (ctx, i) {
                              final inter = intermediaries[i];
                              return SwipeToDelete.custom(
                                key: ValueKey(inter.id),
                                confirmAndDelete: () {
                                  setDialogState(() => refusal = null);
                                  return confirmAndDeleteIntermediary(
                                    context,
                                    ref,
                                    inter,
                                    onRefused: (reason) {
                                      if (dialogContext.mounted) setDialogState(() => refusal = reason);
                                    },
                                  );
                                },
                                child: ListTile(
                                  leading: ReorderableDragStartListener(
                                    index: i,
                                    child: const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
                                  ),
                                  title: Text(inter.name),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.edit, size: 18),
                                    onPressed: () => showIntermediaryEditDialog(context, ref, intermediary: inter),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  if (refusal case final reason?) ...[
                    const SizedBox(height: 8),
                    Text(reason, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => showIntermediaryEditDialog(context, ref),
                child: Text(s.addIntermediary),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(s.close),
              ),
            ],
          );
        },
      ),
    ),
  );
}

/// The header of an intermediary's group in the Accounts and Assets lists:
/// its name and how many rows the group holds. A null [intermediary] heads
/// the accounts that have none (Unassigned).
class IntermediaryGroupHeader extends ConsumerWidget {
  const IntermediaryGroupHeader({super.key, required this.intermediary, required this.count});

  final Intermediary? intermediary;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final title = intermediary?.name ?? ref.watch(appStringsProvider).unassigned;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(intermediary != null ? Icons.business : Icons.folder_open, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$title ($count)',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "move to intermediary" menu of an account or asset row: the
/// intermediaries, [current] checked, and — for an account, which may have
/// none — Unassigned when [allowUnassigned]. [onMove] gets the picked id
/// (null for Unassigned), only when it differs from [current].
class IntermediaryMoveMenu extends ConsumerWidget {
  const IntermediaryMoveMenu({
    super.key,
    required this.intermediaries,
    required this.current,
    required this.onMove,
    this.allowUnassigned = false,
  });

  final List<Intermediary> intermediaries;
  final int? current;
  final bool allowUnassigned;
  final void Function(int? intermediaryId) onMove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    Widget choice(IconData icon, String label, bool isCurrent) => Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        if (isCurrent) const Icon(Icons.check, size: 18),
      ],
    );
    // One-field records: a popup menu reports a null value as "dismissed",
    // so Unassigned (no intermediary) must be a value of its own.
    return PopupMenuButton<(int?,)>(
      icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
      tooltip: s.selectIntermediary,
      itemBuilder: (_) => <PopupMenuEntry<(int?,)>>[
        PopupMenuItem<(int?,)>(
          enabled: false,
          child: Text(s.selectIntermediary, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        const PopupMenuDivider(),
        for (final i in intermediaries) PopupMenuItem<(int?,)>(value: (i.id,), child: choice(Icons.business, i.name, current == i.id)),
        if (allowUnassigned) PopupMenuItem<(int?,)>(value: (null,), child: choice(Icons.folder_open, s.unassigned, current == null)),
      ],
      onSelected: (picked) {
        if (picked.$1 != current) onMove(picked.$1);
      },
    );
  }
}

/// The app's canonical single-date picker.
///
/// [helpText] sets the dialog header (e.g. "Start date" / "End date") so a
/// caller running two picks in sequence can tell them apart. [locale] forces
/// the picker (and its keyboard-input parsing/formatting) to the app locale
/// instead of the device locale. [initialEntryMode] lets a caller open
/// straight into keyboard-input mode — far faster than calendar navigation
/// when the target date is months/years away from today.
Future<DateTime?> pickDate(
  BuildContext context,
  DateTime initial, {
  int firstYear = 1990,
  String? helpText,
  Locale? locale,
  DatePickerEntryMode initialEntryMode = DatePickerEntryMode.calendar,
}) => showDatePicker(
  context: context,
  initialDate: initial,
  firstDate: DateTime(firstYear),
  lastDate: DateTime(2100),
  helpText: helpText,
  locale: locale,
  initialEntryMode: initialEntryMode,
);
