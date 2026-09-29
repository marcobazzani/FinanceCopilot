import 'package:flutter/material.dart';

import 'mobile_pull_to_refresh.dart';

/// The app's one empty-state layout: a large muted [icon], a centred
/// [message] and, when [actionLabel] and [onAction] are both given, a primary
/// "add" action under them.
///
/// Callers keep their own outer spacing (e.g. inside a list); the widget only
/// centres its column in the space it is given.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          if (label != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(label),
            ),
          ],
        ],
      ),
    );
  }
}

/// A tab with nothing to show yet (the dashboard's, the Assets Overview): the
/// shared [EmptyState], centred in a scrollable the pull-to-refresh gesture
/// can drive.
Widget scrollableEmptyState(IconData icon, String message) => MobilePullToRefresh(
  child: CustomScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(icon: icon, message: message),
      ),
    ],
  ),
);
