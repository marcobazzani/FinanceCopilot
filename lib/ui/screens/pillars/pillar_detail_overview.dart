part of 'pillar_detail_screen.dart';

class _OverviewView extends ConsumerStatefulWidget {
  final String pillarId;
  final int? focusAssetId;
  const _OverviewView({required this.pillarId, this.focusAssetId});

  @override
  ConsumerState<_OverviewView> createState() => _OverviewViewState();
}

class _OverviewViewState extends ConsumerState<_OverviewView> {
  bool _loading = true;
  Map<int, _AssetRowState> _rows = {};
  List<int> _orderedAssetIds = [];
  String _filter = '';
  bool _onlyInPillar = false;
  String? _error;
  final _chartState = _ChartViewState();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = ref.read(pillarServiceProvider);
    final assets = await ref.read(activeAssetsProvider.future);
    final marketValues = await ref.read(assetMarketValuesProvider.future);
    // One batched call instead of five queries per asset: the per-asset loop
    // meant 65 sequential round trips on a 13-asset portfolio before the first
    // frame could render, which is why this screen used to sit on a spinner for
    // seconds. `quantitiesForPillar` is kind-aware exactly like
    // availableToAssign was (standard → total − other standard assigned;
    // virtual → total), and test/pillar_service_batch_test.dart pins the
    // equivalence.
    final quantities = await svc.quantitiesForPillar(widget.pillarId, assets.map((a) => a.id));
    final out = <int, _AssetRowState>{};
    for (final a in assets) {
      final q = quantities[a.id];
      if (q == null || q.total <= 0) continue;
      out[a.id] = _AssetRowState(
        assetId: a.id,
        total: q.total,
        available: q.available,
        current: q.current,
      );
    }
    // Display order is decided when the screen OPENS and then FROZEN.
    //
    // The ranking is what the screen is about: how much each asset contributes
    // to THIS pillar, largest first. Total holding value only breaks ties, so a
    // pillar with nothing assigned yet still opens in a sensible order — and an
    // asset held entirely by other pillars sinks to the bottom instead of
    // heading the list with a 0 slice.
    //
    // Frozen, because the slice is derived from `current`, which a slider
    // mutates on every drag frame: re-ranking mid-drag relocated the row (each
    // carries a ValueKey) out from under the user's finger and handed the rest
    // of the gesture to another asset. Commits also re-run this load via the
    // `pillarAssetsProvider` listener, so recomputing here would reshuffle the
    // list the moment a slider is released. Assets already on screen keep their
    // position; ones that appeared since are ranked and appended.
    double sliceOf(int id) {
      final r = out[id]!;
      return (marketValues[id] ?? 0) * (r.total <= 0 ? 0 : r.current / r.total);
    }

    final known = _orderedAssetIds.where(out.containsKey).toList();
    final fresh = out.keys.where((id) => !known.contains(id)).toList()
      ..sort((aId, bId) {
        final bySlice = sliceOf(bId).compareTo(sliceOf(aId));
        if (bySlice != 0) return bySlice;
        return (marketValues[bId] ?? 0).compareTo(marketValues[aId] ?? 0);
      });
    final ordered = [...known, ...fresh];
    if (!mounted) return;
    setState(() {
      _rows = out;
      _orderedAssetIds = ordered;
      _loading = false;
    });
  }

  Future<void> _commit(int assetId) async {
    final row = _rows[assetId];
    if (row == null) return;
    try {
      await ref
          .read(pillarServiceProvider)
          .assign(
            pillarId: widget.pillarId,
            assetId: assetId,
            qty: row.current,
          );
      if (mounted) setState(() => _error = null);
    } on PillarOverAssignedException catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  /// `Map<assetId, fraction>` derived from current row state — drives the
  /// chart's per-asset scaling. Fresh on every build so sliders update
  /// the chart in real time.
  Map<int, double> _liveFractions() {
    final m = <int, double>{};
    for (final r in _rows.values) {
      if (r.total > 0 && r.current > 0) m[r.assetId] = r.current / r.total;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    // External mutations to pillar_assets (other windows, service-level
    // assigns, deletes) must reflow `_rows` — otherwise sliders + chart
    // show stale fractions until the screen is reopened.
    ref.listen(pillarAssetsProvider, (_, _) {
      if (mounted && !_loading) _load();
    });
    final s = ref.watch(appStringsProvider);
    final assetsAsync = ref.watch(assetsProvider);
    final marketValues = ref.watch(assetMarketValuesProvider).value ?? const <int, double>{};
    final pillarsAsync = ref.watch(pillarsProvider);
    final allAsync = ref.watch(allSeriesDataProvider);
    final performanceAsync = ref.watch(pillarPerformanceProvider(widget.pillarId));
    final baseCurrency = ref.watch(baseCurrencyProvider).value ?? 'EUR';
    final locale = ref.watch(appLocaleProvider).value ?? 'en';
    final language = locale.split('_').first;
    final asOfDate = ref.watch(currentDateProvider);

    final assets = assetsAsync.value ?? const <Asset>[];
    final assetById = {for (final a in assets) a.id: a};
    final pillar = (pillarsAsync.value ?? const <Pillar>[]).where((p) => p.id == widget.pillarId).firstOrNull;
    final modelItemsAsync = pillar?.portfolioModelId == null ? null : ref.watch(portfolioModelItemsProvider(pillar!.portfolioModelId!));
    final targetWeightByIsin = <String, double>{};
    if (modelItemsAsync?.value != null) {
      for (final item in modelItemsAsync!.value!) {
        targetWeightByIsin[_normaliseIsin(item.isin)] = item.targetWeight;
      }
    }

    double pillarValue = 0;
    for (final r in _rows.values) {
      if (r.current <= 0) continue;
      final mv = marketValues[r.assetId] ?? 0;
      pillarValue += mv * (r.current / r.total);
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final visibleRows = <_AssetRowState>[];
    for (final id in _orderedAssetIds) {
      final r = _rows[id];
      if (r == null) continue;
      if (_onlyInPillar && r.current <= 1e-9) continue;
      if (_filter.isNotEmpty) {
        final asset = assetById[id];
        if (asset == null) continue;
        final q = _filter.toLowerCase();
        final hit = asset.name.toLowerCase().contains(q) || (asset.ticker?.toLowerCase().contains(q) ?? false);
        if (!hit) continue;
      }
      visibleRows.add(r);
    }
    // Deliberately NOT sorted here. The rows used to be re-sorted on every
    // build by their slice value, which is derived from `row.current` — the
    // value a slider mutates continuously while being dragged. Re-sorting
    // mid-drag moved the row (each has a ValueKey, so Flutter relocates the
    // widget) out from under the user's finger and handed the rest of the
    // gesture to a different asset. Order is decided once in `_load` and stays
    // put; see the comment there.

    final fractions = _liveFractions();
    final livePerformance = allAsync.value == null
        ? null
        : computePillarPerformanceSnapshot(
            asOfDate: asOfDate,
            allData: allAsync.value!,
            fractions: fractions,
          );
    final performance = livePerformance ?? performanceAsync.value;

    return Column(
      children: [
        if (pillar != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: _ObjectiveCard(
              pillar: pillar,
              value: pillarValue,
              performance: performance,
              locale: locale,
              baseCurrency: baseCurrency,
            ),
          ),
        if (allAsync.value != null && fractions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _PillarMarketInvestedChart(
              pillarId: widget.pillarId,
              title: s.pillarHistoryTitle,
              allData: allAsync.value!,
              fractions: fractions,
              state: _chartState,
              locale: locale,
              language: language,
              onChanged: () => setState(() {}),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: s.pillarSearchAssets,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _filter = v),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text(_onlyInPillar ? s.pillarShowInPillarOnly : s.pillarShowAllAssets),
                selected: _onlyInPillar,
                onSelected: (v) => setState(() => _onlyInPillar = v),
              ),
            ],
          ),
        ),
        if (_error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Theme.of(context).colorScheme.errorContainer,
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!)),
              ],
            ),
          ),
        Expanded(
          child: visibleRows.isEmpty
              ? Center(child: Text(s.pillarsEmptyTitle))
              : ListView(
                  children: [
                    for (var i = 0; i < visibleRows.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      Builder(
                        builder: (ctx) {
                          final row = visibleRows[i];
                          final asset = assetById[row.assetId];
                          final sliceValue = (marketValues[row.assetId] ?? 0) * (row.total <= 0 ? 0 : row.current / row.total);
                          final isin = asset?.isin?.trim();
                          final targetWeight = isin == null ? null : targetWeightByIsin[_normaliseIsin(isin)];
                          final currentWeight = pillarValue <= 0 ? 0.0 : sliceValue / pillarValue * 100.0;
                          return _AssetSliderRow(
                            key: ValueKey('pillar-row-${row.assetId}'),
                            row: row,
                            asset: asset,
                            assetMarketValue: marketValues[row.assetId] ?? 0,
                            baseCurrency: baseCurrency,
                            locale: locale,
                            targetWeight: targetWeight,
                            currentWeight: currentWeight,
                            onChanged: (newQty) {
                              setState(() => row.current = newQty);
                            },
                            onChangeEnd: () => _commit(row.assetId),
                            s: s,
                          );
                        },
                      ),
                    ],
                    if (pillar?.portfolioModelId != null) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                        child: Text(s.portfolioDivergenceTitle, style: Theme.of(context).textTheme.titleSmall),
                      ),
                      if (targetWeightByIsin.isNotEmpty)
                        ..._divergenceFooterRows(
                          context: context,
                          s: s,
                          locale: locale,
                          baseCurrency: baseCurrency,
                          marketValues: marketValues,
                          visibleRows: visibleRows,
                          assetById: assetById,
                          targetWeightByIsin: targetWeightByIsin,
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

/// Reuses the dashboard's [ChartCard] widget. Renders TWO lines per asset:
/// the per-asset invested series (dashed) and the per-asset market series
/// (filled), each scaled by the pillar's fraction. Series keys stay
/// identical to the dashboard's so ChartCard's smart-total logic keeps
/// the running total = market value of the pillar's slice.
class _PillarMarketInvestedChart extends StatelessWidget {
  final String pillarId;
  final String title;
  final AllSeriesData allData;
  final Map<int, double> fractions;
  final _ChartViewState state;
  final String locale;
  final String language;
  final VoidCallback onChanged;
  const _PillarMarketInvestedChart({
    required this.pillarId,
    required this.title,
    required this.allData,
    required this.fractions,
    required this.state,
    required this.locale,
    required this.language,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final history = buildPillarScopedHistory(
      allData: allData,
      fractions: fractions,
    );
    final investedTotal = history.investedTotal;
    final marketTotal = history.marketTotal;

    // Use the dashboard's `asset_invested:<id>` / `asset_market:<id>` key
    // shape so ChartCard's smart-total logic recognises the pair and
    // excludes invested from the running total — invested + value never
    // add up in the header. id=-1 is a synthetic single bucket; real asset
    // ids are positive autoincrement, so no collision.
    final scaled = <ChartSeries>[
      if (investedTotal.isNotEmpty)
        ChartSeries(
          key: 'asset_invested:-1',
          name: 'Invested',
          color: Colors.orange,
          spots: investedTotal,
          isDashed: true,
        ),
      if (marketTotal.isNotEmpty)
        ChartSeries(
          key: 'asset_market:-1',
          name: 'Value',
          color: Colors.blue,
          spots: marketTotal,
        ),
    ];
    if (scaled.isEmpty) return const SizedBox.shrink();

    final chart = DashboardChart(
      id: pillarId.hashCode,
      title: title,
      widgetType: 'chart',
      sortOrder: 0,
      seriesJson: '[]',
      createdAt: DateTime.now(),
    );

    // Synthetic AllSeriesData with the trimmed firstDate. ChartCard reads
    // `firstDate` and `baseCurrency` from this object; the per-category
    // lists are unused because we pass `series` directly.
    final trimmedAllData = AllSeriesData(
      firstDate: history.inceptionDate ?? allData.firstDate,
      accounts: const [],
      assetInvested: const [],
      assetMarket: const [],
      assetGain: const [],
      assetNet: const [],
      adjustments: const [],
      incomeAdjustments: const [],
      ephemeralInflows: const [],
      baseCurrency: allData.baseCurrency,
    );

    return ChartCard(
      chart: chart,
      series: scaled,
      allData: trimmedAllData,
      showTotal: false,
      hidden: state.hidden,
      hideComponents: state.hideComponents,
      locale: locale,
      language: language,
      chartHeight: state.height,
      zoomMinX: state.zoomMinX,
      zoomMaxX: state.zoomMaxX,
      zoomMinY: state.zoomMinY,
      zoomMaxY: state.zoomMaxY,
      onToggle: (key) {
        state.hidden.contains(key) ? state.hidden.remove(key) : state.hidden.add(key);
        onChanged();
      },
      onToggleGroup: (keys) {
        keys.every(state.hidden.contains) ? state.hidden.removeAll(keys) : state.hidden.addAll(keys);
        onChanged();
      },
      onToggleHideComponents: () {
        state.hideComponents = !state.hideComponents;
        onChanged();
      },
      onZoom: (minX, maxX, minY, maxY) {
        state.zoomMinX = minX;
        state.zoomMaxX = maxX;
        state.zoomMinY = minY;
        state.zoomMaxY = maxY;
        onChanged();
      },
      onHeightChanged: (h) {
        state.height = h.clamp(180.0, 800.0);
        onChanged();
      },
    );
  }
}
