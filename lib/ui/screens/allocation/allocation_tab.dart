import 'dart:io';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finance_copilot/ui/widgets/mobile_pull_to_refresh.dart';
import 'package:finance_copilot/ui/widgets/privacy_text.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/pillars/financial_health_service.dart' show RatingExt, rateTer;
import 'package:finance_copilot/services/portfolio/allocation_computation_service.dart' as alloc;
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show currencySymbol;
import 'package:finance_copilot/ui/widgets/empty_state.dart';
import 'package:finance_copilot/ui/widgets/footnote.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:intl/intl.dart';

// ════════════════════════════════════════════════════
// Asset type display names
// ════════════════════════════════════════════════════

// Asset Class and Instrument Type use direct asset fields, not composition data.

// ════════════════════════════════════════════════════
// Chart colors
// ════════════════════════════════════════════════════

const _palette = [
  Color(0xFF2196F3), // blue
  Color(0xFF4CAF50), // green
  Color(0xFFFF9800), // orange
  Color(0xFF9C27B0), // purple
  Color(0xFF009688), // teal
  Color(0xFFF44336), // red
  Color(0xFFFFC107), // amber
  Color(0xFF00BCD4), // cyan
  Color(0xFF3F51B5), // indigo
  Color(0xFFE91E63), // pink
  Color(0xFFCDDC39), // lime
  Color(0xFFFF5722), // deep orange
  Color(0xFF795548), // brown
  Color(0xFF607D8B), // blue grey
];

Color _colorAt(int index) => _palette[index % _palette.length];

// ════════════════════════════════════════════════════
// Helpers
// ════════════════════════════════════════════════════

/// A percentage with one decimal, spelled in [locale] ("60,0%" in it_IT).
String _pctText(double pct, String locale) => '${NumberFormat('0.0', locale).format(pct)}%';

String _pct(double value, double total, String locale) => total > 0 ? _pctText(value / total * 100, locale) : '0%';

String _fmtMoney(double value, String locale, String currency) =>
    NumberFormat.currency(locale: locale, symbol: currency, decimalDigits: 0).format(value);

// ════════════════════════════════════════════════════
// AllocationTab
// ════════════════════════════════════════════════════

class AllocationTab extends ConsumerWidget {
  const AllocationTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final assetsAsync = ref.watch(assetsProvider);
    final marketValuesAsync = ref.watch(assetMarketValuesProvider);
    final compositionsAsync = ref.watch(assetCompositionsProvider);
    final baseCurrencyAsync = ref.watch(baseCurrencyProvider);
    final stats = ref.watch(assetStatsProvider).value ?? const {};

    return assetsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(s.error(e))),
      data: (assets) => marketValuesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(s.error(e))),
        data: (marketValues) {
          final baseCurrency = baseCurrencyAsync.value ?? 'EUR';
          final active = assets.where((a) => a.isActive).toList();
          return AllocationOverviewBody(
            assets: active,
            marketValues: marketValues,
            baseCurrency: baseCurrency,
            compositions: compositionsAsync.value ?? const {},
            unvaluedCount: alloc.unvaluedAssetCount(
              active,
              marketValues,
              heldIds: {
                for (final e in stats.entries)
                  if (e.value.totalQuantity != 0) e.key,
              },
            ),
          );
        },
      ),
    );
  }
}

class AllocationOverviewBody extends ConsumerWidget {
  final List<Asset> assets;
  final Map<int, double> marketValues;
  final String baseCurrency;
  final Map<int, List<AssetComposition>> compositions;

  /// Held assets without a value (no price or exchange rate): in no chart,
  /// counted in a note above them.
  final int unvaluedCount;

  const AllocationOverviewBody({
    super.key,
    required this.assets,
    required this.marketValues,
    required this.baseCurrency,
    required this.compositions,
    this.unvaluedCount = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final locale = ref.watch(appLocaleProvider).value ?? Platform.localeName;
    // Over the holdings the slices are drawn from, so they add up to 100%.
    final total = alloc.allocationTotal(assets, marketValues);

    if (total == 0) return scrollableEmptyState(Icons.pie_chart_outline, s.noMarketValues);

    final byCountry = alloc.weightedBreakdown(
      assets,
      marketValues,
      compositions,
      'country',
      (a) => a.country ?? s.unclassified,
    );
    final bySector = alloc.weightedBreakdown(
      assets,
      marketValues,
      compositions,
      'sector',
      (a) => a.sector ?? s.unclassified,
    );
    final byHolding = alloc.weightedBreakdown(
      assets,
      marketValues,
      compositions,
      'holding',
      (a) => a.name,
    );
    final byType = alloc.groupByField(
      assets,
      marketValues,
      (a) => s.assetClassLabel(a.assetClass),
    );
    final byInstrument = alloc.groupByField(
      assets,
      marketValues,
      (a) => s.instrumentTypeLabel(a.instrumentType),
    );
    final byCurrency = alloc.groupByField(assets, marketValues, (a) => a.currency);

    final countryDrill = alloc.drillDownData(
      assets,
      marketValues,
      compositions,
      'country',
      (a) => a.country ?? s.unclassified,
    );
    final sectorDrill = alloc.drillDownData(
      assets,
      marketValues,
      compositions,
      'sector',
      (a) => a.sector ?? s.unclassified,
    );
    final typeDrill = alloc.drillDownByField(
      assets,
      marketValues,
      (a) => s.assetClassLabel(a.assetClass),
    );
    final instrumentDrill = alloc.drillDownByField(
      assets,
      marketValues,
      (a) => s.instrumentTypeLabel(a.instrumentType),
    );

    final holdingEntries = byHolding.entries.toList();
    final byPosition = alloc.groupByField(assets, marketValues, (a) => a.ticker ?? a.name);
    final positionEntries = byPosition.entries.toList();

    final cards = <Widget>[
      _ChartCard(
        title: s.allocGeographic,
        child: _DrillableDonut(data: byCountry, total: total, drillDown: countryDrill, locale: locale),
      ),
      _ChartCard(
        title: s.allocSector,
        child: _DrillableDonut(data: bySector, total: total, drillDown: sectorDrill, locale: locale),
      ),
      _ChartCard(
        title: s.allocAssetClass,
        child: _DrillableDonut(data: byType, total: total, drillDown: typeDrill, locale: locale),
      ),
      _ChartCard(
        title: s.allocInstrument,
        child: _DrillableDonut(data: byInstrument, total: total, drillDown: instrumentDrill, locale: locale),
      ),
      _ChartCard(
        title: s.allocCurrency,
        child: _DonutChart(data: byCurrency, total: total, locale: locale),
      ),
      _ChartCard(
        title: s.allocTopHoldings,
        child: _TopHoldingsInteractive(allHoldings: holdingEntries, total: total, baseCurrency: baseCurrency, locale: locale),
      ),
      _ConcentrationCard(holdings: positionEntries, total: total, baseCurrency: baseCurrency, locale: locale),
      _InvestmentCostsCard(assets: assets, marketValues: marketValues, baseCurrency: baseCurrency, locale: locale),
    ];

    return LayoutBuilder(
      builder: (ctx, constraints) {
        const cardMin = 400.0;
        const gap = 16.0;
        final cols = max(1, (constraints.maxWidth + gap) ~/ (cardMin + gap));

        final rows = <Widget>[];
        for (var i = 0; i < cards.length; i += cols) {
          final rowCards = cards.sublist(i, min(i + cols, cards.length));
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var j = 0; j < cols; j++) ...[
                  if (j > 0) const SizedBox(width: gap),
                  Expanded(child: j < rowCards.length ? rowCards[j] : const SizedBox()),
                ],
              ],
            ),
          );
          if (i + cols < cards.length) rows.add(const SizedBox(height: gap));
        }
        return MobilePullToRefresh(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (unvaluedCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Footnote(s.unpricedExcludedFromTotal(unvaluedCount)),
                  ),
                ...rows,
              ],
            ),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════
// Chart Card wrapper
// ════════════════════════════════════════════════════

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// Drillable Donut Chart
// ════════════════════════════════════════════════════

/// A donut chart where clicking a slice shows a sub-donut with the
/// breakdown of that slice (e.g. click "United States" → see which assets
/// contribute to the US allocation). Click again or press back to return.
class _DrillableDonut extends StatefulWidget {
  final Map<String, double> data;
  final double total;
  final Map<String, Map<String, double>> drillDown;
  final String locale;

  const _DrillableDonut({
    required this.data,
    required this.total,
    required this.drillDown,
    required this.locale,
  });

  @override
  State<_DrillableDonut> createState() => _DrillableDonutState();
}

class _DrillableDonutState extends State<_DrillableDonut> {
  String? _selectedSlice;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: Text('')));
    }

    // If drilled in, show the sub-breakdown
    if (_selectedSlice != null) {
      final subData = widget.drillDown[_selectedSlice];
      if (subData != null && subData.isNotEmpty) {
        final sorted = (subData.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
        final subMap = Map.fromEntries(sorted);
        final subTotal = subData.values.fold(0.0, (a, b) => a + b);

        return Column(
          children: [
            // Back button with slice name
            InkWell(
              onTap: () => setState(() => _selectedSlice = null),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '$_selectedSlice  ${_pct(subTotal, widget.total, widget.locale)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildDonut(subMap, subTotal, null),
          ],
        );
      }
    }

    // Top-level donut
    return _buildDonut(widget.data, widget.total, (sliceName) {
      if (widget.drillDown.containsKey(sliceName)) {
        setState(() => _selectedSlice = sliceName);
      }
    });
  }

  Widget _buildDonut(
    Map<String, double> data,
    double total,
    void Function(String)? onSliceTap,
  ) {
    final entries = data.entries.toList();
    return Column(
      children: [
        // Constrain the chart's hit area to the disc itself — fl_chart's
        // internal PanGestureRecognizer otherwise claims the entire
        // bounding box on touch-down (see fl_chart#1307), which can
        // hold pointer state and starve the surrounding TabBar of taps
        // on macOS (Flutter#136622-class arena bug).
        Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: ClipOval(
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 50,
                  pieTouchData: onSliceTap != null
                      ? PieTouchData(
                          touchCallback: (event, response) {
                            if (event is FlTapUpEvent && response?.touchedSection != null) {
                              final idx = response!.touchedSection!.touchedSectionIndex;
                              if (idx >= 0 && idx < entries.length) {
                                onSliceTap(entries[idx].key);
                              }
                            }
                          },
                        )
                      : null,
                  sections: List.generate(entries.length, (i) {
                    final pct = entries[i].value / total * 100;
                    return PieChartSectionData(
                      value: entries[i].value,
                      color: _colorAt(i),
                      radius: 60,
                      title: pct >= 5 ? _pctText(pct, widget.locale) : '',
                      titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (var i = 0; i < entries.length; i++)
              if (entries[i].value / total * 100 >= 0.5) ...[
                Builder(
                  builder: (_) {
                    final label = '${entries[i].key} ${_pct(entries[i].value, total, widget.locale)}';
                    final child = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 10, height: 10, color: _colorAt(i)),
                        const SizedBox(width: 4),
                        Text(label, style: const TextStyle(fontSize: 12)),
                      ],
                    );
                    if (onSliceTap != null) {
                      return InkWell(
                        onTap: () => onSliceTap(entries[i].key),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: child,
                        ),
                      );
                    }
                    return child;
                  },
                ),
              ],
          ],
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════
// Simple Donut Chart (non-drillable)
// ════════════════════════════════════════════════════

class _DonutChart extends ConsumerWidget {
  final Map<String, double> data;
  final double total;
  final String locale;

  const _DonutChart({required this.data, required this.total, required this.locale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (data.isEmpty) {
      return SizedBox(height: 200, child: Center(child: Text(ref.watch(appStringsProvider).noData)));
    }

    final entries = data.entries.toList();
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 50,
              sections: List.generate(entries.length, (i) {
                final pct = entries[i].value / total * 100;
                return PieChartSectionData(
                  value: entries[i].value,
                  color: _colorAt(i),
                  radius: 60,
                  title: pct >= 5 ? _pctText(pct, locale) : '',
                  titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (var i = 0; i < entries.length; i++)
              if (entries[i].value / total * 100 >= 0.5)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, color: _colorAt(i)),
                    const SizedBox(width: 4),
                    Text('${entries[i].key} ${_pct(entries[i].value, total, locale)}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
          ],
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════
// Top Holdings — Interactive horizontal bars
// ════════════════════════════════════════════════════

class _TopHoldingsInteractive extends ConsumerStatefulWidget {
  final List<MapEntry<String, double>> allHoldings;
  final double total;
  final String baseCurrency;
  final String locale;

  static const _displayCount = 5;

  const _TopHoldingsInteractive({
    required this.allHoldings,
    required this.total,
    required this.baseCurrency,
    required this.locale,
  });

  @override
  ConsumerState<_TopHoldingsInteractive> createState() => _TopHoldingsInteractiveState();
}

class _TopHoldingsInteractiveState extends ConsumerState<_TopHoldingsInteractive> {
  final _hidden = <String>{};

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final isPrivate = ref.watch(privacyModeProvider);
    final theme = Theme.of(context);

    if (widget.allHoldings.isEmpty) {
      return SizedBox(height: 100, child: Center(child: Text(s.noData)));
    }

    // Filter out hidden, take displayCount
    final visible = widget.allHoldings.where((e) => !_hidden.contains(e.key)).take(_TopHoldingsInteractive._displayCount).toList();
    final visibleTotal = visible.fold(0.0, (s, e) => s + e.value);
    final maxValue = visible.isEmpty ? 1.0 : visible.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          _buildBar(visible[i], i, maxValue, visibleTotal, theme, isPrivate),
          if (i < visible.length - 1) const SizedBox(height: 6),
        ],
        if (_hidden.isNotEmpty) ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: () => setState(() => _hidden.clear()),
            child: Text(
              '${s.showComponents} (${_hidden.length})',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBar(MapEntry<String, double> entry, int index, double maxValue, double visibleTotal, ThemeData theme, bool isPrivate) {
    final pct = visibleTotal > 0 ? entry.value / visibleTotal * 100 : 0.0;
    final barFraction = maxValue > 0 ? entry.value / maxValue : 0.0;
    final color = _colorAt(index);
    final amtStr = _fmtMoney(entry.value, widget.locale, widget.baseCurrency);

    return InkWell(
      onTap: () => setState(() => _hidden.add(entry.key)),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _pctText(pct, widget.locale),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                ),
                if (!isPrivate) ...[
                  const SizedBox(width: 8),
                  Text(amtStr, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                ],
              ],
            ),
            const SizedBox(height: 3),
            LayoutBuilder(
              builder: (ctx, constraints) {
                return Container(
                  height: 14,
                  width: constraints.maxWidth * barFraction,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// Concentration Card
// ════════════════════════════════════════════════════

class _ConcentrationCard extends ConsumerWidget {
  final List<MapEntry<String, double>> holdings;
  final double total;
  final String baseCurrency;
  final String locale;

  const _ConcentrationCard({
    required this.holdings,
    required this.total,
    required this.baseCurrency,
    required this.locale,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sl = ref.watch(appStringsProvider);
    final count = holdings.length;
    final conc = alloc.computeConcentration(holdings, total);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(sl.concentrationRisk, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _metricRow(sl.allocPortfolioVal, _fmtMoney(total, locale, baseCurrency), positionSize: true),
            _metricRow(sl.allocHoldings, '$count'),
            const Divider(),
            _metricRow(sl.top1, '${_pctText(conc.top1, locale)}${count >= 1 ? '  (${holdings[0].key})' : ''}'),
            _metricRow(sl.top3, _pctText(conc.top3, locale)),
            _metricRow(sl.top5, _pctText(conc.top5, locale)),
            const Divider(),
            _metricRow(sl.hhiLabel, NumberFormat('0', locale).format(conc.hhi)),
            Text(
              conc.classification == 'diversified'
                  ? sl.allocWellDiversified
                  : conc.classification == 'moderate'
                  ? sl.allocModeratelyConcentrated
                  : sl.allocHighlyConcentrated,
              style: TextStyle(
                fontSize: 12,
                color: conc.classification == 'diversified'
                    ? Colors.green
                    : conc.classification == 'moderate'
                    ? Colors.orange
                    : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// [positionSize] values are masked in privacy mode; counts, weights and
  /// the HHI are shape and stay readable.
  Widget _metricRow(String label, String value, {bool positionSize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          PrivacyText(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            masked: positionSize,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// Investment Costs Table
// ════════════════════════════════════════════════════

class _InvestmentCostsCard extends ConsumerWidget {
  final List<Asset> assets;
  final Map<int, double> marketValues;
  final String baseCurrency;
  final String locale;

  const _InvestmentCostsCard({
    required this.assets,
    required this.marketValues,
    required this.baseCurrency,
    required this.locale,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final symbol = currencySymbol(baseCurrency);
    final amtFmt = NumberFormat.currency(locale: locale, symbol: symbol, decimalDigits: 0);
    final pctFmt = NumberFormat('0.00', locale);
    final theme = Theme.of(context);

    final rows = <({String name, String fullName, double? ter, double mv, double cost})>[];
    double totalValue = 0;

    for (final asset in assets) {
      // Same holdings as the charts: an unvalued asset is counted in the note
      // above them, a liability has no running cost.
      final mv = marketValues[asset.id];
      if (mv == null || mv <= 0) continue;
      totalValue += mv;
      final cost = (asset.ter != null && asset.ter! > 0) ? mv * asset.ter! / 100 : 0.0;
      rows.add((name: asset.ticker ?? asset.name, fullName: asset.name, ter: asset.ter, mv: mv, cost: cost));
    }
    rows.sort((a, b) => b.cost.compareTo(a.cost));
    // Funds without a TER on record are left out of the weighted TER instead
    // of counting as free, and counted in a note below the total.
    final weighted = alloc.computeWeightedTer(assets, marketValues);
    final weightedTer = weighted.ter;

    // The rating's own colour: a TER reads the same colour here as on the
    // Health tab.
    Color terColor(double ter) => rateTer(ter).color;

    final hs = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant);
    final vs = theme.textTheme.bodySmall?.copyWith(fontSize: 13);

    // Values and costs are position size (PrivacyText masks them in privacy
    // mode); TERs are percentages and stay readable.
    return SizedBox(
      width: 960,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.healthInvestmentCosts, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                Text(s.healthNoTer, style: const TextStyle(color: Colors.grey))
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(flex: 4, child: Text(s.healthAsset, style: hs)),
                      Expanded(
                        flex: 2,
                        child: Text(s.healthTer, style: hs, textAlign: TextAlign.right),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(s.healthMarketValue, style: hs, textAlign: TextAlign.right),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(s.healthAnnualCost, style: hs, textAlign: TextAlign.right),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Tooltip(
                            message: row.fullName,
                            child: Text(row.name, style: vs, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            row.ter != null ? '${pctFmt.format(row.ter)}%' : '-',
                            style: vs?.copyWith(color: row.ter != null ? terColor(row.ter!) : Colors.grey),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: PrivacyText(amtFmt.format(row.mv), style: vs, textAlign: TextAlign.right),
                        ),
                        Expanded(
                          flex: 3,
                          child: PrivacyText(
                            row.ter != null ? amtFmt.format(row.cost) : '-',
                            style: vs?.copyWith(color: row.ter != null ? Colors.red.shade300 : Colors.grey),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 16, thickness: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(s.healthWeightedTer, style: vs?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          weightedTer == null ? '-' : '${pctFmt.format(weightedTer)}%',
                          style: vs?.copyWith(fontWeight: FontWeight.bold, color: weightedTer == null ? Colors.grey : terColor(weightedTer)),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: PrivacyText(
                          amtFmt.format(totalValue),
                          style: vs?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: PrivacyText(
                          amtFmt.format(weighted.annualCost),
                          style: vs?.copyWith(fontWeight: FontWeight.bold, color: Colors.red.shade400),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
                if (weighted.unknownTerFunds > 0) Footnote(s.terUnknownExcluded(weighted.unknownTerFunds)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
