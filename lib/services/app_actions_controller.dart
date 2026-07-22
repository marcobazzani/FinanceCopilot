import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Top-level handlers exposed by the AppShell so that any screen's AppBar
/// can drive the global actions (refresh, settings, import/export, import
/// file, support, network retry) regardless of whether it sits inside the
/// shell or has been pushed as a full-screen route.
///
/// Wired in `_AppShellState.initState` via [globalActionsRegistryProvider].
class GlobalActionsRegistry {
  final Future<void> Function() manualRefresh;
  final Future<void> Function(BuildContext context) showImportExportDialog;
  final Future<void> Function(BuildContext context) showSettingsDialog;
  final Future<void> Function(BuildContext context) openImportFiles;
  final Future<void> Function(BuildContext context) openSupport;
  final Future<void> Function() retryNetwork;

  const GlobalActionsRegistry({
    required this.manualRefresh,
    required this.showImportExportDialog,
    required this.showSettingsDialog,
    required this.openImportFiles,
    required this.openSupport,
    required this.retryNetwork,
  });
}

/// Holds the live registry. Null until the AppShell has mounted; the
/// global-actions widget renders disabled buttons in that case.
final globalActionsRegistryProvider = StateProvider<GlobalActionsRegistry?>((ref) => null);
