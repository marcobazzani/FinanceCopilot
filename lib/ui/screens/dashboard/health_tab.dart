part of 'dashboard_screen.dart';

// ════════════════════════════════════════════════════
// Financial Health Tab — KPIs
// ════════════════════════════════════════════════════

// KPI computation logic lives in lib/services/pillars/financial_health_service.dart
// (ratings, scores, the KPIs themselves) and the balances they are built from
// in health_balance_sheet.dart.

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
    final today = ref.watch(currentDateProvider);
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
        final allData = allDataAsync.value;
        final userCharts = ref.watch(dashboardChartsProvider);
        final activeAssets = assets;

        // The balances every ratio is built from. They flow from the user's
        // configured History-tab charts (Total Assets, Portfolio, Liquid
        // Investments, Net Asset Value), each falling back to its hard-coded
        // composition when the role chart is missing. Null: no balance and no
        // holding has a value.
        final sheet = allData == null ? null : computeHealthBalanceSheet(charts: userCharts, allData: allData, activeAssets: activeAssets);

        // The current year for savings. The monthly expenses of the coverage and
        // the FIRE number share one yearly estimate: the current calendar year is
        // not consolidated, so it is smoothed as avg(EoY projection, full last
        // year). With no prior year the FIRE number is N/A — using YTD-only
        // would understate expenses and overstate FIRE progress — and the
        // coverage falls back to the average of this year, saying so.
        var annualIncome = 0.0, annualSavings = 0.0, thisYearMonthlyExpenses = 0.0;
        SmoothedAnnualExpenses? smoothed;
        if (ieData != null && ieData.years.isNotEmpty) {
          final current = ieData.years.last;
          final prev = ieData.years.length >= 2 ? ieData.years[ieData.years.length - 2] : null;
          annualIncome = current.income;
          annualSavings = current.savings;
          thisYearMonthlyExpenses = current.monthlyExpenses > 0 ? current.monthlyExpenses : 0;
          smoothed = estimateSmoothedAnnualExpenses(
            current: _toEoyYear(current),
            prev: prev == null ? null : _toEoyYear(prev),
          );
        }
        final rollingIncome = ieData == null ? 0.0 : incomeOverLastYear(ieData.incomeRecords, today);

        var categories = computeKpis(
          sheet: sheet,
          annualIncome: annualIncome,
          annualSavings: annualSavings,
          rollingIncome: rollingIncome,
          estimatedAnnualExpenses: smoothed?.value,
          thisYearMonthlyExpenses: thisYearMonthlyExpenses,
          s: s,
          locale: locale,
        );
        // What the balances above and the concentration below leave out for
        // want of a price or an exchange rate — never valued at cost, at 0 or
        // converted 1:1 — is counted under the summary, each contributor
        // once: whatever a role total leaves out ([totalExclusions]), and the
        // held assets without a market value today.
        final excluded = [
          if (allData != null)
            for (final role in const ['cash', 'total_assets', 'portfolio', 'liquid_investments', 'net_asset_value'])
              totalExclusions(_DashboardScreenState._seriesForRole(role, userCharts, allData, activeAssets), allData),
          TotalExclusions(
            unpricedAssetIds: {
              for (final asset in activeAssets)
                if ((stats[asset.id]?.totalQuantity ?? 0) != 0 && !marketValues.containsKey(asset.id)) asset.id,
            },
          ),
        ].fold(const TotalExclusions(), (all, next) => all.union(next));

        // ── FIRE number: appended to the Financial & Wealth category ──
        //
        // The yearly expenses over the Safe Withdrawal Rate, rated on how much
        // of it the investable net worth covers. Its info icon opens the FIRE
        // dialog (see [_showFireDialog]), which spells out the figures.
        final investableNetWorth = sheet?.investableNetWorth ?? 0;
        final fireExpenses = smoothed?.value ?? 0;
        final fire = computeFire(netWorth: investableNetWorth, annualExpenses: fireExpenses, swrPct: swrPct);
        final moneyFmt = NumberFormat.decimalPattern(locale);
        final currency = currencySymbol(allData?.baseCurrency ?? ieData?.baseCurrency ?? '');
        final fireCard = sheet == null
            ? HealthKpi(name: s.kpiFireNumber, description: s.noData)
            : fireKpi(fire: fire, s: s, pctFmt: pctFmt, money: (amount) => '${moneyFmt.format(amount.round())} $currency');
        categories = [
          for (final cat in categories)
            if (cat.name == s.healthCatWealth) KpiCategory(name: cat.name, kpis: [...cat.kpis, fireCard]) else cat,
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
              return KpiCategory(name: cat.name, kpis: newKpis);
            }).toList();
          }
        }

        // ── Performance & Diversification ──
        // What a KPI left out, by KPI name: shown under it.
        final footnotes = <String, String>{};

        // Every asset but the liabilities: a debt is not an investment.
        final performance = allData == null
            ? null
            : computePillarPerformanceSnapshot(
                asOfDate: today,
                allData: allData,
                fractions: {
                  for (final asset in activeAssets)
                    if (asset.instrumentType != InstrumentType.liability) asset.id: 1.0,
                },
              );
        if (performance != null && performance.excludedAssetCount > 0) {
          footnotes[s.kpiAnnualizedReturn] = s.pillarPerformanceExcluded(performance.excludedAssetCount);
        }

        // Funds without a TER on record are left out and counted (see
        // computeWeightedTer); nothing to weigh leaves the KPI unrated.
        final weightedTer = computeWeightedTer(activeAssets, marketValues);
        final ter = weightedTer.ter;

        final perfKpis = [
          annualizedReturnKpi(snapshot: performance, s: s, locale: locale),
          // A position without a market value is left out (counted under the
          // summary, see [excluded]), never weighed as worth 0.
          largestPositionKpi(position: computeLargestPosition(activeAssets, marketValues), s: s, locale: locale),
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
            formulaFiguresPrivate: false,
          ),
        ];
        final perfCategory = KpiCategory(name: s.healthPerformance, kpis: perfKpis);
        final allCategories = [...categories, perfCategory];

        // The score is the mean of the categories, so each weighs the same;
        // nothing rated, no score.
        final overall = overallHealth(allCategories);

        return MobilePullToRefresh(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Summary row ──
                _SummarySection(
                  score: overall.score,
                  overallRating: overall.rating,
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
                              onInfoTap: kpi.name == s.kpiFireNumber
                                  ? () => _showFireDialog(
                                      context: context,
                                      s: s,
                                      locale: locale,
                                      netWorth: investableNetWorth,
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

  /// What the value leaves out (e.g. the assets without a price), shown
  /// under the KPI name.
  final String? footnote;

  const _KpiCard({
    required this.kpi,
    required this.pctFmt,
    required this.s,
    this.onInfoTap,
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
    const valueStyle = TextStyle(fontSize: 28, fontWeight: FontWeight.bold);

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
                  // An amount of money is position size; a percentage, a count
                  // of months or an index is not.
                  child: kpi.amountLabel != null ? PrivacyText(kpi.amountLabel!, style: valueStyle) : Text(valueText, style: valueStyle),
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
            if (kpi.subtitle case final subtitle?) Text(subtitle, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
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
                              child: _KpiFormula(kpi: kpi, style: baseStyle, figuresArePrivate: kpi.formulaFiguresPrivate),
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
                _FireDialogRow(label: s.fireAssetsLabel, value: amtFmt.format(widget.netWorth)),
                const SizedBox(height: 4),
                _FireDialogRow(label: s.fireGapLabel, value: amtFmt.format(max(0.0, preview.fiNumber - widget.netWorth))),
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
