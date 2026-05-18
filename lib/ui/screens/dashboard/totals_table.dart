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

  /// Drives the ATH celebration overlay. Owned by `_DashboardScreenState`
  /// so its lifetime is bounded by the Dashboard mount, not by table rebuilds.
  final AthCelebrationController athController;

  const _SummaryTotalsTable({
    required this.allData,
    required this.locale,
    required this.chartRows,
    required this.athController,
  });

  @override
  ConsumerState<_SummaryTotalsTable> createState() => _SummaryTotalsTableState();
}

class _SummaryTotalsTableState extends ConsumerState<_SummaryTotalsTable> {
  String? _expandedRow;

  /// Per-row tap counters for the 6-tap easter-easter egg. Keyed by row
  /// label. Each entry tracks `(count, lastTapAt)`; resets per the
  /// shared [AthTapCounter] window logic.
  final Map<String, ({int count, DateTime last})> _tapCounters = {};

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

    // ATH auto-fire scan — gated by the history-tab-seen provider so we
    // never fire on startup, and by a per-session "already fired" set so
    // dashboard rebuilds don't keep re-triggering. Scope is the three
    // canonical series (kAthEligibleLabels). Fires post-frame to avoid
    // mutating state during build.
    final historySeen = ref.read(historyTabSeenThisSessionProvider);
    if (historySeen) {
      final firedSet = ref.read(athFiredThisSessionProvider);
      final newFires = <String>[];
      for (final row in rows) {
        if (!kAthEligibleLabels.contains(row.label)) continue;
        if (firedSet.contains(row.label)) continue;
        // curr > histMax ⇒ today's total broke the prior max ⇒ new ATH.
        // row.deltaVsMax == curr - histMax (already computed above).
        if (row.deltaVsMax > 0 && row.total > 0) {
          newFires.add(row.label);
        }
      }
      if (newFires.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final notifier = ref.read(athFiredThisSessionProvider.notifier);
          notifier.state = {...notifier.state, ...newFires};
          for (final label in newFires) {
            widget.athController.fire(context, label);
          }
        });
      }
    }

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
                  child: _wrapWithAthTapDetector(
                    row.label,
                    row.deltaVsMax.abs() > 0.5
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

  /// Wraps the vsATH cell of an in-scope row (Total Assets / Portfolio /
  /// Performance) in a tap counter. 6 taps inside [_tapWindow] fire the
  /// celebration overlay regardless of ATH state. Out-of-scope rows get
  /// the child verbatim — no gesture attached.
  Widget _wrapWithAthTapDetector(String label, Widget child) {
    if (!kAthEligibleLabels.contains(label)) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onAthCellTap(label),
      child: child,
    );
  }

  /// Tap-counter logic for the 6-tap easter-easter egg. Delegates the
  /// (count + window) math to [AthTapCounter.next] so the rule is
  /// unit-testable in isolation.
  void _onAthCellTap(String label) {
    final outcome = AthTapCounter.next(_tapCounters[label], DateTime.now());
    if (outcome.fire) {
      _tapCounters.remove(label);
      widget.athController.fire(context, label);
    } else {
      _tapCounters[label] = outcome.state!;
    }
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
