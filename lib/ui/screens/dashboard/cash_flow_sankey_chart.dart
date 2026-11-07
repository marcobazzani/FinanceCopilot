part of 'dashboard_screen.dart';

/// A period's income and savings, exactly as the Income/Expense/Savings chart
/// and the monthly table compute them (expenses = income − savings), plus the
/// refund Income records the savings figure contains.
typedef CashFlowTotals = ({double income, double savings, double refunds});

/// [CashFlowTotals] of a year.
typedef CashFlowYearTotals = CashFlowTotals;

/// "Where the money goes": the picked [periods] of cash flow, summed, as a
/// Sankey: income (+ from savings / untracked income) → available →
/// essential / discretionary / saving plans / uncategorized / untracked
/// expenses / saved → expense categories.
///
/// Income, savings and expenses are [totals]: the yearly chart's and the
/// monthly table's figures of those periods; the ledger in [spending] only
/// splits the expenses by category and saving plan, and what it does not
/// account for stays visible as untracked income / expenses. Privacy mode
/// masks the amounts; band widths and percentages (shape, not size) stay.
class CashFlowSankeyCard extends ConsumerStatefulWidget {
  final SpendingByCategoryData spending;

  /// The (year, month) periods shown, summed.
  final Set<(int, int)> periods;

  /// Income, savings and refunds of [periods].
  final CashFlowTotals totals;

  /// How [periods] read in a title, e.g. "Jan 2024 · 2025".
  final String periodLabel;
  final String locale;
  const CashFlowSankeyCard({
    super.key,
    required this.spending,
    required this.periods,
    required this.totals,
    required this.periodLabel,
    required this.locale,
  });

  @override
  ConsumerState<CashFlowSankeyCard> createState() => CashFlowSankeyCardState();
}

class CashFlowSankeyCardState extends ConsumerState<CashFlowSankeyCard> with _SpendingDrillDown<CashFlowSankeyCard> {
  @override
  SpendingByCategoryData spendingOf(CashFlowSankeyCard card) => card.spending;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final d = widget.spending;
    final byId = ref.watch(categoriesByIdProvider);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final spent = d.sumOfMonths(widget.periods);
    final totals = widget.totals;
    final graph = buildCashFlowSankeyFor(
      period: spent,
      income: totals.income,
      savings: totals.savings,
      recordedRefunds: totals.refunds,
      categories: byId,
    );
    if (graph.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: EmptyState(key: const Key('spendingEmpty'), icon: Icons.account_tree_outlined, message: s.spendingByCategoryEmpty),
      );
    }
    final money = fmt.currencyFormat(widget.locale, currencySymbol(d.baseCurrency));
    final pct = NumberFormat.decimalPercentPattern(locale: widget.locale, decimalDigits: 1);

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: SankeyChart(
            key: const Key('cashFlowSankey'),
            nodes: specs,
            links: links,
            onNodeTap: (id) => _onNodeTap(context, nodeById[id]!, labelOf(nodeById[id]!)),
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

  /// Opens the rows summed into [node] over the picked periods.
  Future<void> _onNodeTap(BuildContext context, CashFlowNode node, String label) async {
    final periods = widget.periods;
    // The rows summed into the node, from the live data.
    final List<int> Function(SpendingByCategoryData)? idsOf = switch (node.kind) {
      CashFlowNodeKind.expense => (d) => d.sumOfMonths(periods).ids(node.categoryId),
      CashFlowNodeKind.uncategorized => (d) => d.sumOfMonths(periods).ids(null),
      CashFlowNodeKind.refunds => (d) => d.sumOfMonths(periods).refundIds,
      _ => null,
    };
    if (idsOf == null) return;
    await openRows(context, idsOf, title: '$label · ${widget.periodLabel}', locale: widget.locale);
  }
}

/// A card over [SpendingByCategoryData] whose rows open the transactions
/// behind them in a sheet. The sheet is its own route and is not rebuilt with
/// the card, so it follows the live data through this: a row re-classified
/// out of what the card shows leaves the list.
mixin _SpendingDrillDown<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  SpendingByCategoryData spendingOf(T card);

  late final _spendingLive = ValueNotifier<SpendingByCategoryData>(spendingOf(widget));

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The sheet listening to this lives in another route: notifying it now,
    // in the middle of the build that delivered the new data, would mark it
    // dirty during build. Hand the data over once the frame is done.
    if (spendingOf(oldWidget) != spendingOf(widget)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _spendingLive.value = spendingOf(widget);
      });
    }
  }

  @override
  void dispose() {
    _spendingLive.dispose();
    super.dispose();
  }

  /// Opens the rows [idsOf] picks from the spending data, titled [title];
  /// nothing when it picks none.
  Future<void> openRows(
    BuildContext context,
    List<int> Function(SpendingByCategoryData) idsOf, {
    required String title,
    required String locale,
  }) async {
    if (idsOf(spendingOf(widget)).isEmpty) return;
    final ids = _MappedListenable(_spendingLive, idsOf);
    try {
      await showTransactionsSheet(context, ids: ids, title: title, locale: locale);
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
