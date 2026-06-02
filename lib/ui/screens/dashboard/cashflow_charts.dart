part of 'dashboard_screen.dart';

// ════════════════════════════════════════════════════
// Income/Expense chart widgets (bar + line)
// ════════════════════════════════════════════════════

/// Mixin for charts with toggleable series that auto-adjust the Y axis
/// when series are hidden. Provides the hidden set, toggle method, and
/// a helper to compute maxY from only visible values.
mixin _ToggleableChartMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final hidden = <String>{};

  void toggle(String key) => setState(() {
    hidden.contains(key) ? hidden.remove(key) : hidden.add(key);
  });

  bool isVisible(String key) => !hidden.contains(key);

  /// Compute chart maxY from only the visible values, with headroom margin.
  double visibleMaxY(Iterable<double> values, {double margin = 1.1}) {
    if (values.isEmpty) return 0.0;
    return values.fold(0.0, max) * margin;
  }
}

/// Bar chart: x=years, bars=Income+Expenses+Savings.
/// When [monthly] is true, values are monthly averages (Income/Months,
/// Expenses/Months, Savings/Months) and labels use the avg-monthly variants.
class _YearlyBarChart extends ConsumerStatefulWidget {
  final _IncomeExpenseData data;
  final String locale;
  final String language;
  final bool monthly;
  const _YearlyBarChart({
    required this.data,
    required this.locale,
    required this.language,
    this.monthly = false,
  });

  @override
  ConsumerState<_YearlyBarChart> createState() => _YearlyBarChartState();
}

class _YearlyBarChartState extends ConsumerState<_YearlyBarChart>
    with _ToggleableChartMixin {

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final labels = widget.monthly
        ? [s.legendAvgMonthlyIncome, s.legendAvgMonthlyExpenses, s.legendAvgMonthlySavings]
        : [s.legendIncome, s.legendExpenses, s.legendSavings];
    final isPrivate = ref.watch(privacyModeProvider);
    final amtFmt   = fmt.amountFormat(widget.locale);
    final sym      = currencySymbol(widget.data.baseCurrency);
    final years    = widget.data.years;
    final now      = ref.watch(currentDateProvider);
    if (years.isEmpty) return const SizedBox.shrink();

    final colorIncome   = Colors.green.shade400;
    final colorExpenses = Colors.red.shade400;
    final colorSavings  = Colors.blue.shade400;

    double incomeOf(_YearBucket y)   => widget.monthly ? y.monthlyIncome   : y.income;
    double expensesOf(_YearBucket y) => widget.monthly ? y.monthlyExpenses : y.expenses;
    double savingsOf(_YearBucket y)  => widget.monthly ? y.monthlySavings : y.savings;

    // Build bar groups: stacked Expenses+Savings rod + thin Income rod
    final showIncome = isVisible('income');
    final showExp = isVisible('expenses');
    final showSav = isVisible('savings');
    const stackW = 20.0;
    const incomeW = 3.0;

    final groups = <BarChartGroupData>[];
    for (int i = 0; i < years.length; i++) {
      final y = years[i];
      final expH = showExp ? expensesOf(y) : 0.0;
      final sav  = savingsOf(y);
      final savH = showSav ? (sav > 0 ? sav : 0.0) : 0.0;

      final rods = <BarChartRodData>[
        // Stacked bar: Expenses (bottom) + Savings (top)
        BarChartRodData(
          toY: expH + savH,
          width: stackW,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          rodStackItems: [
            if (showExp) BarChartRodStackItem(0, expH, colorExpenses),
            if (showSav) BarChartRodStackItem(expH, expH + savH, colorSavings),
          ],
          color: Colors.transparent,
        ),
        // Income as a thin rod (acts as a line marker)
        if (showIncome)
          BarChartRodData(
            toY: incomeOf(y),
            width: incomeW,
            color: colorIncome,
            borderRadius: BorderRadius.circular(1),
          ),
      ];
      groups.add(BarChartGroupData(x: i, barRods: rods, barsSpace: 2));
    }

    final maxY = visibleMaxY(years.expand((y) {
      final sav = savingsOf(y);
      return [
        if (showIncome) incomeOf(y),
        if (showExp || showSav) (showExp ? expensesOf(y) : 0.0) + (showSav && sav > 0 ? sav : 0.0),
      ];
    }), margin: 1.15);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Wrap(spacing: 16, children: [
            _ToggleLegendItem(color: Colors.green.shade400, label: labels[0], enabled: isVisible('income'), onTap: () => toggle('income')),
            _ToggleLegendItem(color: Colors.red.shade400, label: labels[1], enabled: isVisible('expenses'), onTap: () => toggle('expenses')),
            _ToggleLegendItem(color: Colors.blue.shade400, label: labels[2], enabled: isVisible('savings'), onTap: () => toggle('savings')),
          ]),
        ),
        SizedBox(
          height: 280,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
            child: BarChart(BarChartData(
                  barGroups: groups,
                  maxY: maxY,
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    enabled: !isPrivate,
                    touchTooltipData: BarTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final y = years[group.x];
                        return BarTooltipItem(
                          '${y.year}${y.year == now.year ? "*" : ""}\n'
                          '${labels[1]}: ${amtFmt.format(expensesOf(y))} $sym\n'
                          '${labels[2]}: ${amtFmt.format(savingsOf(y))} $sym\n'
                          '${labels[0]}: ${amtFmt.format(incomeOf(y))} $sym',
                          const TextStyle(color: Colors.white, fontSize: 11),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 80,
                        getTitlesWidget: (v, _) => Text(
                          isPrivate ? '\u2022\u2022\u2022\u2022' : _shortAmount(v, sym),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final i = v.round();
                          if (i < 0 || i >= years.length) return const SizedBox.shrink();
                          final y = years[i];
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('${y.year}${y.year == now.year ? "*" : ""}', style: const TextStyle(fontSize: 9)),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                )),
          ),
        ),
      ],
    );
  }
}

/// Chart: x=months(1-12), one series per year. Shows income or expenses.
/// Renders as a line chart by default, or as grouped bars when [histogram] is true.
class _MonthlyByYearLineChart extends ConsumerStatefulWidget {
  final _IncomeExpenseData data;
  final String locale;
  final String language;
  final String field;    // 'income' or 'expenses'
  final bool histogram;
  const _MonthlyByYearLineChart({required this.data, required this.locale,
                                  required this.language, required this.field,
                                  this.histogram = false});

  @override
  ConsumerState<_MonthlyByYearLineChart> createState() => _MonthlyByYearLineChartState();
}

class _MonthlyByYearLineChartState extends ConsumerState<_MonthlyByYearLineChart>
    with _ToggleableChartMixin {

  List<String> _monthAbbr() {
    final f = DateFormat('MMM', widget.language);
    return ['', for (int m = 1; m <= 12; m++) f.format(DateTime(2000, m))];
  }
  static const _palette = [
    Colors.blue, Colors.red, Colors.green, Colors.orange,
    Colors.purple, Colors.teal, Colors.pink, Colors.amber,
    Colors.cyan, Colors.indigo,
  ];

  double _valOf(_MonthBucket mb) => widget.field == 'income' ? mb.income : mb.expenses;

  @override
  Widget build(BuildContext context) {
    final isPrivate = ref.watch(privacyModeProvider);
    final amtFmt = fmt.amountFormat(widget.locale);
    final sym    = currencySymbol(widget.data.baseCurrency);
    final years  = widget.data.years;
    if (years.isEmpty) return const SizedBox.shrink();

    final visibleYearIdx = [for (int i = 0; i < years.length; i++) if (isVisible('${years[i].year}')) i];
    final visibleYears = visibleYearIdx.map((i) => years[i]).toList();
    final maxY = visibleMaxY(visibleYears.expand((y) => y.months).map(_valOf));
    final allHidden = visibleYearIdx.isEmpty;

    final legend = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (int i = 0; i < years.length; i++)
            _ToggleLegendItem(
              color: _palette[i % _palette.length],
              label: '${years[i].year}',
              enabled: isVisible('${years[i].year}'),
              onTap: () => toggle('${years[i].year}'),
            ),
        ],
      ),
    );

    final chart = allHidden
        ? Center(child: Text(ref.watch(appStringsProvider).allSeriesHidden))
        : widget.histogram
            ? _buildHistogram(visibleYearIdx, maxY, isPrivate, amtFmt, sym, years)
            : _buildLineChart(visibleYearIdx, maxY, isPrivate, amtFmt, sym, years);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        legend,
        SizedBox(
          height: 260,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
            child: chart,
          ),
        ),
      ],
    );
  }

  Widget _buildLineChart(List<int> visibleYearIdx, double maxY, bool isPrivate,
      NumberFormat amtFmt, String sym, List<_YearBucket> years) {
    final lineBars = <LineChartBarData>[];
    final yearIndexMap = <int, int>{};   // lineBars index -> years index
    for (final i in visibleYearIdx) {
      final color = _palette[i % _palette.length];
      final spots = [for (final mb in years[i].months) FlSpot(mb.month.toDouble(), _valOf(mb))];
      if (spots.isEmpty) continue;
      yearIndexMap[lineBars.length] = i;
      lineBars.add(LineChartBarData(
        spots: spots,
        color: color,
        barWidth: 2,
        isCurved: false,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }

    return LineChart(LineChartData(
      lineBarsData: lineBars,
      minX: 1,
      maxX: 12,
      minY: 0,
      maxY: maxY,
      gridData: const FlGridData(show: true),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        enabled: !isPrivate,
        touchTooltipData: LineTouchTooltipData(
          tooltipMargin: 16,
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipItems: (spots) => spots.map((s) {
            final barIdx = lineBars.indexOf(s.bar);
            final yearIdx = yearIndexMap[barIdx] ?? -1;
            final yearLabel = yearIdx >= 0 ? '${years[yearIdx].year}' : '';
            return LineTooltipItem(
              '$yearLabel ${_monthAbbr()[s.x.round()]}\n${amtFmt.format(s.y)} $sym',
              TextStyle(color: s.bar.color ?? Colors.white, fontSize: 11),
            );
          }).toList(),
        ),
      ),
      titlesData: _monthYearTitles(isPrivate, sym),
    ));
  }

  Widget _buildHistogram(List<int> visibleYearIdx, double maxY, bool isPrivate,
      NumberFormat amtFmt, String sym, List<_YearBucket> years) {
    final groups = <BarChartGroupData>[];
    final visibleCount = visibleYearIdx.length;
    final barW = visibleCount <= 4 ? 18.0
        : visibleCount <= 7 ? 13.0
        : visibleCount <= 10 ? 9.0
        : 8.0;
    for (int m = 1; m <= 12; m++) {
      final rods = <BarChartRodData>[];
      for (final i in visibleYearIdx) {
        final mb = years[i].months.where((b) => b.month == m).firstOrNull;
        rods.add(BarChartRodData(
          toY: mb == null ? 0 : _valOf(mb),
          color: _palette[i % _palette.length],
          width: barW,
          borderRadius: BorderRadius.circular(1),
        ));
      }
      groups.add(BarChartGroupData(x: m, barRods: rods, barsSpace: 1));
    }

    return BarChart(BarChartData(
      barGroups: groups,
      maxY: maxY,
      gridData: const FlGridData(show: true),
      borderData: FlBorderData(show: false),
      barTouchData: BarTouchData(
        enabled: !isPrivate,
        touchTooltipData: BarTouchTooltipData(
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            if (rodIndex >= visibleYearIdx.length) return null;
            final yearIdx = visibleYearIdx[rodIndex];
            final yearLabel = '${years[yearIdx].year}';
            return BarTooltipItem(
              '$yearLabel ${_monthAbbr()[group.x]}\n${amtFmt.format(rod.toY)} $sym',
              TextStyle(color: rod.color ?? Colors.white, fontSize: 11),
            );
          },
        ),
      ),
      titlesData: _monthYearTitles(isPrivate, sym),
    ));
  }

  FlTitlesData _monthYearTitles(bool isPrivate, String sym) => FlTitlesData(
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        interval: 1,
        getTitlesWidget: (v, _) {
          final m = v.round();
          if (m < 1 || m > 12) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_monthAbbr()[m], style: const TextStyle(fontSize: 9)),
          );
        },
      ),
    ),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 80,
        getTitlesWidget: (v, _) => Text(
          isPrivate ? '\u2022\u2022\u2022\u2022' : _shortAmount(v, sym),
          style: const TextStyle(fontSize: 10),
        ),
      ),
    ),
    topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  );
}

// Shared helpers
String _shortAmount(double v, String sym) {
  if (v.abs() >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M $sym';
  if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(0)}k $sym';
  return '${v.toStringAsFixed(0)} $sym';
}

// (Cash flow rendering is handled by _ChartCard + _UnifiedChart above)
