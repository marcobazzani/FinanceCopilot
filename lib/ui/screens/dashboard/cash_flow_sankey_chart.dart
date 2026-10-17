part of 'dashboard_screen.dart';

/// A period's income and savings, exactly as the Income/Expense/Savings chart
/// and the monthly table compute them (expenses = income − savings), plus the
/// refund Income records the savings figure contains.
typedef CashFlowTotals = ({double income, double savings, double refunds});

/// [CashFlowTotals] of a year.
typedef CashFlowYearTotals = CashFlowTotals;

/// "Where the money goes": one year — or, optionally, one month of it — of
/// cash flow as a Sankey: income (+ from savings / untracked income) →
/// available → essential / discretionary / saving plans / uncategorized /
/// untracked expenses / saved → expense categories. The current year is year
/// to date, its current month month to date.
///
/// Income, savings and expenses are [years] — [months] for a month, by (year,
/// month): the yearly chart's and the monthly table's figures; the ledger in
/// [spending] only splits the expenses by category and saving plan, and what
/// it does not account for stays visible as untracked income / expenses.
/// Privacy mode masks the amounts; band widths, percentages and months
/// (shape, not size) stay.
class CashFlowSankeyCard extends ConsumerStatefulWidget {
  final SpendingByCategoryData spending;
  final Map<int, CashFlowYearTotals> years;
  final Map<(int, int), CashFlowTotals> months;
  final int currentYear;
  final String locale;
  const CashFlowSankeyCard({
    super.key,
    required this.spending,
    required this.years,
    this.months = const {},
    required this.currentYear,
    required this.locale,
  });

  @override
  ConsumerState<CashFlowSankeyCard> createState() => CashFlowSankeyCardState();
}

class CashFlowSankeyCardState extends ConsumerState<CashFlowSankeyCard> {
  int? _year;

  /// The month picked, 1–12; null for the whole year.
  int? _month;

  /// Live spending data for an open drill-down sheet: the sheet is its own
  /// route and is not rebuilt with this card, so it listens to this instead.
  late final _spendingLive = ValueNotifier<SpendingByCategoryData>(widget.spending);

  @override
  void didUpdateWidget(CashFlowSankeyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The sheet listening to this lives in another route: notifying it now,
    // in the middle of the build that delivered the new data, would mark it
    // dirty during build. Hand the data over once the frame is done.
    if (oldWidget.spending != widget.spending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _spendingLive.value = widget.spending;
      });
    }
  }

  @override
  void dispose() {
    _spendingLive.dispose();
    super.dispose();
  }

  int _effectiveYear(List<int> years) {
    if (_year != null && years.contains(_year)) return _year!;
    return years.contains(widget.currentYear) ? widget.currentYear : years.last;
  }

  /// Whether [t] (of a year or a month) has anything to show: income, a
  /// change of savings, or spending in [spent].
  static bool _hasFlow(CashFlowTotals t, SpendingPeriod spent) => t.income.abs() >= 0.005 || t.savings.abs() >= 0.005 || spent.total >= 0.005;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final d = widget.spending;
    final byId = ref.watch(categoriesByIdProvider);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final years = [
      for (final e in widget.years.entries)
        if (_hasFlow(e.value, d.period(e.key))) e.key,
    ]..sort();
    if (years.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: EmptyState(key: const Key('spendingEmpty'), icon: Icons.account_tree_outlined, message: s.spendingByCategoryEmpty),
      );
    }

    final year = _effectiveYear(years);
    // The months of the year with something to show; the one picked stays
    // picked across years that have it.
    final months = [
      for (var m = 1; m <= 12; m++)
        if (widget.months[(year, m)] case final t? when _hasFlow(t, d.period(year, m))) m,
    ];
    final month = months.contains(_month) ? _month : null;
    final totals = month == null ? widget.years[year]! : widget.months[(year, month)]!;
    final graph = buildCashFlowSankey(
      year: year,
      month: month,
      income: totals.income,
      savings: totals.savings,
      recordedRefunds: totals.refunds,
      spending: d,
      categories: byId,
    );
    final spent = d.period(year, month);
    final money = fmt.currencyFormat(widget.locale, currencySymbol(d.baseCurrency), decimalDigits: 0);
    final pct = NumberFormat.decimalPercentPattern(locale: widget.locale, decimalDigits: 1);
    String yearLabel(int y) => y == widget.currentYear ? '$y ${s.ytdSuffix}' : '$y';

    Color colorOf(CashFlowNode n) => switch (n.kind) {
      CashFlowNodeKind.income => Colors.green.shade700,
      CashFlowNodeKind.expense => byId[n.categoryId] != null ? categoryPaint(byId[n.categoryId]!, scheme) : scheme.outline,
      CashFlowNodeKind.fromSavings => scheme.error,
      CashFlowNodeKind.total => scheme.primary,
      CashFlowNodeKind.essential => scheme.tertiary,
      CashFlowNodeKind.discretionary => scheme.secondary,
      CashFlowNodeKind.refunds => Colors.teal.shade400,
      CashFlowNodeKind.untrackedIncome => Colors.green.shade300,
      CashFlowNodeKind.uncategorized => scheme.outlineVariant,
      CashFlowNodeKind.savingPlan => Colors.amber.shade700,
      CashFlowNodeKind.untrackedExpenses => scheme.outline,
      CashFlowNodeKind.saved => Colors.green.shade600,
    };
    String labelOf(CashFlowNode n) => switch (n.kind) {
      CashFlowNodeKind.income => s.legendIncome,
      CashFlowNodeKind.expense => categoryLabelFor(n.categoryId, byId, s),
      CashFlowNodeKind.fromSavings => s.sankeyFromSavings,
      CashFlowNodeKind.total => s.sankeyTotal,
      CashFlowNodeKind.essential => s.sankeyEssential,
      CashFlowNodeKind.discretionary => s.sankeyDiscretionary,
      CashFlowNodeKind.refunds => s.sankeyRefunds,
      CashFlowNodeKind.untrackedIncome => s.sankeyUntrackedIncome,
      CashFlowNodeKind.uncategorized => s.uncategorized,
      // The ledger's own label for these rows.
      CashFlowNodeKind.savingPlan => s.savingForLabel(n.eventName!),
      CashFlowNodeKind.untrackedExpenses => s.sankeyUntrackedExpenses,
      CashFlowNodeKind.saved => s.sankeySaved,
    };

    final nodeById = {for (final n in graph.nodes) n.id: n};
    final specs = [for (final n in graph.nodes) SankeyNodeSpec(id: n.id, layer: n.layer, value: n.value, color: colorOf(n))];
    final links = [
      for (final l in graph.links)
        SankeyLinkSpec(
          from: l.from,
          to: l.to,
          value: l.value,
          // Sources colour their band into the total; after it, the destination does.
          color: colorOf(nodeById[l.from]!.layer == 0 ? nodeById[l.from]! : nodeById[l.to]!),
        ),
    ];

    Widget amountLine(double v, {TextStyle? style}) => PrivacyText(money.format(v), style: style);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final y in years.reversed)
                ChoiceChip(
                  key: Key('sankeyYear:$y'),
                  label: Text(yearLabel(y)),
                  selected: y == year,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _year = y),
                ),
            ],
          ),
        ),
        // Optional: a month of the year, the whole year by default.
        if (months.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  key: const Key('sankeyMonth:all'),
                  label: Text(s.sankeyWholeYear),
                  selected: month == null,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _month = null),
                ),
                for (final m in months)
                  ChoiceChip(
                    key: Key('sankeyMonth:$m'),
                    label: Text(monthAbbr(m, widget.locale)),
                    selected: m == month,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _month = m),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Wrap(
            spacing: 16,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _SummaryItem(
                label: s.legendIncome,
                value: amountLine(graph.income, style: theme.textTheme.bodyMedium),
              ),
              _SummaryItem(
                label: s.legendExpenses,
                value: amountLine(graph.expenses, style: theme.textTheme.bodyMedium),
              ),
              _SummaryItem(
                label: s.legendSavings,
                value: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    amountLine(graph.savings, style: theme.textTheme.bodyMedium),
                    if (graph.savingsRate != null)
                      Text(' (${pct.format(graph.savingsRate)})', key: const Key('sankeySavingsRate'), style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!graph.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
            child: SankeyChart(
              key: const Key('cashFlowSankey'),
              nodes: specs,
              links: links,
              onNodeTap: (id) => _onNodeTap(context, nodeById[id]!, year, month, labelOf(nodeById[id]!)),
              labelBuilder: (context, spec) {
                final n = nodeById[spec.id]!;
                final share = graph.scaleTotal == 0 ? 0.0 : n.value / graph.scaleTotal;
                final first = n.layer == 0;
                const small = TextStyle(fontSize: 10);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: first ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(
                      labelOf(n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: PrivacyText(money.format(n.value), style: small, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        Text(' · ${pct.format(share)}', style: small),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (spent.transfersExcluded >= 0.005)
                // How much money was moved: position size, masked.
                PrivacyText(
                  s.sankeyTransfersExcluded(money.format(spent.transfersExcluded)),
                  key: const Key('sankeyTransfersExcluded'),
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              Text(
                [s.sankeySource, if (d.fxExcluded > 0) s.spendingFxExcluded(d.fxExcluded), s.sankeyTapHint].join(' · '),
                key: const Key('spendingFootnote'),
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// [month] (1–12) of [year], or the whole year when null.
  Future<void> _onNodeTap(BuildContext context, CashFlowNode node, int year, int? month, String label) async {
    // The rows summed into the node, from the live data.
    final List<int> Function(SpendingByCategoryData)? idsOf = switch (node.kind) {
      CashFlowNodeKind.expense => (d) => d.period(year, month).ids(node.categoryId),
      CashFlowNodeKind.uncategorized => (d) => d.period(year, month).ids(null),
      CashFlowNodeKind.refunds => (d) => d.period(year, month).refundIds,
      _ => null,
    };
    if (idsOf == null || idsOf(widget.spending).isEmpty) return;
    // The node's rows follow the ledger: a row re-classified out of the node
    // leaves the list.
    final ids = _MappedListenable(_spendingLive, idsOf);
    final period = month == null ? '$year' : fmt.monthYearFormat(widget.locale).format(DateTime(year, month));
    try {
      await showTransactionsSheet(context, ids: ids, title: '$label · $period', locale: widget.locale);
    } finally {
      ids.dispose();
    }
  }
}

/// [source] seen through [map]: notifies whenever [source] does.
class _MappedListenable<S, T> extends ChangeNotifier implements ValueListenable<T> {
  final ValueListenable<S> source;
  final T Function(S) map;
  _MappedListenable(this.source, this.map) {
    source.addListener(notifyListeners);
  }
  @override
  T get value => map(source.value);
  @override
  void dispose() {
    source.removeListener(notifyListeners);
    super.dispose();
  }
}

/// A list of transactions, biggest first, in a sheet; tapping one swaps the
/// list for the classification wizard's card in the same sheet (no dialog
/// over the sheet). [ids] are the rows to list; when it changes (e.g. a row
/// re-classified out of a Sankey node) the list follows.
Future<void> showTransactionsSheet(
  BuildContext context, {
  required ValueListenable<List<int>> ids,
  required String title,
  required String locale,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.6,
    builder: (ctx, controller) => _NodeTransactionsSheet(ids: ids, title: title, locale: locale, controller: controller),
  ),
);

/// A node's transactions, biggest first; tapping one swaps the list for the
/// classification wizard's card in the same sheet (no dialog over the
/// sheet). Back / Skip / Apply return to the list, which follows the ledger.
class _NodeTransactionsSheet extends ConsumerStatefulWidget {
  final ValueListenable<List<int>> ids;
  final String title;
  final String locale;
  final ScrollController controller;
  const _NodeTransactionsSheet({required this.ids, required this.title, required this.locale, required this.controller});

  @override
  ConsumerState<_NodeTransactionsSheet> createState() => _NodeTransactionsSheetState();
}

class _NodeTransactionsSheetState extends ConsumerState<_NodeTransactionsSheet> {
  ClassificationContext? _classifying;
  int? _loadingId;

  Future<void> _open(Transaction t) async {
    setState(() => _loadingId = t.id);
    final ctx = await loadClassificationContext(ref, t.id);
    if (!mounted) return;
    setState(() {
      _loadingId = null;
      _classifying = ctx;
    });
  }

  void _back() => setState(() => _classifying = null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = _classifying;
    if (c != null) {
      return TransactionClassifyPane(
        target: c,
        title: widget.title,
        leading: IconButton(key: const Key('sankeySheetBack'), icon: const Icon(Icons.arrow_back), onPressed: _back),
        onDone: _back,
        controller: widget.controller,
      );
    }

    final txs = ref.watch(allTransactionsProvider).value ?? const <Transaction>[];
    return ValueListenableBuilder<List<int>>(
      valueListenable: widget.ids,
      builder: (context, idList, _) {
        // Exactly the rows asked for, biggest first (|amount| in the row's own
        // currency); newest, then id, break ties.
        final ids = idList.toSet();
        final rows = txs.where((t) => ids.contains(t.id)).toList()
          ..sort((a, b) {
            final c = b.amount.abs().compareTo(a.amount.abs());
            if (c != 0) return c;
            final d = b.valueDate.compareTo(a.valueDate);
            return d != 0 ? d : a.id.compareTo(b.id);
          });
        final dateFmt = fmt.shortDateFormat(widget.locale);
        final amtFmt = fmt.amountFormat(widget.locale);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('${widget.title} (${rows.length})', style: theme.textTheme.titleMedium),
            ),
            Expanded(
              child: ListView.builder(
                controller: widget.controller,
                itemCount: rows.length,
                itemBuilder: (_, i) {
                  final t = rows[i];
                  return ListTile(
                    key: ValueKey('sankeyTx:${t.id}'),
                    dense: true,
                    title: Text(t.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(dateFmt.format(t.valueDate)),
                    trailing: _loadingId == t.id
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : PrivacyText('${amtFmt.format(t.amount)} ${t.currency}'),
                    onTap: _loadingId == null ? () => _open(t) : null,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final Widget value;
  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$label: ', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      value,
    ],
  );
}
