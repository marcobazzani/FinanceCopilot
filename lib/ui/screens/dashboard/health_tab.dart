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
    final assetsAsync = ref.watch(assetsProvider);
    final marketValuesAsync = ref.watch(assetMarketValuesProvider);
    final accountStatsAsync = ref.watch(convertedAccountStatsProvider);
    final ieAsync = ref.watch(_incomeExpenseDataProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider).value ?? 'EUR';
    final locale = ref.watch(appLocaleProvider).value ?? 'en_US';
    final isPrivate = ref.watch(privacyModeProvider);

    final symbol = currencySymbol(baseCurrency);
    final amtFmt = fmt.currencyFormat(locale, symbol, decimalDigits: 0);
    final pctFmt = NumberFormat('0.00', locale);

    return assetsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(s.error(e))),
      data: (assets) {
        final marketValues = marketValuesAsync.value ?? {};
        final accountStats = accountStatsAsync.value ?? {};
        final ieData = ieAsync.value;

        // Compute totals
        final cash = accountStats.values.whereType<double>().fold(0.0, (a, b) => a + b);
        final activeAssets = assets.where((a) => a.isActive).toList();
        double investments = 0;
        for (final asset in activeAssets) {
          investments += marketValues[asset.id] ?? 0.0;
        }

        // Current year for expenses/savings (most recent data).
        // Last complete year for income (current year is incomplete).
        double annualIncome = 0, annualExpenses = 0, annualSavings = 0, monthlyExpenses = 0;
        if (ieData != null && ieData.years.isNotEmpty) {
          final currentYear = ieData.years.last;
          annualExpenses = currentYear.expenses > 0 ? currentYear.expenses : 0;
          annualSavings = currentYear.savings;
          monthlyExpenses = currentYear.monthlyExpenses > 0 ? currentYear.monthlyExpenses : 0;
          // Income from last complete year (second-to-last) for accurate annual figure
          final incomeYear = ieData.years.length >= 2 ? ieData.years[ieData.years.length - 2] : currentYear;
          annualIncome = incomeYear.income;
        }

        final categories = computeKpis(
          cash: cash, investments: investments,
          annualIncome: annualIncome, annualExpenses: annualExpenses,
          annualSavings: annualSavings, monthlyExpenses: monthlyExpenses,
          s: s, locale: locale,
        );

        // Overall score
        final allKpis = categories.expand((c) => c.kpis).toList();
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
                categories: categories,
                s: s,
                isPrivate: isPrivate,
              ),
              const SizedBox(height: 24),

              // ── KPI Cards ──
              Text(s.healthKpis, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              for (final cat in categories) ...[
                const SizedBox(height: 16),
                Text(cat.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: cat.kpis.map((kpi) => SizedBox(
                    width: 320,
                    child: _KpiCard(kpi: kpi, pctFmt: pctFmt, s: s, isPrivate: isPrivate),
                  )).toList(),
                ),
              ],

              // ── Investment Costs table ──
              const SizedBox(height: 32),
              _InvestmentCostsSection(
                assets: activeAssets, marketValues: marketValues,
                amtFmt: amtFmt, pctFmt: pctFmt, s: s, isPrivate: isPrivate,
                context: context,
              ),
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

// ── Investment Costs Section (extracted from old _FinancialHealthTab) ──

class _InvestmentCostsSection extends StatelessWidget {
  final List<Asset> assets;
  final Map<int, double> marketValues;
  final NumberFormat amtFmt;
  final NumberFormat pctFmt;
  final AppStrings s;
  final bool isPrivate;
  final BuildContext context;

  const _InvestmentCostsSection({
    required this.assets, required this.marketValues,
    required this.amtFmt, required this.pctFmt,
    required this.s, required this.isPrivate, required this.context,
  });

  @override
  Widget build(BuildContext innerContext) {
    final theme = Theme.of(context);
    final rows = <_CostRow>[];
    double totalValue = 0, totalCost = 0;

    for (final asset in assets) {
      final mv = marketValues[asset.id];
      if (mv == null || mv <= 0) continue;
      totalValue += mv;
      if (asset.ter != null && asset.ter! > 0) {
        final annualCost = mv * asset.ter! / 100;
        rows.add(_CostRow(name: asset.ticker ?? asset.name, fullName: asset.name, ter: asset.ter!, marketValue: mv, annualCost: annualCost));
        totalCost += annualCost;
      } else {
        rows.add(_CostRow(name: asset.ticker ?? asset.name, fullName: asset.name, ter: null, marketValue: mv, annualCost: 0));
      }
    }
    rows.sort((a, b) => b.annualCost.compareTo(a.annualCost));
    final weightedTer = totalValue > 0 ? totalCost / totalValue * 100 : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.healthInvestmentCosts, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            if (rows.isEmpty)
              Text(s.healthNoTer, style: const TextStyle(color: Colors.grey))
            else ...[
              _buildHeader(theme),
              const Divider(height: 1),
              ...rows.map((row) => _buildRow(row, theme)),
              const Divider(height: 16, thickness: 2),
              _buildTotal(theme, totalValue, totalCost, weightedTer),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final style = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(flex: 4, child: Text(s.healthAsset, style: style)),
        Expanded(flex: 2, child: Text(s.healthTer, style: style, textAlign: TextAlign.right)),
        Expanded(flex: 3, child: Text(s.healthMarketValue, style: style, textAlign: TextAlign.right)),
        Expanded(flex: 3, child: Text(s.healthAnnualCost, style: style, textAlign: TextAlign.right)),
      ]),
    );
  }

  Widget _buildRow(_CostRow row, ThemeData theme) {
    final vs = theme.textTheme.bodySmall?.copyWith(fontSize: 13);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(flex: 4, child: Tooltip(message: row.fullName, child: Text(row.name, style: vs, overflow: TextOverflow.ellipsis))),
        Expanded(flex: 2, child: Text(row.ter != null ? '${pctFmt.format(row.ter)}%' : '-', style: vs?.copyWith(color: row.ter != null ? _terColor(row.ter!) : Colors.grey), textAlign: TextAlign.right)),
        Expanded(flex: 3, child: PrivacyText(amtFmt.format(row.marketValue), style: vs, textAlign: TextAlign.right)),
        Expanded(flex: 3, child: PrivacyText(row.ter != null ? amtFmt.format(row.annualCost) : '-', style: vs?.copyWith(color: row.ter != null ? Colors.red.shade300 : Colors.grey, fontWeight: row.ter != null ? FontWeight.w600 : null), textAlign: TextAlign.right)),
      ]),
    );
  }

  Widget _buildTotal(ThemeData theme, double totalValue, double totalCost, double weightedTer) {
    final bs = theme.textTheme.bodySmall?.copyWith(fontSize: 13, fontWeight: FontWeight.bold);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(flex: 4, child: Text(s.healthWeightedTer, style: bs)),
        Expanded(flex: 2, child: Text('${pctFmt.format(weightedTer)}%', style: bs?.copyWith(color: _terColor(weightedTer)), textAlign: TextAlign.right)),
        Expanded(flex: 3, child: PrivacyText(amtFmt.format(totalValue), style: bs, textAlign: TextAlign.right)),
        Expanded(flex: 3, child: PrivacyText(amtFmt.format(totalCost), style: bs?.copyWith(color: Colors.red.shade400), textAlign: TextAlign.right)),
      ]),
    );
  }

  static Color _terColor(double ter) {
    if (ter <= 0.20) return Colors.green.shade400;
    if (ter <= 0.50) return Colors.lightGreen;
    if (ter <= 1.00) return Colors.orange;
    return Colors.red.shade400;
  }
}

class _CostRow {
  final String name, fullName;
  final double? ter;
  final double marketValue, annualCost;
  const _CostRow({required this.name, required this.fullName, required this.ter, required this.marketValue, required this.annualCost});
}
