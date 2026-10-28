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

  /// What the import/export icon does while the sync indicator is lit
  /// (straight to Backup or Restore); null leaves it to
  /// [showImportExportDialog].
  final Future<void> Function(BuildContext context)? openSyncIndicator;
  final Future<void> Function(BuildContext context) showSettingsDialog;
  final Future<void> Function(BuildContext context) openImportFiles;
  final Future<void> Function(BuildContext context) openSupport;
  final Future<void> Function() retryNetwork;

  const GlobalActionsRegistry({
    required this.manualRefresh,
    required this.showImportExportDialog,
    this.openSyncIndicator,
    required this.showSettingsDialog,
    required this.openImportFiles,
    required this.openSupport,
    required this.retryNetwork,
  });

  /// The import/export icon's action.
  Future<void> Function(BuildContext context) get openImportExport => openSyncIndicator ?? showImportExportDialog;
}

/// Holds the live registry. Null until the AppShell has mounted; the
/// global-actions widget renders disabled buttons in that case.
final globalActionsRegistryProvider = StateProvider<GlobalActionsRegistry?>((ref) => null);
