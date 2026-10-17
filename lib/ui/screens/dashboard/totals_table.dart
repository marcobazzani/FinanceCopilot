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

    // Compute last value and historical max (excluding last point) for each
    // group. A total without spots has no value at all: null, never 0.
    (double? current, double histMax) lastValueAndMax(List<List<FlSpot>> spotLists) {
      final total = buildTotalSpots(spotLists);
      if (total.isEmpty) return (null, 0.0);
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
    // using the same "smart" aggregation as the chart cards
    // ([buildSmartTotalSpots]: an asset is never counted twice). What any of
    // them leaves out for want of a price or an exchange rate is counted under
    // the table, each contributor once ([totalExclusions]).
    final rows = <_TotalRow>[];
    var excluded = const TotalExclusions();
    for (final cr in widget.chartRows) {
      final totalSpots = buildSmartTotalSpots(cr.series);
      excluded = excluded.union(totalExclusions(cr.series, widget.allData));
      final (curr, histMax) = lastValueAndMax([totalSpots]);
      rows.add(_TotalRow(cr.title, curr, curr == null ? 0 : curr - histMax, cr.series));
    }

    // Nothing to show? Hide the card entirely.
    if (rows.isEmpty) return const SizedBox.shrink();

    // ATH auto-fire scan — gated by the history-tab-seen provider so we
    // never fire on startup, and by a per-session "already fired" set so
    // dashboard rebuilds don't keep re-triggering. Scope is the three
    // canonical series (kAthEligibleLabels). Fires post-frame to avoid
    // mutating state during build. The gate is WATCHED: the History page is
    // built during the tab animation, before the flag flips when it settles,
    // so only a rebuild on the flip runs the scan when the user arrives —
    // otherwise it waited for an unrelated rebuild (e.g. a price refresh).
    final historySeen = ref.watch(historyTabSeenThisSessionProvider);
    if (historySeen) {
      final firedSet = ref.read(athFiredThisSessionProvider);
      final newFires = <String>[];
      for (final row in rows) {
        if (!kAthEligibleLabels.contains(row.label)) continue;
        if (firedSet.contains(row.label)) continue;
        // curr > histMax ⇒ today's total broke the prior max ⇒ new ATH.
        // row.deltaVsMax == curr - histMax (already computed above).
        final total = row.total;
        if (row.deltaVsMax > 0 && total != null && total > 0) {
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
        // Below the card, so the figures are measured in the text style they
        // are drawn in, against the width the rows actually get.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final widths = _columnWidths(context, constraints.maxWidth, rows, amtFmt, s, theme);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.dashTotals, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                // Column headers
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const SizedBox(width: _leadWidth),
                      Expanded(child: Text('', style: _headerStyle(theme))),
                      _figureCell(widths.delta, Text(s.vsATH, style: _headerStyle(theme))),
                      _figureCell(widths.value, Text(s.value, style: _headerStyle(theme))),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ...rows.map((row) => _buildTotalRow(row, amtFmt, theme, widths)),
                _ExcludedFromTotalNote(excluded, plural: true, top: 8),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTotalRow(_TotalRow row, NumberFormat amtFmt, ThemeData theme, ({double delta, double value}) widths) {
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
                const SizedBox(width: _leadWidth - 22),
                Expanded(
                  child: Text(row.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                _wrapWithAthTapDetector(
                  row.label,
                  _figureCell(
                    widths.delta,
                    row.showsDelta ? PrivacyText(_signed(row.deltaVsMax, amtFmt), style: _deltaStyle(row.deltaVsMax)) : const SizedBox.shrink(),
                  ),
                ),
                _figureCell(widths.value, _signedAmount(row.total, amtFmt, _totalStyle)),
              ],
            ),
          ),
        ),
        // The drill-down grows in and out below the row; the row never changes.
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: isExpanded ? Column(children: _buildDrillDown(row.series, amtFmt, theme)) : const SizedBox(width: double.infinity),
        ),
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

  /// A row's total and its distance from the high, as drawn.
  static TextStyle _totalStyle(double v) => TextStyle(fontWeight: FontWeight.bold, color: v >= 0 ? Colors.green.shade400 : Colors.red.shade400);
  static TextStyle _deltaStyle(double v) => TextStyle(fontSize: 11, color: v >= 0 ? Colors.green.shade300 : Colors.red.shade300);

  /// [v] with its sign: the text of every figure of the table.
  static String _signed(double v, NumberFormat amtFmt) => '${v >= 0 ? '+' : ''}${amtFmt.format(v)}';

  /// What stands for a value that is not known.
  static const _dash = '—';

  /// The expand icon of a row and the gap after it, ahead of its label.
  static const _leadWidth = 30.0;

  /// The narrowest the "vs ATH" and "Value" columns are drawn, and the room a
  /// label keeps when the card is too narrow for the figures.
  static const _deltaMinWidth = 110.0;
  static const _valueMinWidth = 120.0;
  static const _labelMinWidth = 80.0;

  /// The widths of the "vs ATH" and "Value" columns, shared by the header and
  /// every row: the widest of the header and the figures laid out on one
  /// line, each in the style it is drawn in, never under the minimum widths —
  /// fixed widths wrapped a total above a million onto a second line. When
  /// that leaves a label less than [_labelMinWidth] of the [available] width,
  /// both columns give up room in proportion and their figures shrink to fit
  /// ([_figureCell]).
  ({double delta, double value}) _columnWidths(
    BuildContext context,
    double available,
    List<_TotalRow> rows,
    NumberFormat amtFmt,
    AppStrings s,
    ThemeData theme,
  ) {
    final header = _headerStyle(theme);
    var delta = _widestOnOneLine(context, [
      (s.vsATH, header),
      for (final row in rows)
        if (row.showsDelta) (_signed(row.deltaVsMax, amtFmt), _deltaStyle(row.deltaVsMax)),
    ], min: _deltaMinWidth);
    var value = _widestOnOneLine(context, [
      (s.value, header),
      for (final row in rows) (row.total == null ? _dash : _signed(row.total!, amtFmt), _totalStyle(row.total ?? 0)),
    ], min: _valueMinWidth);
    final room = available - _leadWidth - _labelMinWidth;
    if (available.isFinite && delta + value > room) {
      final share = max(room, 0.0) / (delta + value);
      delta *= share;
      value *= share;
    }
    return (delta: delta, value: value);
  }

  /// The width the widest of [texts] takes on one line, each in its style as
  /// a [Text] at [context] draws it, and at least [min].
  static double _widestOnOneLine(BuildContext context, List<(String, TextStyle)> texts, {required double min}) {
    final ambient = DefaultTextStyle.of(context).style;
    final boldText = MediaQuery.boldTextOf(context);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    var widest = min;
    for (final (text, style) in texts) {
      var effective = ambient.merge(style);
      if (boldText) effective = effective.merge(const TextStyle(fontWeight: FontWeight.bold));
      final painter = TextPainter(
        text: TextSpan(text: text, style: effective),
        textDirection: direction,
        textScaler: scaler,
        locale: locale,
        maxLines: 1,
      )..layout();
      widest = max(widest, painter.width);
      painter.dispose();
    }
    return widest.ceilToDouble();
  }

  /// A cell of the "vs ATH" or "Value" column, [width] wide: [figure]
  /// right-aligned on one line, scaled down when the column could not be
  /// made as wide as it ([_columnWidths]) — never wrapped.
  static Widget _figureCell(double width, Widget figure) => SizedBox(
    width: width,
    child: Align(
      alignment: Alignment.centerRight,
      child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: figure),
    ),
  );

  static const Map<String, IconData> _seriesIconByPrefix = {
    'account:': Icons.account_balance,
    'asset_market:': Icons.show_chart,
    'asset_invested:': Icons.pie_chart,
    'adjustment:': Icons.calendar_month,
    'adjustment_value:': Icons.calendar_month,
    'adjustment_events:': Icons.calendar_month,
    'income_adj:': Icons.receipt_long,
    'income_adj_value:': Icons.receipt_long,
    'income_adj_events:': Icons.receipt_long,
    'ephemeral_inflow_value:': Icons.credit_card,
    'ephemeral_inflow_events:': Icons.credit_card,
  };

  static IconData _iconForSeriesKey(String key) {
    for (final entry in _seriesIconByPrefix.entries) {
      if (key.startsWith(entry.key)) return entry.value;
    }
    return Icons.circle;
  }

  List<Widget> _buildDrillDown(List<ChartSeries> series, NumberFormat amtFmt, ThemeData theme) {
    // A series without spots has no value (no price or exchange rate): a
    // dash, listed last — never +0.00.
    final items = <({String key, String name, double? value})>[];
    for (final s in series) {
      items.add((key: s.key, name: s.name, value: s.spots.isNotEmpty ? s.spots.last.y : null));
    }
    items.sort((a, b) => (b.value?.abs() ?? -1).compareTo(a.value?.abs() ?? -1));

    return items
        .map(
          (entry) => Padding(
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
                _signedAmount(
                  entry.value,
                  amtFmt,
                  (v) => TextStyle(fontSize: 12, color: v >= 0 ? Colors.green.shade300 : Colors.red.shade300),
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  /// A signed amount, position size and masked in privacy mode; a plain grey
  /// dash when [value] is unknown.
  static Widget _signedAmount(double? value, NumberFormat amtFmt, TextStyle Function(double v) style) =>
      value == null ? Text(_dash, style: style(0).copyWith(color: Colors.grey)) : PrivacyText(_signed(value, amtFmt), style: style(value));
}

class _TotalRow {
  final String label;

  /// Latest total; null when the chart has nothing to add up.
  final double? total;
  final double deltaVsMax; // current - historical max (excluding today)
  final List<ChartSeries> series;
  const _TotalRow(this.label, this.total, this.deltaVsMax, this.series);

  /// Whether the "vs ATH" cell shows [deltaVsMax]: not when the total is
  /// within half a unit of its high.
  bool get showsDelta => deltaVsMax.abs() > 0.5;
}

// ════════════════════════════════════════════════════
// What a total leaves out
// ════════════════════════════════════════════════════

/// The line under a total — or under several, when [plural] — counting the
/// contributors [exclusions] leaves out for want of a price or an exchange
/// rate ([TotalExclusions.excludedFromTotalCount]), [top] below what is above
/// it; nothing when none is left out. Used under the Totals table, the Health
/// summary and a chart card's header total, so they count alike.
class _ExcludedFromTotalNote extends ConsumerWidget {
  final TotalExclusions exclusions;
  final bool plural;
  final double top;

  const _ExcludedFromTotalNote(this.exclusions, {this.plural = false, this.top = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final count = exclusions.excludedFromTotalCount;
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Footnote(plural ? s.unpricedExcludedFromTotals(count) : s.unpricedExcludedFromTotal(count)),
    );
  }
}
