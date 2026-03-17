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

/// Unified series for accounts, assets, and CAPEX.
class _Series {
  final String key; // unique id for toggling: "a:3" (account), "s:7" (asset), "c:1" (capex)
  final String name;
  final Color color;
  final List<FlSpot> spots;
  final bool isAsset;
  final bool isCapex;
  const _Series({
    required this.key,
    required this.name,
    required this.color,
    required this.spots,
    this.isAsset = false,
    this.isCapex = false,
  });
}

/// All chart data: account series, asset series, CAPEX series.
class _ChartData {
  final DateTime firstDate;
  final List<_Series> accounts;
  final List<_Series> assets;
  final List<_Series> capex;
  final String baseCurrency;

  const _ChartData({
    required this.firstDate,
    required this.accounts,
    required this.assets,
    required this.capex,
    required this.baseCurrency,
  });

  List<_Series> get allSeries => [...accounts, ...assets, ...capex];
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

/// Provider that fetches daily balance per active account + cumulative asset
/// invested value, all converted to base currency.
final _chartDataProvider = FutureProvider<_ChartData?>((ref) async {
  final db = ref.watch(databaseProvider);
  final baseCurrency = await ref.watch(baseCurrencyProvider.future);
  final rateService = ref.watch(exchangeRateServiceProvider);

  // Watch reactive streams so we rebuild when data changes
  ref.watch(accountsProvider);
  ref.watch(accountStatsProvider);
  ref.watch(assetsProvider);
  ref.watch(assetStatsProvider);
  ref.watch(capexSchedulesProvider);

  // ── Shared helpers ──
  final allDayKeys = <int>{};

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

  int toDayKey(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch ~/ 1000;

  // ════════════════════════════════════════════════
  // 1. ACCOUNTS — daily balance from transactions
  // ════════════════════════════════════════════════
  final activeAccounts = await (db.select(db.accounts)
        ..where((a) => a.isActive.equals(true))
        ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
      .get();
  final activeIds = activeAccounts.map((a) => a.id).toSet();

  final perAccount = <int, Map<int, double>>{};
  if (activeIds.isNotEmpty) {
    final rows = await db.customSelect(
      'SELECT account_id, operation_date, balance_after '
      'FROM transactions '
      'WHERE account_id IN (${activeIds.join(",")}) '
      'AND balance_after IS NOT NULL '
      'ORDER BY operation_date ASC, id ASC',
    ).get();

    for (final row in rows) {
      final accountId = row.read<int>('account_id');
      final epochSec = row.read<int>('operation_date');
      final balance = row.read<double>('balance_after');
      final dt = DateTime.fromMillisecondsSinceEpoch(epochSec * 1000);
      final dayKey = toDayKey(dt);
      perAccount.putIfAbsent(accountId, () => {});
      perAccount[accountId]![dayKey] = balance;
      allDayKeys.add(dayKey);
    }
  }

  // ════════════════════════════════════════════════
  // 2. ASSETS — cumulative invested value from events
  // ════════════════════════════════════════════════
  final activeAssets = await (db.select(db.assets)
        ..where((a) => a.isActive.equals(true))
        ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
      .get();
  final assetIds = activeAssets.map((a) => a.id).toSet();

  final perAssetDeltas = <int, Map<int, double>>{};

  if (assetIds.isNotEmpty) {
    final evRows = await db.customSelect(
      'SELECT asset_id, date, type, amount, currency, exchange_rate '
      'FROM asset_events '
      'WHERE asset_id IN (${assetIds.join(",")}) '
      'ORDER BY date ASC',
    ).get();

    for (final row in evRows) {
      final assetId = row.read<int>('asset_id');
      final epochSec = row.read<int>('date');
      final type = row.read<String>('type');
      final amount = row.read<double>('amount');
      final currency = row.read<String>('currency');
      final storedRate = row.readNullable<double>('exchange_rate');

      double sign;
      if (type == 'buy' || type == 'contribute') {
        sign = 1.0;
      } else if (type == 'sell') {
        sign = -1.0;
      } else {
        continue;
      }

      final dt = DateTime.fromMillisecondsSinceEpoch(epochSec * 1000);
      final dayKey = toDayKey(dt);

      double baseAmount;
      if (currency == baseCurrency) {
        baseAmount = amount.abs();
      } else if (storedRate != null && storedRate > 0) {
        baseAmount = amount.abs() / storedRate;
      } else {
        final rate = await getCachedRate(currency, dayKey);
        baseAmount = amount.abs() * rate;
      }

      perAssetDeltas.putIfAbsent(assetId, () => {});
      perAssetDeltas[assetId]![dayKey] =
          (perAssetDeltas[assetId]![dayKey] ?? 0) + sign * baseAmount;
      allDayKeys.add(dayKey);
    }
  }

  if (allDayKeys.isEmpty) return null;

  final sortedDays = allDayKeys.toList()..sort();
  final firstDate = DateTime.fromMillisecondsSinceEpoch(sortedDays.first * 1000);

  // ── Build account series ──
  final accountSeries = <_Series>[];
  var colorIdx = 0;

  for (final account in activeAccounts) {
    if (!perAccount.containsKey(account.id)) continue;
    final dayMap = perAccount[account.id]!;
    final spots = <FlSpot>[];
    double? running;

    for (final dayKey in sortedDays) {
      if (dayMap.containsKey(dayKey)) running = dayMap[dayKey];
      if (running != null) {
        final rate = await getCachedRate(account.currency, dayKey);
        final dt = DateTime.fromMillisecondsSinceEpoch(dayKey * 1000);
        final x = dt.difference(firstDate).inDays.toDouble();
        spots.add(FlSpot(x, running * rate));
      }
    }

    accountSeries.add(_Series(
      key: 'a:${account.id}',
      name: account.name,
      color: _chartColors[colorIdx % _chartColors.length],
      spots: spots,
    ));
    colorIdx++;
  }

  // ── Build asset series (cumulative) ──
  final assetSeries = <_Series>[];

  for (final asset in activeAssets) {
    if (!perAssetDeltas.containsKey(asset.id)) continue;
    final deltaMap = perAssetDeltas[asset.id]!;
    final spots = <FlSpot>[];
    var cumulative = 0.0;
    var started = false;

    for (final dayKey in sortedDays) {
      if (deltaMap.containsKey(dayKey)) {
        cumulative += deltaMap[dayKey]!;
        started = true;
      }
      if (started) {
        final dt = DateTime.fromMillisecondsSinceEpoch(dayKey * 1000);
        final x = dt.difference(firstDate).inDays.toDouble();
        spots.add(FlSpot(x, cumulative));
      }
    }

    assetSeries.add(_Series(
      key: 's:${asset.id}',
      name: asset.name,
      color: _chartColors[colorIdx % _chartColors.length],
      spots: spots,
      isAsset: true,
    ));
    colorIdx++;
  }

  // ════════════════════════════════════════════════
  // 3. CAPEX — re-add at expense date, remove during spread steps
  //    At expenseDate: +totalAmount (neutralizes the bank dip)
  //    At each entry date: −stepAmount (gradually spread)
  //    At each reimbursement: −reimbursement (someone else paid back)
  // ════════════════════════════════════════════════
  final activeSchedules = await (db.select(db.depreciationSchedules)
        ..where((s) => s.isActive.equals(true)))
      .get();

  final capexSeries = <_Series>[];

  for (final schedule in activeSchedules) {
    final entries = await (db.select(db.depreciationEntries)
          ..where((e) => e.scheduleId.equals(schedule.id))
          ..orderBy([(e) => OrderingTerm.asc(e.date)]))
        .get();

    // Build delta map: dayKey → amount change
    final deltaMap = <int, double>{};

    // 1. At expense date: re-add the full amount
    if (schedule.expenseDate != null) {
      final expDayKey = toDayKey(schedule.expenseDate!);
      deltaMap[expDayKey] = (deltaMap[expDayKey] ?? 0) + schedule.totalAmount;
      allDayKeys.add(expDayKey);
    }

    // 2. At each spread step: remove the step amount
    for (final entry in entries) {
      final dayKey = toDayKey(entry.date);
      deltaMap[dayKey] = (deltaMap[dayKey] ?? 0) - entry.amount;
      allDayKeys.add(dayKey);
    }

    // 3. Reimbursements: reduce the CAPEX adjustment
    if (schedule.bufferId != null) {
      final reimbursements = await (db.select(db.bufferTransactions)
            ..where((t) => t.bufferId.equals(schedule.bufferId!))
            ..where((t) => t.isReimbursement.equals(true)))
          .get();
      for (final r in reimbursements) {
        final dayKey = toDayKey(r.operationDate);
        deltaMap[dayKey] = (deltaMap[dayKey] ?? 0) - r.amount.abs();
        allDayKeys.add(dayKey);
      }
    }

    if (deltaMap.isEmpty) continue;

    // Walk sorted days, accumulate, build spots.
    // Insert "hold" points before jumps so the line stays flat
    // (step-like) instead of drawing diagonals across gaps.
    final capexDays = deltaMap.keys.toList()..sort();
    final spots = <FlSpot>[];
    var cumulative = 0.0;
    double? prevY;

    for (final dayKey in capexDays) {
      final rate = await getCachedRate(schedule.currency, dayKey);
      final dt = DateTime.fromMillisecondsSinceEpoch(dayKey * 1000);
      final x = dt.difference(firstDate).inDays.toDouble();
      // Hold previous value just before this point to avoid diagonal
      if (prevY != null && x > (spots.last.x + 1)) {
        spots.add(FlSpot(x - 0.5, prevY));
      }
      cumulative += deltaMap[dayKey]!;
      final y = cumulative * rate;
      spots.add(FlSpot(x, y));
      prevY = y;
    }

    capexSeries.add(_Series(
      key: 'c:${schedule.id}',
      name: schedule.assetName,
      color: _chartColors[colorIdx % _chartColors.length],
      spots: spots,
      isCapex: true,
    ));
    colorIdx++;
  }

  return _ChartData(
    firstDate: firstDate,
    accounts: accountSeries,
    assets: assetSeries,
    capex: capexSeries,
    baseCurrency: baseCurrency,
  );
});

// ════════════════════════════════════════════════════
// Dashboard screen with toggleable legend
// ════════════════════════════════════════════════════

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _hidden = <String>{}; // keys of hidden series

  /// Build the total line from visible series using carry-forward.
  /// Each series may start at a different x; before it starts, its contribution is 0.
  /// After it starts, its last known y value is carried forward to fill gaps.
  List<FlSpot> _buildTotal(List<_Series> visible) {
    if (visible.isEmpty) return [];

    // Build {x → y} lookup per series, and collect all x values
    final allX = <double>{};
    final lookups = <Map<double, double>>[];
    for (final s in visible) {
      final m = <double, double>{};
      for (final spot in s.spots) {
        m[spot.x] = spot.y;
        allX.add(spot.x);
      }
      lookups.add(m);
    }

    final sortedX = allX.toList()..sort();
    final running = List<double>.filled(lookups.length, 0.0);

    return sortedX.map((x) {
      var total = 0.0;
      for (var i = 0; i < lookups.length; i++) {
        if (lookups[i].containsKey(x)) {
          running[i] = lookups[i][x]!;
        }
        total += running[i];
      }
      return FlSpot(x, total);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final chartAsync = ref.watch(_chartDataProvider);

    return chartAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (data) {
        if (data == null) {
          return const Center(
            child: Text('No data yet. Import transactions or add assets to get started.',
                style: TextStyle(color: Colors.grey)),
          );
        }

        final allSeries = data.allSeries;
        final visible = allSeries.where((s) => !_hidden.contains(s.key)).toList();
        // Total always includes ALL series, toggle only hides individual lines
        final totalSpots = _buildTotal(allSeries);
        final currentTotal = totalSpots.isNotEmpty ? totalSpots.last.y : 0.0;
        final symbol = currencySymbol(data.baseCurrency);

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Net Worth',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                NumberFormat.currency(locale: 'it_IT', symbol: symbol)
                    .format(currentTotal),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              // Toggleable legend grouped by type
              _GroupedLegend(
                accounts: data.accounts,
                assets: data.assets,
                adjustments: data.capex,
                hidden: _hidden,
                onToggle: (key) => setState(() {
                  if (_hidden.contains(key)) {
                    _hidden.remove(key);
                  } else {
                    _hidden.add(key);
                  }
                }),
                onToggleGroup: (keys) => setState(() {
                  final allHidden = keys.every(_hidden.contains);
                  if (allHidden) {
                    _hidden.removeAll(keys);
                  } else {
                    _hidden.addAll(keys);
                  }
                }),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: totalSpots.length >= 2
                    ? _BalanceChart(
                        data: data,
                        visible: visible,
                        totalSpots: totalSpots,
                      )
                    : const Center(child: Text('Not enough data to plot', style: TextStyle(color: Colors.grey))),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════
// Grouped legend: Accounts | Assets | Adjustments | Total
// ════════════════════════════════════════════════════

class _GroupedLegend extends StatelessWidget {
  final List<_Series> accounts;
  final List<_Series> assets;
  final List<_Series> adjustments;
  final Set<String> hidden;
  final ValueChanged<String> onToggle;
  final ValueChanged<Set<String>> onToggleGroup;

  const _GroupedLegend({
    required this.accounts,
    required this.assets,
    required this.adjustments,
    required this.hidden,
    required this.onToggle,
    required this.onToggleGroup,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (accounts.isNotEmpty)
          ..._buildGroup(context, 'Accounts', accounts, false),
        if (assets.isNotEmpty)
          ..._buildGroup(context, 'Assets', assets, true),
        if (adjustments.isNotEmpty)
          ..._buildGroup(context, 'Adjustments', adjustments, true),
        _ToggleLegendItem(
          color: Colors.white,
          label: 'Total',
          bold: true,
          enabled: true,
          onTap: null,
        ),
      ],
    );
  }

  List<Widget> _buildGroup(BuildContext context, String label, List<_Series> series, bool dashed) {
    final keys = series.map((s) => s.key).toSet();
    final allHidden = keys.every(hidden.contains);
    final groupEnabled = !allHidden;

    return [
      // Group header — tapping toggles all in the group
      GestureDetector(
        onTap: () => onToggleGroup(keys),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: groupEnabled
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: groupEnabled
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                decoration: groupEnabled ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
        ),
      ),
      // Individual items
      for (final s in series)
        _ToggleLegendItem(
          color: s.color,
          label: s.name,
          dashed: dashed,
          enabled: !hidden.contains(s.key),
          onTap: () => onToggle(s.key),
        ),
      // Separator
      const SizedBox(width: 4),
    ];
  }
}

// ════════════════════════════════════════════════════
// Legend item with tap-to-toggle
// ════════════════════════════════════════════════════

class _ToggleLegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;
  final bool bold;
  final bool enabled;
  final VoidCallback? onTap;

  const _ToggleLegendItem({
    required this.color,
    required this.label,
    this.dashed = false,
    this.bold = false,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? color : color.withValues(alpha: 0.3);
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dashed)
              SizedBox(
                width: 12,
                height: 3,
                child: CustomPaint(painter: _DashedLinePainter(effectiveColor)),
              )
            else
              Container(width: 12, height: 3, color: effectiveColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: enabled ? null : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                decoration: enabled ? null : TextDecoration.lineThrough,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const dashWidth = 3.0;
    const gap = 2.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(min(x + dashWidth, size.width), size.height / 2),
        paint,
      );
      x += dashWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ════════════════════════════════════════════════════
// Chart widget
// ════════════════════════════════════════════════════

class _BalanceChart extends StatelessWidget {
  final _ChartData data;
  final List<_Series> visible;
  final List<FlSpot> totalSpots;

  const _BalanceChart({
    required this.data,
    required this.visible,
    required this.totalSpots,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gridColor = isDark ? Colors.white12 : Colors.black12;
    final textColor = isDark ? Colors.white54 : Colors.black54;
    final symbol = currencySymbol(data.baseCurrency);

    // Compute Y range from total line
    final allY = totalSpots.map((s) => s.y);
    final minY = allY.reduce(min);
    final maxY = allY.reduce(max);
    final yRange = maxY - minY;
    final chartMinY = yRange > 0 ? minY - yRange * 0.05 : minY - 100;
    final chartMaxY = yRange > 0 ? maxY + yRange * 0.05 : maxY + 100;

    final totalDays = totalSpots.isNotEmpty ? totalSpots.last.x : 1.0;
    final dateFmt = DateFormat('MMM yyyy');
    final fullFmt = DateFormat('dd MMM yyyy');
    final currFmt = NumberFormat.currency(locale: 'it_IT', symbol: symbol, decimalDigits: 0);

    // Build line bars: total FIRST (background), then visible series on top
    final lineBars = <LineChartBarData>[];

    // Total line
    lineBars.add(LineChartBarData(
      spots: totalSpots,
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

    // Visible series lines
    for (final s in visible) {
      lineBars.add(LineChartBarData(
        spots: s.spots,
        isCurved: true,
        preventCurveOverShooting: true,
        curveSmoothness: 0.15,
        color: s.color,
        barWidth: 2,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
        dashArray: s.isCapex ? [3, 4] : s.isAsset ? [6, 3] : null,
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
                final isTotal = barIndex == 0;
                final seriesIdx = barIndex - 1;
                final date = data.firstDate.add(Duration(days: spot.x.toInt()));

                if (isTotal) {
                  return LineTooltipItem(
                    '${fullFmt.format(date)}\nTotal: ${currFmt.format(spot.y)}',
                    const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  );
                }

                if (seriesIdx >= 0 && seriesIdx < visible.length) {
                  final s = visible[seriesIdx];
                  return LineTooltipItem(
                    '${s.name}: ${currFmt.format(spot.y)}',
                    TextStyle(color: s.color, fontSize: 11),
                  );
                }
                return null;
              }).toList();
            },
          ),
        ),
        lineBarsData: lineBars,
      ),
    );
  }
}
