import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../services/providers/providers.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  required String confirmLabel,
  required String cancelLabel,
  Color? confirmColor,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(content),
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

void showInfoSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Confirm and delete an intermediary. Shared across screens that manage
/// intermediaries (assets and accounts).
Future<void> confirmAndDeleteIntermediary(BuildContext context, WidgetRef ref, Intermediary intermediary) async {
  final s = ref.read(appStringsProvider);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s.deleteIntermediary),
      content: Text(s.deleteIntermediaryConfirm(intermediary.name)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.delete)),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(intermediaryServiceProvider).delete(intermediary.id);
  }
}

/// Show the add/edit intermediary dialog. Shared by assets + accounts.
/// Pressing Enter in the name field saves (same logic as the FilledButton).
Future<void> showIntermediaryEditDialog(
  BuildContext context,
  WidgetRef ref, {
  Intermediary? intermediary,
}) async {
  final s = ref.read(appStringsProvider);
  final nameCtrl = TextEditingController(text: intermediary?.name ?? '');
  final isEdit = intermediary != null;

  Future<void> save(BuildContext ctx) async {
    if (nameCtrl.text.trim().isEmpty) return;
    final svc = ref.read(intermediaryServiceProvider);
    if (isEdit) {
      await svc.update(intermediary.id, IntermediariesCompanion(name: Value(nameCtrl.text.trim())));
    } else {
      await svc.create(name: nameCtrl.text.trim());
    }
    if (ctx.mounted) Navigator.pop(ctx);
  }

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(isEdit ? s.editIntermediary : s.addIntermediary),
        content: TextField(
          controller: nameCtrl,
          decoration: InputDecoration(labelText: s.intermediaryName),
          autofocus: true,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setDialogState(() {}),
          onSubmitted: (_) => save(ctx),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          FilledButton(
            onPressed: nameCtrl.text.trim().isNotEmpty ? () => save(ctx) : null,
            child: Text(isEdit ? s.save : s.create),
          ),
        ],
      ),
    ),
  );
}

/// Show the reorderable intermediary management dialog. Add/edit/delete
/// sub-dialogs stack on top of this dialog without popping it first, so
/// the list refreshes naturally when the sub-dialog closes.
Future<void> showManageIntermediariesDialog(BuildContext context, WidgetRef ref) async {
  final s = ref.read(appStringsProvider);

  await showDialog(
    context: context,
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        final intermediaries = ref.watch(intermediariesProvider).value ?? const <Intermediary>[];
        return AlertDialog(
          title: Text(s.intermediaries),
          // Fixed-size box with explicit dimensions avoids intrinsic-width
          // recursion that AlertDialog triggers on shrink-wrapped lists.
          content: SizedBox(
            width: 320,
            height: 400,
            child: intermediaries.isEmpty
                ? Center(
                    child: Text(s.selectIntermediaryEmpty, style: const TextStyle(color: Colors.grey)),
                  )
                : ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: intermediaries.length,
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) newIndex--;
                      final reordered = List<Intermediary>.from(intermediaries);
                      final item = reordered.removeAt(oldIndex);
                      reordered.insert(newIndex, item);
                      ref.read(intermediaryServiceProvider).reorder(reordered.map((i) => i.id).toList());
                    },
                    itemBuilder: (ctx, i) {
                      final inter = intermediaries[i];
                      return ListTile(
                        key: ValueKey(inter.id),
                        leading: ReorderableDragStartListener(
                          index: i,
                          child: const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
                        ),
                        title: Text(inter.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => showIntermediaryEditDialog(context, ref, intermediary: inter),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              onPressed: () => confirmAndDeleteIntermediary(context, ref, inter),
                            ),
                          ],
                        ),
                      );
                    },
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
  );
}

Future<DateTime?> pickDate(BuildContext context, DateTime initial, {int firstYear = 1990}) => showDatePicker(
  context: context,
  initialDate: initial,
  firstDate: DateTime(firstYear),
  lastDate: DateTime(2100),
);
