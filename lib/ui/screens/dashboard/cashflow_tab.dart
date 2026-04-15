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
  static const _idSaving   = -10;
  static const _idSpending = -11;
  static const _idVelocity = -12;

  int _savingWindow   = 365;
  int _spendingWindow = 365;
  int _velocityWindow = 365;

  late final TextEditingController _savingWinCtl;
  late final TextEditingController _spendingWinCtl;
  late final TextEditingController _velocityWinCtl;

  final _hidden  = <int, Set<String>>{};
  final _heights = <int, double>{};
  final _zooms   = <int, _ChartZoom>{};

  @override
  void initState() {
    super.initState();
    _savingWinCtl   = TextEditingController(text: '$_savingWindow');
    _spendingWinCtl = TextEditingController(text: '$_spendingWindow');
    _velocityWinCtl = TextEditingController(text: '$_velocityWindow');

    // Default zoom: last 365 days
    final totalDays = DateTime.now().difference(widget.allData.firstDate).inDays.toDouble();
    final xMax = totalDays.clamp(0.0, double.infinity);
    final xMin365 = (xMax - 365).clamp(0.0, double.infinity);
    for (final id in [_idSaving, _idSpending, _idVelocity]) {
      _zooms[id] = _ChartZoom()
        ..minX = xMin365
        ..maxX = xMax;
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('MA:', style: TextStyle(fontSize: 12)),
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
    if (h.contains(key)) { h.remove(key); } else { h.add(key); }
  });

  void _onToggleGroup(int chartId, Set<String> keys) => setState(() {
    final h = _hiddenFor(chartId);
    final allHidden = keys.every(h.contains);
    if (allHidden) { h.removeAll(keys); } else { h.addAll(keys); }
  });

  void _onZoom(int chartId, double? minX, double? maxX, double? minY, double? maxY) =>
      setState(() {
        final z = _zoomFor(chartId);
        z.minX = minX; z.maxX = maxX; z.minY = minY; z.maxY = maxY;
      });

  @override
  Widget build(BuildContext context) {
    final allData = widget.allData;
    final locale  = widget.locale;
    final ieAsync = ref.watch(_incomeExpenseDataProvider);
    final ieData  = ieAsync.value;

    // Saving = accounts + invested + adjustments (spread + income)
    final savingSpots = buildTotalSpots([
      ...allData.accounts.map((s) => s.spots),
      ...allData.assetInvested.map((s) => s.spots),
      ...allData.adjustments.map((s) => s.spots),
      ...allData.incomeAdjustments.map((s) => s.spots),
    ]);

    // Cash = accounts + spread adjustments only
    final cashSpots = buildTotalSpots([
      ...allData.accounts.map((s) => s.spots),
      ...allData.adjustments.map((s) => s.spots),
    ]);

    // Spending = cumulative sum of negative daily deltas of saving
    final spendingSpots = _buildSpendingFromSaving(savingSpots);

    final savingMA   = _computeMA(savingSpots,   _savingWindow);
    final spendingMA = _computeMA(spendingSpots, _spendingWindow);
    final savingDiff = _computeDiff(savingSpots, savingMA);

    final savingVel      = _computeVelocity(_computeMA(savingSpots,   _velocityWindow));
    final spendingVelRaw = _computeVelocity(_computeMA(spendingSpots, _velocityWindow));
    final spendingVel    = spendingVelRaw.map((s) => FlSpot(s.x, -s.y)).toList();

    final s = ref.watch(appStringsProvider);
    final chartDefs = [
      (
        id: _idSaving,
        chart: _fakeChart(_idSaving, '${s.dashSaving} vs MA'),
        series: <ChartSeries>[
          ChartSeries(key: 'cf:saving',    name: s.dashSaving, color: Colors.blue,          spots: savingSpots),
          ChartSeries(key: 'cf:saving_ma', name: 'MA',         color: Colors.blue.shade200,  spots: savingMA,   isDashed: true),
          ChartSeries(key: 'cf:diff',      name: 'Diff',       color: Colors.orange,         spots: savingDiff, rightAxis: true),
        ],
        ctl: _savingWinCtl,
        onWin: (int w) => setState(() => _savingWindow = w),
      ),
      (
        id: _idSpending,
        chart: _fakeChart(_idSpending, '${s.legendExpenses} vs MA & ${s.dashCash}'),
        series: <ChartSeries>[
          ChartSeries(key: 'cf:spending',    name: s.legendExpenses, color: Colors.red,           spots: spendingSpots),
          ChartSeries(key: 'cf:spending_ma', name: 'MA',             color: Colors.red.shade200,   spots: spendingMA,  isDashed: true),
          ChartSeries(key: 'cf:cash',        name: s.dashCash,       color: Colors.green,          spots: cashSpots,   rightAxis: true),
        ],
        ctl: _spendingWinCtl,
        onWin: (int w) => setState(() => _spendingWindow = w),
      ),
      (
        id: _idVelocity,
        chart: _fakeChart(_idVelocity, '${s.cfVelocity} (MA)'),
        series: <ChartSeries>[
          ChartSeries(key: 'cf:saving_vel',   name: '${s.dashSaving} vel.',     color: Colors.blue, spots: savingVel),
          ChartSeries(key: 'cf:spending_vel', name: '${s.legendExpenses} vel.', color: Colors.red,  spots: spendingVel),
        ],
        ctl: _velocityWinCtl,
        onWin: (int w) => setState(() => _velocityWindow = w),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 40, 16),
      children: [
        for (int i = 0; i < chartDefs.length; i++) ...[
          Builder(builder: (_) {
            final c = chartDefs[i];
            final z = _zoomFor(c.id);
            return _ChartCard(
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
          }),
          const SizedBox(height: 24),
        ],
        // Income/expense analytics sections
        if (ieAsync.isLoading) ...[
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 24),
        ] else if (ieData != null) ...[
          () {
            final s = ref.watch(appStringsProvider);
            return Column(children: [
              // Chart 4 equivalent: yearly totals bar chart (Expenses + Savings per year)
              ExpansionTile(
                title: Text(s.chartYearlyBarTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                initiallyExpanded: true,
                children: [_YearlyBarChart(data: ieData, locale: locale, language: widget.language)],
              ),
              // Chart 2 equivalent: monthly averages bar chart per year
              ExpansionTile(
                title: Text(s.chartMonthlyAvgTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                children: [_MonthlyAvgBarChart(data: ieData, locale: locale, language: widget.language)],
              ),
              // Chart 3 equivalent: monthly income by year (x=months, one line per year)
              ExpansionTile(
                title: Text(s.chartMonthlyIncomeTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                children: [_MonthlyByYearLineChart(data: ieData, locale: locale, language: widget.language, field: 'income')],
              ),
              // Chart 5 equivalent: monthly expenses by year (x=months, recent years)
              ExpansionTile(
                title: Text(s.chartMonthlyExpensesTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                children: [_MonthlyByYearLineChart(data: ieData, locale: locale, language: widget.language, field: 'expenses', maxYears: 5)],
              ),
              // Tables
              ExpansionTile(
                title: Text(s.chartYearlySummaryTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                children: [_YearlySummaryTable(data: ieData, locale: locale)],
              ),
              ExpansionTile(
                title: Text(s.chartMonthlyIncTableTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                children: [_MonthlyGrid(data: ieData, locale: locale, language: widget.language, field: 'income')],
              ),
              ExpansionTile(
                title: Text(s.chartMonthlyExpTableTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                children: [_MonthlyGrid(data: ieData, locale: locale, language: widget.language, field: 'expenses', maxYears: 5)],
              ),
              ExpansionTile(
                title: Text(s.chartYoYTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                children: [_YoYDiffTable(data: ieData, locale: locale, language: widget.language)],
              ),
              const SizedBox(height: 24),
            ]);
          }(),
        ],
      ],
    );
  }
}
