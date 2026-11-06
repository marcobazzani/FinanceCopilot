part of 'dashboard_screen.dart';

// ════════════════════════════════════════════════════
// Cash Flow tab
// ════════════════════════════════════════════════════

class _CashFlowTab extends ConsumerStatefulWidget {
  final AllSeriesData allData;
  final String locale;
  final String language;
  const _CashFlowTab({required this.allData, required this.locale, required this.language});

  @override
  ConsumerState<_CashFlowTab> createState() => _CashFlowTabState();
}

class _CashFlowTabState extends ConsumerState<_CashFlowTab> {
  static const _idSaving = -10;
  static const _idSpending = -11;
  static const _idVelocity = -12;

  int _savingWindow = 365;
  int _spendingWindow = 365;
  int _velocityWindow = 365;

  late final TextEditingController _savingWinCtl;
  late final TextEditingController _spendingWinCtl;
  late final TextEditingController _velocityWinCtl;

  final _hidden = <int, Set<String>>{};
  final _heights = <int, double>{};
  final _zooms = <int, _ChartZoom>{};

  // Year by year: chart or table; totals or monthly averages.
  bool _yearTable = false;
  bool _yearAverages = false;

  // Month by month: which figure ('income' / 'expenses' / 'savings'), and
  // 'chart' / 'table' / 'yoy'.
  String _monthField = 'income';
  String _monthView = 'chart';
  bool _monthBars = false;

  @override
  void initState() {
    super.initState();
    _savingWinCtl = TextEditingController(text: '$_savingWindow');
    _spendingWinCtl = TextEditingController(text: '$_spendingWindow');
    _velocityWinCtl = TextEditingController(text: '$_velocityWindow');
    _applyRange(_appliedPeriod = _periodOrDefault(ref.read(_cashFlowPeriodProvider), ref.read(currentDateProvider)));
  }

  /// The period the daily charts' range was last set from.
  CashFlowPeriod? _appliedPeriod;

  /// The daily charts open on the period, at least the twelve months up to
  /// its end: their averages run over a year, a month alone shows nothing of
  /// them (every year: all of their history). Only the visible range moves:
  /// their data and moving averages stay whole.
  void _applyRange(CashFlowPeriod period) {
    final first = widget.allData.firstDate;
    final now = ref.read(currentDateProvider);
    final todayX = chart_math.calendarDaysBetween(first, now).toDouble().clamp(0.0, double.infinity);
    double minX;
    double maxX;
    if (period.kind == CashFlowPeriodKind.all) {
      minX = 0;
      maxX = todayX;
    } else {
      final days = period.daysUntil(now);
      final yearBefore = DateTime(days.end.year - 1, days.end.month, days.end.day);
      final start = days.start.isBefore(yearBefore) ? days.start : yearBefore;
      minX = chart_math.calendarDaysBetween(first, start).toDouble().clamp(0.0, double.infinity);
      maxX = chart_math.calendarDaysBetween(first, days.end).toDouble().clamp(minX, double.infinity);
    }
    for (final id in [_idSaving, _idSpending, _idVelocity]) {
      _zooms[id] = _ChartZoom()
        ..minX = minX
        ..maxX = maxX;
    }
  }

  @override
  void dispose() {
    _savingWinCtl.dispose();
    _spendingWinCtl.dispose();
    _velocityWinCtl.dispose();
    super.dispose();
  }

  Set<String> _hiddenFor(int id) => _hidden.putIfAbsent(id, () => {});
  double _heightFor(int id) => _heights.putIfAbsent(id, () => 420.0);
  _ChartZoom _zoomFor(int id) => _zooms.putIfAbsent(id, () => _ChartZoom());

  Widget _maField(TextEditingController ctl, ValueChanged<int> onChanged) {
    final s = ref.read(appStringsProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(s.chartMaShort, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        SizedBox(
          width: 60,
          height: 32,
          child: TextField(
            controller: ctl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) {
              final w = int.tryParse(v);
              if (w != null) onChanged(w.clamp(1, 3000));
            },
          ),
        ),
      ],
    );
  }

  DashboardChart _fakeChart(int id, String title) => DashboardChart(
    id: id,
    title: title,
    widgetType: 'chart',
    sortOrder: 0,
    seriesJson: '[]',
    sourceChartIds: 'cf', // non-null → showTotal=false, no hide-components button
    createdAt: DateTime.now(),
  );

  void _onToggle(int chartId, String key) => setState(() {
    final h = _hiddenFor(chartId);
    if (h.contains(key)) {
      h.remove(key);
    } else {
      h.add(key);
    }
  });

  void _onToggleGroup(int chartId, Set<String> keys) => setState(() {
    final h = _hiddenFor(chartId);
    final allHidden = keys.every(h.contains);
    if (allHidden) {
      h.removeAll(keys);
    } else {
      h.addAll(keys);
    }
  });

  void _onZoom(int chartId, double? minX, double? maxX, double? minY, double? maxY) => setState(() {
    final z = _zoomFor(chartId);
    z.minX = minX;
    z.maxX = maxX;
    z.minY = minY;
    z.maxY = maxY;
  });

  Widget _controls(List<Widget> children) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Wrap(spacing: 12, runSpacing: 8, children: children),
    ),
  );

  Widget _seg<T>(Map<T, String> options, T selected, ValueChanged<T> onChanged) => SegmentedButton<T>(
    segments: [for (final e in options.entries) ButtonSegment<T>(value: e.key, label: Text(e.value))],
    selected: {selected},
    onSelectionChanged: (v) => onChanged(v.first),
    showSelectedIcon: false,
    style: const ButtonStyle(visualDensity: VisualDensity.compact),
  );

  @override
  Widget build(BuildContext context) {
    final allData = widget.allData;
    final locale = widget.locale;
    final ieAsync = ref.watch(_incomeExpenseDataProvider);
    final ieData = ieAsync.value;
    // Income records left out of the yearly figures for want of a rate.
    final incomeRowsWithoutRate = ref.watch(incomeRowsWithoutRateProvider).value;

    // Cash and Saving flow from the user's configured History-tab charts
    // (stored in dashboard_charts) — option B. Fallback to hard-coded
    // compositions when the user deleted the role chart.
    final userCharts = ref.watch(dashboardChartsProvider);
    final activeAssets = ref.watch(activeAssetsProvider).value ?? const <Asset>[];
    final rawSavingSpots = _DashboardScreenState.spotsForRole('saving', userCharts, allData, activeAssets);
    final cashSpots = _DashboardScreenState.spotsForRole('cash', userCharts, allData, activeAssets);

    // Subtract cumulative pension contributions from saving so velocity
    // and spending derivations reflect personal cashflow only. Pension
    // money inflates fund NAV but never lands in the user's bank — see
    // _IncomeExpenseData.pensionContribCumulativeSpots.
    final pensionCum = ieData?.pensionContribCumulativeSpots ?? const <FlSpot>[];
    final savingSpots = _subtractCumulativeSeries(rawSavingSpots, pensionCum);

    // Spending = cumulative sum of negative daily deltas of saving
    final spendingSpots = _buildSpendingFromSaving(savingSpots);

    final savingMA = _computeMA(savingSpots, _savingWindow);
    final spendingMA = _computeMA(spendingSpots, _spendingWindow);
    final savingDiff = _computeDiff(savingSpots, savingMA);

    final savingVel = _computeVelocity(_computeMA(savingSpots, _velocityWindow));
    final spendingVelRaw = _computeVelocity(_computeMA(spendingSpots, _velocityWindow));
    final spendingVel = spendingVelRaw.map((s) => FlSpot(s.x, -s.y)).toList();

    final s = ref.watch(appStringsProvider);
    final chartDefs = [
      (
        id: _idSaving,
        chart: _fakeChart(_idSaving, s.cfVsMovingAverage(s.dashSaving)),
        series: <ChartSeries>[
          ChartSeries(key: 'cf:saving', name: s.dashSaving, color: Colors.blue, spots: savingSpots),
          ChartSeries(key: 'cf:saving_ma', name: s.cfMovingAverage, color: Colors.blue.shade200, spots: savingMA, isDashed: true),
          ChartSeries(key: 'cf:diff', name: s.cfDiff, color: Colors.orange, spots: savingDiff, rightAxis: true),
        ],
        ctl: _savingWinCtl,
        onWin: (int w) => setState(() => _savingWindow = w),
      ),
      (
        id: _idSpending,
        chart: _fakeChart(_idSpending, s.cfVsMovingAverageAnd(s.legendExpenses, s.dashCash)),
        series: <ChartSeries>[
          ChartSeries(key: 'cf:spending', name: s.legendExpenses, color: Colors.red, spots: spendingSpots),
          ChartSeries(key: 'cf:spending_ma', name: s.cfMovingAverage, color: Colors.red.shade200, spots: spendingMA, isDashed: true),
          ChartSeries(key: 'cf:cash', name: s.dashCash, color: Colors.green, spots: cashSpots, rightAxis: true),
        ],
        ctl: _spendingWinCtl,
        onWin: (int w) => setState(() => _spendingWindow = w),
      ),
      (
        id: _idVelocity,
        chart: _fakeChart(_idVelocity, s.cfOfMovingAverage(s.cfVelocity)),
        series: <ChartSeries>[
          ChartSeries(key: 'cf:saving_vel', name: s.cfVelocityOf(s.dashSaving), color: Colors.blue, spots: savingVel),
          ChartSeries(key: 'cf:spending_vel', name: s.cfVelocityOf(s.legendExpenses), color: Colors.red, spots: spendingVel),
        ],
        ctl: _velocityWinCtl,
        onWin: (int w) => setState(() => _velocityWindow = w),
      ),
    ];

    final now = ref.watch(currentDateProvider);
    final spendingAsync = ref.watch(_spendingByCategoryProvider);
    final spending = spendingAsync.value;
    final period = _periodOrDefault(ref.watch(_cashFlowPeriodProvider), now);
    // The period can move from the Spent screen too: the daily charts follow.
    if (period != _appliedPeriod) _applyRange(_appliedPeriod = period);

    final available = _availableMonths(ieData, spending);
    // The Sankey adds up the period's months.
    final sankeyPeriods = period.monthsIn(available);
    final periodLabel = period.label(s, widget.language, now);
    final totals = _totalsOf(ieData, sankeyPeriods);
    // The yearly and monthly views show every year: the history the period
    // sits in.
    final viewData = ieData;
    const bold = TextStyle(fontWeight: FontWeight.w600);
    final small = Theme.of(context).textTheme.bodySmall;
    const loader = Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator()),
    );

    return Column(
      children: [
        // Pinned above the scroll: every section below follows it.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: _SpanSelector(period: period, available: available),
        ),
        const Divider(height: 1),
        Expanded(
          child: MobilePullToRefresh(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 40, 16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _CashFlowOverview(period: period, available: available, today: now, locale: locale, language: widget.language),
                const SizedBox(height: 8),
                // The income records the figures leave out (never converted
                // 1:1), counted once under them.
                if (incomeRowsWithoutRate != null && incomeRowsWithoutRate > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Footnote(s.incomeFxExcluded(incomeRowsWithoutRate), key: const Key('incomeFxFootnote')),
                  ),
                // Where the money goes: the picked periods as a Sankey. Income,
                // savings and expenses are the Income/Expense/Savings figures
                // (one source of truth); the ledger only splits expenses by
                // category. Under the spending: the full picture.
                ExpansionTile(
                  key: const Key('spendingByCategoryTile'),
                  title: Text(s.spendingByCategoryTitle, style: bold),
                  subtitle: Text(s.spendingByCategorySubtitle, style: small),
                  initiallyExpanded: true,
                  children: [
                    if (period.byDays)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Footnote(s.cfSankeyNeedsMonths, key: const Key('cfSankeyNeedsMonths')),
                      )
                    else
                      spendingAsync.when(
                        loading: () => loader,
                        error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text(s.error(e))),
                        data: (d) => ieAsync.isLoading
                            ? loader
                            : CashFlowSankeyCard(spending: d, periods: sankeyPeriods, totals: totals, periodLabel: periodLabel, locale: locale),
                      ),
                  ],
                ),
                if (ieAsync.isLoading)
                  loader
                else if (viewData != null) ...[
                  ExpansionTile(
                    key: const Key('cfYearByYearTile'),
                    title: Text(s.cfYearByYear, style: bold),
                    initiallyExpanded: true,
                    children: [
                      _controls([
                        _seg<bool>({false: s.cfViewChart, true: s.cfViewTable}, _yearTable, (v) => setState(() => _yearTable = v)),
                        if (!_yearTable)
                          _seg<bool>({false: s.cfTotals, true: s.cfMonthlyAverage}, _yearAverages, (v) => setState(() => _yearAverages = v)),
                      ]),
                      if (_yearTable)
                        _YearlySummaryTable(data: viewData, locale: locale)
                      else
                        _YearlyBarChart(data: viewData, locale: locale, language: widget.language, monthly: _yearAverages),
                    ],
                  ),
                  ExpansionTile(
                    key: const Key('cfMonthByMonthTile'),
                    title: Text(s.cfMonthByMonth, style: bold),
                    children: [
                      _controls([
                        _seg<String>(
                          {'income': s.legendIncome, 'expenses': s.legendExpenses, 'savings': s.legendSavings},
                          _monthField,
                          (v) => setState(() => _monthField = v),
                        ),
                        _seg<String>(
                          {'chart': s.cfViewChart, 'table': s.cfViewTable, 'yoy': s.cfViewYoY},
                          _monthView,
                          (v) => setState(() => _monthView = v),
                        ),
                        // Prototype only: lines or grouped bars, to pick one.
                        if (_monthView == 'chart')
                          _seg<bool>({false: s.cfChartLines, true: s.cfChartBars}, _monthBars, (v) => setState(() => _monthBars = v)),
                      ]),
                      switch (_monthView) {
                        'table' => _MonthlyGrid(data: viewData, locale: locale, language: widget.language, field: _monthField),
                        'yoy' => _YoYDiffTable(data: viewData, previous: ieData, locale: locale, language: widget.language, field: _monthField),
                        _ => _MonthlyByYearLineChart(
                          data: viewData,
                          locale: locale,
                          language: widget.language,
                          field: _monthField,
                          histogram: _monthBars,
                        ),
                      },
                    ],
                  ),
                ],
                // The daily charts, closed by default: the picked periods only
                // set their visible range (see _applyRange).
                ExpansionTile(
                  key: const Key('cfTrendsTile'),
                  title: Text(s.cfTrends, style: bold),
                  subtitle: Text(s.cfTrendsSubtitle, style: small),
                  children: [
                    for (final c in chartDefs) ...[
                      Builder(
                        builder: (_) {
                          final z = _zoomFor(c.id);
                          return ChartCard(
                            chart: c.chart,
                            series: c.series,
                            allData: allData,
                            hidden: _hiddenFor(c.id),
                            locale: locale,
                            language: widget.language,
                            chartHeight: _heightFor(c.id),
                            zoomMinX: z.minX,
                            zoomMaxX: z.maxX,
                            zoomMinY: z.minY,
                            zoomMaxY: z.maxY,
                            onToggle: (key) => _onToggle(c.id, key),
                            onToggleGroup: (keys) => _onToggleGroup(c.id, keys),
                            onToggleHideComponents: () {},
                            onZoom: (minX, maxX, minY, maxY) => _onZoom(c.id, minX, maxX, minY, maxY),
                            onHeightChanged: (h) => setState(() => _heights[c.id] = h.clamp(200.0, 900.0)),
                            headerExtra: _maField(c.ctl, c.onWin),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Income, savings and refunds of [periods], summed from the monthly buckets
/// (a year's months add up to the year).
CashFlowTotals _totalsOf(_IncomeExpenseData? data, Set<(int, int)> periods) {
  var income = 0.0, savings = 0.0, refunds = 0.0;
  for (final y in data?.years ?? const <_YearBucket>[]) {
    for (final m in y.months) {
      if (!periods.contains((y.year, m.month))) continue;
      income += m.income;
      savings += m.savings;
      refunds += m.refunds;
    }
  }
  return (income: income, savings: savings, refunds: refunds);
}

/// How a figure moved from [before] to [now], as an amount ([money]), colored
/// by whether up is good. An amount is position size: privacy mode masks it.
Widget _moneyChange(double now, double before, {required bool upIsGood, required NumberFormat money, bool large = false}) {
  final d = now - before;
  return _ChangeText(
    text: '${d >= 0 ? '▲' : '▼'} ${money.format(d.abs())}',
    good: d.abs() < 0.5 ? null : (d > 0) == upIsGood,
    amount: true,
    large: large,
  );
}

/// A change next to a figure: green when it is for the better, red when for
/// the worse, muted when there is no telling ([good] null).
class _ChangeText extends StatelessWidget {
  final String text;
  final bool? good;

  /// The change is an amount: position size, masked in privacy mode.
  final bool amount;

  /// In a screen's heading rather than next to a card's figure.
  final bool large;
  const _ChangeText({required this.text, required this.good, this.amount = false, this.large = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (good) {
      true => Colors.green.shade500,
      false => theme.colorScheme.error,
      null => theme.colorScheme.onSurfaceVariant,
    };
    final style = (large ? theme.textTheme.titleMedium : theme.textTheme.titleSmall)?.copyWith(color: color, fontWeight: FontWeight.w600);
    return amount ? PrivacyText(text, style: style) : Text(text, style: style);
  }
}
