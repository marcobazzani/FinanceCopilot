import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/privacy_text.dart';

import '../../database/database.dart';
import '../../database/tables.dart';
import '../../services/providers.dart';
import 'package:intl/intl.dart';

// ════════════════════════════════════════════════════
// Asset type display names
// ════════════════════════════════════════════════════

const _assetTypeLabels = <AssetType, String>{
  AssetType.stock: 'Stock',
  AssetType.stockEtf: 'Stock ETF',
  AssetType.bondEtf: 'Bond ETF',
  AssetType.commEtf: 'Commodity ETF',
  AssetType.goldEtc: 'Gold ETC',
  AssetType.monEtf: 'Money Market ETF',
  AssetType.crypto: 'Crypto',
  AssetType.cash: 'Cash',
  AssetType.pension: 'Pension',
  AssetType.deposit: 'Deposit',
  AssetType.realEstate: 'Real Estate',
  AssetType.alternative: 'Alternative',
  AssetType.liability: 'Liability',
};

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

/// Groups assets by a field, sums market values, returns sorted descending map.
Map<String, double> _groupByField(
  List<Asset> assets,
  Map<int, double> values,
  String Function(Asset) keyFn,
) {
  final map = <String, double>{};
  for (final asset in assets) {
    final val = values[asset.id];
    if (val == null || val == 0) continue;
    final key = keyFn(asset);
    map[key] = (map[key] ?? 0) + val;
  }
  final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return Map.fromEntries(sorted);
}

String _pct(double value, double total) =>
    total > 0 ? '${(value / total * 100).toStringAsFixed(1)}%' : '0%';

String _fmtMoney(double value, String locale, String currency) =>
    NumberFormat.currency(locale: locale, symbol: currency, decimalDigits: 0).format(value);

/// Compute weighted breakdown using composition data.
Map<String, double> _weightedBreakdown(
  List<Asset> assets,
  Map<int, double> marketValues,
  Map<int, List<AssetComposition>> compositions,
  String compositionType,
  String Function(Asset) fallback,
) {
  final result = <String, double>{};
  for (final asset in assets) {
    final mv = marketValues[asset.id] ?? 0;
    if (mv <= 0) continue;

    final comps = compositions[asset.id]
        ?.where((c) => c.type == compositionType)
        .toList();

    if (comps != null && comps.isNotEmpty) {
      for (final c in comps) {
        result[c.name] = (result[c.name] ?? 0) + mv * c.weight / 100;
      }
    } else {
      final key = fallback(asset);
      result[key] = (result[key] ?? 0) + mv;
    }
  }
  final sorted = result.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return Map.fromEntries(sorted);
}

/// Compute drill-down data: for each key in the breakdown, which assets contribute.
/// Returns Map<sliceKey, Map<assetName, value>>.
Map<String, Map<String, double>> _drillDownData(
  List<Asset> assets,
  Map<int, double> marketValues,
  Map<int, List<AssetComposition>> compositions,
  String compositionType,
  String Function(Asset) fallback,
) {
  final result = <String, Map<String, double>>{};
  for (final asset in assets) {
    final mv = marketValues[asset.id] ?? 0;
    if (mv <= 0) continue;

    final comps = compositions[asset.id]
        ?.where((c) => c.type == compositionType)
        .toList();

    if (comps != null && comps.isNotEmpty) {
      for (final c in comps) {
        final contribution = mv * c.weight / 100;
        result.putIfAbsent(c.name, () => {});
        result[c.name]![asset.name] = (result[c.name]![asset.name] ?? 0) + contribution;
      }
    } else {
      final key = fallback(asset);
      result.putIfAbsent(key, () => {});
      result[key]![asset.name] = (result[key]![asset.name] ?? 0) + mv;
    }
  }
  return result;
}

// ════════════════════════════════════════════════════
// AllocationTab
// ════════════════════════════════════════════════════

class AllocationTab extends ConsumerWidget {
  const AllocationTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsAsync = ref.watch(assetsProvider);
    final marketValuesAsync = ref.watch(assetMarketValuesProvider);
    final compositionsAsync = ref.watch(assetCompositionsProvider);
    final baseCurrencyAsync = ref.watch(baseCurrencyProvider);

    return assetsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (assets) => marketValuesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (marketValues) {
          final compositions = compositionsAsync.value ?? {};
          final baseCurrency = baseCurrencyAsync.value ?? 'EUR';
          final locale = ref.watch(appLocaleProvider).value ?? 'en_US';
          final total = marketValues.values.fold(0.0, (a, b) => a + b);

          if (total == 0) {
            return const Center(
              child: Text('No market values available.',
                  style: TextStyle(color: Colors.grey)),
            );
          }

          // Weighted breakdowns
          final byCountry = _weightedBreakdown(
            assets, marketValues, compositions, 'country',
            (a) => a.country ?? 'Unclassified',
          );
          final bySector = _weightedBreakdown(
            assets, marketValues, compositions, 'sector',
            (a) => a.sector ?? 'Unclassified',
          );
          final byHolding = _weightedBreakdown(
            assets, marketValues, compositions, 'holding',
            (a) => a.name,
          );
          final byType = _weightedBreakdown(
            assets, marketValues, compositions, 'assetclass',
            (a) => _assetTypeLabels[a.assetType] ?? a.assetType.name,
          );
          final byCurrency = _groupByField(assets, marketValues, (a) => a.currency);

          // Drill-down data for clickable charts
          final countryDrill = _drillDownData(
            assets, marketValues, compositions, 'country',
            (a) => a.country ?? 'Unclassified',
          );
          final sectorDrill = _drillDownData(
            assets, marketValues, compositions, 'sector',
            (a) => a.sector ?? 'Unclassified',
          );
          final typeDrill = _drillDownData(
            assets, marketValues, compositions, 'assetclass',
            (a) => _assetTypeLabels[a.assetType] ?? a.assetType.name,
          );

          final holdingEntries = byHolding.entries.toList();
          final topHoldings = holdingEntries.take(10).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _ChartCard(
                  title: 'Geographic Allocation',
                  child: _DrillableDonut(
                    data: byCountry,
                    total: total,
                    drillDown: countryDrill,
                  ),
                ),
                _ChartCard(
                  title: 'Sector Allocation',
                  child: _DrillableDonut(
                    data: bySector,
                    total: total,
                    drillDown: sectorDrill,
                  ),
                ),
                _ChartCard(
                  title: 'Asset Type',
                  child: _DrillableDonut(
                    data: byType,
                    total: total,
                    drillDown: typeDrill,
                  ),
                ),
                _ChartCard(
                  title: 'Currency Exposure',
                  child: _DonutChart(data: byCurrency, total: total),
                ),
                _ChartCard(
                  title: 'Top Holdings',
                  child: _TopHoldingsChart(
                    holdings: topHoldings,
                    total: total,
                    baseCurrency: baseCurrency,
                    locale: locale,
                  ),
                ),
                _ConcentrationCard(
                  holdings: holdingEntries,
                  total: total,
                  baseCurrency: baseCurrency,
                  locale: locale,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// Chart Card wrapper
// ════════════════════════════════════════════════════

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  final double width;

  const _ChartCard({required this.title, required this.child, this.width = 480});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
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

  const _DrillableDonut({
    required this.data,
    required this.total,
    required this.drillDown,
  });

  @override
  State<_DrillableDonut> createState() => _DrillableDonutState();
}

class _DrillableDonutState extends State<_DrillableDonut> {
  String? _selectedSlice;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: Text('No data')));
    }

    // If drilled in, show the sub-breakdown
    if (_selectedSlice != null) {
      final subData = widget.drillDown[_selectedSlice];
      if (subData != null && subData.isNotEmpty) {
        final sorted = (subData.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)));
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
                      '$_selectedSlice  ${_pct(subTotal, widget.total)}',
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
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 50,
              pieTouchData: onSliceTap != null
                  ? PieTouchData(
                      touchCallback: (event, response) {
                        if (event is FlTapUpEvent &&
                            response?.touchedSection != null) {
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
                  title: pct >= 5 ? '${pct.toStringAsFixed(1)}%' : '',
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
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: List.generate(entries.length, (i) {
            final label = '${entries[i].key} ${_pct(entries[i].value, total)}';
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
          }),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════
// Simple Donut Chart (non-drillable)
// ════════════════════════════════════════════════════

class _DonutChart extends StatelessWidget {
  final Map<String, double> data;
  final double total;

  const _DonutChart({required this.data, required this.total});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: Text('No data')));
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
                  title: pct >= 5 ? '${pct.toStringAsFixed(1)}%' : '',
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
          children: List.generate(entries.length, (i) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, color: _colorAt(i)),
                const SizedBox(width: 4),
                Text('${entries[i].key} ${_pct(entries[i].value, total)}',
                    style: const TextStyle(fontSize: 12)),
              ],
            );
          }),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════
// Top Holdings Bar Chart
// ════════════════════════════════════════════════════

class _TopHoldingsChart extends StatelessWidget {
  final List<MapEntry<String, double>> holdings;
  final double total;
  final String baseCurrency;
  final String locale;

  const _TopHoldingsChart({
    required this.holdings,
    required this.total,
    required this.baseCurrency,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    if (holdings.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: Text('No data')));
    }

    final reversed = holdings.reversed.toList();
    final maxValue = holdings.first.value;

    return SizedBox(
      height: max(200, holdings.length * 36.0),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxValue * 1.15,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final entry = reversed[group.x.toInt()];
                return BarTooltipItem(
                  '${entry.key}\n${_fmtMoney(entry.value, locale, baseCurrency)} (${_pct(entry.value, total)})',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 100,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= reversed.length) return const SizedBox();
                  final name = reversed[idx].key;
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      name.length > 14 ? '${name.substring(0, 12)}…' : name,
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barGroups: List.generate(reversed.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: reversed[i].value,
                  color: _colorAt(reversed.length - 1 - i),
                  width: 18,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                ),
              ],
            );
          }),
        ),
        duration: const Duration(milliseconds: 300),
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
    final isPrivate = ref.watch(privacyModeProvider);
    final count = holdings.length;
    final top1 = count >= 1 ? holdings[0].value / total * 100 : 0.0;
    final top3 = count >= 3
        ? holdings.take(3).fold(0.0, (a, b) => a + b.value) / total * 100
        : (count > 0 ? holdings.fold(0.0, (a, b) => a + b.value) / total * 100 : 0.0);
    final top5 = count >= 5
        ? holdings.take(5).fold(0.0, (a, b) => a + b.value) / total * 100
        : (count > 0 ? holdings.fold(0.0, (a, b) => a + b.value) / total * 100 : 0.0);

    // Herfindahl-Hirschman Index
    final hhi = total > 0
        ? holdings.fold(0.0, (sum, e) => sum + pow(e.value / total, 2)) * 10000
        : 0.0;

    return SizedBox(
      width: 480,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Concentration Risk', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _metricRow('Portfolio Value', _fmtMoney(total, locale, baseCurrency), blur: isPrivate),
              _metricRow('Holdings', '$count'),
              const Divider(),
              _metricRow('Top 1', '${top1.toStringAsFixed(1)}%${count >= 1 ? '  (${holdings[0].key})' : ''}'),
              _metricRow('Top 3', '${top3.toStringAsFixed(1)}%'),
              _metricRow('Top 5', '${top5.toStringAsFixed(1)}%'),
              const Divider(),
              _metricRow('HHI', hhi.toStringAsFixed(0)),
              Text(
                hhi < 1500 ? 'Well diversified' : hhi < 2500 ? 'Moderately concentrated' : 'Highly concentrated',
                style: TextStyle(
                  fontSize: 12,
                  color: hhi < 1500 ? Colors.green : hhi < 2500 ? Colors.orange : Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricRow(String label, String value, {bool blur = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          blur
              ? PrivacyText(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))
              : Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
