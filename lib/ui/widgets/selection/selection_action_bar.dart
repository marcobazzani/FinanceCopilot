import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_strings.dart';
import '../../../services/providers/providers.dart';
import 'selection_controller.dart';

/// Persistent bottom action bar shown while a [SelectionController] is active.
///
/// Each list screen uses this in its `Scaffold.bottomNavigationBar` slot,
/// gated on `controller.active`. The bar is the single place that renders
/// the count label, select-all / deselect-all toggle, cancel (X) button, and
/// the bulk-delete confirmation dialog — no per-screen duplication.
class SelectionActionBar<T> extends ConsumerWidget {
  final SelectionController<T> controller;

  /// All currently-visible ids on the screen (after any filter / search).
  /// Used for "select all" and to flip the label to "deselect all" when
  /// everything visible is already selected.
  final List<T> visibleIds;

  /// Async bulk-delete callback. Called only after the user confirms the
  /// dialog. On success, the controller is cleared automatically.
  final Future<void> Function(Set<T> ids) onDelete;

  const SelectionActionBar({
    super.key,
    required this.controller,
    required this.visibleIds,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (ctx, _) {
        final count = controller.count;
        final allVisibleSelected = visibleIds.isNotEmpty &&
            visibleIds.every(controller.contains);

        return Material(
          elevation: 8,
          color: theme.colorScheme.surfaceContainerHighest,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: s.cancel,
                    onPressed: controller.clear,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      s.nSelected(count),
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    icon: Icon(allVisibleSelected
                        ? Icons.deselect
                        : Icons.select_all),
                    label: Text(allVisibleSelected ? s.deselectAll : s.selectAll),
                    onPressed: visibleIds.isEmpty
                        ? null
                        : () {
                            if (allVisibleSelected) {
                              controller.clear();
                            } else {
                              controller.selectAll(visibleIds);
                            }
                          },
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.delete, color: theme.colorScheme.error),
                    tooltip: s.delete,
                    onPressed: count == 0 ? null : () => _confirmAndDelete(ctx, s),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmAndDelete(BuildContext context, AppStrings s) async {
    final count = controller.count;
    final ids = controller.ids;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.bulkDeleteTitle),
        content: Text(s.bulkDeleteBody(count)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await onDelete(ids);
    controller.clear();
  }
}
