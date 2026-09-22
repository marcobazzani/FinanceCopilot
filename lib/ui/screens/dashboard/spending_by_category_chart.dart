part of 'dashboard_screen.dart';

/// "Where the money goes": spending per category, one bar per year (current
/// year = YTD), toggle between absolute amounts and share of the year.
///
/// Uncategorized spending is always its own bucket so incomplete
/// classification is visible instead of silently distorting the picture.
class _SpendingByCategoryChart extends ConsumerStatefulWidget {
  final SpendingByCategoryData data;
  final String locale;
  const _SpendingByCategoryChart({required this.data, required this.locale});

  @override
  ConsumerState<_SpendingByCategoryChart> createState() => _SpendingByCategoryChartState();
}

class _SpendingByCategoryChartState extends ConsumerState<_SpendingByCategoryChart> with _ToggleableChartMixin {
  bool _share = false;

  /// Year colors: oldest faded → current year strongest.
  Color _yearColor(ColorScheme scheme, int index, int count) {
    if (count <= 1) return scheme.primary;
    final t = index / (count - 1);
    return Color.lerp(scheme.primary.withValues(alpha: 0.35), scheme.primary, t)!;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final d = widget.data;
    final byId = ref.watch(categoriesByIdProvider);
    final isPrivate = ref.watch(privacyModeProvider);
    final scheme = Theme.of(context).colorScheme;
    final amtFmt = fmt.amountFormat(widget.locale);
    final sym = currencySymbol(d.baseCurrency);

    if (d.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(s.spendingByCategoryEmpty, textAlign: TextAlign.center, key: const Key('spendingEmpty')),
      );
    }

    final years = d.years;
    final visibleYears = years.where((y) => isVisible('$y')).toList();
    final cats = d.categoriesByTotal();
    String catLabel(int? id) => categoryLabelFor(id, byId, s);
    String yearLabel(int y) => y == d.currentYear ? '$y ${s.ytdSuffix}' : '$y';

    double value(int y, int? c) => _share ? d.share(y, c) * 100 : d.amount(y, c);

    final groups = <BarChartGroupData>[];
    for (var i = 0; i < cats.length; i++) {
      groups.add(
        BarChartGroupData(
          x: i,
          barsSpace: 2,
          barRods: [
            for (final y in visibleYears)
              BarChartRodData(
                toY: value(y, cats[i]),
                width: (28 / visibleYears.length).clamp(4.0, 14.0),
                color: _yearColor(scheme, years.indexOf(y), years.length),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
              ),
          ],
        ),
      );
    }
    final maxY = visibleMaxY([
      for (final y in visibleYears)
        for (final c in cats) value(y, c),
    ], margin: 1.15);
    final chartWidth = (cats.length * (visibleYears.length * 16.0 + 24)).clamp(320.0, 4000.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    for (var i = 0; i < years.length; i++)
                      _ToggleLegendItem(
                        color: _yearColor(scheme, i, years.length),
                        label: yearLabel(years[i]),
                        enabled: isVisible('${years[i]}'),
                        onTap: () => toggle('${years[i]}'),
                      ),
                  ],
                ),
              ),
              SegmentedButton<bool>(
                key: const Key('spendingModeToggle'),
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: [
                  ButtonSegment(value: false, label: Text(s.chartModeAmount)),
                  ButtonSegment(value: true, label: Text(s.chartModeShare)),
                ],
                selected: {_share},
                onSelectionChanged: (v) => setState(() => _share = v.first),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 320,
          child: LayoutBuilder(
            builder: (ctx, box) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: max(chartWidth, box.maxWidth),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
                  child: BarChart(
                    BarChartData(
                      barGroups: groups,
                      maxY: maxY == 0 ? 1 : maxY,
                      gridData: const FlGridData(show: true, drawVerticalLine: false),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(
                        enabled: _share || !isPrivate,
                        touchCallback: (event, response) {
                          if (event is! FlTapUpEvent || response?.spot == null) return;
                          final spot = response!.spot!;
                          final cat = cats[spot.touchedBarGroupIndex];
                          final year = visibleYears[spot.touchedRodDataIndex];
                          _showDrillDown(context, year: year, categoryId: cat, label: catLabel(cat));
                        },
                        touchTooltipData: BarTouchTooltipData(
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          getTooltipItem: (group, gi, rod, ri) {
                            final cat = cats[group.x];
                            final y = visibleYears[ri];
                            final v = _share ? '${(d.share(y, cat) * 100).toStringAsFixed(1)}%' : '${amtFmt.format(d.amount(y, cat))} $sym';
                            return BarTooltipItem(
                              '${catLabel(cat)}\n${yearLabel(y)}: $v',
                              const TextStyle(color: Colors.white, fontSize: 11),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: _share ? 40 : 70,
                            getTitlesWidget: (v, _) => Text(
                              _share ? '${v.round()}%' : (isPrivate ? '\u2022\u2022\u2022\u2022' : _shortAmount(v, sym)),
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 56,
                            getTitlesWidget: (v, _) {
                              final i = v.round();
                              if (i < 0 || i >= cats.length) return const SizedBox.shrink();
                              final c = cats[i] == null ? null : byId[cats[i]];
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      c == null ? Icons.help_outline : categoryIcon(c),
                                      size: 14,
                                      color: c == null ? scheme.outline : categoryPaint(c, scheme),
                                    ),
                                    SizedBox(
                                      width: 64,
                                      child: Text(
                                        catLabel(cats[i]),
                                        style: const TextStyle(fontSize: 9),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            [s.spendingTransfersExcluded, if (d.fxExcluded > 0) s.spendingFxExcluded(d.fxExcluded)].join(' · '),
            key: const Key('spendingFootnote'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Future<void> _showDrillDown(BuildContext context, {required int year, required int? categoryId, required String label}) async {
    final s = ref.read(appStringsProvider);
    final txs = await ref.read(allTransactionsProvider.future);
    final byId = ref.read(categoriesByIdProvider);
    final excluded = ref.read(ledgerRolesProvider).value ?? const <int, LedgerRole>{};
    final rows = txs.where((t) {
      if (t.amount >= 0 || t.status == TransactionStatus.cancelled || t.valueDate.year != year) return false;
      if (excluded.containsKey(t.id)) return false;
      final cat = t.categoryId == null ? null : byId[t.categoryId];
      if (!isSpendingCategoryType(cat?.type)) return false;
      return (cat?.id) == categoryId;
    }).toList()..sort((a, b) => b.valueDate.compareTo(a.valueDate));
    if (!context.mounted) return;
    final dateFmt = fmt.shortDateFormat(widget.locale);
    final amtFmt = fmt.amountFormat(widget.locale);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (ctx, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('$label · $year (${rows.length})', style: Theme.of(ctx).textTheme.titleMedium),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: rows.length,
                itemBuilder: (_, i) {
                  final t = rows[i];
                  return ListTile(
                    dense: true,
                    title: Text(t.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(dateFmt.format(t.valueDate)),
                    trailing: PrivacyText('${amtFmt.format(t.amount)} ${t.currency}'),
                  );
                },
              ),
            ),
            if (rows.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(s.noCategory)),
          ],
        ),
      ),
    );
  }
}
