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
    final statsAsync = ref.watch(assetStatsProvider);
    final marketValuesAsync = ref.watch(assetMarketValuesProvider);
    final accountStatsAsync = ref.watch(convertedAccountStatsProvider);
    final allDataAsync = ref.watch(allSeriesDataProvider);
    final ieAsync = ref.watch(_incomeExpenseDataProvider);
    // Income records left out of the yearly figures for want of a rate.
    final incomeRowsWithoutRate = ref.watch(incomeRowsWithoutRateProvider).value;
    final locale = ref.watch(appLocaleProvider).value ?? 'en_US';
    final swrPct = ref.watch(fireSwrProvider).value ?? kDefaultFireSwrPct;

    // Price changes for Today, YTD, All — use midnight dates to match History
    // tab. Yesterday is one calendar day back: 24 hours before a local
    // midnight is 23:00 two days before (or 01:00) around a daylight-saving
    // change.
    final today = ref.watch(currentDateProvider);
    final todayChanges = ref.watch(assetDailyChangesProvider(DateTime(today.year, today.month, today.day - 1)));
    final ytdChanges = ref.watch(assetDailyChangesProvider(DateTime(today.year, 1, 1)));
    final allChanges = ref.watch(assetDailyChangesProvider(DateTime(2000, 1, 1)));
    final pctFmt = NumberFormat('0.00', locale);

    // Wait for every input before rendering: a KPI computed from an input
    // still loading, or one that failed, would read its placeholder 0 as a
    // real figure.
    final inputs = <AsyncValue<Object?>>[assetsAsync, statsAsync, marketValuesAsync, accountStatsAsync, allDataAsync, ieAsync];
    if (inputs.any((a) => a.isLoading)) {
      return const Center(child: CircularProgressIndicator());
    }
    final failed = inputs.where((a) => a.hasError).firstOrNull;
    if (failed != null) return Center(child: Text(s.error(failed.error!)));

    return assetsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(s.error(e))),
      data: (assets) {
        final marketValues = marketValuesAsync.value ?? {};
        final stats = statsAsync.value ?? const {};
        final ieData = ieAsync.value;

        // Cash / Portfolio / Liquid Investments flow from the user's
        // configured History-tab charts (option B). Each falls back to the
        // hard-coded composition when the role chart is missing.
        final allData = allDataAsync.value;
        final userCharts = ref.watch(dashboardChartsProvider);
        final activeAssets = assets;
        final cash = allData == null ? 0.0 : _DashboardScreenState.valueForRole('cash', userCharts, allData, activeAssets);
        final investments = allData == null ? 0.0 : _DashboardScreenState.valueForRole('portfolio', userCharts, allData, activeAssets);
        final liquidInvestments = allData == null
            ? 0.0
            : _DashboardScreenState.valueForRole('liquid_investments', userCharts, allData, activeAssets);
        // After-tax Net Asset Value — drives the FIRE indicator.
        final netAssetValue = allData == null ? 0.0 : _DashboardScreenState.valueForRole('net_asset_value', userCharts, allData, activeAssets);

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
          final cutoff = DateTime(today.year - 1, today.month, today.day);
          for (final year in ieData.years) {
            for (final month in year.months) {
              if (DateTime(month.year, month.month).isAfter(cutoff)) {
                rollingIncome += month.income;
              }
            }
          }
        }

        var categories = computeKpis(
          cash: cash,
          investments: investments,
          liquidInvestments: liquidInvestments,
          annualIncome: annualIncome,
          rollingIncome: rollingIncome,
          annualExpenses: annualExpenses,
          annualSavings: annualSavings,
          monthlyExpenses: monthlyExpenses,
          s: s,
          locale: locale,
        );
        // A KPI whose inputs are missing is N/A: computeKpis reads a zero
        // base as a 0 ratio and rates it, so no balances, no income or no
        // expenses would come out as a Poor 0% / 0 months. The net worth is
        // missing when neither the cash nor the portfolio total has a value —
        // nothing held, or all of it left out for want of a rate.
        final netWorthRatios = [s.kpiLiquidityRatio, s.kpiInvestmentWeight, s.kpiLiquidAssetRatio, s.kpiIncomeToWealth];
        final netWorthKnown =
            allData != null &&
            ['cash', 'portfolio'].any((role) => _DashboardScreenState.spotsForRole(role, userCharts, allData, activeAssets).isNotEmpty);
        final missingInputs = <String>{
          if (!netWorthKnown) ...netWorthRatios,
          if (allData == null || monthlyExpenses <= 0) s.kpiExpenseCoverage,
          if (annualIncome <= 0) s.kpiSavingsRate,
          if (rollingIncome <= 0) s.kpiIncomeToWealth,
        };
        // A ratio over a known net worth of zero or less is N/A as well: it
        // means nothing. Its data is there, so it says that instead.
        final unavailable = <String, String>{
          for (final kpi in missingInputs) kpi: s.noData,
          if (netWorthKnown && cash + investments <= 0)
            for (final kpi in netWorthRatios)
              if (!missingInputs.contains(kpi)) kpi: s.kpiNetWorthNotPositive,
        };
        categories = [for (final cat in categories) _withUnavailable(cat, unavailable)];
        // What the balances above and the concentration below leave out for
        // want of a price or an exchange rate — never valued at cost, at 0 or
        // converted 1:1 — is counted under the summary, each contributor
        // once: whatever a role total leaves out ([totalExclusions]), and the
        // held assets without a market value today.
        final excluded = [
          if (allData != null)
            for (final role in const ['cash', 'portfolio', 'liquid_investments', 'net_asset_value'])
              totalExclusions(_DashboardScreenState._seriesForRole(role, userCharts, allData, activeAssets), allData),
          TotalExclusions(
            unpricedAssetIds: {
              for (final asset in activeAssets)
                if ((stats[asset.id]?.totalQuantity ?? 0) != 0 && !marketValues.containsKey(asset.id)) asset.id,
            },
          ),
        ].fold(const TotalExclusions(), (all, next) => all.union(next));

        // ── FIRE KPI: appended to the Wealth category ──
        //
        // Base = Net Asset Value (after-tax) — driven by the configured
        // `net_asset_value` role chart or its synthesized fallback.
        // The current calendar year is not consolidated, so use a smoothed
        // expense estimate = avg(EoY projection, full last year). When no
        // prior year is available the KPI is marked N/A — using YTD-only
        // would understate expenses and overstate FIRE progress. Its info icon
        // opens the FIRE dialog (see [_showFireDialog]), which spells out the
        // figures: the KPI carries no formula text of its own.
        final netWorth = netAssetValue;
        SmoothedAnnualExpenses? smoothed;
        if (ieData != null && ieData.years.isNotEmpty) {
          final cur = ieData.years.last;
          final prev = ieData.years.length >= 2 ? ieData.years[ieData.years.length - 2] : null;
          smoothed = estimateSmoothedAnnualExpenses(
            current: _toEoyYear(cur),
            prev: prev == null ? null : _toEoyYear(prev),
          );
        }
        final fireExpenses = smoothed?.value ?? 0;
        final fire = computeFire(
          netWorth: netWorth,
          annualExpenses: fireExpenses,
          swrPct: swrPct,
        );

        final fireKpi = HealthKpi(
          name: s.kpiFireProgress,
          value: fire.insufficientData ? null : fire.progressPct,
          rating: fire.rating,
          description: fire.insufficientData ? s.kpiFireInsufficientData() : fireDescription(fire.rating, s),
        );
        categories = [
          for (final cat in categories)
            if (cat.name == s.healthCatWealth)
              KpiCategory(
                name: cat.name,
                kpis: [...cat.kpis, fireKpi],
                overallRating: categoryRating([...cat.kpis, fireKpi]),
              )
            else
              cat,
        ];

        // Augment the Savings Rate KPI's info dialog with an EoY projection.
        if (ieData != null && ieData.years.length >= 2) {
          final current = ieData.years.last;
          final prev = ieData.years[ieData.years.length - 2];
          final eoySpan = buildEoyExplanationSpan(
            current: _toEoyYear(current),
            prev: _toEoyYear(prev),
            amtFmt: fmt.amountFormat(locale),
            pctFmt: NumberFormat('0.0%', locale),
            sym: currencySymbol(ieData.baseCurrency),
            s: s,
            locale: locale,
          );
          if (eoySpan != null) {
            categories = categories.map((cat) {
              if (cat.name != s.healthCatLiquidity) return cat;
              final newKpis = cat.kpis.map((k) {
                if (k.name != s.kpiSavingsRate) return k;
                // The symbolic first line of the formula, with its line break,
                // is the first child: privacy mode keeps it readable and
                // selectable ([_KpiFormula]). The figures plugged into it are
                // position size, marked like the projection's amounts; an N/A
                // rate has none.
                final [symbolic, ...figures] = k.formula.split('\n');
                final rich = TextSpan(
                  children: [
                    TextSpan(text: '$symbolic\n'),
                    if (figures.isNotEmpty) ...[PositionFigureSpan(text: figures.join('\n')), const TextSpan(text: '\n')],
                    const TextSpan(text: '\n'),
                    eoySpan,
                  ],
                );
                return HealthKpi(
                  name: k.name,
                  value: k.value,
                  unit: k.unit,
                  rating: k.rating,
                  description: k.description,
                  formula: k.formula,
                  formulaRich: rich,
                );
              }).toList();
              return KpiCategory(name: cat.name, kpis: newKpis, overallRating: cat.overallRating);
            }).toList();
          }
        }

        // Build Performance & Diversification category
        // What a price-change KPI left out, by KPI name: shown under it.
        final footnotes = <String, String>{};
        HealthKpi changeKpi(String name, AsyncValue<List<AssetDailyChange>> changes) {
          final data = changes.value;
          // Held assets without a price (today or at the reference date) or an
          // exchange rate are not in the change: counted under it, as the
          // Price Changes card counts them under its total.
          final unlisted = data == null ? 0 : _unlistedHeldAssets(activeAssets, stats, data);
          if (unlisted > 0) footnotes[name] = s.unpricedExcludedFromTotal(unlisted);
          // No price data: no value and no rating, not a 0.00% change.
          if (data == null || data.isEmpty) return HealthKpi(name: name, description: s.noData);
          final pairs = data
              .map(
                (c) => (
                  c.previousPrice * c.quantity / c.priceDivisor * c.previousFxRate,
                  c.todayPrice * c.quantity / c.priceDivisor * c.todayFxRate,
                ),
              )
              .toList();
          final pct = computePriceChangePct(pairs);
          return HealthKpi(name: name, value: pct, rating: ratePriceChange(pct));
        }

        // A position without a market value is left out (counted under the
        // summary, see [excluded]), never weighed as worth 0.
        final byPosition = <String, double>{};
        for (final asset in activeAssets) {
          final mv = marketValues[asset.id];
          if (mv != null && mv > 0) byPosition[asset.ticker ?? asset.name] = (byPosition[asset.ticker ?? asset.name] ?? 0) + mv;
        }
        final positionTotal = byPosition.values.fold(0.0, (a, b) => a + b);
        final conc = computeConcentration(byPosition.entries.toList(), positionTotal);

        // Funds without a TER on record are left out and counted (see
        // computeWeightedTer); nothing to weigh leaves the KPI unrated.
        final weightedTer = computeWeightedTer(activeAssets, marketValues);
        final ter = weightedTer.ter;

        final perfKpis = [
          changeKpi(s.kpiToday, todayChanges),
          changeKpi(s.kpiYtd, ytdChanges),
          changeKpi(s.kpiAllTime, allChanges),
          // No valued holding: no concentration to measure, not an HHI of 0
          // rated as perfectly diversified.
          HealthKpi(
            name: s.hhiLabel,
            value: byPosition.isEmpty ? null : conc.hhi,
            unit: '',
            rating: byPosition.isEmpty ? Rating.na : rateHhi(conc.hhi),
            formula: '${s.hhiFullName}\n< 1500 = ${s.allocWellDiversified}\n< 2500 = ${s.allocModeratelyConcentrated}',
          ),
          HealthKpi(
            name: s.healthTer,
            value: ter,
            unit: '%',
            rating: ter == null ? Rating.na : rateTer(ter),
            formula: [
              s.healthWeightedTer,
              ter == null ? '-' : '${pctFmt.format(ter)}%',
              if (weightedTer.unknownTerFunds > 0) s.terUnknownExcluded(weightedTer.unknownTerFunds),
            ].join('\n'),
          ),
        ];
        final perfCategory = KpiCategory(
          name: s.healthPerformance,
          kpis: perfKpis,
          overallRating: categoryRating(perfKpis),
        );
        final allCategories = [...categories, perfCategory];

        // Overall score includes all categories; nothing rated, no score.
        final allKpis = allCategories.expand((c) => c.kpis).toList();
        final ratedKpis = allKpis.where((k) => k.rating != Rating.na).toList();
        final overallScore = ratedKpis.isEmpty ? null : ratedKpis.map((k) => k.rating.score).reduce((a, b) => a + b) / ratedKpis.length;
        final overallRating = overallScore == null
            ? Rating.na
            : overallScore >= 87
            ? Rating.ottimo
            : overallScore >= 62
            ? Rating.buono
            : overallScore >= 37
            ? Rating.sufficiente
            : Rating.scarso;

        return MobilePullToRefresh(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Summary row ──
                _SummarySection(
                  score: overallScore,
                  overallRating: overallRating,
                  categories: allCategories,
                  s: s,
                ),
                _ExcludedFromTotalNote(excluded, plural: true, top: 8),
                if (incomeRowsWithoutRate != null && incomeRowsWithoutRate > 0) ...[
                  const SizedBox(height: 8),
                  Footnote(s.incomeFxExcluded(incomeRowsWithoutRate)),
                ],
                const SizedBox(height: 24),

                // ── KPI Cards (all categories including Performance & Diversification) ──
                Text(s.healthKpis, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                for (final cat in allCategories) ...[
                  const SizedBox(height: 16),
                  Text(
                    cat.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cards = cat.kpis
                          .map(
                            (kpi) => _KpiCard(
                              kpi: kpi,
                              pctFmt: pctFmt,
                              s: s,
                              footnote: footnotes[kpi.name],
                              // Liquidity and Wealth formulas plug in cash, income,
                              // expenses and net worth; the Performance ones only
                              // percentages and index thresholds.
                              formulaFiguresArePrivate: cat != perfCategory,
                              onInfoTap: kpi.name == s.kpiFireProgress
                                  ? () => _showFireDialog(
                                      context: context,
                                      s: s,
                                      locale: locale,
                                      netWorth: netWorth,
                                      annualExpenses: fireExpenses,
                                      smoothed: smoothed,
                                      currentSwr: swrPct,
                                    )
                                  : null,
                            ),
                          )
                          .toList();
                      if (constraints.maxWidth < 680) {
                        return Column(
                          children: cards
                              .map(
                                (card) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: card,
                                ),
                              )
                              .toList(),
                        );
                      }
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: cards
                            .map(
                              (card) => ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 320),
                                child: card,
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// [cat] with the KPIs named in [unavailable] made N/A, each saying why with
/// the description it is mapped to (see [_naKpi]), and its rating taken over
/// the rest.
KpiCategory _withUnavailable(KpiCategory cat, Map<String, String> unavailable) {
  if (!cat.kpis.any((k) => unavailable.containsKey(k.name))) return cat;
  final kpis = [
    for (final k in cat.kpis)
      if (unavailable[k.name] case final why?) _naKpi(k, why) else k,
  ];
  return KpiCategory(name: cat.name, kpis: kpis, overallRating: categoryRating(kpis));
}

/// [kpi] that cannot be computed, for the reason [description] gives: no
/// value ("-"), no rating, and only the symbolic first line of its formula —
/// no placeholder figures.
HealthKpi _naKpi(HealthKpi kpi, String description) => HealthKpi(
  name: kpi.name,
  unit: kpi.unit,
  description: description,
  formula: kpi.formula.split('\n').first,
);

// ── Summary section ──

class _SummarySection extends StatelessWidget {
  /// Average score of the rated KPIs; null when none is rated.
  final double? score;
  final Rating overallRating;
  final List<KpiCategory> categories;
  final AppStrings s;

  const _SummarySection({
    required this.score,
    required this.overallRating,
    required this.categories,
    required this.s,
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
                painter: _ScoreGaugePainter(score: score ?? 0, color: overallRating.color),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        score == null ? '-' : score!.round().toString(),
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
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = Colors.grey.shade800
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );

    // Filled arc
    final fillSweep = sweepAngle * (score / 100).clamp(0, 1);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      fillSweep,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreGaugePainter oldDelegate) => oldDelegate.score != score || oldDelegate.color != color;
}

// ── KPI Card ──

class _KpiCard extends StatefulWidget {
  final HealthKpi kpi;
  final NumberFormat pctFmt;
  final AppStrings s;

  /// Optional override for the info icon tap. When set, the default
  /// formula dialog is bypassed.
  final VoidCallback? onInfoTap;

  /// The figures plugged into the formula are position size, masked in
  /// privacy mode. False when they are only percentages or thresholds.
  final bool formulaFiguresArePrivate;

  /// What the value leaves out (e.g. the assets without a price), shown
  /// under the KPI name.
  final String? footnote;

  const _KpiCard({
    required this.kpi,
    required this.pctFmt,
    required this.s,
    this.onInfoTap,
    this.formulaFiguresArePrivate = true,
    this.footnote,
  });

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final kpi = widget.kpi;
    final theme = Theme.of(context);

    final valueText = kpi.value != null ? (kpi.unit == '%' ? '${widget.pctFmt.format(kpi.value!)}%' : '${kpi.value!.round()}${kpi.unit}') : '-';

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
                  child: Text(
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
            if (widget.footnote case final footnote?) ...[
              const SizedBox(height: 2),
              Footnote(footnote),
            ],
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
                if (kpi.formula.isNotEmpty || kpi.formulaRich != null || widget.onInfoTap != null)
                  InkWell(
                    onTap: () {
                      if (widget.onInfoTap != null) {
                        widget.onInfoTap!();
                        return;
                      }
                      final baseStyle = TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      );
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(kpi.name, style: const TextStyle(fontSize: 14)),
                          content: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: SingleChildScrollView(
                              child: _KpiFormula(kpi: kpi, style: baseStyle, figuresArePrivate: widget.formulaFiguresArePrivate),
                            ),
                          ),
                          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(widget.s.close))],
                        ),
                      );
                    },
                    child: Icon(Icons.info_outline, size: 16, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  ),
              ],
            ),
            // Details grow in and out; the header above never changes.
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              kpi.rating == Rating.scarso
                                  ? Icons.error
                                  : kpi.rating == Rating.sufficiente
                                  ? Icons.warning
                                  : Icons.check_circle,
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
                        // An unrated KPI has no place on the scale: the marker
                        // would sit in the red zone.
                        if (kpi.rating != Rating.na) _TrafficLightGauge(rating: kpi.rating, value: kpi.value ?? 0),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// A KPI's formula: the symbolic formula on its first line, then the user's
/// own figures plugged into it (and, for some KPIs, a longer explanation).
///
/// When those figures are position size ([figuresArePrivate]), privacy mode
/// masks them and renders everything below the first line as plain text, so
/// the amounts can be neither read nor copied out; the symbolic formula stays
/// readable and selectable. A plain [HealthKpi.formula] is all figures below
/// its first line and blurs as one block; a [HealthKpi.formulaRich] carries
/// its first line, with its line break, as its first child, and marks its
/// figures itself ([PositionFigureSpan]): only they blur — the words, months
/// and percentages around them stay readable.
class _KpiFormula extends ConsumerWidget {
  final HealthKpi kpi;
  final TextStyle style;
  final bool figuresArePrivate;

  const _KpiFormula({required this.kpi, required this.style, required this.figuresArePrivate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrivate = ref.watch(privacyModeProvider) && figuresArePrivate;
    final rich = kpi.formulaRich;
    if (!isPrivate) {
      return rich != null ? SelectableText.rich(rich, style: style) : SelectableText(kpi.formula, style: style);
    }
    final String symbolic;
    final Widget figures;
    if (rich == null) {
      final [first, ...rest] = kpi.formula.split('\n');
      symbolic = first;
      figures = PrivacyBlur(child: Text(rest.join('\n'), style: style));
    } else {
      final [head, ...rest] = rich.children!;
      // Its line break is the one between the two texts below.
      symbolic = head.toPlainText().split('\n').first;
      figures = Text.rich(TextSpan(children: [for (final span in rest) _maskFigures(span, style)]), style: style);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SelectableText(symbolic, style: style),
        figures,
      ],
    );
  }
}

/// [span] with every [PositionFigureSpan] in it masked ([privacyFigureSpan])
/// in [style], merged with the styles of the spans it sits in.
InlineSpan _maskFigures(InlineSpan span, TextStyle style) => switch (span) {
  PositionFigureSpan(text: final text, style: final own) => privacyFigureSpan(text ?? '', style: style.merge(own)),
  TextSpan(text: final text, style: final own, children: final children?) => TextSpan(
    text: text,
    style: own,
    children: [for (final child in children) _maskFigures(child, style.merge(own))],
  ),
  _ => span,
};

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
    canvas.drawCircle(
      Offset(markerX, h / 2),
      6,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(markerX, h / 2),
      6,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.position != position;
}

// ── FIRE info + SWR editor dialog ──

Future<void> _showFireDialog({
  required BuildContext context,
  required AppStrings s,
  required String locale,
  required double netWorth,
  required double annualExpenses,
  required SmoothedAnnualExpenses? smoothed,
  required double currentSwr,
}) => showDialog<void>(
  context: context,
  builder: (_) => _FireDialog(
    s: s,
    locale: locale,
    netWorth: netWorth,
    annualExpenses: annualExpenses,
    smoothed: smoothed,
    currentSwr: currentSwr,
  ),
);

/// FIRE explanation with a live SWR editor. Owns its text controller and
/// disposes it with the dialog, after the closing animation stopped
/// rebuilding the field.
class _FireDialog extends ConsumerStatefulWidget {
  final AppStrings s;
  final String locale;
  final double netWorth;
  final double annualExpenses;
  final SmoothedAnnualExpenses? smoothed;
  final double currentSwr;

  const _FireDialog({
    required this.s,
    required this.locale,
    required this.netWorth,
    required this.annualExpenses,
    required this.smoothed,
    required this.currentSwr,
  });

  @override
  ConsumerState<_FireDialog> createState() => _FireDialogState();
}

class _FireDialogState extends ConsumerState<_FireDialog> {
  late final NumberFormat _swrFmt = NumberFormat('0.00', widget.locale);
  // Every digit of the stored rate: an untouched save keeps it as it is.
  late final TextEditingController _controller = TextEditingController(
    text: fmt.editableFigure(widget.currentSwr, _swrFmt, locale: widget.locale),
  );
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _storeSwr(double swr) {
    final db = ref.read(databaseProvider);
    return db.into(db.appConfigs).insertOnConflictUpdate(AppConfigsCompanion.insert(key: 'FIRE_SWR', value: swr.toString()));
  }

  /// The typed rate, read strictly in the display locale; null while the
  /// field is empty or holds text the locale cannot read.
  double? get _typedSwr => fmt.readOptionalNumber(_controller.text, locale: widget.locale).value;

  /// Why [text] is not a usable rate, or null when it is a positive number.
  String? _swrError(String text) {
    final typed = fmt.readOptionalNumber(text, locale: widget.locale);
    if (typed.invalid) return widget.s.invalidNumber;
    final value = typed.value;
    return value == null || value <= 0 ? widget.s.fireSwrInvalid : null;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final smoothed = widget.smoothed;
    final swrFmt = _swrFmt;
    final amtFmt = fmt.amountFormat(widget.locale);
    final parsed = _typedSwr;
    final effectiveSwr = (parsed != null && parsed > 0) ? parsed : widget.currentSwr;
    final preview = computeFire(
      netWorth: widget.netWorth,
      annualExpenses: widget.annualExpenses,
      swrPct: effectiveSwr,
    );
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(s.fireDialogTitle, style: const TextStyle(fontSize: 14)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.fireDialogIntro, style: TextStyle(fontSize: 12, height: 1.5, color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: TextFormField(
                  controller: _controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: s.fireSwrLabel,
                    hintText: s.fireSwrHint,
                    suffixText: '%',
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => _swrError(v ?? ''),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 12),
              if (!preview.insufficientData) ...[
                _FireDialogRow(
                  label: s.fireExpensesEstimateLabel,
                  value: amtFmt.format(widget.annualExpenses),
                ),
                if (smoothed != null && smoothed.projectedCurrent != null) ...[
                  const SizedBox(height: 2),
                  _FireDialogRow(
                    label:
                        '  ${s.fireProjectedCurrent}'
                        '${smoothed.projectionMonths != null ? ' ${s.fireProjectionMonths(smoothed.projectionMonths!)}' : ''}',
                    value: amtFmt.format(smoothed.projectedCurrent!),
                    subtle: true,
                  ),
                ],
                if (smoothed != null && smoothed.prevTotal != null) ...[
                  const SizedBox(height: 2),
                  _FireDialogRow(
                    label: '  ${s.fireLastYearTotal}',
                    value: amtFmt.format(smoothed.prevTotal!),
                    subtle: true,
                  ),
                ],
                const SizedBox(height: 8),
                _FireDialogRow(label: s.fireNumberLabel, value: amtFmt.format(preview.fiNumber)),
                const SizedBox(height: 4),
                _FireDialogRow(
                  label: s.fireProgressLabel,
                  value: '${swrFmt.format(preview.progressPct)}%',
                  masked: false,
                ),
              ] else
                Text(s.kpiFireInsufficientData(), style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            _controller.text = fmt.editableFigure(kDefaultFireSwrPct, swrFmt, locale: widget.locale);
            setState(() {});
            await _storeSwr(kDefaultFireSwrPct);
          },
          child: Text(s.fireResetDefault),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          onPressed: () async {
            if (_formKey.currentState?.validate() != true) return;
            await _storeSwr(_typedSwr!);
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(s.save),
        ),
      ],
    );
  }
}

class _FireDialogRow extends StatelessWidget {
  final String label;
  final String value;
  final bool subtle;

  /// [value] is position size (expenses, the FI target), masked in privacy
  /// mode. False for the coverage percentage: shape, not magnitude.
  final bool masked;
  const _FireDialogRow({required this.label, required this.value, this.subtle = false, this.masked = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valStyle = subtle
        ? TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)
        : const TextStyle(fontSize: 13, fontWeight: FontWeight.w600);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: subtle ? 11 : 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        PrivacyText(value, style: valStyle, masked: masked),
      ],
    );
  }
}
