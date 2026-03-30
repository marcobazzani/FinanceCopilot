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
    final amtFmt = fmt.currencyFormat(widget.locale, symbol, decimalDigits: 0);
    final theme = Theme.of(context);

    final d = widget.allData;

    // Compute last value for each group
    double lastValue(List<List<FlSpot>> spotLists) {
      final total = buildTotalSpots(spotLists);
      return total.isNotEmpty ? total.last.y : 0.0;
    }

    // Cash = accounts + spread adjustments
    final cashTotal = lastValue([
      ...d.accounts.map((s) => s.spots),
      ...d.adjustments.map((s) => s.spots),
    ]);

    // Saving = accounts + invested + adjustments + income adj
    final savingTotal = lastValue([
      ...d.accounts.map((s) => s.spots),
      ...d.assetInvested.map((s) => s.spots),
      ...d.adjustments.map((s) => s.spots),
      ...d.incomeAdjustments.map((s) => s.spots),
    ]);

    // Invested = cost basis of invested assets
    final investedTotal = lastValue(d.assetInvested.map((s) => s.spots).toList());

    // Portfolio = current market value of assets
    final portfolioTotal = lastValue(d.assetMarket.map((s) => s.spots).toList());

    // Build rows: label, total, series for drill-down
    final rows = <_TotalRow>[
      _TotalRow(s.dashCash, cashTotal, [...d.accounts, ...d.adjustments]),
      _TotalRow(s.dashSaving, savingTotal, [...d.accounts, ...d.assetInvested, ...d.adjustments, ...d.incomeAdjustments]),
      _TotalRow(s.dashInvested, investedTotal, d.assetInvested),
      _TotalRow(s.dashPortfolio, portfolioTotal, d.assetMarket),
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
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(row.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Text(
                  amtFmt.format(row.total),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: row.total >= 0 ? Colors.green.shade400 : Colors.red.shade400,
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

  List<Widget> _buildDrillDown(List<_Series> series, NumberFormat amtFmt, ThemeData theme) {
    // Get last value for each series
    final items = <MapEntry<String, double>>[];
    for (final s in series) {
      final val = s.spots.isNotEmpty ? s.spots.last.y : 0.0;
      if (val.abs() > 0.01) {
        items.add(MapEntry(s.name, val));
      }
    }
    items.sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    return items.map((entry) => Padding(
      padding: const EdgeInsets.only(left: 34, right: 0, top: 2, bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              entry.key,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Text(
            amtFmt.format(entry.value),
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
  final List<_Series> series;
  const _TotalRow(this.label, this.total, this.series);
}
