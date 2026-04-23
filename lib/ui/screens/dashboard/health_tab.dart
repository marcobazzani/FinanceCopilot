part of 'dashboard_screen.dart';

// ════════════════════════════════════════════════════
// Financial Health Tab — KPIs + Investment Costs
// ════════════════════════════════════════════════════

// KPI computation logic lives in lib/services/financial_health_service.dart
// (Rating, HealthKpi, KpiCategory, rateNormal, categoryRating, computeKpis)

// ── Main widget ──

class _FinancialHealthTab extends ConsumerWidget {
  const _FinancialHealthTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final assetsAsync = ref.watch(activeAssetsProvider);
    final marketValuesAsync = ref.watch(assetMarketValuesProvider);
    final accountStatsAsync = ref.watch(convertedAccountStatsProvider);
    final allDataAsync = ref.watch(allSeriesDataProvider);
    final ieAsync = ref.watch(_incomeExpenseDataProvider);
    final locale = ref.watch(appLocaleProvider).value ?? 'en_US';

    // Price changes for Today, YTD, All — use midnight dates to match History tab
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayChanges = ref.watch(assetDailyChangesProvider(today.subtract(const Duration(days: 1))));
    final ytdChanges = ref.watch(assetDailyChangesProvider(DateTime(today.year, 1, 1)));
    final allChanges = ref.watch(assetDailyChangesProvider(DateTime(2000, 1, 1)));
    final isPrivate = ref.watch(privacyModeProvider);

    final pctFmt = NumberFormat('0.00', locale);

    // Wait for all required data before rendering — avoids flicker with zeros
    if (assetsAsync.isLoading || marketValuesAsync.isLoading || accountStatsAsync.isLoading || allDataAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (assetsAsync.hasError) return Center(child: Text(s.error(assetsAsync.error ?? '')));

    return assetsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(s.error(e))),
      data: (assets) {
        final marketValues = marketValuesAsync.value ?? {};
        final ieData = ieAsync.value;

        // Cash / Portfolio / Liquid Investments flow from the user's
        // configured History-tab charts (option B). Each falls back to the
        // hard-coded composition when the role chart is missing.
        final allData = allDataAsync.value;
        final userCharts = ref.watch(dashboardChartsProvider).value ?? const <DashboardChart>[];
        final activeAssets = assets;
        final cash = allData == null
            ? 0.0
            : _DashboardScreenState.valueForRole('cash', userCharts, allData, activeAssets);
        final investments = allData == null
            ? 0.0
            : _DashboardScreenState.valueForRole('portfolio', userCharts, allData, activeAssets);
        final liquidInvestments = allData == null
            ? 0.0
            : _DashboardScreenState.valueForRole('liquid_investments', userCharts, allData, activeAssets);

        // Current year for savings/expenses. Rolling 12m for income-to-wealth.
        double annualIncome = 0, annualExpenses = 0, annualSavings = 0, monthlyExpenses = 0;
        double rollingIncome = 0;
        if (ieData != null && ieData.years.isNotEmpty) {
          final currentYear = ieData.years.last;
          annualIncome = currentYear.income;
          annualExpenses = currentYear.expenses > 0 ? currentYear.expenses : 0;
          annualSavings = currentYear.savings;
          monthlyExpenses = currentYear.monthlyExpenses > 0 ? currentYear.monthlyExpenses : 0;
          // Rolling 12 months income for income-to-wealth ratio
          final now = DateTime.now();
          final cutoff = DateTime(now.year - 1, now.month, now.day);
          for (final year in ieData.years) {
            for (final month in year.months) {
              if (DateTime(month.year, month.month).isAfter(cutoff)) {
                rollingIncome += month.income;
              }
            }
          }
        }

        final categories = computeKpis(
          cash: cash, investments: investments,
          liquidInvestments: liquidInvestments,
          annualIncome: annualIncome, rollingIncome: rollingIncome,
          annualExpenses: annualExpenses,
          annualSavings: annualSavings, monthlyExpenses: monthlyExpenses,
          s: s, locale: locale,
        );

        // Build Performance & Diversification category
        HealthKpi changeKpi(String name, AsyncValue<List<AssetDailyChange>> changes) {
          final data = changes.value;
          if (data == null || data.isEmpty) return HealthKpi(name: name, value: 0, rating: Rating.na);
          final pairs = data.map((c) => (
            c.previousPrice * c.quantity / c.priceDivisor * c.previousFxRate,
            c.todayPrice * c.quantity / c.priceDivisor * c.todayFxRate,
          )).toList();
          final pct = computePriceChangePct(pairs);
          return HealthKpi(name: name, value: pct, rating: ratePriceChange(pct));
        }
        final byPosition = <String, double>{};
        for (final asset in activeAssets) {
          final mv = marketValues[asset.id] ?? 0.0;
          if (mv > 0) byPosition[asset.ticker ?? asset.name] = (byPosition[asset.ticker ?? asset.name] ?? 0) + mv;
        }
        final positionTotal = byPosition.values.fold(0.0, (a, b) => a + b);
        final conc = computeConcentration(byPosition.entries.toList(), positionTotal);

        var terCost = 0.0, terTotal = 0.0;
        for (final asset in activeAssets) {
          final mv = marketValues[asset.id] ?? 0.0;
          if (mv <= 0) continue;
          terTotal += mv;
          if (asset.ter != null && asset.ter! > 0) terCost += mv * asset.ter! / 100;
        }
        final weightedTer = terTotal > 0 ? terCost / terTotal * 100 : 0.0;

        final perfKpis = [
          changeKpi(s.kpiToday, todayChanges),
          changeKpi(s.kpiYtd, ytdChanges),
          changeKpi(s.kpiAllTime, allChanges),
          HealthKpi(name: 'HHI', value: conc.hhi, unit: '', rating: rateHhi(conc.hhi),
            formula: 'Herfindahl-Hirschman Index\n< 1500 = ${s.allocWellDiversified}\n< 2500 = ${s.allocModeratelyConcentrated}'),
          HealthKpi(name: s.healthTer, value: weightedTer, unit: '%',
            rating: weightedTer <= 0.2 ? Rating.ottimo : weightedTer <= 0.5 ? Rating.buono : weightedTer <= 1.0 ? Rating.sufficiente : Rating.scarso,
            formula: 'Weighted Avg TER\n${pctFmt.format(weightedTer)}%'),
        ];
        final perfCategory = KpiCategory(
          name: s.healthPerformance,
          kpis: perfKpis,
          overallRating: categoryRating(perfKpis),
        );
        final allCategories = [...categories, perfCategory];

        // Overall score includes all categories
        final allKpis = allCategories.expand((c) => c.kpis).toList();
        final ratedKpis = allKpis.where((k) => k.rating != Rating.na).toList();
        final overallScore = ratedKpis.isEmpty ? 0.0
            : ratedKpis.map((k) => k.rating.score).reduce((a, b) => a + b) / ratedKpis.length;
        final overallRating = overallScore >= 87 ? Rating.ottimo
            : overallScore >= 62 ? Rating.buono
            : overallScore >= 37 ? Rating.sufficiente
            : Rating.scarso;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Summary row ──
              _SummarySection(
                score: overallScore,
                overallRating: overallRating,
                categories: allCategories,
                s: s,
                isPrivate: isPrivate,
              ),
              const SizedBox(height: 24),

              // ── KPI Cards (all categories including Performance & Diversification) ──
              Text(s.healthKpis, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              for (final cat in allCategories) ...[
                const SizedBox(height: 16),
                Text(cat.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cards = cat.kpis.map((kpi) => _KpiCard(kpi: kpi, pctFmt: pctFmt, s: s, isPrivate: isPrivate)).toList();
                    if (constraints.maxWidth < 680) {
                      return Column(
                        children: cards.map((card) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: card,
                        )).toList(),
                      );
                    }
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: cards.map((card) => ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: card,
                      )).toList(),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Summary section ──

class _SummarySection extends StatelessWidget {
  final double score;
  final Rating overallRating;
  final List<KpiCategory> categories;
  final AppStrings s;
  final bool isPrivate;

  const _SummarySection({
    required this.score, required this.overallRating,
    required this.categories, required this.s, required this.isPrivate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Score gauge
            SizedBox(
              width: 120,
              height: 120,
              child: CustomPaint(
                painter: _ScoreGaugePainter(score: score, color: overallRating.color),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isPrivate ? '••' : score.round().toString(),
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: overallRating.color),
                      ),
                      Text(overallRating.label(s), style: TextStyle(fontSize: 12, color: overallRating.color)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            // Category ratings
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.healthSummary, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  for (final cat in categories)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(child: Text(cat.name, style: const TextStyle(fontSize: 13))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: cat.overallRating.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              cat.overallRating.label(s),
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cat.overallRating.color),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Circular score gauge painter ──

class _ScoreGaugePainter extends CustomPainter {
  final double score;
  final Color color;
  _ScoreGaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const startAngle = 2.3; // ~132°
    const sweepAngle = 4.6; // ~264° arc

    // Background arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepAngle, false,
      Paint()..color = Colors.grey.shade800..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round,
    );

    // Filled arc
    final fillSweep = sweepAngle * (score / 100).clamp(0, 1);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, fillSweep, false,
      Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreGaugePainter oldDelegate) =>
      oldDelegate.score != score || oldDelegate.color != color;
}

// ── KPI Card ──

class _KpiCard extends StatefulWidget {
  final HealthKpi kpi;
  final NumberFormat pctFmt;
  final AppStrings s;
  final bool isPrivate;

  const _KpiCard({required this.kpi, required this.pctFmt, required this.s, required this.isPrivate});

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final kpi = widget.kpi;
    final theme = Theme.of(context);

    final valueText = kpi.value != null
        ? (kpi.unit == '%'
            ? '${widget.pctFmt.format(kpi.value!)}%'
            : '${kpi.value!.round()}${kpi.unit}')
        : '-';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Value + rating badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: PrivacyText(
                    valueText,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kpi.rating.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kpi.rating.color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    kpi.rating.label(widget.s),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kpi.rating.color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // KPI name
            Text(kpi.name, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            // Expand toggle + info
            Row(
              children: [
                InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Row(
                    children: [
                      Text(widget.s.healthDetails, style: TextStyle(fontSize: 12, color: theme.colorScheme.primary)),
                      Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 16, color: theme.colorScheme.primary),
                    ],
                  ),
                ),
                const Spacer(),
                if (kpi.formula.isNotEmpty)
                  InkWell(
                    onTap: () => showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(kpi.name, style: const TextStyle(fontSize: 14)),
                        content: Text(kpi.formula, style: TextStyle(fontSize: 13, fontFamily: 'monospace', color: theme.colorScheme.onSurfaceVariant)),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                      ),
                    ),
                    child: Icon(Icons.info_outline, size: 16, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    kpi.rating == Rating.scarso ? Icons.error : kpi.rating == Rating.sufficiente ? Icons.warning : Icons.check_circle,
                    size: 16,
                    color: kpi.rating.color,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(kpi.description, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _TrafficLightGauge(rating: kpi.rating, value: kpi.value ?? 0),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Traffic light gauge ──

class _TrafficLightGauge extends StatelessWidget {
  final Rating rating;
  final double value;

  const _TrafficLightGauge({required this.rating, required this.value});

  @override
  Widget build(BuildContext context) {
    // 4-zone gauge: scarso | sufficiente | buono | ottimo
    final position = (rating.score / 100).clamp(0.05, 0.95);
    return SizedBox(
      height: 14,
      child: CustomPaint(
        size: const Size(double.infinity, 14),
        painter: _GaugePainter(position: position),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double position;
  _GaugePainter({required this.position});

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    final r = h / 2;

    final zones = [
      (const Color(0xFFF44336), 0.25), // red
      (const Color(0xFFFF9800), 0.25), // orange
      (const Color(0xFF4CAF50).withValues(alpha: 0.5), 0.25), // light green
      (const Color(0xFF4CAF50), 0.25), // green
    ];

    var x = 0.0;
    for (final (color, fraction) in zones) {
      final zoneWidth = w * fraction;
      final rect = RRect.fromLTRBR(x, 2, x + zoneWidth, h - 2, Radius.circular(r));
      canvas.drawRRect(rect, Paint()..color = color);
      x += zoneWidth;
    }

    // Marker
    final markerX = (w * position).clamp(r, w - r);
    canvas.drawCircle(Offset(markerX, h / 2), 6, Paint()..color = Colors.white..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(markerX, h / 2), 6, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.position != position;
}

