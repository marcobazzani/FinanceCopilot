part of 'dashboard_screen.dart';

// ════════════════════════════════════════════════════
// Cash Flow overview: Expenses, Income and Savings, and their screens
// ════════════════════════════════════════════════════

/// The three figures of the overview, each with its own screen: the same
/// Income, Expenses and Savings as Year by year and the Sankey.
enum _Stat { expenses, income, savings }

/// What the Expenses screen is narrowed to: one category, merchant, account
/// or currency; [label] names it.
enum _FilterKind { category, merchant, account, currency }

typedef _SpendFilter = ({_FilterKind kind, Object? key, String label});

/// One step of the Expenses drill-down: a kind and the values it keeps, each
/// with its name. The values of a step add up (one merchant or another: a
/// supplier and the one that replaced it); the steps narrow one another (a
/// category, then merchants in it).
typedef _FilterStep = ({_FilterKind kind, Map<Object?, String> keys});

/// Whether [e] matches a value of [st].
bool _keepsStep(_FilterStep st, SpendingEntry e) => st.keys.keys.any((k) => _keeps((kind: st.kind, key: k, label: ''), e));

/// Whether [e] matches every step of [steps].
bool _keepsAll(List<_FilterStep> steps, SpendingEntry e) => steps.every((st) => _keepsStep(st, e));

/// The steps with [f] added: a value of a kind already narrowed joins that
/// step; another kind is a new step after the others.
List<_FilterStep> _withFilter(List<_FilterStep> steps, _SpendFilter f) {
  final i = steps.indexWhere((x) => x.kind == f.kind);
  if (i < 0) {
    return [
      ...steps,
      (kind: f.kind, keys: {f.key: f.label}),
    ];
  }
  return [...steps]..[i] = (kind: f.kind, keys: {...steps[i].keys, f.key: f.label});
}

/// What the list groups by once [steps] narrow the screen: the categories
/// until one is picked, then the merchants in it; [current] once both are.
_SpentBy _nextGrouping(List<_FilterStep> steps, _SpentBy current) {
  final kinds = {for (final st in steps) st.kind};
  if (!kinds.contains(_FilterKind.category)) return _SpentBy.category;
  if (!kinds.contains(_FilterKind.merchant)) return _SpentBy.merchant;
  return current;
}

/// What [e] is under [kind] — its category, merchant, account or currency —
/// with [names] to name it; null when it has none (a row without a merchant,
/// a saving plan's step without a category or an account).
({Object? key, String name})? _valueOf(
  _FilterKind kind,
  SpendingEntry e, {
  required String Function(int? category) categoryName,
  required Map<int, String> accounts,
}) => switch (kind) {
  _FilterKind.category => e.plan != null ? null : (key: e.categoryId, name: categoryName(e.categoryId)),
  _FilterKind.merchant => e.merchantKey == null ? null : (key: e.merchantKey, name: e.merchantName ?? e.merchantKey!),
  _FilterKind.account => e.accountId == null ? null : (key: e.accountId, name: accounts[e.accountId] ?? '#${e.accountId}'),
  _FilterKind.currency => (key: e.currency, name: e.currency),
};

/// Whether [e] is one of the spending rows [f] keeps. A saving plan's steps
/// have no category, merchant or account.
bool _keeps(_SpendFilter f, SpendingEntry e) => switch (f.kind) {
  _FilterKind.category => e.plan == null && e.categoryId == f.key,
  _FilterKind.merchant => e.merchantKey != null && e.merchantKey == f.key,
  _FilterKind.account => e.accountId != null && e.accountId == f.key,
  _FilterKind.currency => e.currency == f.key,
};

/// How the spending list groups its rows.
enum _SpentBy { category, merchant, account, currency }

/// [stats] of [period] for the overview or a screen, from the live data.
_PeriodStats _statsFor(WidgetRef ref, CashFlowPeriod period, {required String language}) {
  final ieData = ref.watch(_incomeExpenseDataProvider).value;
  final spending = ref.watch(_spendingByCategoryProvider).value;
  return _PeriodStats.of(
    period: period,
    compare: ref.watch(_cashFlowCompareProvider),
    today: ref.watch(currentDateProvider),
    available: _availableMonths(ieData, spending),
    ieData: ieData,
    spending: spending,
    s: ref.watch(appStringsProvider),
    language: language,
  );
}

/// The currency symbol the Cash Flow figures are in.
String _cashFlowSymbol(WidgetRef ref) => currencySymbol(
  ref.watch(_incomeExpenseDataProvider).value?.baseCurrency ?? ref.watch(_spendingByCategoryProvider).value?.baseCurrency ?? '',
);

/// Goes to [period]: the overview, its screens and the sections below follow.
void _showPeriod(WidgetRef ref, CashFlowPeriod period) => ref.read(_cashFlowPeriodProvider.notifier).state = period;

/// The Cash Flow overview: what the period earned, spent and kept, as three
/// cards. Swiping the cards, or tapping a name on the strip under them, moves
/// one period at a time (a month by a month, a week by a week); each card
/// opens its screen.
class _CashFlowOverview extends ConsumerStatefulWidget {
  final CashFlowPeriod period;
  final Map<int, List<int>> available;
  final DateTime today;
  final String locale;
  final String language;
  const _CashFlowOverview({required this.period, required this.available, required this.today, required this.locale, required this.language});

  @override
  ConsumerState<_CashFlowOverview> createState() => _CashFlowOverviewState();
}

class _CashFlowOverviewState extends ConsumerState<_CashFlowOverview> {
  late List<CashFlowPeriod> _periods;
  late PageController _controller;

  @override
  void initState() {
    super.initState();
    final pages = _pagesOf(widget.period, widget.available, widget.today);
    _periods = pages.periods;
    _controller = PageController(initialPage: pages.index);
  }

  @override
  void didUpdateWidget(covariant _CashFlowOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pages = _pagesOf(widget.period, widget.available, widget.today);
    if (pages.periods.length != _periods.length || pages.periods.first != _periods.first) {
      // Another kind of period, or more data: another run of pages.
      final old = _controller;
      _periods = pages.periods;
      _controller = PageController(initialPage: pages.index);
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    } else if (_controller.hasClients && _controller.page?.round() != pages.index) {
      // Moved from elsewhere (a screen, the selector): the cards follow.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(pages.index);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final index = max(0, _periods.indexOf(widget.period));
    final stats = _statsFor(ref, widget.period, language: widget.language);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  stats.label,
                  key: const Key('cfOverviewPeriod'),
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            _CompareMenu(compare: ref.watch(_cashFlowCompareProvider)),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 380,
          child: NotificationListener<ScrollEndNotification>(
            // The period moves once the cards have settled: the sections below
            // rebuild with it, and doing that while the page is still sliding
            // stalls the swipe.
            onNotification: (_) {
              final i = _controller.page?.round();
              if (i != null && _periods[i] != widget.period) _showPeriod(ref, _periods[i]);
              return false;
            },
            child: PageView.builder(
              key: ValueKey('cfOverviewPages:${_periods.first}:${_periods.length}'),
              controller: _controller,
              itemCount: _periods.length,
              itemBuilder: (context, i) => _OverviewPage(
                stats: i == index ? stats : _statsFor(ref, _periods[i], language: widget.language),
                current: i == index,
                locale: widget.locale,
                language: widget.language,
              ),
            ),
          ),
        ),
        if (_periods.length > 1)
          _PeriodStrip(
            periods: _periods,
            index: index,
            language: widget.language,
            tooltipOf: (p) => p.label(s, widget.language, widget.today),
            onTap: (i) => _controller.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic),
          ),
        if (stats.notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              stats.notes.join('\n'),
              key: const Key('cfComparedWith'),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

/// The figure of [stat] as a card or a screen shows it, flying between the
/// two (the overview's current page only: one hero a tag).
Widget _statAmount(String text, {required _Stat stat, required bool hero, TextStyle? style, Key? key}) {
  final child = Material(
    type: MaterialType.transparency,
    child: PrivacyText(text, key: key, style: style, maxLines: 1),
  );
  return hero ? Hero(tag: 'cfStat:${stat.name}', child: child) : child;
}

/// One period of the overview: Expenses across the top, Income and Savings
/// under it.
class _OverviewPage extends ConsumerWidget {
  final _PeriodStats stats;

  /// The page shown (not a neighbour built for the swipe).
  final bool current;
  final String locale;
  final String language;
  const _OverviewPage({required this.stats, required this.current, required this.locale, required this.language});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final symbol = _cashFlowSymbol(ref);
    final money = fmt.currencyFormat(locale, symbol);
    final title = theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant);
    final big = theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700);
    void open(_Stat stat) => Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => _StatScreen(stat: stat, locale: locale, language: language),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    );
    // The income bars: the parts of the period, as its screen shows them.
    final incomeBars = [for (final p in stats.parts) (value: p.income, future: p.future)];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        children: [
          SizedBox(
            height: 196,
            child: _OverviewCard(
              key: const Key('cfExpensesCard'),
              onTap: () => open(_Stat.expenses),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.legendExpenses, style: title),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: _statAmount(
                          money.format(stats.expenses),
                          stat: _Stat.expenses,
                          hero: current,
                          style: big,
                          key: const Key('cfExpensesTotal'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (stats.expensesVs case final vs?) _moneyChange(vs.current, vs.base, upIsGood: false, money: money),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _RunningChart(
                      now: stats.expensesRun,
                      before: stats.expensesRunBefore,
                      days: stats.dayCount,
                      ticks: stats.ticks,
                      good: _isBetterVs(stats.expensesVs, upIsGood: false),
                      locale: locale,
                      symbol: symbol,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 172,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _OverviewCard(
                    key: const Key('cfIncomeCard'),
                    onTap: () => open(_Stat.income),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.legendIncome, style: title),
                        const SizedBox(height: 2),
                        _statAmount(money.format(stats.income), stat: _Stat.income, hero: current, style: big, key: const Key('cfIncomeTotal')),
                        if (stats.incomeVs case final vs?) _moneyChange(vs.current, vs.base, upIsGood: true, money: money),
                        const SizedBox(height: 10),
                        Expanded(
                          child: _MiniBars(bars: incomeBars, color: Colors.blue.shade400),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _OverviewCard(
                    key: const Key('cfSavingsCard'),
                    onTap: () => open(_Stat.savings),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.legendSavings, style: title),
                        const SizedBox(height: 2),
                        _statAmount(
                          money.format(stats.savings),
                          stat: _Stat.savings,
                          hero: current,
                          style: big,
                          key: const Key('cfSavingsTotal'),
                        ),
                        _NetSign(net: stats.savings),
                        const Spacer(),
                        _InOutBars(income: stats.income, spent: stats.expenses),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "In the black" or "In the red", with its sign.
class _NetSign extends ConsumerWidget {
  final double net;
  const _NetSign({required this.net});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final color = net >= 0 ? Colors.green.shade500 : theme.colorScheme.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(net >= 0 ? Icons.add_circle : Icons.remove_circle, size: 16, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            net >= 0 ? s.cfInPositive : s.cfInNegative,
            style: theme.textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// A rounded tile of the overview; tappable when [onTap] is given.
class _OverviewCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _OverviewCard({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.fromLTRB(18, 16, 18, 14), child: child),
    ),
  );
}

/// Where the overview is: five periods in a row, each with its name, the one
/// shown highlighted. The five stay put while you move among them; ‹ › go to
/// the five before or after. Tapping a name goes to that period.
class _PeriodStrip extends StatelessWidget {
  final List<CashFlowPeriod> periods;
  final int index;
  final String language;
  final String Function(CashFlowPeriod period) tooltipOf;
  final ValueChanged<int> onTap;
  const _PeriodStrip({required this.periods, required this.index, required this.language, required this.tooltipOf, required this.onTap});

  static const _block = 5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Blocks of five counted back from the latest period, so the newest block
    // always ends with it.
    final last = periods.length - 1;
    final end = last - ((last - index) ~/ _block) * _block;
    final start = max(0, end - _block + 1);
    return Row(
      children: [
        IconButton(
          key: const Key('cfStripOlder'),
          icon: const Icon(Icons.chevron_left),
          onPressed: start > 0 ? () => onTap(start - 1) : null,
        ),
        // The oldest block may hold fewer than five: the slots keep their place.
        for (var i = end - start + 1; i < _block; i++) const Spacer(),
        for (var i = start; i <= end; i++)
          Expanded(
            child: Tooltip(
              message: tooltipOf(periods[i]),
              child: InkWell(
                key: Key('cfStrip:$i'),
                borderRadius: BorderRadius.circular(16),
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  height: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? scheme.surfaceContainerHighest : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    shortLabel(periods[i], language),
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: i == index ? scheme.onSurface : scheme.onSurfaceVariant,
                      fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        IconButton(
          key: const Key('cfStripNewer'),
          icon: const Icon(Icons.chevron_right),
          onPressed: end < last ? () => onTap(end + 1) : null,
        ),
      ],
    );
  }
}

/// What the overview and its screens compare the period with: the period
/// before it, the same period a year earlier, or nothing.
class _CompareMenu extends ConsumerWidget {
  final CashFlowCompare compare;
  const _CompareMenu({required this.compare});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final names = {
      CashFlowCompare.none: s.cfCompareNone,
      CashFlowCompare.previous: s.cfComparePrevious,
      CashFlowCompare.yearEarlier: s.cfCompareYearEarlier,
    };
    return PopupMenuButton<CashFlowCompare>(
      key: const Key('cfCompare'),
      tooltip: s.cfCompare,
      initialValue: compare,
      onSelected: (c) => ref.read(_cashFlowCompareProvider.notifier).state = c,
      itemBuilder: (_) => [for (final c in CashFlowCompare.values) PopupMenuItem(value: c, child: Text(names[c]!))],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.compare_arrows, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              compare == CashFlowCompare.none ? s.cfCompare : names[compare]!,
              style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
            ),
            Icon(Icons.arrow_drop_down, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

/// The span selector: this week, month, half year or year in one tap, and
/// "⋯" for a custom period. The current span is highlighted; a custom period
/// highlights "⋯".
class _SpanSelector extends ConsumerWidget {
  final CashFlowPeriod period;
  final Map<int, List<int>> available;
  const _SpanSelector({required this.period, required this.available});

  Future<void> _pickCustom(BuildContext context, WidgetRef ref, DateTime today) async {
    final s = ref.read(appStringsProvider);
    final first = _firstMonth(available, today);
    final firstDay = DateTime(first.$1, first.$2, 1);
    final day = dayOf(today);
    DateTime clamp(DateTime d) => d.isBefore(firstDay) ? firstDay : (d.isAfter(day) ? day : d);
    final range = await showDateRangePicker(
      context: context,
      firstDate: firstDay,
      lastDate: day,
      initialDateRange: period.start == null ? null : DateTimeRange(start: clamp(period.start!), end: clamp(period.end!)),
      helpText: s.cfCustomPeriod,
    );
    if (range == null) return;
    _showPeriod(ref, CashFlowPeriod.fromDays(range.start, range.end));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final today = ref.watch(currentDateProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = period.span;
    final labels = {
      CashFlowSpan.week: s.cfSpanWeek,
      CashFlowSpan.month: s.cfSpanMonth,
      CashFlowSpan.half: s.cfSpanHalf,
      CashFlowSpan.year: s.cfSpanYear,
    };
    const spans = CashFlowSpan.values;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(22)),
            child: LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth / spans.length;
                return Stack(
                  children: [
                    if (selected != null)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        left: spans.indexOf(selected) * w,
                        width: w,
                        top: 0,
                        bottom: 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(18)),
                        ),
                      ),
                    Row(
                      children: [
                        for (final span in spans)
                          Expanded(
                            child: InkWell(
                              key: Key('cfSpan:${span.name}'),
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => _showPeriod(ref, CashFlowPeriod.current(span, today)),
                              child: Center(
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: (theme.textTheme.titleSmall ?? const TextStyle()).copyWith(
                                    color: span == selected ? scheme.onSurface : scheme.onSurfaceVariant,
                                    fontWeight: span == selected ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                  child: Text(labels[span]!),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: s.cfCustomPeriod,
          child: Material(
            color: selected == null ? scheme.surfaceContainerHighest : scheme.surfaceContainerHigh,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const Key('cfSpanCustom'),
              onTap: () => _pickCustom(context, ref, today),
              child: const SizedBox(width: 44, height: 44, child: Icon(Icons.more_horiz)),
            ),
          ),
        ),
      ],
    );
  }
}

/// A screen of one figure — Expenses, Income or Savings: the figure and its
/// change, a chart (running total, bars or ring), the span selector, then
/// what the figure is made of. It follows the Cash Flow period and moves it.
class _StatScreen extends ConsumerStatefulWidget {
  final _Stat stat;
  final String locale;
  final String language;
  const _StatScreen({required this.stat, required this.locale, required this.language});

  @override
  ConsumerState<_StatScreen> createState() => _StatScreenState();
}

class _StatScreenState extends ConsumerState<_StatScreen> {
  /// Expenses opens on its card's running total, Income and Savings on bars.
  late _ChartMode _mode = widget.stat == _Stat.expenses ? _ChartMode.running : _ChartMode.bars;

  /// The bar picked and the period it is a part of; null: the whole period.
  ({CashFlowPeriod period, int index})? _picked;

  /// What the Expenses screen is narrowed to (list rows or ring slices
  /// tapped, values added on a step), in the order picked; it stays across
  /// chart modes, spans and periods. Empty: all.
  List<_FilterStep> _steps = const [];

  void _addFilter(_SpendFilter f) => setState(() {
    _steps = _withFilter(_steps, f);
    _narrowBy = _nextGrouping(_steps, _narrowBy);
  });

  /// How the list under a narrowed screen groups its rows: what the next
  /// step picks among. The whole screen's list keeps its own grouping.
  _SpentBy _narrowBy = _SpentBy.category;

  void _removeStep(int i) => setState(() => _steps = [..._steps]..removeAt(i));

  /// Picks the values of step [i] among those the other steps leave, in the
  /// period and in the days it is compared with: a merchant paid only last
  /// year can join the comparison. None picked removes the step.
  Future<void> _editStep(int i, SpendingByCategoryData spending, _PeriodStats stats, Map<int, String> accounts) async {
    final s = ref.read(appStringsProvider);
    final byId = ref.read(categoriesByIdProvider);
    final step = _steps[i];
    final others = [..._steps]..removeAt(i);
    final now = <Object?, double>{}, before = <Object?, double>{}, names = <Object?, String>{};
    void collect(Iterable<SpendingEntry> rows, Map<Object?, double> into) {
      for (final e in rows) {
        if (!_keepsAll(others, e)) continue;
        final v = _valueOf(step.kind, e, categoryName: (id) => categoryLabelFor(id, byId, s), accounts: accounts);
        if (v == null) continue;
        into[v.key] = (into[v.key] ?? 0) + e.amount;
        names[v.key] ??= v.name;
      }
    }

    collect(spending.entriesBetween(stats.start, stats.until), now);
    collect(spending.entriesIn(stats.comparedDays), before);
    double both(Object? k) => (now[k] ?? 0) + (before[k] ?? 0);
    final keys = names.keys.toList()..sort((a, b) => both(b).compareTo(both(a)));
    final picked = await showDialog<Map<Object?, String>>(
      context: context,
      builder: (_) => _StepValuesDialog(
        keys: keys,
        names: names,
        now: now,
        before: stats.comparedDays.isEmpty ? null : before,
        vsLabel: stats.vsLabel,
        picked: step.keys,
        locale: widget.locale,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _steps = [..._steps]..[i] = (kind: step.kind, keys: picked));
    if (picked.isEmpty) _removeStep(i);
  }

  /// How the Expenses list groups its rows; it stays as the screen changes
  /// around it, a filter set and cleared included.
  _SpentBy _spentBy = _SpentBy.category;

  /// The bars of [stats]: its parts; on Savings a pair per month of it, or
  /// the period itself when it is a month or shorter.
  List<_Part> _barsOf(_PeriodStats stats) {
    if (widget.stat != _Stat.savings) return stats.parts;
    final span = partSpanOf(stats.period);
    if (span == CashFlowPartSpan.month || span == CashFlowPartSpan.year) return stats.parts;
    return [
      (
        label: shortLabel(stats.period, widget.language),
        start: stats.start,
        end: stats.end,
        income: stats.income,
        expenses: stats.expenses,
        savings: stats.savings,
        future: false,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = ref.watch(currentDateProvider);
    final ieData = ref.watch(_incomeExpenseDataProvider).value;
    final spending = ref.watch(_spendingByCategoryProvider).value;
    final available = _availableMonths(ieData, spending);
    final period = _periodOrDefault(ref.watch(_cashFlowPeriodProvider), today);
    final stats = _statsFor(ref, period, language: widget.language);
    final symbol = _cashFlowSymbol(ref);
    final money = fmt.currencyFormat(widget.locale, symbol);
    final muted = theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant);
    final stat = widget.stat;
    final first = _firstMonth(available, today);
    final byId = ref.watch(categoriesByIdProvider);

    // A bar picked shows its part: its figure, its lists, against the
    // period's average part.
    final bars = _barsOf(stats);
    final picked = _picked?.period == period ? _picked!.index : null;
    final part = picked == null || picked >= bars.length ? null : bars[picked];
    final partPeriod = part == null ? null : CashFlowPeriod.fromDays(part.start, part.end);
    final shown = partPeriod == null ? stats : _statsFor(ref, partPeriod, language: widget.language);
    void pick(int i) {
      if (i >= bars.length || bars[i].future) return;
      setState(() => _picked = picked == i ? null : (period: period, index: i));
    }

    void step(int by) {
      if (period.canStep(by, first, today)) _showPeriod(ref, period.shifted(by));
    }

    final (title, value, change, upIsGood, whole) = switch (stat) {
      _Stat.expenses => (s.legendExpenses, shown.expenses, stats.expensesVs, false, stats.expenses),
      _Stat.income => (s.legendIncome, shown.income, stats.incomeVs, true, stats.income),
      _Stat.savings => (s.legendSavings, shown.savings, stats.savingsVs, true, stats.savings),
    };
    // Narrowed to a category, merchant, account or currency: the spending rows
    // it keeps — over the period, each part, and the period compared with.
    final filter = stat == _Stat.expenses && spending != null && _steps.isNotEmpty
        ? (kind: _steps.last.kind, key: _steps.last.keys.keys.first, label: _steps.map((st) => st.keys.values.join(', ')).join(' › '))
        : null;
    bool keeps(SpendingEntry e) => _keepsAll(_steps, e);
    final day = dayOf(today);
    DateTime upTo(DateTime end) => end.isAfter(day) ? day : end;
    final narrowParts = filter == null
        ? null
        : [for (final b in bars) b.future ? 0.0 : spending!.spentBetween(b.start, upTo(b.end), where: keeps)];
    final narrowTotal = filter == null ? null : spending!.spentBetween(stats.start, stats.until, where: keeps);
    final narrowValue = filter == null ? null : (part == null ? narrowTotal : spending!.spentBetween(part.start, upTo(part.end), where: keeps));

    // The average part: of the parts begun; narrowed, of those since its first
    // spending (a category first used in February is not averaged over
    // January).
    final double? average;
    if (narrowParts != null) {
      final firstUsed = narrowParts.indexWhere((a) => a.abs() >= 0.005);
      final parts = firstUsed < 0 ? 0 : stats.partsBegun - firstUsed;
      average = parts <= 0 ? null : narrowTotal! / parts;
    } else {
      // Picked, or Expenses as bars: the average part stands where the change would.
      final shows = part != null || (stat == _Stat.expenses && _mode == _ChartMode.bars);
      average = !shows || stats.partsBegun == 0 ? null : whole / stats.partsBegun;
    }
    String averageOf(String amount) => switch (partSpanOf(period)) {
      CashFlowPartSpan.day => s.cfAveragePerDay(amount),
      CashFlowPartSpan.week => s.cfAveragePerWeek(amount),
      CashFlowPartSpan.month => s.cfAveragePerMonth(amount),
      CashFlowPartSpan.year => s.cfAveragePerYear(amount),
    };

    final ringCategories = shown.spending.byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final narrowNow = filter == null ? null : spending!.runningBetween(stats.start, stats.until, where: keeps);
    final narrowBefore = filter == null || stats.otherStart == null || stats.otherEnd == null
        ? null
        : spending!.runningBetween(stats.otherStart!, stats.otherEnd!, where: keeps);
    // Narrowed, the figure against the same days of the period compared with
    // (as the whole Expenses are), and that period's whole.
    final narrowVs = filter == null || narrowTotal == null || stats.comparedDays.isEmpty || narrowBefore == null
        ? null
        : (
            now: narrowTotal,
            before: spending!.entriesIn(stats.comparedDays).where(keeps).fold(0.0, (a, e) => a + e.amount),
            whole: narrowBefore.isEmpty ? 0.0 : narrowBefore.last,
          );
    final accounts = {for (final a in ref.watch(accountsProvider).value ?? const <Account>[]) a.id: a.name};
    final stepCategory = _steps.where((x) => x.kind == _FilterKind.category).firstOrNull;
    // Narrowed to merchants, the list is their rows; before, what the next
    // step would pick among, above the rows.
    final breakdown = !_steps.any((x) => x.kind == _FilterKind.merchant);
    final narrowedData = filter == null
        ? null
        : SpendingByCategoryData(
            years: spending!.years,
            currentYear: spending.currentYear,
            fxExcluded: spending.fxExcluded,
            baseCurrency: spending.baseCurrency,
            entries: spending.entries.where(keeps).toList(),
          );

    Widget chart() {
      if (stat == _Stat.savings) {
        return _BarsChart(
          bars: [for (final (i, b) in bars.indexed) (label: b.label, a: b.income, b: b.expenses, highlight: picked == null || picked == i)],
          color: scheme.primary,
          locale: widget.locale,
          symbol: symbol,
          onTap: pick,
        );
      }
      final spent = stat == _Stat.expenses;
      return switch (_mode) {
        _ChartMode.running => _RunningChart(
          now: narrowNow ?? (spent ? stats.expensesRun : stats.incomeRun),
          before: filter != null ? narrowBefore : (spent ? stats.expensesRunBefore : stats.incomeRunBefore),
          days: stats.dayCount,
          ticks: stats.ticks,
          good: narrowNow != null
              ? (narrowNow.isEmpty || narrowBefore == null || narrowBefore.length < narrowNow.length
                    ? null
                    : _isBetter(narrowNow.last, narrowBefore[narrowNow.length - 1], upIsGood: false))
              : _isBetterVs(spent ? stats.expensesVs : stats.incomeVs, upIsGood: !spent),
          detailed: true,
          locale: widget.locale,
          symbol: symbol,
          title: filter?.label ?? title,
          upIsGood: upIsGood,
          start: stats.start,
          otherStart: stats.otherStart,
          language: widget.language,
        ),
        _ChartMode.bars => _BarsChart(
          bars: [
            for (final (i, b) in bars.indexed)
              (label: b.label, a: narrowParts?[i] ?? (spent ? b.expenses : b.income), b: null, highlight: picked == null || picked == i),
          ],
          color: spent ? scheme.error : Colors.blue.shade400,
          locale: widget.locale,
          symbol: symbol,
          onTap: pick,
          // The average part, against the one picked.
          average: spent ? average : null,
        ),
        _ChartMode.ring => _RingChart(
          slices: [
            for (final MapEntry(key: id, value: v) in ringCategories)
              (value: v, color: categoryPaintOrNone(id == null ? null : byId[id], scheme)),
            for (final p in shown.spending.savingPlans) (value: p.amount, color: Colors.amber.shade700),
          ],
          // A category picked stands out; tapping a slice picks its category.
          highlight: stepCategory == null ? null : ringCategories.indexWhere((e) => stepCategory.keys.containsKey(e.key)),
          onTap: (i) {
            if (i >= ringCategories.length) return;
            final id = ringCategories[i].key;
            _addFilter((kind: _FilterKind.category, key: id, label: categoryLabelFor(id, byId, s)));
          },
        ),
      };
    }

    return PopScope(
      canPop: _steps.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _steps.isNotEmpty) _removeStep(_steps.length - 1);
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            if (stat != _Stat.savings)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _ModeToggle(
                  mode: _mode,
                  ring: stat == _Stat.expenses,
                  onChanged: (m) => setState(() {
                    _mode = m;
                    _picked = null;
                  }),
                ),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: title,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: ' · ${filter?.label ?? stats.label}',
                          style: theme.textTheme.titleLarge?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    key: const Key('cfStatTitle'),
                  ),
                ),
                IconButton(
                  tooltip: s.cfPreviousPeriodTooltip,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: period.canStep(-1, first, today) ? () => _showPeriod(ref, period.shifted(-1)) : null,
                ),
                IconButton(
                  tooltip: s.cfNextPeriodTooltip,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: period.canStep(1, first, today) ? () => _showPeriod(ref, period.shifted(1)) : null,
                ),
              ],
            ),
            _statAmount(
              money.format(narrowValue ?? value),
              stat: stat,
              hero: true,
              key: const Key('cfStatTotal'),
              style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            // Savings: what they are made of, then how they moved.
            if (stat == _Stat.savings)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  children: [
                    _InOutAmount(icon: Icons.add_circle, color: Colors.green.shade500, text: money.format(shown.income)),
                    _InOutAmount(icon: Icons.remove_circle, color: scheme.error, text: money.format(shown.expenses)),
                    if (partPeriod != null) Text('· ${partPeriod.label(s, widget.language, today)}', style: muted),
                  ],
                ),
              ),
            // A part picked, a filter, or Expenses as bars: the average part and
            // where the figure stands; else the change.
            if (stat != _Stat.savings && (average != null || partPeriod != null || filter != null))
              Wrap(
                key: const Key('cfStatAverage'),
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Icon(Icons.bar_chart, size: 18, color: scheme.primary),
                  if (average != null)
                    PrivacySentence(
                      averageOf(privacySlot(0)),
                      figures: [money.format(average)],
                      style: theme.textTheme.bodyLarge?.copyWith(color: scheme.primary),
                    ),
                  Text('· ${(partPeriod ?? period).label(s, widget.language, today)}', style: muted),
                ],
              ),
            if (narrowVs != null && partPeriod == null)
              Padding(
                key: const Key('cfFilterVs'),
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    _moneyChange(narrowVs.now, narrowVs.before, upIsGood: false, money: money),
                    if (stats.vsLabel case final vs?) Text(s.cfVs(vs), style: muted),
                    PrivacyText(
                      '(${money.format(narrowVs.before)} → ${money.format(narrowVs.whole)})',
                      key: const Key('cfFilterVsWhole'),
                      style: muted,
                    ),
                  ],
                ),
              ),
            if (stat != _Stat.savings && (average != null || partPeriod != null || filter != null))
              const SizedBox.shrink()
            else if (change != null && partPeriod == null)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  _moneyChange(change.current, change.base, upIsGood: upIsGood, money: money, large: true),
                  if (stats.vsLabel case final vs?) Text(s.cfVs(vs), style: muted),
                ],
              ),
            const SizedBox(height: 20),
            // A swipe on the bars or the ring goes to the period before or after.
            GestureDetector(
              key: const Key('cfStatChart'),
              onHorizontalDragEnd: _mode == _ChartMode.running && stat != _Stat.savings
                  ? null
                  : (d) {
                      final v = d.primaryVelocity ?? 0;
                      if (v.abs() >= 200) step(v < 0 ? 1 : -1);
                    },
              child: SizedBox(height: 240, child: chart()),
            ),
            const SizedBox(height: 20),
            _SpanSelector(period: period, available: available),
            if (stats.notes.isNotEmpty && partPeriod == null && filter == null && average == null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(stats.notes.join('\n'), style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ),
            const SizedBox(height: 24),
            if (spending != null)
              switch (stat) {
                _Stat.expenses when filter != null => _FilteredRows(
                  filter: filter,
                  entries: [
                    for (final e in spending.entriesBetween(part?.start ?? stats.start, part == null ? stats.until : upTo(part.end)))
                      if (keeps(e)) e,
                  ],
                  locale: widget.locale,
                  language: widget.language,
                  onClear: () => setState(() => _steps = const []),
                  title: Wrap(
                    key: const Key('cfFilterSteps'),
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (i, st) in _steps.indexed)
                        _StepChip(
                          key: Key('cfFilterStep:$i'),
                          step: st,
                          onEdit: () => _editStep(i, spending, stats, accounts),
                          onRemove: () => _removeStep(i),
                        ),
                    ],
                  ),
                  breakdown: breakdown
                      ? _SpentList(
                          spending: narrowedData!,
                          narrowed: true,
                          stats: shown,
                          locale: widget.locale,
                          language: widget.language,
                          by: _narrowBy,
                          onBy: (by) => setState(() => _narrowBy = by),
                          onFilter: _addFilter,
                        )
                      : null,
                ),
                _Stat.expenses => _SpentList(
                  spending: spending,
                  stats: shown,
                  locale: widget.locale,
                  language: widget.language,
                  by: _spentBy,
                  onBy: (by) => setState(() => _spentBy = by),
                  onFilter: _addFilter,
                ),
                _Stat.income => _IncomeList(stats: shown, locale: widget.locale, language: widget.language),
                _Stat.savings => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(title: s.legendIncome, amount: '+${money.format(shown.income)}'),
                    _IncomeList(stats: shown, locale: widget.locale, language: widget.language, titled: false),
                    const SizedBox(height: 24),
                    _SectionTitle(title: s.legendExpenses, amount: '−${money.format(shown.expenses)}'),
                    _SpentList(spending: spending, stats: shown, locale: widget.locale, language: widget.language, titled: false),
                  ],
                ),
              },
          ],
        ),
      ),
    );
  }
}

/// A step of the Expenses drill-down: its kind's icon and its values; a tap
/// picks its values, ✕ removes it.
class _StepChip extends ConsumerWidget {
  final _FilterStep step;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  const _StepChip({super.key, required this.step, required this.onEdit, required this.onRemove});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return InputChip(
      avatar: Icon(switch (step.kind) {
        _FilterKind.category => Icons.category_outlined,
        _FilterKind.merchant => Icons.storefront_outlined,
        _FilterKind.account => Icons.account_balance_outlined,
        _FilterKind.currency => Icons.currency_exchange,
      }, size: 18),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(step.keys.values.join(', '), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 4),
          const Icon(Icons.add, size: 16),
        ],
      ),
      tooltip: s.cfFilterEdit,
      onPressed: onEdit,
      deleteIcon: const Icon(Icons.close, size: 18),
      onDeleted: onRemove,
    );
  }
}

/// The values a step can keep, the biggest first, each with what it spent in
/// the period and in the days compared with ([before], null without a
/// comparison); the ones [picked] ticked. Returns the values ticked.
class _StepValuesDialog extends ConsumerStatefulWidget {
  final List<Object?> keys;
  final Map<Object?, String> names;
  final Map<Object?, double> now;
  final Map<Object?, double>? before;
  final String? vsLabel;
  final Map<Object?, String> picked;
  final String locale;
  const _StepValuesDialog({
    required this.keys,
    required this.names,
    required this.now,
    required this.before,
    required this.vsLabel,
    required this.picked,
    required this.locale,
  });

  @override
  ConsumerState<_StepValuesDialog> createState() => _StepValuesDialogState();
}

class _StepValuesDialogState extends ConsumerState<_StepValuesDialog> {
  late final Map<Object?, String> _picked = {...widget.picked};

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final money = fmt.currencyFormat(widget.locale, _cashFlowSymbol(ref));
    return AlertDialog(
      title: Text(s.cfFilterEdit),
      content: SizedBox(
        width: 420,
        height: 480,
        child: ListView(
          children: [
            for (final k in widget.keys)
              CheckboxListTile(
                key: Key('cfStepValue:$k'),
                value: _picked.containsKey(k),
                title: Text(widget.names[k]!),
                subtitle: Wrap(
                  children: [
                    PrivacyText(money.format(widget.now[k] ?? 0), style: muted),
                    if (widget.before case final before?)
                      PrivacySentence(' · ${widget.vsLabel ?? ''}: ${privacySlot(0)}', figures: [money.format(before[k] ?? 0)], style: muted),
                  ],
                ),
                onChanged: (v) => setState(() => v == true ? _picked[k] = widget.names[k]! : _picked.remove(k)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('cfStepValuesDone'),
          onPressed: () => Navigator.pop(context, _picked),
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}

/// A row's change against the days compared with, in percent: red up, green
/// down (spending), "new" when those days had none of it.
class _RowChange extends ConsumerWidget {
  final double now;
  final double before;
  final String locale;
  const _RowChange({required this.now, required this.before, required this.locale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final percent = NumberFormat.decimalPercentPattern(locale: locale, decimalDigits: 0);
    final d = now - before;
    final same = d.abs() < 0.005;
    final text = same
        ? '='
        : before.abs() < 0.005
        ? '▲ ${s.cfChangeNew}'
        : '${d > 0 ? '▲' : '▼'} ${percent.format((d / before).abs())}';
    return _ChangeText(text: text, good: same ? null : d < 0);
  }
}

/// An amount in or out, with its sign: the Savings screen's income and
/// expenses.
class _InOutAmount extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InOutAmount({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 4),
      PrivacyText(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    ],
  );
}

/// The chart mode switch at the top of a screen: running total, bars, ring.
class _ModeToggle extends StatelessWidget {
  final _ChartMode mode;

  /// The ring is for what is made of categories: the ledger's spending.
  final bool ring;
  final ValueChanged<_ChartMode> onChanged;
  const _ModeToggle({required this.mode, required this.ring, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final modes = [_ChartMode.running, _ChartMode.bars, if (ring) _ChartMode.ring];
    const icons = {_ChartMode.running: Icons.show_chart, _ChartMode.bars: Icons.bar_chart, _ChartMode.ring: Icons.donut_large};
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(22)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in modes)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(color: m == mode ? scheme.surfaceContainerHighest : Colors.transparent, shape: BoxShape.circle),
              child: IconButton(
                key: Key('cfChartMode:${m.name}'),
                icon: Icon(icons[m], color: m == mode ? scheme.onSurface : scheme.onSurfaceVariant),
                onPressed: () => onChanged(m),
              ),
            ),
        ],
      ),
    );
  }
}

/// A list's heading with its total on the right.
class _SectionTitle extends StatelessWidget {
  final String title;
  final String amount;
  const _SectionTitle({required this.title, required this.amount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          ),
          PrivacyText(amount, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// One row of a list: what it is, how many rows make it, its amount and share.
typedef _ListRow = ({Key key, Widget avatar, String title, String subtitle, double amount, double? share, VoidCallback? onTap});

/// Rows on one rounded card, the biggest few first and the rest behind "Show
/// all". Amounts are masked in privacy mode; shares and counts are not.
class _RowsCard extends ConsumerStatefulWidget {
  final List<_ListRow> rows;

  /// Rows always shown under the others, after a divider: how the list adds
  /// up to [total].
  final List<_ListRow> footer;

  /// The figure the list adds up to, last and in bold.
  final ({Key key, String title, double amount})? total;
  final String locale;
  final String symbol;
  const _RowsCard({
    super.key,
    required this.rows,
    required this.locale,
    required this.symbol,
    this.footer = const [],
    this.total,
    this.before = const {},
    this.beforeLabel,
  });

  /// Each row's figure in the days the period is compared with, by row key:
  /// the row tells it, named [beforeLabel], and its change against it.
  final Map<Key, double> before;
  final String? beforeLabel;

  @override
  ConsumerState<_RowsCard> createState() => _RowsCardState();
}

class _RowsCardState extends ConsumerState<_RowsCard> {
  static const _shown = 5;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = ref.watch(appStringsProvider);
    final money = fmt.currencyFormat(widget.locale, widget.symbol);
    final share = NumberFormat.decimalPercentPattern(locale: widget.locale, decimalDigits: 0);
    String shareOf(double v) => v > 0 && v < 0.005 ? '<1%' : share.format(v);
    final rows = _all ? widget.rows : widget.rows.take(_shown).toList();
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    if (widget.rows.isEmpty && widget.footer.isEmpty && widget.total == null) return const SizedBox.shrink();
    final bold = theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    Widget tile(_ListRow r) => ListTile(
      key: r.key,
      minVerticalPadding: 12,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18),
      leading: r.avatar,
      title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
      subtitle: r.subtitle.isEmpty && widget.before[r.key] == null
          ? null
          : Row(
              children: [
                Flexible(
                  child: Text(r.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
                ),
                // What the row was in the days compared with: position size.
                if (widget.before[r.key] case final b?)
                  Flexible(
                    child: PrivacySentence(
                      ' · ${widget.beforeLabel ?? ''}: ${privacySlot(0)}',
                      figures: [money.format(b)],
                      style: muted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          PrivacyText(money.format(r.amount), style: theme.textTheme.titleMedium),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.before[r.key] case final b?) ...[
                _RowChange(now: r.amount, before: b, locale: widget.locale),
                if (r.share != null) const SizedBox(width: 8),
              ],
              if (r.share case final share?) Text(shareOf(share), style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
      onTap: r.onTap,
    );

    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          children: [
            const SizedBox(height: 6),
            for (final r in rows) tile(r),
            if (widget.rows.length > _shown)
              TextButton(
                key: const Key('cfRowsShowAll'),
                onPressed: () => setState(() => _all = !_all),
                child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(_all ? s.showLessRows : s.showAllRows)),
              ),
            if (widget.footer.isNotEmpty || widget.total != null) const Divider(height: 1, indent: 18, endIndent: 18),
            for (final r in widget.footer) tile(r),
            if (widget.total case final t?)
              ListTile(
                key: t.key,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                leading: const SizedBox(width: RowIconBadge.extent),
                title: Text(t.title, style: bold),
                trailing: PrivacyText(money.format(t.amount), style: bold),
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

/// What the period spent, by category or by merchant, each row opening its
/// transactions; "Manage" opens Categories & rules.
class _SpentList extends ConsumerStatefulWidget {
  final SpendingByCategoryData spending;
  final _PeriodStats stats;
  final String locale;
  final String language;

  /// With its own heading (the grouping switch); off under the Savings
  /// screen's heading.
  final bool titled;

  /// How the rows are grouped, and the switch to another grouping.
  final _SpentBy by;
  final ValueChanged<_SpentBy>? onBy;

  /// Narrows the screen to a row's category, merchant, account or currency;
  /// without it a row opens its transactions.
  final ValueChanged<_SpendFilter>? onFilter;

  /// [spending] holds only the rows the screen is narrowed to: the list sums
  /// them, and how the categories add up to the Expenses is not its to tell.
  final bool narrowed;
  const _SpentList({
    required this.spending,
    required this.stats,
    required this.locale,
    required this.language,
    this.titled = true,
    this.by = _SpentBy.category,
    this.onBy,
    this.onFilter,
    this.narrowed = false,
  });

  @override
  ConsumerState<_SpentList> createState() => _SpentListState();
}

class _SpentListState extends ConsumerState<_SpentList> with _SpendingDrillDown<_SpentList> {
  _SpentBy get _by => widget.by;

  @override
  SpendingByCategoryData spendingOf(_SpentList list) => list.spending;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final byId = ref.watch(categoriesByIdProvider);
    final st = widget.stats;
    final (from, to) = (st.start, st.until);
    final p = widget.narrowed ? widget.spending.sumOfDays(from, to) : st.spending;
    // Shares of what the ledger holds: the rows add up to it.
    final total = widget.narrowed ? widget.spending.spentBetween(from, to) : st.spent;
    Category? category(int? id) => id == null ? null : byId[id];
    void open(String title, List<int> Function(SpendingByCategoryData) idsOf) =>
        openRows(context, idsOf, title: '$title · ${st.label}', locale: widget.locale);
    // A row narrows the screen to itself, or opens its transactions.
    VoidCallback tapOf(_SpendFilter f, List<int> Function(SpendingByCategoryData) idsOf) {
      final narrow = widget.onFilter;
      return narrow != null ? () => narrow(f) : () => open(f.label, idsOf);
    }

    // By account or currency: the period's rows summed by it. A saving plan's
    // steps have no account: by account, each plan is its own row, as by
    // category; by currency, they count in the plan's.
    final entries = widget.spending.entriesBetween(from, to).toList();
    Map<K, ({double amount, int count})> sumsBy<K>(K Function(SpendingEntry) keyOf, {bool plans = true, Iterable<SpendingEntry>? from}) {
      final out = <K, ({double amount, int count})>{};
      for (final e in from ?? entries) {
        if (!plans && e.plan != null) continue;
        final k = keyOf(e);
        final was = out[k] ?? (amount: 0.0, count: 0);
        out[k] = (amount: was.amount + e.amount, count: was.count + 1);
      }
      return out;
    }

    final accounts = {for (final a in ref.watch(accountsProvider).value ?? const <Account>[]) a.id: a.name};
    // Each row against the same days of the period compared with, as the
    // Expenses are; a row only that period had is listed too, so a merchant
    // paid then and not now can be picked.
    final compared = st.comparedDays.isEmpty ? null : st.comparedDays;
    final other = compared == null ? null : widget.spending.sumOfRanges(compared);
    final otherEntries = compared == null ? const <SpendingEntry>[] : widget.spending.entriesIn(compared).toList();
    final before = <Key, double>{
      if (other != null) ...{
        for (final id in {...p.byCategory.keys, ...other.byCategory.keys}) Key('cfSpendingCategory:$id'): other.amount(id),
        for (final k in {...p.merchants.keys, ...other.merchants.keys}) Key('cfSpendingMerchant:$k'): other.merchants[k]?.amount ?? 0.0,
        for (final e in entries)
          if (e.plan == null && e.accountId != null) Key('cfSpendingAccount:${e.accountId}'): 0.0,
        for (final MapEntry(key: id, value: v) in sumsBy((e) => e.accountId, plans: false, from: otherEntries).entries)
          Key('cfSpendingAccount:$id'): v.amount,
        for (final e in entries) Key('cfSpendingCurrency:${e.currency}'): 0.0,
        for (final MapEntry(key: c, value: v) in sumsBy((e) => e.currency, from: otherEntries).entries) Key('cfSpendingCurrency:$c'): v.amount,
      },
    };
    final planRows = <_ListRow>[
      for (final plan in p.savingPlans)
        (
          key: Key('cfSpendingPlan:${plan.eventId}'),
          avatar: RowIconBadge(icon: Icons.savings_outlined, color: Colors.amber.shade700, tint: 0.15),
          title: s.savingForLabel(plan.name),
          subtitle: s.legendSavings,
          amount: plan.amount,
          share: total <= 0 ? 0.0 : plan.amount / total,
          onTap: null,
        ),
    ];

    // The rows only the days compared with had, at nothing now.
    const none = (amount: 0.0, count: 0);
    final merchants = {...?other?.merchants, ...p.merchants};
    final byAccount = {
      for (final e in otherEntries)
        if (e.plan == null && e.accountId != null) e.accountId!: none,
      ...sumsBy((e) => e.accountId!, plans: false),
    };
    final byCurrency = {for (final e in otherEntries) e.currency: none, ...sumsBy((e) => e.currency)};
    final rows =
        <_ListRow>[
          if (_by == _SpentBy.category) ...[
            for (final id in {...p.byCategory.keys, ...?other?.byCategory.keys})
              (
                key: Key('cfSpendingCategory:$id'),
                avatar: CategoryAvatar(category: category(id)),
                title: categoryLabelFor(id, byId, s),
                subtitle: s.cfTransactions(p.ids(id).length),
                amount: p.amount(id),
                share: total <= 0 ? 0.0 : p.amount(id) / total,
                onTap: tapOf(
                  (kind: _FilterKind.category, key: id, label: categoryLabelFor(id, byId, s)),
                  (live) => live.sumOfDays(from, to).ids(id),
                ),
              ),
            ...planRows,
          ] else if (_by == _SpentBy.merchant)
            for (final MapEntry(key: k, value: m) in merchants.entries)
              (
                key: Key('cfSpendingMerchant:$k'),
                avatar: m.mainCategory == null
                    ? RowIconBadge(icon: Icons.storefront_outlined, color: scheme.outline, tint: 0.15)
                    : CategoryAvatar(category: category(m.mainCategory)),
                title: m.name,
                subtitle: s.cfTransactions(p.merchants[k]?.ids.length ?? 0),
                amount: p.merchants[k]?.amount ?? 0.0,
                share: total <= 0 ? 0.0 : (p.merchants[k]?.amount ?? 0.0) / total,
                onTap: tapOf((
                  kind: _FilterKind.merchant,
                  key: k,
                  label: m.name,
                ), (live) => live.sumOfDays(from, to).merchants[k]?.ids ?? const []),
              )
          else if (_by == _SpentBy.account) ...[
            for (final MapEntry(key: id, value: sum) in byAccount.entries)
              (
                key: Key('cfSpendingAccount:$id'),
                avatar: RowIconBadge(icon: Icons.account_balance_outlined, color: scheme.primary, tint: 0.15),
                title: accounts[id] ?? '#$id',
                subtitle: s.cfTransactions(sum.count),
                amount: sum.amount,
                share: total <= 0 ? 0.0 : sum.amount / total,
                onTap: tapOf(
                  (kind: _FilterKind.account, key: id, label: accounts[id] ?? '#$id'),
                  (live) => [
                    for (final e in live.entriesBetween(from, to))
                      if (e.accountId == id) ?e.id,
                  ],
                ),
              ),
            ...planRows,
          ] else
            for (final MapEntry(key: code, value: sum) in byCurrency.entries)
              (
                key: Key('cfSpendingCurrency:$code'),
                avatar: RowIconBadge(icon: Icons.currency_exchange, color: scheme.primary, tint: 0.15),
                title: code,
                subtitle: s.cfTransactions(sum.count),
                amount: sum.amount,
                share: total <= 0 ? 0.0 : sum.amount / total,
                onTap: tapOf(
                  (kind: _FilterKind.currency, key: code, label: code),
                  (live) => [
                    for (final e in live.entriesBetween(from, to))
                      if (e.currency == code) ?e.id,
                  ],
                ),
              ),
          // The biggest first; those the period did not have, by what they were.
        ]..sort((a, b) {
          final c = b.amount.compareTo(a.amount);
          return c != 0 ? c : (before[b.key] ?? 0).compareTo(before[a.key] ?? 0);
        });
    // By category, the list adds up to the Expenses: the ledger's spending,
    // less the refunds received, and what no transaction shows.
    final footer = <_ListRow>[];
    if (_by == _SpentBy.category && !widget.narrowed) {
      if (st.refunds >= 0.5) {
        footer.add((
          key: const Key('cfExpensesRefunds'),
          avatar: RowIconBadge(icon: Icons.replay, color: Colors.teal.shade400, tint: 0.15),
          title: s.sankeyRefunds,
          subtitle: s.cfRefundsNote,
          amount: -st.refunds,
          share: null,
          onTap: null,
        ));
      }
      if (st.untracked.abs() >= 0.5) {
        footer.add((
          key: const Key('cfExpensesUntracked'),
          avatar: RowIconBadge(icon: Icons.help_outline, color: scheme.outline, tint: 0.15),
          title: st.untracked > 0 ? s.sankeyUntrackedExpenses : s.sankeyUntrackedIncome,
          subtitle: st.untracked > 0 ? s.cfUntrackedExpensesNote : s.cfUntrackedIncomeNote,
          amount: st.untracked,
          share: null,
          onTap: null,
        ));
      }
      // With lines to close the gap, the categories' sum heads them, so the
      // arithmetic can be read without opening every row.
      if (footer.isNotEmpty && rows.isNotEmpty) {
        footer.insert(0, (
          key: const Key('cfExpensesCategories'),
          avatar: RowIconBadge(icon: Icons.category_outlined, color: scheme.primary, tint: 0.15),
          title: s.cfAllCategories,
          subtitle: s.cfTransactions(p.idsByCategory.values.fold(0, (a, ids) => a + ids.length)),
          amount: total,
          share: null,
          onTap: null,
        ));
      }
    }

    String byName(_SpentBy by) => switch (by) {
      _SpentBy.category => s.cfByCategory,
      _SpentBy.merchant => s.cfByMerchant,
      _SpentBy.account => s.cfByAccount,
      _SpentBy.currency => s.cfByCurrency,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (widget.titled)
              PopupMenuButton<_SpentBy>(
                key: const Key('cfSpentBy'),
                initialValue: _by,
                onSelected: widget.onBy,
                itemBuilder: (_) => [for (final by in _SpentBy.values) PopupMenuItem(value: by, child: Text(byName(by)))],
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(byName(_by), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                      const Icon(Icons.keyboard_arrow_down),
                    ],
                  ),
                ),
              ),
            const Spacer(),
            TextButton(
              key: const Key('cfSpendingManage'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CategoriesRulesScreen())),
              child: Text(s.cfManage),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Rows at nothing are only the days compared with: nothing spent now.
        if (rows.every((r) => r.amount.abs() < 0.005) && footer.isEmpty && st.expenses.abs() < 0.5)
          EmptyState(key: const Key('cfSpendingEmpty'), icon: Icons.receipt_long_outlined, message: s.spendingByCategoryEmpty)
        else
          _RowsCard(
            rows: rows,
            footer: footer,
            total: _by != _SpentBy.category || widget.narrowed
                ? null
                : (key: const Key('cfExpensesTotalRow'), title: s.legendExpenses, amount: st.expenses),
            locale: widget.locale,
            symbol: currencySymbol(widget.spending.baseCurrency),
            before: before,
            beforeLabel: st.vsLabel,
          ),
        // How the categories add up to the Expenses: under the categories only.
        if (_by == _SpentBy.category && !widget.narrowed) ...[
          const SizedBox(height: 10),
          Footnote(s.cfExpensesNote(s.legendExpenses, s.cfYearByYear, s.spendingByCategoryTitle), key: const Key('cfSpendingNote')),
        ],
      ],
    );
  }
}

/// The spending rows a filter keeps, newest day first: a card naming the
/// filter, how many rows it keeps and Clear; then each day under its date and
/// its total, its rows on a card. A transaction opens its classification
/// card.
class _FilteredRows extends ConsumerWidget {
  final _SpendFilter filter;
  final List<SpendingEntry> entries;
  final String locale;
  final String language;
  final VoidCallback onClear;

  /// What names the filter on its card (its steps); else its label.
  final Widget? title;

  /// Under the card, above the days: what the rows are made of, a row
  /// narrowing further.
  final Widget? breakdown;
  const _FilteredRows({
    required this.filter,
    required this.entries,
    required this.locale,
    required this.language,
    required this.onClear,
    this.title,
    this.breakdown,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final byId = ref.watch(categoriesByIdProvider);
    final txs = {for (final t in ref.watch(allTransactionsProvider).value ?? const <Transaction>[]) t.id: t};
    final symbol = _cashFlowSymbol(ref);
    final money = fmt.currencyFormat(locale, symbol);
    final date = fmt.fullDateFormat(language);
    final days = <DateTime, List<SpendingEntry>>{};
    for (final e in entries.reversed) {
      (days[e.day] ??= []).add(e);
    }
    final planBadge = RowIconBadge(icon: Icons.savings_outlined, color: Colors.amber.shade700, tint: 0.15);
    final avatar = switch (filter.kind) {
      _FilterKind.category => CategoryAvatar(category: byId[filter.key]),
      _FilterKind.merchant => RowIconBadge(icon: Icons.storefront_outlined, color: scheme.outline, tint: 0.15),
      _FilterKind.account => RowIconBadge(icon: Icons.account_balance_outlined, color: scheme.primary, tint: 0.15),
      _FilterKind.currency => RowIconBadge(icon: Icons.currency_exchange, color: scheme.primary, tint: 0.15),
    };

    // A transaction by its counterparty, the statement's words under it (the
    // category when they only repeat the name); a saving plan's step by its
    // plan. Spent: a negative amount.
    _ListRow row(SpendingEntry e) {
      final t = e.id == null ? null : txs[e.id];
      if (t == null) {
        return (
          key: Key('cfFilterTx:${e.id}'),
          avatar: planBadge,
          title: e.plan == null ? '' : s.savingForLabel(e.plan!.name),
          subtitle: s.legendSavings,
          amount: -e.amount,
          share: null,
          onTap: null,
        );
      }
      final name = t.counterparty;
      final repeats = name == null || t.description.trim().toLowerCase() == name.trim().toLowerCase();
      return (
        key: Key('cfFilterTx:${t.id}'),
        avatar: CategoryAvatar(category: byId[t.categoryId]),
        title: name ?? t.description,
        subtitle: repeats ? categoryLabelFor(t.categoryId, byId, s) : t.description,
        amount: -e.amount,
        share: null,
        onTap: () => showTransactionClassifySheet(context, tx: t, title: s.classifyTransaction, accountId: t.accountId),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            key: const Key('cfFilter'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            leading: avatar,
            title: title ?? Text(filter.label, style: theme.textTheme.titleMedium),
            subtitle: Text(s.cfTransactions(entries.length), style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            trailing: FilledButton.tonal(key: const Key('cfFilterClear'), onPressed: onClear, child: Text(s.cfClearFilter)),
          ),
        ),
        if (breakdown case final b?) ...[const SizedBox(height: 24), b],
        for (final MapEntry(key: d, value: rows) in days.entries) ...[
          const SizedBox(height: 24),
          _SectionTitle(title: date.format(d), amount: money.format(-rows.fold(0.0, (a, e) => a + e.amount))),
          _RowsCard(key: ValueKey(d), rows: [for (final e in rows) row(e)], locale: locale, symbol: symbol),
        ],
      ],
    );
  }
}

/// The period's income: its records over a week or a month, its months over
/// anything longer (a month row goes to that month).
class _IncomeList extends ConsumerWidget {
  final _PeriodStats stats;
  final String locale;
  final String language;
  final bool titled;
  const _IncomeList({required this.stats, required this.locale, required this.language, this.titled = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final total = stats.income;
    final today = ref.watch(currentDateProvider);
    final byRecord = stats.period.byDays || stats.period.kind == CashFlowPeriodKind.month;
    final date = fmt.fullDateFormat(language);
    final avatar = RowIconBadge(icon: Icons.south_west, color: Colors.green.shade500, tint: 0.15);
    final rows = <_ListRow>[
      if (byRecord)
        for (final r in stats.incomeRecords)
          (
            key: Key('cfIncomeRecord:${r.id}'),
            avatar: avatar,
            title: date.format(r.date),
            subtitle: s.incomeTypeIncome,
            amount: r.amount,
            share: total <= 0 ? 0.0 : r.amount / total,
            onTap: null,
          )
      else
        for (final b in stats.parts)
          if (b.income > 0)
            () {
              final records = stats.incomeRecords.where((r) => !dayOf(r.date).isBefore(b.start) && !dayOf(r.date).isAfter(b.end)).length;
              final month = stats.period.kind == CashFlowPeriodKind.all
                  ? CashFlowPeriod.year(b.start.year)
                  : CashFlowPeriod.month(b.start.year, b.start.month);
              return (
                key: Key('cfIncomeBucket:${b.start.year}-${b.start.month}'),
                avatar: avatar,
                title: month.label(s, language, today),
                subtitle: s.cfRecords(records),
                amount: b.income,
                share: total <= 0 ? 0.0 : b.income / total,
                onTap: () => _showPeriod(ref, month),
              );
            }(),
    ]..sort((a, b) => b.amount.compareTo(a.amount));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (titled)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(s.legendIncome, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          ),
        if (rows.isEmpty)
          EmptyState(key: const Key('cfIncomeEmpty'), icon: Icons.savings_outlined, message: s.cfNoIncome)
        else
          _RowsCard(rows: rows, locale: locale, symbol: _cashFlowSymbol(ref)),
      ],
    );
  }
}
