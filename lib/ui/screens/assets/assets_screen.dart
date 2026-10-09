import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';
import 'package:finance_copilot/services/market/web_market_data_service.dart';
import 'package:finance_copilot/services/market/market_price_service.dart' show exchangeCurrency, isKnownExchange, supportedExchanges;
import 'package:finance_copilot/services/portfolio/portfolio_model_service.dart' show isIsin, isinCacheKey;
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/utils/dialogs.dart';
import 'package:finance_copilot/utils/formatters.dart' as fmt;
import 'package:finance_copilot/ui/screens/assets/asset_detail_screen.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show currencySymbol;
import 'package:finance_copilot/ui/widgets/asset_search.dart';
import 'package:finance_copilot/ui/widgets/empty_state.dart';
import 'package:finance_copilot/ui/widgets/global_app_bar_actions.dart';
import 'package:finance_copilot/ui/widgets/mobile_pull_to_refresh.dart';
import 'package:finance_copilot/ui/widgets/privacy_text.dart';
import 'package:finance_copilot/ui/widgets/selection/selectable_item.dart';
import 'package:finance_copilot/ui/widgets/selection/selection_action_bar.dart';
import 'package:finance_copilot/ui/widgets/selection/selection_controller.dart';
import 'package:finance_copilot/ui/widgets/swipe_to_delete.dart';

part 'asset_tile.dart';
part 'create_dialog.dart';

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
                return EmptyState(
                  icon: Icons.pie_chart,
                  message: s.noAssetsYet,
                  actionLabel: s.createAsset,
                  onAction: () => showDialog(
                    context: context,
                    builder: (ctx) => _CreateAssetDialog(ref: ref),
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
        IntermediaryGroupHeader(intermediary: intermediary, count: assets.length),
        ...assets.map((asset) {
          final stat = stats[asset.id];
          return SelectableItem<int>(
            key: ValueKey(asset.id),
            controller: _selection,
            id: asset.id,
            child: SwipeToDelete.custom(
              key: ValueKey('dismiss_asset_${asset.id}'),
              confirmAndDelete: () => confirmAndDeleteAsset(context, ref, asset),
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
                onMove: (newId) => ref.read(intermediaryServiceProvider).moveAsset(asset.id, newId),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AssetDetailScreen(asset: asset)),
                ),
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
