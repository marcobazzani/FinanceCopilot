import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:finance_copilot/services/app_actions_controller.dart';
import '../../services/providers/providers.dart';
import '../../utils/visualization_clock.dart';

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
          _WaybackAction(),
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

class _WaybackAction extends ConsumerWidget {
  const _WaybackAction();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(waybackDateProvider);
    final currentDate = ref.watch(currentDateProvider);
    final s = ref.watch(appStringsProvider);
    final localeTag = ref.watch(appLocaleProvider).value ?? Localizations.localeOf(context).toLanguageTag();
    final dateFmt = DateFormat.yMMMd(localeTag);
    final active = selectedDate != null;
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.history_toggle_off,
        color: active ? Theme.of(context).colorScheme.primary : null,
      ),
      tooltip: active ? s.waybackActiveTooltip(dateFmt.format(currentDate)) : s.tooltipWaybackMachine,
      onSelected: (action) => _handleWaybackAction(context, ref, action),
      itemBuilder: (_) => _waybackMenuItems(context, ref),
    );
  }
}

Future<void> _handleWaybackAction(
  BuildContext context,
  WidgetRef ref,
  String action,
) async {
  final selectedDate = ref.read(waybackDateProvider);
  final realToday = dateOnly(DateTime.now());
  final localeTag = ref.read(appLocaleProvider).value ?? Localizations.localeOf(context).toLanguageTag();
  switch (action) {
    case 'reset':
      ref.read(waybackDateProvider.notifier).state = null;
    case 'monthEnd':
      ref.read(waybackDateProvider.notifier).state = lastCompletedMonthEnd(realToday);
    case 'yearEnd':
      ref.read(waybackDateProvider.notifier).state = lastCompletedYearEnd(realToday);
    case 'nextMonthEnd':
      ref.read(waybackDateProvider.notifier).state = nextMonthEnd(realToday);
    case 'nextYearEnd':
      ref.read(waybackDateProvider.notifier).state = nextYearEnd(realToday);
    case 'custom':
      final picked = await showDatePicker(
        context: context,
        initialDate: selectedDate ?? realToday,
        firstDate: DateTime(1970),
        // Allow forward time-travel ("wayforward") up to 10 years ahead, so the
        // user can project future-dated scheduled events / saving plans.
        lastDate: DateTime(realToday.year + 10, 12, 31),
        locale: Locale(localeTag.split(RegExp('[-_]')).first),
      );
      if (picked != null) {
        ref.read(waybackDateProvider.notifier).state = dateOnly(picked);
      }
  }
}

List<PopupMenuEntry<String>> _waybackMenuItems(
  BuildContext context,
  WidgetRef ref,
) {
  final selectedDate = ref.watch(waybackDateProvider);
  final currentDate = ref.watch(currentDateProvider);
  final s = ref.watch(appStringsProvider);
  final localeTag = ref.watch(appLocaleProvider).value ?? Localizations.localeOf(context).toLanguageTag();
  final dateFmt = DateFormat.yMMMd(localeTag);
  return [
    if (selectedDate != null)
      PopupMenuItem(
        value: 'reset',
        child: Row(
          children: [
            const Icon(Icons.today),
            const SizedBox(width: 12),
            Text(s.waybackReset),
          ],
        ),
      ),
    PopupMenuItem(
      value: 'monthEnd',
      child: Row(
        children: [
          const Icon(Icons.calendar_month),
          const SizedBox(width: 12),
          Text(s.waybackLastEndOfMonth),
        ],
      ),
    ),
    PopupMenuItem(
      value: 'yearEnd',
      child: Row(
        children: [
          const Icon(Icons.event),
          const SizedBox(width: 12),
          Text(s.waybackLastEndOfYear),
        ],
      ),
    ),
    PopupMenuItem(
      value: 'nextMonthEnd',
      child: Row(
        children: [
          const Icon(Icons.fast_forward),
          const SizedBox(width: 12),
          Text(s.waybackNextEndOfMonth),
        ],
      ),
    ),
    PopupMenuItem(
      value: 'nextYearEnd',
      child: Row(
        children: [
          const Icon(Icons.event_available),
          const SizedBox(width: 12),
          Text(s.waybackNextEndOfYear),
        ],
      ),
    ),
    PopupMenuItem(
      value: 'custom',
      child: Row(
        children: [
          const Icon(Icons.edit_calendar),
          const SizedBox(width: 12),
          Text(s.waybackCustom),
        ],
      ),
    ),
    PopupMenuItem(
      enabled: false,
      child: Text(
        '${s.waybackCurrentDate}: ${dateFmt.format(currentDate)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ),
  ];
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
      onPressed: () => ref.read(privacyModeProvider.notifier).state = !isPrivate,
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
          case 'reset':
          case 'monthEnd':
          case 'yearEnd':
          case 'nextMonthEnd':
          case 'nextYearEnd':
          case 'custom':
            await _handleWaybackAction(context, ref, action);
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
          child: Row(
            children: [
              Icon(isPrivate ? Icons.visibility_off : Icons.visibility),
              const SizedBox(width: 12),
              Text(isPrivate ? s.tooltipHideAmounts : s.tooltipShowAmounts),
            ],
          ),
        ),
        ..._waybackMenuItems(context, ref),
        if (!online)
          PopupMenuItem(
            value: 'retryNetwork',
            child: Row(
              children: [
                Icon(Icons.signal_wifi_off, color: Colors.red.shade300),
                const SizedBox(width: 12),
                Text(s.noNetworkRetry),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'refresh',
          enabled: !isSyncing,
          child: Row(
            children: [
              isSyncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              const SizedBox(width: 12),
              Text(s.tooltipRefreshPrices),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'importExport',
          child: Row(
            children: [
              const Icon(Icons.import_export),
              const SizedBox(width: 12),
              Text(s.tooltipImportExportDb),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              const Icon(Icons.settings),
              const SizedBox(width: 12),
              Text(s.tooltipSettings),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'importFile',
          child: Row(
            children: [
              const Icon(Icons.file_upload),
              const SizedBox(width: 12),
              Text(s.tooltipImportFile),
            ],
          ),
        ),
      ],
    );
  }
}
