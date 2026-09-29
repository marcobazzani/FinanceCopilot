import 'package:flutter/material.dart';

/// The canonical list delete (the trashcan lives in the detail view; a list
/// row swipes): the row slides away end to start over a red background with a
/// trash icon, and asks first — with the entity's own confirmation, the one
/// its trashcan asks.
///
/// The delete runs inside [Dismissible.confirmDismiss], before the row
/// collapses: by the time the list rebuilds, the row is gone from the data, so
/// a dismissed row is never left in the tree ("A dismissed Dismissible widget
/// is still part of the tree"). A cancelled or refused delete slides the row
/// back. The [key] identifies the row: give each row its own.
class SwipeToDelete extends StatelessWidget {
  /// [confirmAndDelete] asks, deletes once confirmed and says whether it did:
  /// the same call as the detail view's trashcan (its own confirmation, a
  /// reassign dialog, a refusal to explain).
  const SwipeToDelete.custom({
    required Key super.key,
    required this.confirmAndDelete,
    required this.child,
  });

  final Future<bool> Function() confirmAndDelete;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: key!,
      direction: DismissDirection.endToStart,
      background: Container(
        color: scheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete, color: scheme.onErrorContainer),
      ),
      confirmDismiss: (_) => confirmAndDelete(),
      child: child,
    );
  }
}
