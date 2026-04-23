part of 'dashboard_screen.dart';

// ════════════════════════════════════════════════════
// Summary Totals Table (below Price Changes)
// ════════════════════════════════════════════════════

class _SummaryTotalsTable extends ConsumerStatefulWidget {
  final AllSeriesData allData;
  final String locale;
  /// One row per non-combined, non-widget chart currently on the History tab.
  /// The table stays in sync with the user's chart list — delete a chart,
  /// its row disappears; rename a chart, the row label follows.
  final List<({String title, List<ChartSeries> series})> chartRows;

  const _SummaryTotalsTable({
    required this.allData,
    required this.locale,
    required this.chartRows,
  });

  @override
  ConsumerState<_SummaryTotalsTable> createState() => _SummaryTotalsTableState();
}

class _SummaryTotalsTableState extends ConsumerState<_SummaryTotalsTable> {
  String? _expandedRow;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final symbol = currencySymbol(widget.allData.baseCurrency);
    final amtFmt = fmt.currencyFormat(widget.locale, symbol, decimalDigits: 2);
    final theme = Theme.of(context);

    // Compute last value and historical max (excluding last point) for each group
    (double current, double histMax) lastValueAndMax(List<List<FlSpot>> spotLists) {
      final total = buildTotalSpots(spotLists);
      if (total.isEmpty) return (0.0, 0.0);
      final current = total.last.y;
      // Historical max excluding the last point (today)
      var hMax = double.negativeInfinity;
      for (var i = 0; i < total.length - 1; i++) {
        if (total[i].y > hMax) hMax = total[i].y;
      }
      if (hMax == double.negativeInfinity) hMax = current;
      return (current, hMax);
    }

    // Build one row per chart — totals are derived from the chart's own series
    // using the same "smart" aggregation as the chart cards (when an asset has
    // both invested and market series visible, only market counts toward total).
    final rows = <_TotalRow>[];
    for (final cr in widget.chartRows) {
      final totalSpots = _DashboardScreenState._buildSmartTotalSpotsStatic(cr.series);
      final (curr, histMax) = lastValueAndMax([totalSpots]);
      rows.add(_TotalRow(cr.title, curr, curr - histMax, cr.series));
    }

    // Nothing to show? Hide the card entirely.
    if (rows.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.dashTotals, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            // Column headers
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const SizedBox(width: 30),
                  Expanded(child: Text('', style: _headerStyle(theme))),
                  SizedBox(width: 110, child: Text(s.vsATH, style: _headerStyle(theme), textAlign: TextAlign.right)),
                  SizedBox(width: 120, child: Text(s.value, style: _headerStyle(theme), textAlign: TextAlign.right)),
                ],
              ),
            ),
            const Divider(height: 1),
            ...rows.map((row) => _buildTotalRow(row, amtFmt, theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(_TotalRow row, NumberFormat amtFmt, ThemeData theme) {
    final isExpanded = _expandedRow == row.label;

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expandedRow = isExpanded ? null : row.label),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 22,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(row.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                SizedBox(
                  width: 110,
                  child: row.deltaVsMax.abs() > 0.5
                      ? PrivacyText(
                          '${row.deltaVsMax >= 0 ? '+' : ''}${amtFmt.format(row.deltaVsMax)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: row.deltaVsMax >= 0 ? Colors.green.shade300 : Colors.red.shade300,
                          ),
                          textAlign: TextAlign.right,
                        )
                      : const SizedBox.shrink(),
                ),
                SizedBox(
                  width: 120,
                  child: PrivacyText(
                    '${row.total >= 0 ? '+' : ''}${amtFmt.format(row.total)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: row.total >= 0 ? Colors.green.shade400 : Colors.red.shade400,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ..._buildDrillDown(row.series, amtFmt, theme),
        const Divider(height: 1),
      ],
    );
  }

  static TextStyle _headerStyle(ThemeData theme) => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: theme.colorScheme.onSurfaceVariant,
  );

  static IconData _iconForSeriesKey(String key) {
    if (key.startsWith('account:')) return Icons.account_balance;
    if (key.startsWith('asset_market:')) return Icons.show_chart;
    if (key.startsWith('asset_invested:')) return Icons.pie_chart;
    if (key.startsWith('adjustment:')) return Icons.calendar_month;
    if (key.startsWith('income_adj:')) return Icons.receipt_long;
    return Icons.circle;
  }

  List<Widget> _buildDrillDown(List<ChartSeries> series, NumberFormat amtFmt, ThemeData theme) {
    final items = <({String key, String name, double value})>[];
    for (final s in series) {
      final val = s.spots.isNotEmpty ? s.spots.last.y : 0.0;
      items.add((key: s.key, name: s.name, value: val));
    }
    items.sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    return items.map((entry) => Padding(
      padding: const EdgeInsets.only(left: 34, right: 0, top: 2, bottom: 2),
      child: Row(
        children: [
          Icon(_iconForSeriesKey(entry.key), size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              entry.name,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          PrivacyText(
            '${entry.value >= 0 ? '+' : ''}${amtFmt.format(entry.value)}',
            style: TextStyle(
              fontSize: 12,
              color: entry.value >= 0 ? Colors.green.shade300 : Colors.red.shade300,
            ),
          ),
        ],
      ),
    )).toList();
  }
}

class _TotalRow {
  final String label;
  final double total;
  final double deltaVsMax; // current - historical max (excluding today)
  final List<ChartSeries> series;
  const _TotalRow(this.label, this.total, this.deltaVsMax, this.series);
}
