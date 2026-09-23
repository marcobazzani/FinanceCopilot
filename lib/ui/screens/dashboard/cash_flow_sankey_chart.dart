part of 'dashboard_screen.dart';

/// Yearly income and savings, exactly as the Income/Expense/Savings chart
/// computes them (expenses = income − savings).
typedef CashFlowYearTotals = ({double income, double savings});

/// "Where the money goes": one year of cash flow as a Sankey — income (+ from
/// savings / untracked income) → available → essential / discretionary /
/// uncategorized / untracked expenses / saved
/// → expense categories. The current year is year to date.
///
/// Income, savings and expenses are [years] (the yearly chart's figures); the
/// ledger in [spending] only splits the expenses by category, and what it
/// does not account for stays visible as untracked income / expenses. Privacy mode
/// masks the amounts; band widths and percentages (shape, not size) stay.
class CashFlowSankeyCard extends ConsumerStatefulWidget {
  final SpendingByCategoryData spending;
  final Map<int, CashFlowYearTotals> years;
  final int currentYear;
  final String locale;
  const CashFlowSankeyCard({super.key, required this.spending, required this.years, required this.currentYear, required this.locale});

  @override
  ConsumerState<CashFlowSankeyCard> createState() => CashFlowSankeyCardState();
}

class CashFlowSankeyCardState extends ConsumerState<CashFlowSankeyCard> {
  int? _year;

  /// Live spending data for an open drill-down sheet: the sheet is its own
  /// route and is not rebuilt with this card, so it listens to this instead.
  late final _spendingLive = ValueNotifier<SpendingByCategoryData>(widget.spending);

  @override
  void didUpdateWidget(CashFlowSankeyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spending != widget.spending) _spendingLive.value = widget.spending;
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

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final d = widget.spending;
    final byId = ref.watch(categoriesByIdProvider);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final years = [
      for (final e in widget.years.entries)
        if (e.value.income.abs() >= 0.005 || e.value.savings.abs() >= 0.005 || d.totalFor(e.key) >= 0.005) e.key,
    ]..sort();
    if (years.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(s.spendingByCategoryEmpty, textAlign: TextAlign.center, key: const Key('spendingEmpty')),
      );
    }

    final year = _effectiveYear(years);
    final totals = widget.years[year]!;
    final graph = buildCashFlowSankey(year: year, income: totals.income, savings: totals.savings, spending: d, categories: byId);
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
      CashFlowNodeKind.untrackedIncome => Colors.green.shade300,
      CashFlowNodeKind.uncategorized => scheme.outlineVariant,
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
      CashFlowNodeKind.untrackedIncome => s.sankeyUntrackedIncome,
      CashFlowNodeKind.uncategorized => s.uncategorized,
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
              onNodeTap: (id) => _onNodeTap(context, nodeById[id]!, year, labelOf(nodeById[id]!)),
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
              if (d.transfersExcluded(year) >= 0.005)
                // How much money was moved: position size, masked.
                PrivacyText(
                  s.sankeyTransfersExcluded(money.format(d.transfersExcluded(year))),
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

  Future<void> _onNodeTap(BuildContext context, CashFlowNode node, int year, String label) async {
    final categoryId = switch (node.kind) {
      CashFlowNodeKind.expense => node.categoryId,
      CashFlowNodeKind.uncategorized => null,
      _ => -1,
    };
    if (categoryId == -1 || widget.spending.ids(year, categoryId).isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (ctx, controller) => _NodeTransactionsSheet(
          spending: _spendingLive,
          year: year,
          categoryId: categoryId,
          label: label,
          locale: widget.locale,
          controller: controller,
        ),
      ),
    );
  }
}

/// A node's transactions, biggest first; tapping one swaps the list for the
/// classification wizard's card in the same sheet (no dialog over the
/// sheet). Back / Skip / Apply return to the list, which follows the ledger.
class _NodeTransactionsSheet extends ConsumerStatefulWidget {
  final ValueListenable<SpendingByCategoryData> spending;
  final int year;

  /// Category of the node; null = uncategorized.
  final int? categoryId;
  final String label;
  final String locale;
  final ScrollController controller;
  const _NodeTransactionsSheet({
    required this.spending,
    required this.year,
    required this.categoryId,
    required this.label,
    required this.locale,
    required this.controller,
  });

  @override
  ConsumerState<_NodeTransactionsSheet> createState() => _NodeTransactionsSheetState();
}

class _NodeTransactionsSheetState extends ConsumerState<_NodeTransactionsSheet> {
  ({MerchantGroup group, List<Transaction> rows})? _classifying;
  int? _loadingId;

  Future<void> _open(Transaction t) async {
    setState(() => _loadingId = t.id);
    final base = ref.read(baseCurrencyProvider).value;
    final rates = base == null ? null : CachedRateResolver(ref.read(exchangeRateServiceProvider), base);
    final ctx = await ref.read(transactionClassifierServiceProvider).classificationContextFor(t.id, rate: rates?.getRate, baseCurrency: base);
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
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 16, 4),
            child: Row(
              children: [
                IconButton(key: const Key('sankeySheetBack'), icon: const Icon(Icons.arrow_back), onPressed: _back),
                Expanded(child: Text('${widget.label} · ${widget.year}', style: theme.textTheme.titleMedium)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: widget.controller,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              child: TransactionClassifyCard(
                key: ValueKey(('classify', c.rows.first.id)),
                group: c.group,
                samples: c.rows,
                onSkip: _back,
                onApplied: (_) => _back(),
              ),
            ),
          ),
        ],
      );
    }

    final txs = ref.watch(allTransactionsProvider).value ?? const <Transaction>[];
    return ValueListenableBuilder<SpendingByCategoryData>(
      valueListenable: widget.spending,
      builder: (context, spending, _) {
        // Exactly the rows summed into the node, biggest first (|amount| in
        // the row's own currency); newest, then id, break ties.
        final ids = spending.ids(widget.year, widget.categoryId).toSet();
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
              child: Text('${widget.label} · ${widget.year} (${rows.length})', style: theme.textTheme.titleMedium),
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
