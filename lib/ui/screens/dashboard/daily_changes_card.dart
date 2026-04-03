part of 'dashboard_screen.dart';

// ════════════════════════════════════════════════════
// Asset Daily Changes Card
// ════════════════════════════════════════════════════

class _AssetDailyChangesCard extends ConsumerStatefulWidget {
  final String locale;
  final String baseCurrency;

  const _AssetDailyChangesCard({
    required this.locale,
    required this.baseCurrency,
  });

  @override
  ConsumerState<_AssetDailyChangesCard> createState() => _AssetDailyChangesCardState();
}

enum _SortCol { name, priceDiff, pct, valueDiff, marketValue }
enum _SortDir { asc, desc, none }

class _AssetDailyChangesCardState extends ConsumerState<_AssetDailyChangesCard> {
  static const _units = ['d', 'w', 'm', 'y', 'YTD', 'All'];
  late final TextEditingController _numberController;
  _SortCol _sortCol = _SortCol.name;
  _SortDir _sortDir = _SortDir.asc;

  int get _number => ref.read(_priceChangeNumberProvider);
  set _number(int v) => ref.read(_priceChangeNumberProvider.notifier).state = v;
  String get _unit => ref.read(_priceChangeUnitProvider);
  set _unit(String v) => ref.read(_priceChangeUnitProvider.notifier).state = v;

  @override
  void initState() {
    super.initState();
    _numberController = TextEditingController(
      text: ref.read(_priceChangeNumberProvider).toString(),
    );
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  void _onHeaderTap(_SortCol col) {
    setState(() {
      if (_sortCol == col) {
        // Cycle: asc → desc → none (back to default name asc)
        _sortDir = switch (_sortDir) {
          _SortDir.asc => _SortDir.desc,
          _SortDir.desc => _SortDir.none,
          _SortDir.none => _SortDir.asc,
        };
        if (_sortDir == _SortDir.none) {
          _sortCol = _SortCol.name;
          _sortDir = _SortDir.asc;
        }
      } else {
        _sortCol = col;
        _sortDir = _SortDir.asc;
      }
    });
  }

  List<AssetDailyChange> _applySorting(List<AssetDailyChange> changes) {
    final sorted = List.of(changes);
    int Function(AssetDailyChange, AssetDailyChange) comparator;
    switch (_sortCol) {
      case _SortCol.name:
        comparator = (a, b) => (a.ticker ?? a.name).compareTo(b.ticker ?? b.name);
      case _SortCol.priceDiff:
        comparator = (a, b) => (a.priceDiff * a.todayFxRate).compareTo(b.priceDiff * b.todayFxRate);
      case _SortCol.pct:
        comparator = (a, b) => a.pricePct.compareTo(b.pricePct);
      case _SortCol.valueDiff:
        comparator = (a, b) => a.valueDiff.compareTo(b.valueDiff);
      case _SortCol.marketValue:
        comparator = (a, b) => a.todayPrice.compareTo(b.todayPrice);
    }
    sorted.sort((a, b) => _sortDir == _SortDir.desc ? comparator(b, a) : comparator(a, b));
    return sorted;
  }

  bool get _isSpecialUnit => _unit == 'YTD' || _unit == 'All';

  DateTime get _referenceDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_unit) {
      'd' => today.subtract(Duration(days: _number)),
      'w' => today.subtract(Duration(days: _number * 7)),
      'm' => DateTime(today.year, today.month - _number, today.day),
      'y' => DateTime(today.year - _number, today.month, today.day),
      'YTD' => DateTime(today.year, 1, 1),
      'All' => DateTime(2000, 1, 1),
      _ => today.subtract(const Duration(days: 1)),
    };
  }

  @override
  Widget build(BuildContext context) {
    // Watch providers to rebuild when period changes
    ref.watch(_priceChangeNumberProvider);
    ref.watch(_priceChangeUnitProvider);
    final s = ref.watch(appStringsProvider);
    final isPrivate = ref.watch(privacyModeProvider);
    final changesAsync = ref.watch(assetDailyChangesProvider(_referenceDate));
    final theme = Theme.of(context);
    final amtFmt = fmt.amountFormat(widget.locale);
    final symbol = currencySymbol(widget.baseCurrency);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.dashPriceChanges, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                Flexible(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.end,
                    children: [
                SizedBox(
                  width: 56,
                  child: TextField(
                    controller: _numberController,
                    enabled: !_isSpecialUnit,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
                      isDense: true,
                      border: const OutlineInputBorder(),
                      suffixIconConstraints: const BoxConstraints(maxWidth: 20, maxHeight: 32),
                      suffixIcon: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 16,
                            width: 20,
                            child: IconButton(
                              onPressed: _isSpecialUnit ? null : () {
                                setState(() {
                                  _number++;
                                  _numberController.text = '$_number';
                                });
                              },
                              icon: const Icon(Icons.arrow_drop_up, size: 16),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                          SizedBox(
                            height: 16,
                            width: 20,
                            child: IconButton(
                              onPressed: _isSpecialUnit || _number <= 1 ? null : () {
                                setState(() {
                                  _number--;
                                  _numberController.text = '$_number';
                                });
                              },
                              icon: const Icon(Icons.arrow_drop_down, size: 16),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n > 0) setState(() => _number = n);
                    },
                  ),
                ),
                ..._units.map((u) {
                  final selected = u == _unit;
                  return ChoiceChip(
                    label: Text(u),
                    selected: selected,
                    onSelected: (_) => setState(() {
                      _unit = u;
                      if (_isSpecialUnit) {
                        _numberController.text = '';
                      } else if (_numberController.text.isEmpty) {
                        _number = 1;
                        _numberController.text = '1';
                      }
                    }),
                    labelStyle: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w400),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                  );
                }),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            changesAsync.when(
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              )),
              error: (e, _) => Text(s.error(e), style: const TextStyle(color: Colors.red, fontSize: 12)),
              data: (changes) {
                if (changes.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(s.dashNoPriceData, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  );
                }

                final sorted = _applySorting(changes);

                final totalDiff = sorted.fold(0.0, (sum, c) => sum + c.valueDiff);
                final totalPreviousValue = sorted.fold(0.0, (sum, c) => sum + c.previousPrice * c.quantity * c.previousFxRate);
                final totalPct = totalPreviousValue != 0 ? (totalDiff / totalPreviousValue) * 100 : 0.0;

                Widget headerCell(String label, _SortCol col, {int flex = 2, TextAlign align = TextAlign.right}) {
                  final isActive = _sortCol == col;
                  final arrow = isActive ? (_sortDir == _SortDir.asc ? ' \u25B2' : ' \u25BC') : '';
                  return Expanded(
                    flex: flex,
                    child: GestureDetector(
                      onTap: () => _onHeaderTap(col),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Text(
                          '$label$arrow',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isActive ? theme.colorScheme.primary : Colors.grey,
                            fontSize: 10,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                          ),
                          textAlign: align,
                        ),
                      ),
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final tableContent = Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              headerCell(s.colAsset, _SortCol.name, flex: 3, align: TextAlign.left),
                              headerCell(s.colPrice, _SortCol.marketValue, flex: 2),
                              headerCell('Price \u0394 ($symbol)', _SortCol.priceDiff),
                              headerCell('%', _SortCol.pct),
                              headerCell('Value \u0394 ($symbol)', _SortCol.valueDiff, flex: 3),
                            ],
                          ),
                        ),
                        ...sorted.map((c) => _buildRow(
                          theme: theme,
                          name: c.ticker ?? c.name,
                          marketValue: c.todayPrice * c.todayFxRate,
                          priceDiff: c.priceDiff * c.todayFxRate,
                          pricePct: c.pricePct,
                          valueDiff: c.valueDiff,
                          amtFmt: amtFmt,
                          url: c.investingUrl,
                          isPrivate: isPrivate,
                          marketOpen: c.marketOpen,
                          s: s,
                        )),
                        const Divider(height: 16),
                        _buildRow(
                          theme: theme,
                          name: s.legendTotal,
                          marketValue: null,
                          priceDiff: null,
                          pricePct: totalPct,
                          valueDiff: totalDiff,
                          amtFmt: amtFmt,
                          bold: true,
                          isPrivate: isPrivate,
                        ),
                      ],
                    );
                    // On narrow screens, allow horizontal scrolling for the data table
                    if (constraints.maxWidth < 500) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(width: 500, child: tableContent),
                      );
                    }
                    return tableContent;
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow({
    required ThemeData theme,
    required String name,
    required double? marketValue,
    required double? priceDiff,
    required double pricePct,
    required double valueDiff,
    required NumberFormat amtFmt,
    bool bold = false,
    String? url,
    required bool isPrivate,
    bool? marketOpen,
    AppStrings? s,
  }) {
    final isPositive = valueDiff >= 0;
    final color = valueDiff == 0 ? Colors.grey : (isPositive ? Colors.green : Colors.red);
    final arrow = valueDiff == 0 ? '' : (isPositive ? '\u25B2 ' : '\u25BC ');
    final weight = bold ? FontWeight.w700 : FontWeight.w400;

    Widget maybeBlur(Widget child) => isPrivate
        ? ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6), child: child)
        : child;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (marketOpen != null)
                  Tooltip(
                    message: marketOpen ? (s?.marketOpen ?? '') : (s?.marketClosed ?? ''),
                    child: Container(
                      width: 7, height: 7,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: marketOpen ? Colors.green : Colors.grey,
                      ),
                    ),
                  ),
                Flexible(
                  child: url != null
                      ? MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => launchUrl(Uri.parse(url)),
                            child: Text(
                              name,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: weight,
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline,
                                decorationColor: theme.colorScheme.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                      : Text(
                          name,
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: weight),
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              marketValue != null ? amtFmt.format(marketValue) : '',
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: weight, fontSize: 11),
              textAlign: TextAlign.right,
            ),
          ),
          if (priceDiff != null)
            Expanded(
              flex: 2,
              child: Text(
                '${priceDiff >= 0 ? '+' : ''}${amtFmt.format(priceDiff)}',
                style: theme.textTheme.bodySmall?.copyWith(color: color, fontSize: 11),
                textAlign: TextAlign.right,
              ),
            )
          else
            const Expanded(flex: 2, child: SizedBox()),
          Expanded(
            flex: 2,
            child: Text(
              '${pricePct >= 0 ? '+' : ''}${pricePct.toStringAsFixed(2)}%',
              style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: weight, fontSize: 11),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 3,
            child: maybeBlur(Text(
              '$arrow${amtFmt.format(valueDiff.abs())}',
              style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: weight),
              textAlign: TextAlign.right,
            )),
          ),
        ],
      ),
    );
  }
}
