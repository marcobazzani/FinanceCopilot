import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/app_actions_controller.dart';
import '../../services/providers/providers.dart';

/// Builds the complete `actions:` list for an AppBar. The screen passes its
/// local action buttons via [local]; this function appends the global
/// cluster (privacy, refresh, import/export, settings, …) and inserts a
/// thin vertical separator between the two groups when both are present.
///
/// Use directly:
/// ```
/// AppBar(actions: globalAppBarActions(context, ref, local: [
///   IconButton(...), IconButton(...),
/// ]))
/// ```
///
/// On widths < 600 px the global cluster collapses into a single overflow
/// menu so it doesn't crowd out the screen's local actions.
List<Widget> globalAppBarActions(
  BuildContext context,
  WidgetRef ref, {
  List<Widget> local = const [],
}) {
  final width = MediaQuery.sizeOf(context).width;
  final globals = width < 600
      ? const <Widget>[_GlobalActionsOverflow()]
      : const <Widget>[
          _PrivacyAction(),
          _NetworkRetryAction(),
          _RefreshAction(),
          _ImportExportAction(),
          _SettingsAction(),
          _ImportFileAction(),
        ];
  if (local.isEmpty) return globals;
  return [...local, const _Separator(), ...globals];
}

class _Separator extends StatelessWidget {
  const _Separator();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 4),
    child: VerticalDivider(width: 1, indent: 12, endIndent: 12, thickness: 1),
  );
}

class _PrivacyAction extends ConsumerWidget {
  const _PrivacyAction();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrivate = ref.watch(privacyModeProvider);
    final s = ref.watch(appStringsProvider);
    return IconButton(
      icon: Icon(isPrivate ? Icons.visibility_off : Icons.visibility),
      tooltip: isPrivate ? s.tooltipHideAmounts : s.tooltipShowAmounts,
      onPressed: () =>
          ref.read(privacyModeProvider.notifier).state = !isPrivate,
    );
  }
}

class _NetworkRetryAction extends ConsumerWidget {
  const _NetworkRetryAction();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(networkOnlineProvider);
    if (online) return const SizedBox.shrink();
    final reg = ref.watch(globalActionsRegistryProvider);
    return IconButton(
      icon: Icon(Icons.signal_wifi_off, color: Colors.red.shade300),
      tooltip: ref.read(appStringsProvider).noNetworkRetry,
      onPressed: reg == null ? null : () => reg.retryNetwork(),
    );
  }
}

class _RefreshAction extends ConsumerWidget {
  const _RefreshAction();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSyncing = ref.watch(isManualSyncingProvider);
    final reg = ref.watch(globalActionsRegistryProvider);
    final s = ref.watch(appStringsProvider);
    return IconButton(
      icon: isSyncing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh),
      tooltip: s.tooltipRefreshPrices,
      onPressed: (isSyncing || reg == null) ? null : () => reg.manualRefresh(),
    );
  }
}

class _ImportExportAction extends ConsumerWidget {
  const _ImportExportAction();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reg = ref.watch(globalActionsRegistryProvider);
    final s = ref.watch(appStringsProvider);
    return IconButton(
      icon: const Icon(Icons.import_export),
      tooltip: s.tooltipImportExportDb,
      onPressed: reg == null ? null : () => reg.showImportExportDialog(context),
    );
  }
}

class _SettingsAction extends ConsumerWidget {
  const _SettingsAction();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reg = ref.watch(globalActionsRegistryProvider);
    final s = ref.watch(appStringsProvider);
    return IconButton(
      icon: const Icon(Icons.settings),
      tooltip: s.tooltipSettings,
      onPressed: reg == null ? null : () => reg.showSettingsDialog(context),
    );
  }
}

class _ImportFileAction extends ConsumerWidget {
  const _ImportFileAction();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reg = ref.watch(globalActionsRegistryProvider);
    final s = ref.watch(appStringsProvider);
    return IconButton(
      icon: const Icon(Icons.file_upload),
      tooltip: s.tooltipImportFile,
      onPressed: reg == null ? null : () => reg.openImportFiles(context),
    );
  }
}

class _GlobalActionsOverflow extends ConsumerWidget {
  const _GlobalActionsOverflow();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reg = ref.watch(globalActionsRegistryProvider);
    final isPrivate = ref.watch(privacyModeProvider);
    final isSyncing = ref.watch(isManualSyncingProvider);
    final online = ref.watch(networkOnlineProvider);
    final s = ref.watch(appStringsProvider);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (action) async {
        switch (action) {
          case 'privacy':
            ref.read(privacyModeProvider.notifier).state = !isPrivate;
          case 'retryNetwork':
            await reg?.retryNetwork();
          case 'refresh':
            await reg?.manualRefresh();
          case 'importExport':
            if (context.mounted) await reg?.showImportExportDialog(context);
          case 'settings':
            if (context.mounted) await reg?.showSettingsDialog(context);
          case 'importFile':
            if (context.mounted) await reg?.openImportFiles(context);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'privacy',
          child: Row(children: [
            Icon(isPrivate ? Icons.visibility_off : Icons.visibility),
            const SizedBox(width: 12),
            Text(isPrivate ? s.tooltipHideAmounts : s.tooltipShowAmounts),
          ]),
        ),
        if (!online)
          PopupMenuItem(
            value: 'retryNetwork',
            child: Row(children: [
              Icon(Icons.signal_wifi_off, color: Colors.red.shade300),
              const SizedBox(width: 12),
              Text(s.noNetworkRetry),
            ]),
          ),
        PopupMenuItem(
          value: 'refresh',
          enabled: !isSyncing,
          child: Row(children: [
            isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            const SizedBox(width: 12),
            Text(s.tooltipRefreshPrices),
          ]),
        ),
        PopupMenuItem(
          value: 'importExport',
          child: Row(children: [
            const Icon(Icons.import_export),
            const SizedBox(width: 12),
            Text(s.tooltipImportExportDb),
          ]),
        ),
        PopupMenuItem(
          value: 'settings',
          child: Row(children: [
            const Icon(Icons.settings),
            const SizedBox(width: 12),
            Text(s.tooltipSettings),
          ]),
        ),
        PopupMenuItem(
          value: 'importFile',
          child: Row(children: [
            const Icon(Icons.file_upload),
            const SizedBox(width: 12),
            Text(s.tooltipImportFile),
          ]),
        ),
      ],
    );
  }
}
