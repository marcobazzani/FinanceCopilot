import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:finance_copilot/services/app_actions_controller.dart';
import '../../l10n/app_strings.dart';
import '../../services/providers/providers.dart';
import '../../utils/visualization_clock.dart';

/// A single entry inside an [AppBarAction] submenu (e.g. a rebalance-scope
/// choice). Rendered as a menu item on desktop and inside a modal on mobile.
class AppBarSubAction {
  const AppBarSubAction({
    required this.label,
    required this.onSelected,
    this.dividerBefore = false,
  });

  final String label;
  final VoidCallback onSelected;

  /// Draws a divider immediately before this entry (used to group choices).
  final bool dividerBefore;
}

/// A screen-specific ("local") AppBar action.
///
/// Renders as an [IconButton] (or a [PopupMenuButton] when [submenu] is
/// non-empty). Local actions stay visible on every screen size; on phones the
/// global cluster folds into the overflow to make room, not the locals.
class AppBarAction {
  const AppBarAction({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color,
    this.submenu = const [],
  });

  final IconData icon;

  /// Doubles as the accessible tooltip on desktop and the menu label on mobile.
  final String tooltip;

  /// Tapped-action callback. Ignored when [submenu] is non-empty. When null and
  /// there is no submenu, the action renders disabled.
  final VoidCallback? onPressed;

  /// Optional icon tint (e.g. red for destructive actions).
  final Color? color;

  /// When non-empty, the action is a chooser: a [PopupMenuButton] on desktop,
  /// a modal on mobile.
  final List<AppBarSubAction> submenu;

  bool get hasSubmenu => submenu.isNotEmpty;
  bool get isEnabled => onPressed != null || hasSubmenu;
}

/// Renders a local action as a top-level AppBar widget (wide layout).
Widget _localActionWidget(AppBarAction a) {
  if (a.hasSubmenu) {
    return PopupMenuButton<int>(
      icon: Icon(a.icon, color: a.color),
      tooltip: a.tooltip,
      onSelected: (i) => a.submenu[i].onSelected(),
      itemBuilder: (_) => [
        for (final (i, sub) in a.submenu.indexed) ...[
          if (sub.dividerBefore) const PopupMenuDivider(),
          PopupMenuItem<int>(value: i, child: Text(sub.label)),
        ],
      ],
    );
  }
  return IconButton(
    icon: Icon(a.icon, color: a.color),
    tooltip: a.tooltip,
    onPressed: a.onPressed,
  );
}

/// Builds the complete `actions:` list for an AppBar. The screen passes its
/// local action buttons via [local]; this function appends the global
/// cluster (privacy, refresh, import/export, settings, …).
///
/// Use directly:
/// ```
/// AppBar(actions: globalAppBarActions(context, ref, local: [
///   AppBarAction(icon: ..., tooltip: ..., onPressed: ...),
/// ]))
/// ```
///
/// Layout:
/// - Wide (≥ 600 px): all globals as icon buttons, with the screen's local
///   actions prepended as icon buttons and a thin separator between the groups.
/// - Narrow (< 600 px):
///   - Screens WITHOUT local actions (the main tabs): refresh, import/export,
///     settings and support stay visible as icon buttons; the remaining globals
///     (privacy, time-travel, network-retry, import-file) live in the overflow.
///   - Screens WITH local actions (detail screens): the local actions stay
///     visible and every global collapses into the single overflow — there
///     isn't room for both the locals and the global icons on a phone.
List<Widget> globalAppBarActions(
  BuildContext context,
  WidgetRef ref, {
  List<AppBarAction> local = const [],
}) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < 600) {
    if (local.isEmpty) {
      // Main tab screens: the primary globals stay visible, the rest fold in.
      return const [
        _RefreshAction(),
        _ImportExportAction(),
        _SettingsAction(),
        _SupportAction(),
        _GlobalActionsOverflow(),
      ];
    }
    // Detail screens: keep the local actions visible and fold ALL globals into
    // the single overflow (the pre-existing behaviour).
    return [
      for (final a in local) _localActionWidget(a),
      const _Separator(),
      const _GlobalActionsOverflow(includeAllGlobals: true),
    ];
  }
  const globals = <Widget>[
    _PrivacyAction(),
    _WaybackAction(),
    _NetworkRetryAction(),
    _RefreshAction(),
    _ImportExportAction(),
    _SettingsAction(),
    _SupportAction(),
    _ImportFileAction(),
  ];
  if (local.isEmpty) return globals;
  return [
    for (final a in local) _localActionWidget(a),
    const _Separator(),
    ...globals,
  ];
}

class _Separator extends StatelessWidget {
  const _Separator();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 4),
    child: VerticalDivider(width: 1, indent: 12, endIndent: 12, thickness: 1),
  );
}

/// Shows the wayback machine picker as a modal dialog.
Future<void> _showWaybackModal(BuildContext context, WidgetRef ref) async {
  final selectedDate = ref.read(waybackDateProvider);
  final currentDate = ref.read(currentDateProvider);
  final s = ref.read(appStringsProvider);
  final localeTag = ref.read(appLocaleProvider).value ?? Localizations.localeOf(context).toLanguageTag();
  final dateFmt = DateFormat.yMMMd(localeTag);

  final action = await showDialog<String>(
    context: context,
    builder: (_) => _WaybackDialog(
      selectedDate: selectedDate,
      currentDate: currentDate,
      dateFmt: dateFmt,
      s: s,
    ),
  );

  if (action != null && context.mounted) {
    await _handleWaybackAction(context, ref, action);
  }
}

class _WaybackDialog extends StatelessWidget {
  const _WaybackDialog({
    required this.selectedDate,
    required this.currentDate,
    required this.dateFmt,
    required this.s,
  });

  final DateTime? selectedDate;
  final DateTime currentDate;
  final DateFormat dateFmt;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text(s.tooltipWaybackMachine),
      children: [
        if (selectedDate != null)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'reset'),
            child: Row(
              children: [
                const Icon(Icons.today),
                const SizedBox(width: 12),
                Text(s.waybackReset),
              ],
            ),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'monthEnd'),
          child: Row(
            children: [
              const Icon(Icons.calendar_month),
              const SizedBox(width: 12),
              Text(s.waybackLastEndOfMonth),
            ],
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'yearEnd'),
          child: Row(
            children: [
              const Icon(Icons.event),
              const SizedBox(width: 12),
              Text(s.waybackLastEndOfYear),
            ],
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'nextMonthEnd'),
          child: Row(
            children: [
              const Icon(Icons.fast_forward),
              const SizedBox(width: 12),
              Text(s.waybackNextEndOfMonth),
            ],
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'nextYearEnd'),
          child: Row(
            children: [
              const Icon(Icons.event_available),
              const SizedBox(width: 12),
              Text(s.waybackNextEndOfYear),
            ],
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'custom'),
          child: Row(
            children: [
              const Icon(Icons.edit_calendar),
              const SizedBox(width: 12),
              Text(s.waybackCustom),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: Text(
            '${s.waybackCurrentDate}: ${dateFmt.format(currentDate)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
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
    return IconButton(
      icon: Icon(
        Icons.history_toggle_off,
        color: active ? Theme.of(context).colorScheme.primary : null,
      ),
      tooltip: active ? s.waybackActiveTooltip(dateFmt.format(currentDate)) : s.tooltipWaybackMachine,
      onPressed: () => _showWaybackModal(context, ref),
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

class _SupportAction extends ConsumerWidget {
  const _SupportAction();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reg = ref.watch(globalActionsRegistryProvider);
    final s = ref.watch(appStringsProvider);
    return IconButton(
      icon: const Icon(Icons.support_agent),
      tooltip: s.support,
      onPressed: reg == null ? null : () => reg.openSupport(context),
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

/// Overflow ("⋮") menu. By default it holds the non-primary globals (privacy,
/// time-travel, network-retry, import-file). On detail screens the local
/// actions occupy the visible slots, so [includeAllGlobals] also folds in
/// refresh, import/export, settings and support — keeping every global reachable.
class _GlobalActionsOverflow extends ConsumerWidget {
  const _GlobalActionsOverflow({this.includeAllGlobals = false});

  final bool includeAllGlobals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reg = ref.watch(globalActionsRegistryProvider);
    final isPrivate = ref.watch(privacyModeProvider);
    final online = ref.watch(networkOnlineProvider);
    final isSyncing = ref.watch(isManualSyncingProvider);
    final s = ref.watch(appStringsProvider);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (action) async {
        switch (action) {
          case 'privacy':
            ref.read(privacyModeProvider.notifier).state = !isPrivate;
          case 'wayback':
            if (context.mounted) await _showWaybackModal(context, ref);
          case 'retryNetwork':
            await reg?.retryNetwork();
          case 'refresh':
            await reg?.manualRefresh();
          case 'importExport':
            if (context.mounted) await reg?.showImportExportDialog(context);
          case 'settings':
            if (context.mounted) await reg?.showSettingsDialog(context);
          case 'support':
            if (context.mounted) await reg?.openSupport(context);
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
        PopupMenuItem(
          value: 'wayback',
          child: Row(
            children: [
              const Icon(Icons.history_toggle_off),
              const SizedBox(width: 12),
              Text(s.tooltipWaybackMachine),
            ],
          ),
        ),
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
        if (includeAllGlobals) ...[
          PopupMenuItem(
            value: 'refresh',
            enabled: !isSyncing,
            child: Row(
              children: [
                const Icon(Icons.refresh),
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
            value: 'support',
            child: Row(
              children: [
                const Icon(Icons.support_agent),
                const SizedBox(width: 12),
                Text(s.support),
              ],
            ),
          ),
        ],
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
