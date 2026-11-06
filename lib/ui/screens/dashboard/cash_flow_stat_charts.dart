part of 'dashboard_screen.dart';

// ════════════════════════════════════════════════════
// Cash Flow stats: the charts of the overview and its screens
// ════════════════════════════════════════════════════

/// How the period is drawn on an Expenses or Income screen.
enum _ChartMode { running, bars, ring }

/// Whether [now] is for the better against [before]: fewer expenses, more
/// income. Null when they are the same, or there is nothing to compare.
bool? _isBetter(double now, double? before, {required bool upIsGood}) {
  if (before == null || (now - before).abs() < 0.5) return null;
  return (now > before) == upIsGood;
}

/// Whether [vs] is for the better: the comparison a change shows.
bool? _isBetterVs(ComparedFigure? vs, {required bool upIsGood}) => vs == null ? null : _isBetter(vs.current, vs.base, upIsGood: upIsGood);

/// The colour of a figure for the better, for the worse, or neither.
Color _goodColor(bool? good, ColorScheme scheme) => switch (good) {
  true => Colors.green.shade500,
  false => scheme.error,
  null => scheme.primary,
};

/// [value] in a few characters ("2.6K €"), for chart labels.
String _compact(double value, String locale, String symbol) => '${NumberFormat.compact(locale: locale).format(value)} $symbol';

/// A running total over the whole period, day 1 to its last: the period's
/// own so far ([now], ending today on a dot) over the comparison period's
/// ([before], grey). The line is green when the period does better than the
/// one it is compared with, red when worse ([good], the same comparison as the
/// change shown with it), neutral without one. Amounts appear only on the
/// detailed chart, and never in privacy mode.
class _RunningChart extends ConsumerWidget {
  final List<double> now;
  final List<double>? before;

  /// Days of the period: the x axis runs 1 to it, whatever has happened yet.
  final int days;
  final List<ChartTick> ticks;

  /// Whether the period does better than the one it is compared with; null:
  /// no comparison, or no difference.
  final bool? good;
  final bool detailed;
  final String locale;
  final String symbol;
  const _RunningChart({
    required this.now,
    required this.before,
    required this.days,
    required this.ticks,
    required this.good,
    required this.locale,
    required this.symbol,
    this.detailed = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isPrivate = ref.watch(privacyModeProvider);
    final b = [...?before?.take(days)];
    if (days < 1 || (now.isEmpty && b.isEmpty)) return const SizedBox.shrink();
    final color = _goodColor(good, scheme);
    final top = [...now, ...b].fold(0.0, max);
    final labels = {for (final t in ticks) t.x: t.label};
    List<FlSpot> spots(List<double> values) => [for (final (i, v) in values.indexed) FlSpot(i + 1.0, v)];
    final last = now.isEmpty ? null : FlSpot(now.length.toDouble(), now.last);
    final textStyle = TextStyle(fontSize: detailed ? 11 : 10, color: scheme.onSurfaceVariant);

    return LineChart(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      LineChartData(
        minX: 1,
        maxX: max(2, days).toDouble(),
        minY: 0,
        maxY: top <= 0 ? 1 : top * 1.12,
        gridData: FlGridData(
          show: detailed,
          drawHorizontalLine: false,
          verticalInterval: 1,
          checkToShowVerticalLine: (x) => labels.containsKey(x.round()) && (x - x.round()).abs() < 0.01,
          getDrawingVerticalLine: (_) => FlLine(color: scheme.outlineVariant.withValues(alpha: 0.35), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          enabled: detailed && !isPrivate,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItems: (spots) => [
              for (final spot in spots)
                LineTooltipItem(_compact(spot.y, locale, symbol), TextStyle(color: scheme.onInverseSurface, fontSize: 12)),
            ],
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (detailed && last != null)
              HorizontalLine(
                y: last.y,
                color: scheme.outline,
                strokeWidth: 1,
                dashArray: const [4, 4],
                label: HorizontalLineLabel(
                  show: !isPrivate,
                  alignment: Alignment.topRight,
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  labelResolver: (line) => _compact(line.y, locale, symbol),
                ),
              ),
          ],
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: ticks.isNotEmpty,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final label = labels[value.round()];
                if (label == null || (value - value.round()).abs() > 0.01) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(label, style: textStyle),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          if (b.length > 1)
            LineChartBarData(
              spots: spots(b),
              isCurved: true,
              curveSmoothness: 0.15,
              preventCurveOverShooting: true,
              color: scheme.outline.withValues(alpha: 0.8),
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
            ),
          if (now.isNotEmpty)
            LineChartBarData(
              spots: spots(now),
              isCurved: true,
              curveSmoothness: 0.15,
              preventCurveOverShooting: true,
              color: color,
              barWidth: detailed ? 3 : 2.5,
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
                ),
              ),
              dotData: FlDotData(
                checkToShowDot: (spot, _) => spot.x == last?.x,
                getDotPainter: (_, _, _, _) =>
                    FlDotCirclePainter(radius: 4.5, color: color, strokeWidth: 4, strokeColor: color.withValues(alpha: 0.3)),
              ),
            ),
        ],
      ),
    );
  }
}

/// One bar ([a]), or a pair (income [a] and expenses [b]); [highlight]: the
/// period shown, in full colour, the others muted.
typedef _Bar = ({String label, double a, double? b, bool highlight});

/// Labelled bars: the period against the ones before it. The tallest bar's
/// amount sits top right, never in privacy mode; touching a bar tells its
/// amount, not in privacy mode either.
class _BarsChart extends ConsumerWidget {
  final List<_Bar> bars;

  /// The colour of single bars; pairs are green and red.
  final Color color;
  final String locale;
  final String symbol;
  const _BarsChart({required this.bars, required this.color, required this.locale, required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isPrivate = ref.watch(privacyModeProvider);
    if (bars.isEmpty) return const SizedBox.shrink();
    final top = bars.fold(0.0, (m, b) => max(m, max(b.a, b.b ?? 0)));
    final paired = bars.any((b) => b.b != null);
    final count = bars.length;
    final width = (paired ? 0.55 : 1.0) * (count <= 6 ? 30.0 : (count <= 12 ? 18.0 : 8.0));
    BarChartRodData rod(double v, Color c, bool highlight) {
      final shade = highlight ? c : c.withValues(alpha: 0.35);
      return BarChartRodData(
        toY: v,
        width: width,
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            shade.withValues(alpha: shade.a * 0.7),
            shade,
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(min(8, width / 2))),
      );
    }

    return Stack(
      children: [
        BarChart(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          BarChartData(
            maxY: top <= 0 ? 1 : top * 1.15,
            minY: 0,
            alignment: BarChartAlignment.spaceAround,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(
              show: true,
              border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
            ),
            barTouchData: BarTouchData(
              enabled: !isPrivate,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => scheme.inverseSurface,
                getTooltipItem: (group, _, rod, _) =>
                    BarTooltipItem(_compact(rod.toY, locale, symbol), TextStyle(color: scheme.onInverseSurface, fontSize: 12)),
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  getTitlesWidget: (value, meta) {
                    final i = value.round();
                    if (i < 0 || i >= count) return const SizedBox.shrink();
                    final b = bars[i];
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        b.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: b.highlight ? scheme.onSurface : scheme.onSurfaceVariant,
                          fontWeight: b.highlight ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (final (i, b) in bars.indexed)
                BarChartGroupData(
                  x: i,
                  barsSpace: 4,
                  barRods: [
                    if (b.b case final spent?) ...[
                      rod(b.a, Colors.green.shade500, b.highlight),
                      rod(spent, scheme.error, b.highlight),
                    ] else
                      rod(b.a, color, b.highlight),
                  ],
                ),
            ],
          ),
        ),
        if (!isPrivate && top > 0)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
              child: Text(_compact(top, locale, symbol), style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ),
          ),
      ],
    );
  }
}

/// One slice of the ring.
typedef _Slice = ({double value, Color color});

/// What the ledger holds of the period's spending, as a ring of its
/// categories (the list under it tells each one's amount). Shape, not size.
class _RingChart extends StatelessWidget {
  final List<_Slice> slices;
  const _RingChart({required this.slices});

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) return const SizedBox.shrink();
    return PieChart(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 72,
        startDegreeOffset: -90,
        sections: [for (final s in slices) PieChartSectionData(value: s.value, color: s.color, radius: 26, showTitle: false)],
      ),
    );
  }
}

/// The period and the ones before it as small labelled bars: the period's
/// own (the last) in [color], the others grey. Shape, not size.
class _MiniBars extends StatelessWidget {
  final List<({String label, double value, bool current})> bars;
  final Color color;
  const _MiniBars({required this.bars, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final top = bars.fold(0.0, (m, b) => max(m, b.value));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in bars)
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) => Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                        width: 12,
                        height: max(4.0, box.maxHeight * (top <= 0 ? 0 : b.value / top)),
                        decoration: BoxDecoration(color: b.current ? color : scheme.outlineVariant, borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  b.label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: b.current ? scheme.onSurface : scheme.onSurfaceVariant,
                    fontWeight: b.current ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// What came in against what went out, as two bars on the same scale.
class _InOutBars extends StatelessWidget {
  final double income;
  final double spent;
  const _InOutBars({required this.income, required this.spent});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final top = max(income, spent);
    Widget bar(double value, Color color) => LayoutBuilder(
      builder: (context, box) => Container(
        height: 10,
        decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(5)),
        alignment: Alignment.centerLeft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          width: box.maxWidth * (top <= 0 ? 0 : (value / top).clamp(0.0, 1.0)),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
        ),
      ),
    );
    return Column(
      children: [
        bar(income, Colors.green.shade500),
        const SizedBox(height: 8),
        bar(spent, scheme.error),
      ],
    );
  }
}
