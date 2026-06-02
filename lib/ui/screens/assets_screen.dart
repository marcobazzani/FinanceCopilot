import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../database/database.dart';
import '../../database/tables.dart';
import '../../services/asset_service.dart';
import '../../services/web_market_data_service.dart';
import '../../services/market_price_service.dart' show exchangeCurrency, isKnownExchange, supportedExchanges;
import '../../services/providers/providers.dart';
import '../../l10n/app_strings.dart';
import '../../utils/dialogs.dart';
import '../../utils/formatters.dart' as fmt;
import 'asset_detail_screen.dart';
import 'dashboard/dashboard_screen.dart' show currencySymbol;
import '../widgets/asset_search.dart';
import '../widgets/global_app_bar_actions.dart';
import '../widgets/mobile_pull_to_refresh.dart';
import '../widgets/privacy_text.dart';
import '../widgets/selection/selectable_item.dart';
import '../widgets/selection/selection_action_bar.dart';
import '../widgets/selection/selection_controller.dart';

part 'assets/asset_tile.dart';
part 'assets/create_dialog.dart';

class AssetsScreen extends ConsumerStatefulWidget {
  const AssetsScreen({super.key});

  @override
  ConsumerState<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends ConsumerState<AssetsScreen> {
  final _selection = SelectionController<int>();

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final assetsAsync = ref.watch(assetsProvider);
    final statsAsync = ref.watch(assetStatsProvider);
    final intermediariesAsync = ref.watch(intermediariesProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider).value ?? 'EUR';
    final locale = ref.watch(appLocaleProvider).value ?? Platform.localeName;
    final convertedStats = ref.watch(convertedAssetStatsProvider).value ?? {};
    final marketValues = ref.watch(assetMarketValuesProvider).value ?? {};
    final noMarketData = ref.watch(assetsWithoutMarketPriceProvider).value ?? const <int>{};

    return ListenableBuilder(
      listenable: _selection,
      builder: (lbCtx, _) {
        // Build the id list in rendered order: grouped by intermediary.
        // Every asset must have an intermediary (schema v29 invariant).
        final assets = assetsAsync.value ?? const <Asset>[];
        final intermediariesNow = intermediariesAsync.value ?? const <Intermediary>[];
        final grouping = <int, List<int>>{};
        for (final a in assets) {
          (grouping[a.intermediaryId] ??= []).add(a.id);
        }
        final allAssetIds = <int>[
          for (final i in intermediariesNow) ...?grouping[i.id],
        ];
        _selection.setOrderedIds(allAssetIds);
        return Scaffold(
          appBar: AppBar(actions: globalAppBarActions(context, ref)),
          body: assetsAsync.when(
            data: (assets) {
              if (assets.isEmpty && (intermediariesAsync.value ?? []).isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pie_chart, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(height: 16),
                      Text(s.noAssetsYet, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => showDialog(
                          context: context,
                          builder: (ctx) => _CreateAssetDialog(ref: ref),
                        ),
                        icon: const Icon(Icons.add),
                        label: Text(s.createAsset),
                      ),
                    ],
                  ),
                );
              }

              final stats = statsAsync.value ?? {};
              final intermediaries = intermediariesAsync.value ?? [];

              final grouped = <int, List<Asset>>{};
              for (final asset in assets) {
                (grouped[asset.intermediaryId] ??= []).add(asset);
              }

              return MobilePullToRefresh(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 80),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    for (final i in intermediaries)
                      if (grouped[i.id]?.isNotEmpty ?? false)
                        _buildGroup(
                          context,
                          s,
                          i.id,
                          i,
                          grouped[i.id] ?? [],
                          stats,
                          convertedStats,
                          marketValues,
                          noMarketData,
                          baseCurrency,
                          locale,
                          intermediaries,
                        ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(s.error(e))),
          ),
          bottomNavigationBar: _selection.active
              ? SelectionActionBar<int>(
                  controller: _selection,
                  visibleIds: allAssetIds,
                  onDelete: (ids) => ref.read(assetServiceProvider).deleteMany(ids.toList()),
                )
              : null,
          floatingActionButton: _selection.active
              ? null
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'add_intermediary_assets',
                      onPressed: () => _showManageIntermediariesDialog(context),
                      child: const Icon(Icons.business),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      heroTag: 'add_asset',
                      onPressed: () => showDialog(
                        context: context,
                        builder: (ctx) => _CreateAssetDialog(ref: ref),
                      ),
                      child: const Icon(Icons.add),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildGroup(
    BuildContext context,
    AppStrings s,
    int groupId,
    Intermediary intermediary,
    List<Asset> assets,
    Map<int, AssetStats> stats,
    Map<int, double?> convertedStats,
    Map<int, double> marketValues,
    Set<int> noMarketData,
    String baseCurrency,
    String locale,
    List<Intermediary> intermediaries,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.business, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${intermediary.name} (${assets.length})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...assets.map((asset) {
          final stat = stats[asset.id];
          return SelectableItem<int>(
            key: ValueKey(asset.id),
            controller: _selection,
            id: asset.id,
            child: _AssetTile(
              asset: asset,
              stats: stat,
              convertedInvested: convertedStats[asset.id],
              marketValue: marketValues[asset.id],
              hasNoMarketData: noMarketData.contains(asset.id),
              baseCurrency: baseCurrency,
              locale: locale,
              strings: s,
              intermediaries: intermediaries,
              onMove: (newId) {
                if (newId != asset.intermediaryId) {
                  ref.read(intermediaryServiceProvider).moveAsset(asset.id, newId);
                }
              },
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AssetDetailScreen(asset: asset)),
              ),
            ),
          );
        }),
        const Divider(height: 1),
      ],
    );
  }

  Future<void> _showManageIntermediariesDialog(BuildContext context) => showManageIntermediariesDialog(context, ref);
}
