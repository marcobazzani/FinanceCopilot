import 'package:flutter/material.dart';

import 'selection_controller.dart';

/// Wraps any list-item widget with the gesture + visual layer needed for
/// multi-select mode. Adds:
///
///   * long-press → [SelectionController.enter]
///   * single tap while active → [SelectionController.toggle]
///   * tinted background + check-circle overlay when selected
///   * pointer-event suppression of the child's own `onTap` while active
///
/// The child is rendered verbatim (no layout reshuffling, no theme changes)
/// so every call site can keep its existing tile widget exactly as-is.
class SelectableItem<T> extends StatelessWidget {
  final SelectionController<T> controller;
  final T id;
  final Widget child;

  const SelectableItem({
    super.key,
    required this.controller,
    required this.id,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (ctx, _) {
        final selected = controller.contains(id);
        final active = controller.active;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Long-press is always wired so the user can start selection mode.
          onLongPress: () => controller.enter(id),
          // Single tap routes through the controller while selection is
          // active; otherwise the child's own onTap handler runs (because we
          // only enable IgnorePointer when active).
          onTap: active ? () => controller.toggle(id) : null,
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                color: selected
                    ? Theme.of(ctx).colorScheme.primaryContainer.withValues(alpha: 0.4)
                    : Colors.transparent,
                child: IgnorePointer(
                  ignoring: active,
                  child: child,
                ),
              ),
              if (selected)
                const Positioned(
                  left: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Icon(Icons.check_circle, size: 20, color: Colors.blue),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
