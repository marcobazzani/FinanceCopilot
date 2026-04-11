import 'package:flutter/foundation.dart';

/// Tracks the set of currently-selected item ids for one list screen.
///
/// One controller is created per screen that supports multi-select and lives
/// for the screen's lifetime. It is a [ChangeNotifier] so widgets can rebuild
/// via [ListenableBuilder] when the selection changes.
class SelectionController<T> extends ChangeNotifier {
  final Set<T> _selected = <T>{};

  /// The currently-visible ids in their display order. Used by [enter] to
  /// expand a long-press into a range when selection is already active.
  /// Hint only — setting this never notifies listeners, so it is safe to
  /// call from inside a build() method.
  List<T>? _orderedIds;

  void setOrderedIds(List<T> orderedIds) {
    _orderedIds = orderedIds;
  }

  /// True when at least one item is selected (i.e. selection mode is active).
  bool get active => _selected.isNotEmpty;

  int get count => _selected.length;

  /// Read-only view of the current selection.
  Set<T> get ids => Set.unmodifiable(_selected);

  bool contains(T id) => _selected.contains(id);

  /// Entry point for a long-press.
  ///
  /// If selection mode is not yet active, simply adds [id] and starts the
  /// mode. If it IS active and an [setOrderedIds] hint has been provided,
  /// long-pressing expands the selection to cover the range from [id] to the
  /// furthest already-selected item (inclusive, by index distance). Without
  /// an ordered-ids hint this falls back to a simple add.
  void enter(T id) {
    if (_selected.isEmpty || _orderedIds == null) {
      if (_selected.add(id)) notifyListeners();
      return;
    }

    final ordered = _orderedIds!;
    final pressedIdx = ordered.indexOf(id);
    if (pressedIdx < 0) {
      // Pressed id is not in the current visible list — no range to expand.
      if (_selected.add(id)) notifyListeners();
      return;
    }

    int? furthestIdx;
    var furthestDistance = -1;
    for (var i = 0; i < ordered.length; i++) {
      if (!_selected.contains(ordered[i])) continue;
      final d = (i - pressedIdx).abs();
      if (d > furthestDistance) {
        furthestDistance = d;
        furthestIdx = i;
      }
    }

    if (furthestIdx == null) {
      if (_selected.add(id)) notifyListeners();
      return;
    }

    final start = pressedIdx < furthestIdx ? pressedIdx : furthestIdx;
    final end = pressedIdx < furthestIdx ? furthestIdx : pressedIdx;
    var changed = false;
    for (var i = start; i <= end; i++) {
      if (_selected.add(ordered[i])) changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Tap while active: toggles [id]. If the last selected item is toggled
  /// off, [active] becomes false and listeners are still notified.
  void toggle(T id) {
    if (!_selected.remove(id)) _selected.add(id);
    notifyListeners();
  }

  /// Cancel button or post-delete cleanup. No-op if already empty.
  void clear() {
    if (_selected.isEmpty) return;
    _selected.clear();
    notifyListeners();
  }

  /// Replaces the current selection with [all]. Callers pass the currently
  /// visible ids on the screen (after any search / filter applied).
  void selectAll(Iterable<T> all) {
    _selected
      ..clear()
      ..addAll(all);
    notifyListeners();
  }
}
