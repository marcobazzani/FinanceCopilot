part of 'dashboard_screen.dart';

// ════════════════════════════════════════════════════
// Income/Expense chart widgets (bar + line)
// ════════════════════════════════════════════════════

/// Bar chart: x=years, bars=Income+Expenses+Savings (Chart 4 equivalent).
class _YearlyBarChart extends ConsumerStatefulWidget {
  final _IncomeExpenseData data;
  final String locale;
  const _YearlyBarChart({required this.data, required this.locale});

  @override
  ConsumerState<_YearlyBarChart> createState() => _YearlyBarChartState();
}

class _YearlyBarChartState extends ConsumerState<_YearlyBarChart> {
  final _hidden = <String>{};
  void _toggle(String key) => setState(() {
    _hidden.contains(key) ? _hidden.remove(key) : _hidden.add(key);
  });

  static const _keys = ['income', 'expenses', 'savings'];

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final labels = [s.legendIncome, s.legendExpenses, s.legendSavings];
    final isPrivate = ref.watch(privacyModeProvider);
    final amtFmt   = fmt.amountFormat(widget.locale);
    final sym      = currencySymbol(widget.data.baseCurrency);
    final years    = widget.data.years;
    final now      = DateTime.now();
    if (years.isEmpty) return const SizedBox.shrink();

    final colorIncome   = Colors.green.shade400;
    final colorExpenses = Colors.red.shade400;
    final colorSavings  = Colors.blue.shade400;
    const barW = 20.0;

    // Build bar groups: stacked Expenses+Savings rod + thin Income rod
    final showIncome = !_hidden.contains('income');
    final showExp = !_hidden.contains('expenses');
    final showSav = !_hidden.contains('savings');
    const stackW = 20.0;
    const incomeW = 3.0;

    final groups = <BarChartGroupData>[];
    for (int i = 0; i < years.length; i++) {
      final y = years[i];
      final expH = showExp ? y.expenses : 0.0;
      final savH = showSav ? (y.savings > 0 ? y.savings : 0.0) : 0.0;

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
            toY: y.income,
            width: incomeW,
            color: colorIncome,
            borderRadius: BorderRadius.circular(1),
          ),
      ];
      groups.add(BarChartGroupData(x: i, barRods: rods, barsSpace: 2));
    }

    final allVals = years.expand((y) => [y.income, y.expenses + (y.savings > 0 ? y.savings : 0)]);
    final maxY = allVals.fold(0.0, max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Wrap(spacing: 16, children: [
            _ToggleLegendItem(color: Colors.green.shade400, label: labels[0], enabled: !_hidden.contains('income'), onTap: () => _toggle('income')),
            _ToggleLegendItem(color: Colors.red.shade400, label: labels[1], enabled: !_hidden.contains('expenses'), onTap: () => _toggle('expenses')),
            _ToggleLegendItem(color: Colors.blue.shade400, label: labels[2], enabled: !_hidden.contains('savings'), onTap: () => _toggle('savings')),
          ]),
        ),
        _maybeBlur(isPrivate, SizedBox(
          height: 280,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
            child: BarChart(BarChartData(
                  barGroups: groups,
                  maxY: maxY * 1.15,
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final y = years[group.x];
                        return BarTooltipItem(
                          '${y.year}${y.year == now.year ? "*" : ""}\n'
                          '${labels[1]}: ${amtFmt.format(y.expenses)} $sym\n'
                          '${labels[2]}: ${amtFmt.format(y.savings)} $sym\n'
                          '${labels[0]}: ${amtFmt.format(y.income)} $sym',
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
                        getTitlesWidget: (v, _) => Text(_shortAmount(v, sym), style: const TextStyle(fontSize: 10)),
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
        )),
      ],
    );
  }
}

/// Bar chart: x=years, bars=Monthly-avg Expenses + Monthly-avg Savings (Chart 2 equivalent).
class _MonthlyAvgBarChart extends ConsumerStatefulWidget {
  final _IncomeExpenseData data;
  final String locale;
  const _MonthlyAvgBarChart({required this.data, required this.locale});

  @override
  ConsumerState<_MonthlyAvgBarChart> createState() => _MonthlyAvgBarChartState();
}

class _MonthlyAvgBarChartState extends ConsumerState<_MonthlyAvgBarChart> {
  final _hidden = <String>{};
  void _toggle(String key) => setState(() {
    _hidden.contains(key) ? _hidden.remove(key) : _hidden.add(key);
  });

  static const _keys = ['income', 'expenses', 'savings'];

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final labels = [s.legendAvgMonthlyIncome, s.legendAvgMonthlyExpenses, s.legendAvgMonthlySavings];
    final tipLabels = [s.tipAvgMonthIncome, s.tipAvgMonthExpenses, s.tipAvgMonthSavings];
    final isPrivate = ref.watch(privacyModeProvider);
    final amtFmt = fmt.amountFormat(widget.locale);
    final sym    = currencySymbol(widget.data.baseCurrency);
    final years  = widget.data.years;
    final now    = DateTime.now();
    if (years.isEmpty) return const SizedBox.shrink();

    final colors = [Colors.green.shade400, Colors.red.shade400, Colors.blue.shade400];
    const barW = 12.0;
    const gap  = 4.0;

    final visibleIndices = [0, 1, 2].where((k) => !_hidden.contains(_keys[k])).toList();

    final groups = <BarChartGroupData>[];
    for (int i = 0; i < years.length; i++) {
      final y = years[i];
      final vals = [y.monthlyIncome, y.monthlyExpenses, y.savings / max(1, y.months.length)];
      final rods = <BarChartRodData>[];
      for (final k in visibleIndices) {
        rods.add(BarChartRodData(toY: vals[k], color: colors[k], width: barW));
      }
      groups.add(BarChartGroupData(x: i, barRods: rods, barsSpace: gap));
    }

    final maxY = years.map((y) => [y.monthlyIncome, y.monthlyExpenses]).expand((l) => l).fold(0.0, max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Wrap(spacing: 16, children: [
            _ToggleLegendItem(color: Colors.green.shade400, label: labels[0], enabled: !_hidden.contains('income'), onTap: () => _toggle('income')),
            _ToggleLegendItem(color: Colors.red.shade400, label: labels[1], enabled: !_hidden.contains('expenses'), onTap: () => _toggle('expenses')),
            _ToggleLegendItem(color: Colors.blue.shade400, label: labels[2], enabled: !_hidden.contains('savings'), onTap: () => _toggle('savings')),
          ]),
        ),
        _maybeBlur(isPrivate, SizedBox(
          height: 260,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
            child: BarChart(BarChartData(
              barGroups: groups,
              maxY: maxY * 1.1,
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final y = years[group.x];
                    if (rodIndex >= visibleIndices.length) return null;
                    final origIdx = visibleIndices[rodIndex];
                    final vals = [y.monthlyIncome, y.monthlyExpenses, y.savings / max(1, y.months.length)];
                    return BarTooltipItem(
                      '${y.year}${y.year == now.year ? "*" : ""}\n${tipLabels[origIdx]}\n${amtFmt.format(vals[origIdx])} $sym',
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
                    getTitlesWidget: (v, _) => Text(_shortAmount(v, sym), style: const TextStyle(fontSize: 10)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final i = v.round();
                      if (i < 0 || i >= years.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('${years[i].year}${years[i].year == now.year ? "*" : ""}',
                                    style: const TextStyle(fontSize: 9)),
                      );
                    },
                  ),
                ),
                topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
            )),
          ),
        )),
      ],
    );
  }
}

/// Line chart: x=months(1-12), one line per year. Shows income or expenses.
/// Chart 3 equivalent (income) and Chart 5 equivalent (expenses).
class _MonthlyByYearLineChart extends ConsumerStatefulWidget {
  final _IncomeExpenseData data;
  final String locale;
  final String field;    // 'income' or 'expenses'
  final int? maxYears;   // limit to most recent N years
  const _MonthlyByYearLineChart({required this.data, required this.locale,
                                  required this.field, this.maxYears});

  @override
  ConsumerState<_MonthlyByYearLineChart> createState() => _MonthlyByYearLineChartState();
}

class _MonthlyByYearLineChartState extends ConsumerState<_MonthlyByYearLineChart> {
  final _hidden = <String>{};
  void _toggle(String key) => setState(() {
    _hidden.contains(key) ? _hidden.remove(key) : _hidden.add(key);
  });

  static const _monthAbbr = ['','Jan','Feb','Mar','Apr','May','Jun',
                                 'Jul','Aug','Sep','Oct','Nov','Dec'];
  static const _palette = [
    Colors.blue, Colors.red, Colors.green, Colors.orange,
    Colors.purple, Colors.teal, Colors.pink, Colors.amber,
    Colors.cyan, Colors.indigo,
  ];

  @override
  Widget build(BuildContext context) {
    final isPrivate = ref.watch(privacyModeProvider);
    final amtFmt = fmt.amountFormat(widget.locale);
    final sym    = currencySymbol(widget.data.baseCurrency);
    var   years  = widget.data.years;
    if (widget.maxYears != null && years.length > widget.maxYears!) {
      years = years.sublist(years.length - widget.maxYears!);
    }
    if (years.isEmpty) return const SizedBox.shrink();

    // Build visible line bars only
    final lineBars = <LineChartBarData>[];
    final yearIndexMap = <int, int>{};   // lineBars index → years index
    for (int i = 0; i < years.length; i++) {
      final key = '${years[i].year}';
      if (_hidden.contains(key)) continue;
      final color = _palette[i % _palette.length];
      final spots = <FlSpot>[];
      for (final mb in years[i].months) {
        final val = widget.field == 'income' ? mb.income : mb.expenses;
        spots.add(FlSpot(mb.month.toDouble(), val));
      }
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

    final allVals = years.expand((y) => y.months).map((m) => widget.field == 'income' ? m.income : m.expenses);
    final maxY    = allVals.isEmpty ? 0.0 : allVals.fold(0.0, max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (int i = 0; i < years.length; i++)
                _ToggleLegendItem(
                  color: _palette[i % _palette.length],
                  label: '${years[i].year}',
                  enabled: !_hidden.contains('${years[i].year}'),
                  onTap: () => _toggle('${years[i].year}'),
                ),
            ],
          ),
        ),
        _maybeBlur(isPrivate, SizedBox(
          height: 260,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
            child: lineBars.isEmpty
                ? Center(child: Text(ref.watch(appStringsProvider).allSeriesHidden))
                : LineChart(LineChartData(
                    lineBarsData: lineBars,
                    minX: 1,
                    maxX: 12,
                    minY: 0,
                    maxY: maxY * 1.1,
                    gridData: const FlGridData(show: true),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        tooltipMargin: 16,
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItems: (spots) => spots.map((s) {
                          final barIdx = lineBars.indexOf(s.bar);
                          final yearIdx = yearIndexMap[barIdx] ?? -1;
                          final yearLabel = yearIdx >= 0 ? '${years[yearIdx].year}' : '';
                          return LineTooltipItem(
                            '$yearLabel ${_monthAbbr[s.x.round()]}\n${amtFmt.format(s.y)} $sym',
                            TextStyle(color: s.bar.color ?? Colors.white, fontSize: 11),
                          );
                        }).toList(),
                      ),
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          getTitlesWidget: (v, _) {
                            final m = v.round();
                            if (m < 1 || m > 12) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(_monthAbbr[m], style: const TextStyle(fontSize: 9)),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 80,
                          getTitlesWidget: (v, _) => Text(_shortAmount(v, sym), style: const TextStyle(fontSize: 10)),
                        ),
                      ),
                      topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                  )),
          ),
        )),
      ],
    );
  }
}

// Shared helpers
Widget _maybeBlur(bool isPrivate, Widget child) => isPrivate
    ? ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6), child: child)
    : child;

Widget _legendDot(Color color, String label) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 11)),
  ],
);

String _shortAmount(double v, String sym) {
  if (v.abs() >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M $sym';
  if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(0)}k $sym';
  return '${v.toStringAsFixed(0)} $sym';
}

// (Cash flow rendering is handled by _ChartCard + _UnifiedChart above)
// ════ end of file ════
