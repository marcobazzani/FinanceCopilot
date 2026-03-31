part of 'dashboard_screen.dart';

// ════════════════════════════════════════════════════
// Summary Totals Table (below Price Changes)
// ════════════════════════════════════════════════════

class _SummaryTotalsTable extends ConsumerStatefulWidget {
  final _AllSeriesData allData;
  final String locale;

  const _SummaryTotalsTable({required this.allData, required this.locale});

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

    final d = widget.allData;

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

    // Cash = accounts + spread adjustments
    final (cashTotal, cashMax) = lastValueAndMax([
      ...d.accounts.map((s) => s.spots),
      ...d.adjustments.map((s) => s.spots),
    ]);

    // Saving = accounts + invested + adjustments + income adj
    final (savingTotal, savingMax) = lastValueAndMax([
      ...d.accounts.map((s) => s.spots),
      ...d.assetInvested.map((s) => s.spots),
      ...d.adjustments.map((s) => s.spots),
      ...d.incomeAdjustments.map((s) => s.spots),
    ]);

    // Invested = cost basis of invested assets
    final (investedTotal, investedMax) = lastValueAndMax(d.assetInvested.map((s) => s.spots).toList());

    // Portfolio = current market value of assets
    final (portfolioTotal, portfolioMax) = lastValueAndMax(d.assetMarket.map((s) => s.spots).toList());

    // Total Assets = accounts + market values + adjustments
    final (totalAssetsTotal, totalAssetsMax) = lastValueAndMax([
      ...d.accounts.map((s) => s.spots),
      ...d.assetMarket.map((s) => s.spots),
      ...d.adjustments.map((s) => s.spots),
    ]);

    // Build rows: label, total, delta vs historical max, series for drill-down
    final rows = <_TotalRow>[
      _TotalRow(s.dashTotalAssets, totalAssetsTotal, totalAssetsTotal - totalAssetsMax, [...d.accounts, ...d.assetMarket, ...d.adjustments]),
      _TotalRow(s.dashCash, cashTotal, cashTotal - cashMax, [...d.accounts, ...d.adjustments]),
      _TotalRow(s.dashSaving, savingTotal, savingTotal - savingMax, [...d.accounts, ...d.assetInvested, ...d.adjustments, ...d.incomeAdjustments]),
      _TotalRow(s.dashInvested, investedTotal, investedTotal - investedMax, d.assetInvested),
      _TotalRow(s.dashPortfolio, portfolioTotal, portfolioTotal - portfolioMax, d.assetMarket),
    ];

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

  List<Widget> _buildDrillDown(List<_Series> series, NumberFormat amtFmt, ThemeData theme) {
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
  final List<_Series> series;
  const _TotalRow(this.label, this.total, this.deltaVsMax, this.series);
}
