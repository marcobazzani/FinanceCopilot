import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:drift/drift.dart' show OrderingTerm, Variable;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../utils/chart_math.dart' as chart_math;
import '../../../utils/formatters.dart' as fmt;

import '../../../database/database.dart';
import '../../../database/tables.dart';
import '../../../database/providers.dart';
import '../../../l10n/app_strings.dart';
import '../../../services/exchange_rate_service.dart';
import '../../../services/financial_health_service.dart';
import '../../../services/allocation_computation_service.dart';
import '../../../services/providers/providers.dart';
import '../../widgets/privacy_text.dart';
import '../allocation_tab.dart';

part 'models.dart';
part 'rate_resolver.dart';
part 'data_providers.dart';
part 'cashflow_math.dart';
part 'chart_card.dart';
part 'unified_chart.dart';
part 'daily_changes_card.dart';
part 'cashflow_tab.dart';
part 'yearly_summary_table.dart';
part 'monthly_grid.dart';
part 'yoy_diff_table.dart';
part 'cashflow_charts.dart';
part 'totals_table.dart';
part 'health_tab.dart';
part 'chart_editor_dialog.dart';

// ════════════════════════════════════════════════════
// Dashboard screen with dynamic custom charts
// ════════════════════════════════════════════════════

/// Public facade over the role resolvers living on `_DashboardScreenState`.
/// Lets tests (and any future external caller) compute role-driven totals
/// without reaching into the private State class. The semantics and
/// fallbacks are defined on `_DashboardScreenState.spotsForRole`.
class ChartRoles {
  const ChartRoles._();

  static List<FlSpot> spotsForRole(
    String role,
    List<DashboardChart> charts,
    AllSeriesData allData,
    List<Asset> activeAssets,
  ) => _DashboardScreenState.spotsForRole(role, charts, allData, activeAssets);

  static double valueForRole(
    String role,
    List<DashboardChart> charts,
    AllSeriesData allData,
    List<Asset> activeAssets,
  ) => _DashboardScreenState.valueForRole(role, charts, allData, activeAssets);
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _ChartZoom {
  double? minX, maxX, minY, maxY;
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _hiddenPerChart = <int, Set<String>>{}; // chartId → hidden series keys
  final _chartHeights = <int, double>{}; // chartId → user-set height
  final _chartZooms = <int, _ChartZoom>{}; // chartId → independent zoom
  final _hideComponents = <int, bool>{}; // chartId → hide individual lines
  static const _defaultChartHeight = 420.0;
  static const _minChartHeight = 200.0;
  static const _maxChartHeight = 900.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Set<String> _hiddenFor(int chartId) =>
      _hiddenPerChart.putIfAbsent(chartId, () => {});

  double _heightFor(int chartId) =>
      _chartHeights.putIfAbsent(chartId, () => _defaultChartHeight);

  _ChartZoom _zoomFor(int chartId) =>
      _chartZooms.putIfAbsent(chartId, () => _ChartZoom());

  bool _hideComponentsFor(int chartId, {bool defaultValue = true}) =>
      _hideComponents.putIfAbsent(chartId, () => defaultValue);

  @override
  Widget build(BuildContext context) {
    final allDataAsync = ref.watch(allSeriesDataProvider);
    final locale = ref.watch(appLocaleProvider).value ?? Platform.localeName;
    final langCode = ref.watch(portableLanguageProvider);
    final language = langCode.startsWith('it') ? 'it_IT' : 'en_US';
    final s = ref.watch(appStringsProvider);

    return Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: s.dashTabHealth),
              Tab(text: s.dashTabHistory),
              Tab(text: s.dashTabCashFlow),
              Tab(text: s.dashTabAssetsOverview),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const _FinancialHealthTab(),
                _buildChartsTab(allDataAsync, locale, language, context, s),
                _buildCashFlowTab(allDataAsync, locale, language, context, s),
                const AllocationTab(),
              ],
            ),
          ),
        ],
    );
  }

  Widget _buildChartsTab(
    AsyncValue<AllSeriesData?> allDataAsync,
    String locale,
    String language,
    BuildContext context,
    AppStrings s,
  ) {
    return allDataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(s.error(e))),
      data: (allData) {
        if (allData == null) {
          return Center(
            child: Text(s.dashNoData,
                style: const TextStyle(color: Colors.grey)),
          );
        }

        final userCharts = ref.watch(dashboardChartsProvider).value ?? const <DashboardChart>[];
        final activeAssets = ref.watch(activeAssetsProvider).value ?? const <Asset>[];
        // DB-stored charts are authoritative once any exist. Static defaults
        // are used only as a fallback when the DB has no rows (fresh install).
        final rawCharts = userCharts.isNotEmpty
            ? userCharts
            : _buildStaticCharts(allData, activeAssets, s);
        // Render order: Price Changes widget first, then combined-overlay
        // charts (Totals), then everything else (regular + role-tagged).
        // Within each bucket, preserve the user's sort_order.
        int bucket(DashboardChart c) {
          if (c.widgetType == 'price_changes') return 0;
          if (c.sourceChartIds != null) return 1; // combined overlays
          return 2; // regular charts + role-tagged (cash/saving/portfolio/liquid_investments)
        }
        final charts = [...rawCharts]
          ..sort((a, b) {
            final ba = bucket(a);
            final bb = bucket(b);
            if (ba != bb) return ba.compareTo(bb);
            return a.sortOrder.compareTo(b.sortOrder);
          });

        // Build set of chart IDs that are sources of a combined chart
        final collapsedChartIds = <int>{};
        for (final chart in charts) {
          if (chart.widgetType == 'chart' && chart.sourceChartIds != null) {
            final resolved = _resolveSourceIds(chart, charts);
            collapsedChartIds.addAll(resolved);
          }
        }
        // Performance chart is self-collapsible (not part of Totals)
        collapsedChartIds.add(-8);

        return Stack(
          children: [
            ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 40, 96),
          itemCount: charts.length,
          itemBuilder: (context, index) {
            final chart = charts[index];

            // Price changes widget
            if (chart.widgetType == 'price_changes') {
              // Derive Totals rows from every non-combined chart on the
              // dashboard — role-tagged ones (cash / saving / portfolio /
              // liquid_investments) included, so the summary stays in sync
              // with the chart list.
              final rowCharts = charts
                  .where((c) => c.widgetType != 'price_changes' && c.sourceChartIds == null)
                  .toList();
              final chartRows = rowCharts.map((c) {
                final series = _filterSeries(allData, _parseSeriesJson(c.seriesJson));
                return (title: c.title, series: series);
              }).toList();
              return Padding(
                key: ValueKey(chart.id),
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AssetDailyChangesCard(locale: locale, baseCurrency: allData.baseCurrency),
                    const SizedBox(height: 16),
                    _SummaryTotalsTable(
                      allData: allData,
                      locale: locale,
                      chartRows: chartRows,
                    ),
                  ],
                ),
              );
            }

            // Chart widgets
            final isCombined = chart.sourceChartIds != null;

            List<ChartSeries> filteredSeries;
            if (isCombined) {
              filteredSeries = _buildCombinedSeries(charts, chart, allData);
            } else {
              final seriesConfigs = _parseSeriesJson(chart.seriesJson);
              filteredSeries = _filterSeries(allData, seriesConfigs);
            }

            final hidden = _hiddenFor(chart.id);
            final zoom = _zoomFor(chart.id);
            final hideComp = isCombined ? false : _hideComponentsFor(chart.id);
            final isUserChart = chart.id > 0; // DB rows have positive ids; static defaults are negative

            final chartCard = _ChartCard(
              chart: chart,
              series: filteredSeries,
              allData: allData,
              hidden: hidden,
              hideComponents: hideComp,
              locale: locale,
              language: language,
              chartHeight: _heightFor(chart.id),
              zoomMinX: zoom.minX,
              zoomMaxX: zoom.maxX,
              zoomMinY: zoom.minY,
              zoomMaxY: zoom.maxY,
              onEdit: isUserChart
                  ? () => isCombined
                      ? _showCombineChartsDialog(context, charts, chart)
                      : _showChartEditor(context, allData, chart)
                  : null,
              onDelete: isUserChart ? () => _deleteChart(context, chart) : null,
              onToggle: (key) => setState(() {
                hidden.contains(key) ? hidden.remove(key) : hidden.add(key);
              }),
              onToggleGroup: (keys) => setState(() {
                keys.every(hidden.contains) ? hidden.removeAll(keys) : hidden.addAll(keys);
              }),
              onToggleHideComponents: () => setState(() {
                _hideComponents[chart.id] = !hideComp;
              }),
              onZoom: (minX, maxX, minY, maxY) => setState(() {
                zoom.minX = minX;
                zoom.maxX = maxX;
                zoom.minY = minY;
                zoom.maxY = maxY;
              }),
              onHeightChanged: (h) => setState(() {
                _chartHeights[chart.id] = h.clamp(_minChartHeight, _maxChartHeight);
              }),
            );

            // Source charts: collapsible (same as Cash Flow tab)
            if (collapsedChartIds.contains(chart.id)) {
              return Padding(
                key: ValueKey(chart.id),
                padding: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  title: Text(chart.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: isUserChart
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => isCombined
                                  ? _showCombineChartsDialog(context, charts, chart)
                                  : _showChartEditor(context, allData, chart),
                              tooltip: s.edit,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () => _deleteChart(context, chart),
                              tooltip: s.delete,
                            ),
                            const Icon(Icons.expand_more),
                          ],
                        )
                      : null,
                  children: [chartCard],
                ),
              );
            }

            return Padding(
              key: ValueKey(chart.id),
              padding: const EdgeInsets.only(bottom: 24),
              child: chartCard,
            );
          },
        ),
            Positioned(
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'dash_reset',
                    tooltip: s.chartResetDefaults,
                    onPressed: () => _resetToDefaults(context, allData),
                    child: const Icon(Icons.restart_alt),
                  ),
                  const SizedBox(height: 8),
                  // Only allow one combined/overlay chart at a time: hide
                  // the merge FAB whenever one already exists.
                  if (!charts.any((c) => c.sourceChartIds != null)) ...[
                    FloatingActionButton.small(
                      heroTag: 'dash_combine',
                      tooltip: s.chartCombineNewTitle,
                      onPressed: () =>
                          _showCombineChartsDialog(context, charts, null),
                      child: const Icon(Icons.merge_type),
                    ),
                    const SizedBox(height: 8),
                  ],
                  FloatingActionButton(
                    heroTag: 'dash_add',
                    tooltip: s.chartNewTitle,
                    onPressed: () => _showChartEditor(context, allData, null),
                    child: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showChartEditor(
    BuildContext context,
    AllSeriesData allData,
    DashboardChart? existing,
  ) async {
    final result = await showDialog<_ChartEditorResult>(
      context: context,
      builder: (ctx) => _ChartEditorDialog(
        allData: allData,
        existing: existing,
      ),
    );
    if (result == null) return;

    final service = ref.read(dashboardChartServiceProvider);
    final seriesJson = jsonEncode(result.selectedSeries);

    if (existing != null && existing.id > 0) {
      await service.update(
        existing.id,
        title: result.title,
        seriesJson: seriesJson,
      );
    } else {
      await service.create(title: result.title, seriesJson: seriesJson);
    }
  }

  Future<void> _showCombineChartsDialog(
    BuildContext context,
    List<DashboardChart> charts,
    DashboardChart? existing,
  ) async {
    // Any non-widget chart can feed Totals — both role-tagged (cash, saving,
    // portfolio, liquid_investments) and user-created custom charts.
    final candidates = charts
        .where((c) => c.widgetType != 'price_changes' && c.sourceChartIds == null)
        .toList();
    final result = await showDialog<_CombineChartsResult>(
      context: context,
      builder: (ctx) => _CombineChartsDialog(
        charts: candidates,
        existing: existing,
      ),
    );
    if (result == null) return;

    final service = ref.read(dashboardChartServiceProvider);
    final sourceField =
        result.autoAll ? '*' : jsonEncode(result.selectedChartIds);

    if (existing != null && existing.id > 0) {
      await service.update(
        existing.id,
        title: result.title,
        sourceChartIds: sourceField,
      );
    } else {
      await service.create(
        title: result.title,
        seriesJson: '[]',
        sourceChartIds: sourceField,
      );
    }
  }

  Future<void> _resetToDefaults(
      BuildContext context, AllSeriesData allData) async {
    final s = ref.read(appStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.chartResetConfirmTitle),
        content: Text(s.chartResetConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.chartResetDefaults),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final service = ref.read(dashboardChartServiceProvider);
    // Wipe existing rows so we start clean.
    final existing = await service.getAll();
    for (final c in existing) {
      await service.delete(c.id);
    }

    // Seed from the live static defaults.
    final activeAssets = ref.read(activeAssetsProvider).value ?? const <Asset>[];
    final defaults = _buildStaticCharts(allData, activeAssets, s);
    // Two-pass: create non-combined first, then combined referencing real ids.
    for (final chart in defaults) {
      if (chart.sourceChartIds != null) continue;
      await service.create(
        title: chart.title,
        seriesJson: chart.seriesJson,
        widgetType: chart.widgetType,
      );
    }
    for (final chart in defaults) {
      if (chart.sourceChartIds == null) continue;
      // Dynamic marker: Totals auto-includes any non-combined chart present.
      await service.create(
        title: chart.title,
        seriesJson: chart.seriesJson,
        widgetType: chart.widgetType,
        sourceChartIds: '*',
      );
    }
  }

  Future<void> _deleteChart(BuildContext context, DashboardChart chart) async {
    final s = ref.read(appStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.chartDeleteTitle),
        content: Text(s.chartDeleteConfirm(chart.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(dashboardChartServiceProvider).delete(chart.id);
    }
  }

  Widget _buildCashFlowTab(
    AsyncValue<AllSeriesData?> allDataAsync,
    String locale,
    String language,
    BuildContext context,
    AppStrings s,
  ) {
    return allDataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(s.error(e))),
      data: (allData) {
        if (allData == null) {
          return Center(
            child: Text(s.noDataYet,
                style: const TextStyle(color: Colors.grey)),
          );
        }
        return _CashFlowTab(allData: allData, locale: locale, language: language);
      },
    );
  }

  /// Build the fixed set of dashboard widgets from live series data.
  /// Widget definitions are static; series are resolved dynamically from all
  /// active accounts, assets, and adjustments — no IDs are hardcoded.
  List<DashboardChart> _buildStaticCharts(
    AllSeriesData allData,
    List<Asset> activeAssets,
    AppStrings s,
  ) {
    final now = DateTime.now();

    List<Map<String, dynamic>> toConfigs(List<ChartSeries> series) => series.map((s) {
          final parts = s.key.split(':');
          return {'type': parts[0], 'id': int.parse(parts[1])};
        }).toList();

    // Total Assets: all accounts + all market values + spread adjustments
    final totalAssetsJson = jsonEncode([
      ...toConfigs(allData.accounts),
      ...toConfigs(allData.assetMarket),
      ...toConfigs(allData.adjustments),
    ]);

    final cashJson   = jsonEncode(toConfigs(allData.cashSeries));
    final savingJson = jsonEncode(toConfigs(allData.savingSeries));

    // Invested: all invested assets
    final investedJson = jsonEncode(toConfigs(allData.assetInvested));

    // Portfolio: all market-value assets
    final portfolioJson = jsonEncode(toConfigs(allData.assetMarket));

    // Liquid Investments: market-value assets whose instrumentType is not
    // pension / realEstate / alternative / liability. Same filter Health
    // used to apply inline; now materialised as an editable chart.
    final liquidInvestmentsJson =
        jsonEncode(toConfigs(_liquidAssetMarket(allData, activeAssets)));

    // Performance: gain per asset (market - invested)
    final performanceJson = jsonEncode(toConfigs(allData.assetGain));

    // Stable negative IDs avoid clashing with any real DB rows
    const idPriceChanges = -1;
    const idTotals = -2;
    const idTotalAssets = -3;
    const idCash = -4;
    const idSaving = -5;
    const idInvested = -6;
    const idPortfolio = -7;
    const idLiquidInvestments = -9;
    const idPerformance = -8;

    return [
      DashboardChart(id: idPriceChanges, title: s.dashPriceChanges, widgetType: 'price_changes',
          sortOrder: 0, seriesJson: '[]', createdAt: now),
      DashboardChart(id: idTotals, title: s.dashTotals, widgetType: 'chart',
          sortOrder: 1, seriesJson: '[]',
          sourceChartIds: jsonEncode([idTotalAssets, idCash, idSaving, idInvested, idPortfolio]),
          createdAt: now),
      DashboardChart(id: idTotalAssets, title: s.dashTotalAssets, widgetType: 'chart',
          sortOrder: 2, seriesJson: totalAssetsJson, createdAt: now),
      // Cash / Saving / Portfolio / Liquid Investments carry dedicated
      // widget_type markers so Cash Flow + Health can resolve them by role.
      DashboardChart(id: idCash, title: s.dashCash, widgetType: 'cash',
          sortOrder: 3, seriesJson: cashJson, createdAt: now),
      DashboardChart(id: idSaving, title: s.dashSaving, widgetType: 'saving',
          sortOrder: 4, seriesJson: savingJson, createdAt: now),
      DashboardChart(id: idInvested, title: s.dashInvested, widgetType: 'chart',
          sortOrder: 5, seriesJson: investedJson, createdAt: now),
      DashboardChart(id: idPortfolio, title: s.dashPortfolio, widgetType: 'portfolio',
          sortOrder: 6, seriesJson: portfolioJson, createdAt: now),
      DashboardChart(id: idLiquidInvestments, title: s.dashLiquidInvestments,
          widgetType: 'liquid_investments',
          sortOrder: 7, seriesJson: liquidInvestmentsJson, createdAt: now),
      DashboardChart(id: idPerformance, title: s.dashPerformance, widgetType: 'chart',
          sortOrder: 8, seriesJson: performanceJson, createdAt: now),
    ];
  }

  /// Resolve the source chart IDs for a combined chart.
  /// Literal "*" means "every non-widget, non-combined chart present" —
  /// this is how the seeded Totals chart stays in sync as the user adds
  /// or removes charts. Role-tagged charts (cash / saving / portfolio /
  /// liquid_investments) are included alongside user-created ones.
  List<int> _resolveSourceIds(DashboardChart combined, List<DashboardChart> allCharts) {
    final src = combined.sourceChartIds;
    if (src == null) return const [];
    if (src == '*') {
      return allCharts
          .where((c) =>
              c.id != combined.id &&
              c.widgetType != 'price_changes' &&
              c.sourceChartIds == null)
          .map((c) => c.id)
          .toList();
    }
    try {
      return (jsonDecode(src) as List).cast<int>();
    } catch (_) {
      return const [];
    }
  }

  /// Build series for a combined chart: each source chart's total becomes a line.
  List<ChartSeries> _buildCombinedSeries(List<DashboardChart> allCharts, DashboardChart combined, AllSeriesData allData) {
    final sourceIds = _resolveSourceIds(combined, allCharts);
    if (sourceIds.isEmpty) return [];

    final result = <ChartSeries>[];
    var colorIdx = 0;

    for (final srcId in sourceIds) {
      final srcChart = allCharts.where((c) => c.id == srcId).firstOrNull;
      if (srcChart == null) continue;

      final seriesConfigs = _parseSeriesJson(srcChart.seriesJson);
      final srcSeries = _filterSeries(allData, seriesConfigs);
      if (srcSeries.isEmpty) continue;

      // Compute total spots for this source chart using the smart logic
      final totalSpots = _buildSmartTotalSpotsStatic(srcSeries);
      if (totalSpots.isEmpty) continue;

      result.add(ChartSeries(
        key: 'combined_src:$srcId',
        name: srcChart.title,
        color: _chartColors[colorIdx % _chartColors.length],
        spots: totalSpots,
      ));
      colorIdx++;
    }

    return result;
  }

  /// Static version of smart total spots for use outside _ChartCard.
  static List<FlSpot> _buildSmartTotalSpotsStatic(List<ChartSeries> visible) {
    final visibleInvestedIds = <int>{};
    final visibleMarketIds = <int>{};
    for (final s in visible) {
      final parts = s.key.split(':');
      if (parts.length != 2) continue;
      final id = int.tryParse(parts[1]);
      if (id == null) continue;
      if (parts[0] == 'asset_invested') visibleInvestedIds.add(id);
      if (parts[0] == 'asset_market') visibleMarketIds.add(id);
    }
    final excludeFromTotal = <String>{};
    for (final id in visibleInvestedIds) {
      if (visibleMarketIds.contains(id)) {
        excludeFromTotal.add('asset_invested:$id');
      }
    }
    final spotsForTotal = visible
        .where((s) => !excludeFromTotal.contains(s.key) && !s.rightAxis)
        .map((s) => s.spots)
        .toList();
    return buildTotalSpots(spotsForTotal);
  }


  static List<Map<String, dynamic>> _parseSeriesJson(String json) {
    try {
      return (jsonDecode(json) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static List<ChartSeries> _filterSeries(AllSeriesData allData, List<Map<String, dynamic>> configs) {
    final result = <ChartSeries>[];
    for (final config in configs) {
      final type = config['type'] as String?;
      final id = config['id'] as int?;
      if (type == null || id == null) continue;
      // Optional polarity flip — only adjustments use this today, but the
      // implementation is type-agnostic: sign=-1 negates every y value.
      final sign = (config['sign'] as num?)?.toInt() ?? 1;

      // Legacy: the combined `adjustment:<id>` / `income_adj:<id>` keys used
      // before the value/events split now map to BOTH halves so older
      // charts keep rendering the full event contribution.
      final keys = (type == 'adjustment')
          ? const ['adjustment_value', 'adjustment_events']
          : (type == 'income_adj')
              ? const ['income_adj_value', 'income_adj_events']
              : [type];

      for (final prefix in keys) {
        final key = '$prefix:$id';
        final match = allData.allSeries.where((s) => s.key == key);
        if (match.isEmpty) continue;
        final src = match.first;
        result.add(sign == 1
            ? src
            : ChartSeries(
                key: src.key,
                name: src.name,
                color: src.color,
                spots: src.spots.map((p) => FlSpot(p.x, sign * p.y)).toList(),
                isDashed: src.isDashed,
                rightAxis: src.rightAxis,
              ));
      }
    }
    return result;
  }

  /// Pick asset_market series whose asset's instrumentType is NOT in
  /// `illiquidTypes` (pension / realEstate / alternative / liability).
  /// Used both at seed time (default Liquid Investments chart) and in the
  /// role resolver fallback.
  static List<ChartSeries> _liquidAssetMarket(
    AllSeriesData allData,
    List<Asset> activeAssets,
  ) {
    const illiquid = {
      InstrumentType.pension,
      InstrumentType.realEstate,
      InstrumentType.alternative,
      InstrumentType.liability,
    };
    final liquidIds = {
      for (final a in activeAssets)
        if (!illiquid.contains(a.instrumentType)) a.id,
    };
    return allData.assetMarket.where((ser) {
      final parts = ser.key.split(':');
      if (parts.length != 2) return false;
      final id = int.tryParse(parts[1]);
      return id != null && liquidIds.contains(id);
    }).toList();
  }

  /// Role resolver: latest cumulative total for the user's chart of this
  /// role, or the hard-coded fallback composition if the chart is missing
  /// or unresolvable. Keeps Cash Flow + Health working even when the user
  /// deletes a fundamental chart.
  static List<FlSpot> spotsForRole(
    String role,
    List<DashboardChart> charts,
    AllSeriesData allData,
    List<Asset> activeAssets,
  ) {
    final chart = charts.where((c) => c.widgetType == role).firstOrNull;
    if (chart != null) {
      final series = _filterSeries(allData, _parseSeriesJson(chart.seriesJson));
      if (series.isNotEmpty) {
        return _buildSmartTotalSpotsStatic(series);
      }
    }
    return switch (role) {
      'cash'               => allData.cashSpots,
      'saving'             => allData.savingSpots,
      'portfolio'          => _buildSmartTotalSpotsStatic(allData.assetMarket),
      'liquid_investments' =>
        _buildSmartTotalSpotsStatic(_liquidAssetMarket(allData, activeAssets)),
      _                    => const <FlSpot>[],
    };
  }

  /// Scalar latest value for a role — Health KPIs want the current number.
  static double valueForRole(
    String role,
    List<DashboardChart> charts,
    AllSeriesData allData,
    List<Asset> activeAssets,
  ) {
    final spots = spotsForRole(role, charts, allData, activeAssets);
    return spots.isEmpty ? 0.0 : spots.last.y;
  }

}
