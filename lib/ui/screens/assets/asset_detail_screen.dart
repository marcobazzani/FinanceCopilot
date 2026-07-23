import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:finance_copilot/utils/dialogs.dart';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/market/composition_service.dart';
import 'package:finance_copilot/services/market/web_market_data_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:finance_copilot/services/market/market_price_service.dart' show supportedExchanges;
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/utils/formatters.dart' as fmt;
import 'package:finance_copilot/utils/logger.dart';
import 'package:finance_copilot/ui/screens/assets/asset_detail_charts_provider.dart';
import 'package:finance_copilot/ui/screens/assets/asset_event_edit_screen.dart';
import 'package:finance_copilot/ui/screens/pillars/pillar_detail_screen.dart';
import 'package:finance_copilot/ui/widgets/global_app_bar_actions.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show ChartSeries, DragZoomWrapper, UnifiedChart, currencySymbol;
import 'package:finance_copilot/ui/widgets/asset_search.dart';
import 'package:finance_copilot/ui/widgets/mobile_pull_to_refresh.dart';
import 'package:finance_copilot/ui/widgets/privacy_text.dart';
import 'package:finance_copilot/ui/widgets/selection/selectable_item.dart';
import 'package:finance_copilot/ui/widgets/selection/selection_action_bar.dart';
import 'package:finance_copilot/ui/widgets/selection/selection_controller.dart';

part 'chart_section.dart';
part 'composition_section.dart';
part 'edit_dialog.dart';

final _log = getLogger('AssetDetailScreen');

/// Shows events for a single asset, with summary card + event list + edit.
class AssetDetailScreen extends ConsumerStatefulWidget {
  final Asset asset;
  const AssetDetailScreen({super.key, required this.asset});

  @override
  ConsumerState<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends ConsumerState<AssetDetailScreen> {
  final _selection = SelectionController<int>();

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  Asset get asset => widget.asset;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final eventsStream = ref.watch(assetEventsProvider(asset.id));
    final locale = ref.watch(appLocaleProvider).value ?? Platform.localeName;
    final dateFmt = fmt.shortDateFormat(locale);
    final amtFmt = fmt.currencyFormat(locale, asset.currency);
    final baseCurrency = ref.watch(baseCurrencyProvider).value ?? 'EUR';
    final showConverted = asset.currency != baseCurrency;
    final baseFmt = fmt.currencyFormat(locale, currencySymbol(baseCurrency));
    final convertedAmounts = showConverted ? ref.watch(convertedEventAmountsProvider(asset.id)).value ?? {} : <int, double>{};

    return ListenableBuilder(
      listenable: _selection,
      builder: (lbCtx, _) {
        final events = eventsStream.value ?? const <AssetEvent>[];
        _selection.setOrderedIds(events.map((e) => e.id).toList());
        return Scaffold(
          appBar: AppBar(
            title: Text(asset.name),
            actions: globalAppBarActions(
              context,
              ref,
              local: [
                AppBarAction(
                  icon: Icons.view_quilt_outlined,
                  tooltip: s.pillarAssignToTitle,
                  onPressed: () => _pickPillarThenEdit(context, ref, asset.id),
                ),
                AppBarAction(
                  icon: Icons.edit,
                  tooltip: s.tooltipEditAsset,
                  onPressed: () => _editAsset(context, ref),
                ),
                AppBarAction(
                  icon: Icons.delete_sweep,
                  tooltip: s.tooltipWipeEvents,
                  onPressed: () => _confirmWipeEvents(context, ref),
                ),
                AppBarAction(
                  icon: Icons.delete_outline,
                  color: Colors.red,
                  tooltip: s.tooltipDeleteAsset,
                  onPressed: () => _confirmDeleteAsset(context, ref),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              // Asset info card
              Card(
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (asset.ticker != null) ...[
                            Chip(label: Text(asset.ticker!), avatar: const Icon(Icons.label, size: 16)),
                            const SizedBox(width: 8),
                          ],
                          Chip(label: Text(asset.currency)),
                        ],
                      ),
                      if (asset.isin != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(s.isinPrefix(asset.isin!), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ),
                      if (asset.taxRate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            s.taxRateLabel((asset.taxRate! * 100).toStringAsFixed(1)),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Asset charts (portfolio history + performance)
              _AssetChartSection(assetId: asset.id),
              // Composition breakdown
              _CompositionSection(assetId: asset.id),
              // Events header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Text(s.eventsLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    eventsStream.when(
                      data: (events) => Text(s.nEvents(events.length), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      loading: () => const SizedBox(),
                      error: (_, _) => const SizedBox(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // Events list
              Expanded(
                child: eventsStream.when(
                  data: (events) {
                    if (events.isEmpty) {
                      return Center(
                        child: Text(
                          s.noEventsYet,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      );
                    }
                    return MobilePullToRefresh(
                      child: ListView.separated(
                        itemCount: events.length,
                        physics: const AlwaysScrollableScrollPhysics(),
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final ev = events[i];
                          final typeColor = _colorForEventType(ev.type);
                          return SelectableItem<int>(
                            controller: _selection,
                            id: ev.id,
                            child: ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: typeColor.withValues(alpha: 0.15),
                                child: Text(
                                  ev.type.name.substring(0, 1).toUpperCase(),
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: typeColor),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    ev.type.name,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: typeColor),
                                  ),
                                  // Quantity and price reveal position size — censor in privacy mode.
                                  if (ev.quantity != null) ...[
                                    const SizedBox(width: 8),
                                    PrivacyText(
                                      'qty: ${ev.quantity!.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                  if (ev.price != null) ...[
                                    const SizedBox(width: 8),
                                    PrivacyText('@ ${ev.price!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ],
                              ),
                              subtitle: Text(dateFmt.format(ev.valueDate), style: const TextStyle(fontSize: 12)),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  PrivacyText(
                                    '${ev.amount >= 0 ? '+' : ''}${amtFmt.format(ev.amount)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: ev.amount >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                                    ),
                                  ),
                                  if (showConverted && convertedAmounts.containsKey(ev.id))
                                    PrivacyText(
                                      '≈ ${baseFmt.format(convertedAmounts[ev.id]!)}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                ],
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AssetEventEditScreen(event: ev, asset: asset),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text(s.error(e))),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _selection.active
              ? SelectionActionBar<int>(
                  controller: _selection,
                  visibleIds: events.map((e) => e.id).toList(),
                  onDelete: (ids) => ref.read(assetEventServiceProvider).deleteMany(ids.toList()),
                )
              : null,
          floatingActionButton: _selection.active
              ? null
              : FloatingActionButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AssetEventEditScreen(asset: asset)),
                  ),
                  child: const Icon(Icons.add),
                ),
        );
      },
    );
  }

  Color _colorForEventType(EventType type) {
    return switch (type) {
      EventType.buy => Colors.blue,
      EventType.sell => Colors.orange,
      EventType.revalue => Colors.teal,
    };
  }

  Future<void> _editAsset(BuildContext context, WidgetRef ref) async {
    // Pull the latest asset row from the live stream rather than reusing
    // `widget.asset` (the snapshot captured when the user first opened
    // this screen). Without this, fields edited in a previous dialog
    // session look "not saved" on reopen — the DB is updated but the
    // dialog re-initializes controllers from the stale snapshot.
    final live = ref.read(assetsProvider).value?.firstWhere((a) => a.id == asset.id, orElse: () => asset) ?? asset;
    await showDialog(
      context: context,
      builder: (ctx) => _EditAssetDialog(ref: ref, asset: live),
    );
  }

  Future<void> _pickPillarThenEdit(
    BuildContext context,
    WidgetRef ref,
    int assetId,
  ) async {
    final s = ref.read(appStringsProvider);
    final pillars = await ref.read(pillarsProvider.future);
    if (!context.mounted) return;
    if (pillars.isEmpty) {
      showInfoSnack(context, s.pillarsEmptyTitle);
      return;
    }
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(s.pillarPickPillar),
        children: pillars
            .map(
              (p) => SimpleDialogOption(
                onPressed: () => Navigator.of(ctx).pop(p.id),
                child: Text(p.name),
              ),
            )
            .toList(),
      ),
    );
    if (picked == null || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PillarDetailScreen(
          pillarId: picked,
          focusAssetId: assetId,
        ),
      ),
    );
  }

  Future<void> _confirmWipeEvents(BuildContext context, WidgetRef ref) async {
    final s = ref.read(appStringsProvider);
    final evCount = ref.read(assetEventsProvider(asset.id)).value?.length ?? 0;
    if (evCount == 0) {
      showInfoSnack(context, s.noEventsToWipe);
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: s.wipeAllEventsTitle,
      content: '${s.wipeEventsBody(evCount, asset.name)}${s.cannotBeUndone}',
      confirmLabel: s.wipe,
      cancelLabel: s.cancel,
      confirmColor: Colors.orange,
    );
    if (confirmed) {
      _log.warning('wiping events for asset ${asset.id}');
      final deleted = await ref.read(assetEventServiceProvider).deleteByAsset(asset.id);
      if (context.mounted) {
        showInfoSnack(context, s.wipedEvents(deleted));
      }
    }
  }

  Future<void> _confirmDeleteAsset(BuildContext context, WidgetRef ref) async {
    final s = ref.read(appStringsProvider);
    final confirmed = await showConfirmDialog(
      context,
      title: s.deleteAssetTitle,
      content: s.deleteAssetConfirm(asset.name),
      confirmLabel: s.delete,
      cancelLabel: s.cancel,
      confirmColor: Colors.red,
    );
    if (confirmed) {
      _log.warning('deleting asset id=${asset.id}, name=${asset.name}');
      await ref.read(assetEventServiceProvider).deleteByAsset(asset.id);
      await ref.read(assetServiceProvider).delete(asset.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

// ──────────────────────────────────────────────
// Asset chart cards (value + price)
// ──────────────────────────────────────────────
