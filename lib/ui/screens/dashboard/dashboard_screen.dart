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

// ════════════════════════════════════════════════════
// Dashboard screen with dynamic custom charts
// ════════════════════════════════════════════════════

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
    final allDataAsync = ref.watch(_allSeriesDataProvider);
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
    AsyncValue<_AllSeriesData?> allDataAsync,
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

        final charts = _buildStaticCharts(allData, s);

        // Build set of chart IDs that are sources of a combined chart
        final collapsedChartIds = <int>{};
        for (final chart in charts) {
          if (chart.widgetType == 'chart' && chart.sourceChartIds != null) {
            try {
              final ids = (jsonDecode(chart.sourceChartIds!) as List).cast<int>();
              collapsedChartIds.addAll(ids);
            } catch (_) {}
          }
        }
        // Performance chart is self-collapsible (not part of Totals)
        collapsedChartIds.add(-8);

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 40, 16),
          itemCount: charts.length,
          itemBuilder: (context, index) {
            final chart = charts[index];

            // Price changes widget
            if (chart.widgetType == 'price_changes') {
              return Padding(
                key: ValueKey(chart.id),
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AssetDailyChangesCard(locale: locale, baseCurrency: allData.baseCurrency),
                    const SizedBox(height: 16),
                    _SummaryTotalsTable(allData: allData, locale: locale),
                  ],
                ),
              );
            }

            // Chart widgets
            final isCombined = chart.sourceChartIds != null;

            List<_Series> filteredSeries;
            if (isCombined) {
              filteredSeries = _buildCombinedSeries(charts, chart, allData);
            } else {
              final seriesConfigs = _parseSeriesJson(chart.seriesJson);
              filteredSeries = _filterSeries(allData, seriesConfigs);
            }

            final hidden = _hiddenFor(chart.id);
            final zoom = _zoomFor(chart.id);
            final hideComp = isCombined ? false : _hideComponentsFor(chart.id);

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
        );
      },
    );
  }

  Widget _buildCashFlowTab(
    AsyncValue<_AllSeriesData?> allDataAsync,
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
  List<DashboardChart> _buildStaticCharts(_AllSeriesData allData, AppStrings s) {
    final now = DateTime.now();

    List<Map<String, dynamic>> toConfigs(List<_Series> series) => series.map((s) {
          final parts = s.key.split(':');
          return {'type': parts[0], 'id': int.parse(parts[1])};
        }).toList();

    // Total Assets: all accounts + all market values + spread adjustments
    final totalAssetsJson = jsonEncode([
      ...toConfigs(allData.accounts),
      ...toConfigs(allData.assetMarket),
      ...toConfigs(allData.adjustments),
    ]);

    // Cash: all accounts + spread adjustments only (no income adj)
    final cashJson = jsonEncode([
      ...toConfigs(allData.accounts),
      ...toConfigs(allData.adjustments),
    ]);

    // Saving: all accounts + all invested assets + all adjustments (spread + income)
    final savingJson = jsonEncode([
      ...toConfigs(allData.accounts),
      ...toConfigs(allData.assetInvested),
      ...toConfigs(allData.adjustments),
      ...toConfigs(allData.incomeAdjustments),
    ]);

    // Invested: all invested assets
    final investedJson = jsonEncode(toConfigs(allData.assetInvested));

    // Portfolio: all market-value assets
    final portfolioJson = jsonEncode(toConfigs(allData.assetMarket));

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
      DashboardChart(id: idCash, title: s.dashCash, widgetType: 'chart',
          sortOrder: 3, seriesJson: cashJson, createdAt: now),
      DashboardChart(id: idSaving, title: s.dashSaving, widgetType: 'chart',
          sortOrder: 4, seriesJson: savingJson, createdAt: now),
      DashboardChart(id: idInvested, title: s.dashInvested, widgetType: 'chart',
          sortOrder: 5, seriesJson: investedJson, createdAt: now),
      DashboardChart(id: idPortfolio, title: s.dashPortfolio, widgetType: 'chart',
          sortOrder: 6, seriesJson: portfolioJson, createdAt: now),
      DashboardChart(id: idPerformance, title: s.dashPerformance, widgetType: 'chart',
          sortOrder: 7, seriesJson: performanceJson, createdAt: now),
    ];
  }

  /// Build series for a combined chart: each source chart's total becomes a line.
  List<_Series> _buildCombinedSeries(List<DashboardChart> allCharts, DashboardChart combined, _AllSeriesData allData) {
    List<int> sourceIds;
    try {
      sourceIds = (jsonDecode(combined.sourceChartIds!) as List).cast<int>();
    } catch (_) {
      return [];
    }

    final result = <_Series>[];
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

      result.add(_Series(
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
  static List<FlSpot> _buildSmartTotalSpotsStatic(List<_Series> visible) {
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


  List<Map<String, dynamic>> _parseSeriesJson(String json) {
    try {
      return (jsonDecode(json) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  List<_Series> _filterSeries(_AllSeriesData allData, List<Map<String, dynamic>> configs) {
    final result = <_Series>[];
    for (final config in configs) {
      final type = config['type'] as String?;
      final id = config['id'] as int?;
      if (type == null || id == null) continue;
      final key = '$type:$id';
      final match = allData.allSeries.where((s) => s.key == key);
      if (match.isNotEmpty) result.add(match.first);
    }
    return result;
  }

}
