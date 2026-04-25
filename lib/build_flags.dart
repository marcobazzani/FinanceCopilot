import 'dart:io';

/// Runtime gate for the chart-editor debug tooling.
///
/// Read from the **process environment** (not `--dart-define`) so the same
/// release binary can be flipped between modes by setting `DEBUG_CHARTS=1`
/// in the shell before launching:
///
/// ```bash
/// open build/macos/Build/Products/Release/FinanceCopilot.app                 # off
/// DEBUG_CHARTS=1 open build/macos/.../FinanceCopilot.app                     # on
/// ```
///
/// Off semantics:
///   - editor UI hidden (FAB menu, edit/delete/reorder/restore/export)
///   - default charts read from `assets/default_charts.json`
///   - DB seed for `dashboard_charts` skipped
///
/// On semantics:
///   - full editor restored
///   - DB-backed charts (with the JSON seed bootstrapping the table)
///   - "Export config" entry surfaces in the FAB menu
///
/// Mobile note: `Platform.environment` works on macOS/Linux/Windows desktop.
/// On Android/iOS it's effectively read-only and the var won't be set per
/// app — the app behaves as if off, which is the correct production default.
bool get debugChartsEnabled {
  if (!_envHasKey) return false;
  final raw = Platform.environment['DEBUG_CHARTS']!;
  if (raw.isEmpty) return false;
  final lower = raw.toLowerCase();
  return lower != '0' && lower != 'false' && lower != 'no';
}

bool get _envHasKey =>
    Platform.environment.containsKey('DEBUG_CHARTS');
