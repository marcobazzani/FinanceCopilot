import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/legacy.dart';

import '../models/dashboard_chart.dart';

/// In-memory state for the History-tab chart editor (debug mode only).
///
/// Holds two lists:
///   * `charts` — what's currently displayed and edited.
///   * `pristine` — the baseline loaded from `assets/default_charts.json`,
///     used both for `isDirty` detection and as the target of `reset()`.
///
/// Mutations replace state immutably so Riverpod sees the change.
class EditableChartsState {
  final List<DashboardChart> charts;
  final List<DashboardChart> pristine;

  const EditableChartsState({required this.charts, required this.pristine});

  EditableChartsState copyWith({
    List<DashboardChart>? charts,
    List<DashboardChart>? pristine,
  }) =>
      EditableChartsState(
        charts: charts ?? this.charts,
        pristine: pristine ?? this.pristine,
      );

  /// True when the user's working set differs from the loaded JSON.
  /// Used to surface a dirty indicator on the Export FAB.
  bool get isDirty {
    if (charts.length != pristine.length) return true;
    for (var i = 0; i < charts.length; i++) {
      if (charts[i] != pristine[i]) return true;
    }
    return false;
  }
}

class EditableChartsNotifier extends StateNotifier<EditableChartsState> {
  EditableChartsNotifier(super.initial);

  /// Append a new chart at the end. Used when the editor creates a fresh
  /// custom or combined chart. Picks an id one less than the smallest
  /// existing — JSON-loaded charts use -1, -2, ... so user additions
  /// continue downward.
  void add(DashboardChart chart) {
    final existingIds = state.charts.map((c) => c.id).toList();
    final nextId = existingIds.isEmpty
        ? -1
        : (existingIds.reduce(min) - 1);
    final placed = chart.copyWith(
      id: chart.id == 0 ? nextId : chart.id,
      sortOrder: state.charts.length,
    );
    state = state.copyWith(charts: [...state.charts, placed]);
  }

  /// Replace the chart with the same id. No-op when id is missing.
  void update(DashboardChart chart) {
    final list = [
      for (final c in state.charts) c.id == chart.id ? chart : c,
    ];
    state = state.copyWith(charts: list);
  }

  /// Remove by id.
  void delete(int id) {
    state = state.copyWith(
      charts: state.charts.where((c) => c.id != id).toList(),
    );
  }

  /// Move a chart up (-1) or down (+1) within the list. The caller
  /// constrains which charts are reorderable; this method just swaps
  /// adjacent positions in the bucket sublist.
  void move(int id, int direction) {
    final list = [...state.charts];
    final idx = list.indexWhere((c) => c.id == id);
    if (idx < 0) return;
    final target = idx + direction;
    if (target < 0 || target >= list.length) return;
    final tmp = list[idx];
    list[idx] = list[target];
    list[target] = tmp;
    // Re-sequence sortOrder so the rendered order matches the list order.
    for (var i = 0; i < list.length; i++) {
      list[i] = list[i].copyWith(sortOrder: i);
    }
    state = state.copyWith(charts: list);
  }

  /// Restore a single role chart (cash / saving / portfolio /
  /// liquid_investments) from the pristine baseline. Used by the FAB
  /// menu's "Restore Cash" etc. items when the user has deleted one.
  void restoreRole(String role) {
    if (state.charts.any((c) => c.widgetType == role)) return; // already present
    final template = state.pristine
        .where((c) => c.widgetType == role)
        .firstOrNull;
    if (template == null) return;
    add(template.copyWith(id: 0)); // 0 → notifier picks a fresh id
  }

  /// Replace the working state with a fresh copy of the pristine list.
  /// Wipes any user edits in this session — same effect as quitting and
  /// relaunching the app, just without the round-trip.
  void reset() {
    state = state.copyWith(charts: List.of(state.pristine));
  }

  /// Replace the entire list — used by the Combine flow when the user
  /// edits / creates a combined chart (the editor returns a full chart;
  /// we just splice it into state via update or add).
  void replaceAll(List<DashboardChart> charts) {
    state = state.copyWith(charts: charts);
  }
}

/// Helper used by the JSON loader and the resolver to read sourceChartIds —
/// kept here for visibility. `*` → null (resolver decides), JSON list of
/// strings or ints → decoded to its element type.
List<dynamic>? decodeSourceChartIds(String? raw) {
  if (raw == null || raw == '*') return null;
  try {
    final v = jsonDecode(raw);
    if (v is List) return v;
  } catch (_) {}
  return null;
}
