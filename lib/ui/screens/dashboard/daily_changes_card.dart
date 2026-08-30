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

enum _SortCol { name, pct, valueDiff, marketValue }

enum _SortDir { asc, desc, none }

class _AssetDailyChangesCardState extends ConsumerState<_AssetDailyChangesCard> {
  static const _units = ['d', 'w', 'm', 'y', 'WTD', 'MTD', 'YTD', 'All'];
  // Units with no numeric multiplier: they anchor to the start of a calendar
  // period (or a fixed epoch), so the number field is disabled for them.
  static const _specialUnits = {'WTD', 'MTD', 'YTD', 'All'};
  late final TextEditingController _numberController;
  _SortCol _sortCol = _SortCol.name;
  _SortDir _sortDir = _SortDir.asc;

  // Effective values: session override (this run) wins; else the persisted
  // default from AppConfigs; else the built-in fallback. Validated against
  // [_units] so a stale/unknown persisted unit can't select a missing chip.
  int get _number => ref.read(_priceChangeNumberOverrideProvider) ?? ref.read(defaultPriceChangeNumberProvider).value ?? 1;
  set _number(int v) => ref.read(_priceChangeNumberOverrideProvider.notifier).state = v;
  String get _unit {
    final override = ref.read(_priceChangeUnitOverrideProvider);
    if (override != null) return override;
    final persisted = ref.read(defaultPriceChangeUnitProvider).value;
    return (persisted != null && _units.contains(persisted)) ? persisted : 'd';
  }

  set _unit(String v) => ref.read(_priceChangeUnitOverrideProvider.notifier).state = v;

  /// The persisted default unit to mark with a pin, or null when unset/unknown.
  String? get _markedUnit {
    final persisted = ref.read(defaultPriceChangeUnitProvider).value;
    return (persisted != null && _units.contains(persisted)) ? persisted : null;
  }

  @override
  void initState() {
    super.initState();
    _numberController = TextEditingController(text: _number.toString());
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
      case _SortCol.pct:
        comparator = (a, b) {
          double basePct(AssetDailyChange c) {
            final prev = c.previousPrice * c.quantity / c.priceDivisor * c.previousFxRate;
            return prev != 0 ? (c.valueDiff / prev) * 100 : 0;
          }

          return basePct(a).compareTo(basePct(b));
        };
      case _SortCol.valueDiff:
        comparator = (a, b) => a.valueDiff.compareTo(b.valueDiff);
      case _SortCol.marketValue:
        comparator = (a, b) => a.todayPrice.compareTo(b.todayPrice);
    }
    sorted.sort((a, b) => _sortDir == _SortDir.desc ? comparator(b, a) : comparator(a, b));
    return sorted;
  }

  bool get _isSpecialUnit => _specialUnits.contains(_unit);

  DateTime _referenceDate(DateTime today) => priceChangeReferenceDate(
    today: today,
    unit: _unit,
    number: _number,
    firstDayOfWeekIndex: MaterialLocalizations.of(context).firstDayOfWeekIndex,
  );

  @override
  Widget build(BuildContext context) {
    // Watch overrides + persisted defaults so the card rebuilds when the period
    // changes this session OR when a long-press persists a new default.
    ref.watch(_priceChangeNumberOverrideProvider);
    ref.watch(_priceChangeUnitOverrideProvider);
    ref.watch(defaultPriceChangeUnitProvider);
    // When the persisted default number resolves/changes and the user hasn't
    // overridden it this session, reflect it in the spinner (after build, so we
    // never mutate a controller mid-build). Special units keep the field empty.
    ref.listen(defaultPriceChangeNumberProvider, (_, next) {
      if (ref.read(_priceChangeNumberOverrideProvider) != null) return;
      if (_specialUnits.contains(_unit)) return;
      final text = (next.value ?? 1).toString();
      if (_numberController.text != text) _numberController.text = text;
    });
    final today = ref.watch(currentDateProvider);
    final s = ref.watch(appStringsProvider);
    final changesAsync = ref.watch(assetDailyChangesProvider(_referenceDate(today)));
    final theme = Theme.of(context);
    final amtFmt = fmt.amountFormat(widget.locale);
    final symbol = currencySymbol(widget.baseCurrency);
    final markedUnit = _markedUnit;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (ctx, constraints) {
                final wide = constraints.maxWidth > 600;
                final chips = <Widget>[
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
                                onPressed: _isSpecialUnit
                                    ? null
                                    : () {
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
                                onPressed: _isSpecialUnit || _number <= 1
                                    ? null
                                    : () {
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
                    final isDefault = u == markedUnit;
                    return GestureDetector(
                      // Long-press persists this period as the default for next
                      // launch (tap still just selects it for this session).
                      onLongPress: () async {
                        final number = _number;
                        await savePriceChangePeriodDefault(ref.read(databaseProvider), unit: u, number: number);
                        setState(() {
                          _unit = u;
                          if (_isSpecialUnit) {
                            _numberController.text = '';
                          } else if (_numberController.text.isEmpty) {
                            _number = 1;
                            _numberController.text = '1';
                          }
                        });
                        if (!context.mounted) return;
                        showInfoSnack(context, s.dashDefaultPeriodSet(u));
                      },
                      child: ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(u),
                            if (isDefault) ...[
                              const SizedBox(width: 3),
                              Semantics(
                                label: s.dashDefaultPeriodMarker,
                                child: Icon(Icons.push_pin, size: 9, color: theme.colorScheme.primary),
                              ),
                            ],
                          ],
                        ),
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
                      ),
                    );
                  }),
                ];
                if (wide) {
                  return Row(
                    children: [
                      Text(s.dashPriceChanges, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      ...chips,
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.dashPriceChanges, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Wrap(spacing: 4, runSpacing: 4, children: chips),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            changesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
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
                final totalPreviousValue = sorted.fold(0.0, (sum, c) => sum + c.previousPrice * c.quantity / c.priceDivisor * c.previousFxRate);
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

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          headerCell(s.colAsset, _SortCol.name, flex: 3, align: TextAlign.left),
                          headerCell(s.colPrice, _SortCol.marketValue, flex: 2),
                          headerCell('%', _SortCol.pct),
                          headerCell('Value \u0394 ($symbol)', _SortCol.valueDiff, flex: 3),
                        ],
                      ),
                    ),
                    ...sorted.map((c) {
                      final hasFx = c.currency != c.baseCurrency;
                      final prevValueBase = c.previousPrice * c.quantity / c.priceDivisor * c.previousFxRate;
                      final basePct = prevValueBase != 0 ? (c.valueDiff / prevValueBase) * 100 : 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Column(
                          children: [
                            _buildRow(
                              theme: theme,
                              name: c.ticker ?? c.name,
                              marketValue: c.todayPrice * c.todayFxRate,
                              pricePct: basePct,
                              valueDiff: c.valueDiff,
                              amtFmt: amtFmt,
                              url: c.providerUrl,
                              marketOpen: c.marketOpen,
                              s: s,
                            ),
                            if (hasFx)
                              _buildSubRow(
                                theme: theme,
                                assetPrice: c.todayPrice,
                                assetPricePct: c.pricePct,
                                assetValueDiff: c.priceDiff * c.quantity / c.priceDivisor,
                                assetCurrency: c.currency,
                                amtFmt: amtFmt,
                              ),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 16),
                    _buildRow(
                      theme: theme,
                      name: s.legendTotal,
                      marketValue: null,
                      pricePct: totalPct,
                      valueDiff: totalDiff,
                      amtFmt: amtFmt,
                      bold: true,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static Color _bracketColor(double v) => v == 0 ? Colors.grey.shade500 : (v > 0 ? Colors.green.shade300 : Colors.red.shade300);

  Widget _buildRow({
    required ThemeData theme,
    required String name,
    required double? marketValue,
    required double pricePct,
    required double valueDiff,
    required NumberFormat amtFmt,
    bool bold = false,
    String? url,
    bool? marketOpen,
    AppStrings? s,
  }) {
    final isPositive = valueDiff >= 0;
    final color = valueDiff == 0 ? Colors.grey : (isPositive ? Colors.green : Colors.red);
    final arrow = valueDiff == 0 ? '' : (isPositive ? '\u25B2 ' : '\u25BC ');
    final weight = bold ? FontWeight.w700 : FontWeight.w400;

    return Row(
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
                    width: 7,
                    height: 7,
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
          child: marketValue != null
              ? Text(
                  amtFmt.format(marketValue),
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: weight, fontSize: 11),
                  textAlign: TextAlign.right,
                )
              : Text(
                  '',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: weight, fontSize: 11),
                  textAlign: TextAlign.right,
                ),
        ),
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
          child: PrivacyBlur(
            child: Text(
              '$arrow${amtFmt.format(valueDiff.abs())}',
              style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: weight),
              textAlign: TextAlign.right,
            ),
          ),
        ),
      ],
    );
  }

  /// Indented, smaller-font continuation of the row above showing the
  /// asset's native-currency price/pct/diff. Rendered only when the
  /// asset's currency differs from base.
  Widget _buildSubRow({
    required ThemeData theme,
    required double assetPrice,
    required double assetPricePct,
    required double assetValueDiff,
    required String assetCurrency,
    required NumberFormat amtFmt,
  }) {
    final pctColor = _bracketColor(assetPricePct);
    final diffColor = _bracketColor(assetValueDiff);
    final priceStr = amtFmt.format(assetPrice);
    final pctStr = '${assetPricePct >= 0 ? '+' : ''}${assetPricePct.toStringAsFixed(2)}%';
    final diffStr = '${assetValueDiff >= 0 ? '+' : ''}${amtFmt.format(assetValueDiff)}';

    final subStyle = TextStyle(fontSize: 9, color: Colors.grey.shade500);

    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text('\u21B3 $assetCurrency', style: subStyle),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(priceStr, style: subStyle, textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 2,
            child: Text(
              pctStr,
              style: subStyle.copyWith(color: pctColor),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 3,
            child: PrivacyBlur(
              child: Text(
                diffStr,
                style: subStyle.copyWith(color: diffColor),
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
