import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:drift/drift.dart' show OrderingTerm;

import '../../database/database.dart';
import '../../database/providers.dart';
import '../../services/providers.dart';
import '../../utils/logger.dart';

final _log = getLogger('DashboardScreen');

/// Per-account daily balance series + total.
class _ChartData {
  final DateTime firstDate;
  final List<_AccountSeries> accounts;
  final List<FlSpot> totalSpots;
  final double currentTotal;
  final String baseCurrency;

  const _ChartData({
    required this.firstDate,
    required this.accounts,
    required this.totalSpots,
    required this.currentTotal,
    required this.baseCurrency,
  });
}

class _AccountSeries {
  final String name;
  final Color color;
  final List<FlSpot> spots;
  const _AccountSeries({required this.name, required this.color, required this.spots});
}

final _chartColors = [
  Colors.blue,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.teal,
  Colors.red,
  Colors.amber,
  Colors.cyan,
];

/// Currency symbol lookup for display.
String currencySymbol(String code) {
  return switch (code) {
    'EUR' => '€',
    'USD' => '\$',
    'GBP' => '£',
    'JPY' => '¥',
    'CHF' => 'CHF',
    _ => code,
  };
}

/// Provider that fetches daily balance per active account, converted to base currency.
final _chartDataProvider = FutureProvider<_ChartData?>((ref) async {
  final db = ref.watch(databaseProvider);
  final baseCurrency = await ref.watch(baseCurrencyProvider.future);
  final rateService = ref.watch(exchangeRateServiceProvider);

  // Get active accounts
  final activeAccounts = await (db.select(db.accounts)
        ..where((a) => a.isActive.equals(true))
        ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
      .get();
  if (activeAccounts.isEmpty) return null;
  final activeIds = activeAccounts.map((a) => a.id).toSet();

  // Fetch all transactions for active accounts
  final rows = await db.customSelect(
    'SELECT account_id, operation_date, balance_after '
    'FROM transactions '
    'WHERE account_id IN (${activeIds.join(",")}) '
    'AND balance_after IS NOT NULL '
    'ORDER BY operation_date ASC, id ASC',
  ).get();

  if (rows.isEmpty) return null;

  // Build per-account daily balance series
  final perAccount = <int, Map<int, double>>{}; // accountId -> {dayKey -> balance}
  final allDayKeys = <int>{};

  for (final row in rows) {
    final accountId = row.read<int>('account_id');
    final epochSec = row.read<int>('operation_date');
    final balance = row.read<double>('balance_after');

    final dt = DateTime.fromMillisecondsSinceEpoch(epochSec * 1000);
    final dayKey = DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch ~/ 1000;

    perAccount.putIfAbsent(accountId, () => {});
    perAccount[accountId]![dayKey] = balance;
    allDayKeys.add(dayKey);
  }

  final sortedDays = allDayKeys.toList()..sort();
  final firstDate = DateTime.fromMillisecondsSinceEpoch(sortedDays.first * 1000);

  // Rate cache to avoid redundant DB lookups
  final rateCache = <String, double>{};
  Future<double> getCachedRate(String from, int dayKey) async {
    if (from == baseCurrency) return 1.0;
    final key = '$from:$dayKey';
    if (rateCache.containsKey(key)) return rateCache[key]!;
    final date = DateTime.fromMillisecondsSinceEpoch(dayKey * 1000);
    final rate = await rateService.getRate(from, baseCurrency, date);
    rateCache[key] = rate ?? 1.0;
    return rate ?? 1.0;
  }

  // Build FlSpot series per account (carry forward, convert to base currency)
  final accountSeries = <_AccountSeries>[];
  var colorIdx = 0;

  for (final account in activeAccounts) {
    if (!perAccount.containsKey(account.id)) continue;

    final dayMap = perAccount[account.id]!;
    final spots = <FlSpot>[];
    double? running;

    for (final dayKey in sortedDays) {
      if (dayMap.containsKey(dayKey)) {
        running = dayMap[dayKey];
      }
      if (running != null) {
        final rate = await getCachedRate(account.currency, dayKey);
        final dt = DateTime.fromMillisecondsSinceEpoch(dayKey * 1000);
        final x = dt.difference(firstDate).inDays.toDouble();
        spots.add(FlSpot(x, running * rate));
      }
    }

    accountSeries.add(_AccountSeries(
      name: account.name,
      color: _chartColors[colorIdx % _chartColors.length],
      spots: spots,
    ));
    colorIdx++;
  }

  // Build total line: sum of all accounts' converted balance at each day
  final runningConverted = <int, double>{}; // accountId -> last converted balance
  final totalByDay = <int, double>{};
  for (final dayKey in sortedDays) {
    for (final account in activeAccounts) {
      if (perAccount.containsKey(account.id) &&
          perAccount[account.id]!.containsKey(dayKey)) {
        final rate = await getCachedRate(account.currency, dayKey);
        runningConverted[account.id] = perAccount[account.id]![dayKey]! * rate;
      }
    }
    double total = 0;
    for (final v in runningConverted.values) {
      total += v;
    }
    totalByDay[dayKey] = total;
  }

  final totalSpots = sortedDays.map((dayKey) {
    final dt = DateTime.fromMillisecondsSinceEpoch(dayKey * 1000);
    final x = dt.difference(firstDate).inDays.toDouble();
    return FlSpot(x, totalByDay[dayKey]!);
  }).toList();

  final currentTotal = totalSpots.isNotEmpty ? totalSpots.last.y : 0.0;

  return _ChartData(
    firstDate: firstDate,
    accounts: accountSeries,
    totalSpots: totalSpots,
    currentTotal: currentTotal,
    baseCurrency: baseCurrency,
  );
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartAsync = ref.watch(_chartDataProvider);

    return chartAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (data) {
        if (data == null) {
          return const Center(
            child: Text('No balance data yet. Import transactions to get started.',
                style: TextStyle(color: Colors.grey)),
          );
        }
        final symbol = currencySymbol(data.baseCurrency);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Balance',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                NumberFormat.currency(locale: 'it_IT', symbol: symbol)
                    .format(data.currentTotal),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              // Legend
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  for (final s in data.accounts)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 12, height: 3, color: s.color),
                        const SizedBox(width: 4),
                        Text(s.name, style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 12, height: 3, color: Colors.white),
                      const SizedBox(width: 4),
                      const Text('Total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(child: _BalanceChart(data: data)),
            ],
          ),
        );
      },
    );
  }
}

class _BalanceChart extends StatelessWidget {
  final _ChartData data;
  const _BalanceChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gridColor = isDark ? Colors.white12 : Colors.black12;
    final textColor = isDark ? Colors.white54 : Colors.black54;
    final symbol = currencySymbol(data.baseCurrency);

    // Compute Y range from total line
    final allY = data.totalSpots.map((s) => s.y);
    final minY = allY.reduce(min);
    final maxY = allY.reduce(max);
    final yRange = maxY - minY;
    final chartMinY = yRange > 0 ? minY - yRange * 0.05 : minY - 100;
    final chartMaxY = yRange > 0 ? maxY + yRange * 0.05 : maxY + 100;

    final totalDays = data.totalSpots.isNotEmpty ? data.totalSpots.last.x : 1.0;
    final dateFmt = DateFormat('MMM yyyy');
    final fullFmt = DateFormat('dd MMM yyyy');
    final currFmt = NumberFormat.currency(locale: 'it_IT', symbol: symbol, decimalDigits: 0);

    // Build line bars: total FIRST (background), then per-account on top
    final lineBars = <LineChartBarData>[];

    // Total line first (drawn behind account lines)
    lineBars.add(LineChartBarData(
      spots: data.totalSpots,
      isCurved: true,
      preventCurveOverShooting: true,
      curveSmoothness: 0.15,
      color: isDark ? Colors.white : theme.colorScheme.primary,
      barWidth: 2.5,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: (isDark ? Colors.white : theme.colorScheme.primary)
            .withValues(alpha: 0.08),
      ),
    ));

    // Account lines on top
    for (final s in data.accounts) {
      lineBars.add(LineChartBarData(
        spots: s.spots,
        isCurved: true,
        preventCurveOverShooting: true,
        curveSmoothness: 0.15,
        color: s.color,
        barWidth: 2,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }

    return LineChart(
      LineChartData(
        minY: chartMinY,
        maxY: chartMaxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yRange > 0 ? yRange / 4 : 100,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: gridColor, strokeWidth: 0.5),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: totalDays > 0 ? totalDays / 5 : 1,
              getTitlesWidget: (value, meta) {
                final date = data.firstDate.add(Duration(days: value.toInt()));
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(dateFmt.format(date),
                      style: TextStyle(fontSize: 10, color: textColor)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              interval: yRange > 0 ? yRange / 4 : 100,
              getTitlesWidget: (value, meta) {
                return Text(currFmt.format(value),
                    style: TextStyle(fontSize: 10, color: textColor));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final barIndex = spot.barIndex;
                final isTotal = barIndex == 0; // Total is first line
                final accountIdx = barIndex - 1;
                final label = isTotal ? 'Total' : data.accounts[accountIdx].name;
                final date = data.firstDate.add(Duration(days: spot.x.toInt()));
                if (isTotal) {
                  return LineTooltipItem(
                    '${fullFmt.format(date)}\n$label: ${currFmt.format(spot.y)}',
                    const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  );
                }
                return LineTooltipItem(
                  '$label: ${currFmt.format(spot.y)}',
                  TextStyle(
                    color: data.accounts[accountIdx].color,
                    fontSize: 11,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: lineBars,
      ),
    );
  }
}
