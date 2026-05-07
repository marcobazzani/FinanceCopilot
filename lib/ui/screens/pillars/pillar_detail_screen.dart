import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../database/database.dart';
import '../../../l10n/app_strings.dart';
import '../../../models/dashboard_chart.dart';
import '../../../services/pillar_service.dart';
import '../../../services/providers/providers.dart';
import '../../widgets/global_app_bar_actions.dart';
import '../../../utils/formatters.dart' as fmt;
import '../dashboard/dashboard_screen.dart'
    show AllSeriesData, ChartCard, ChartSeries, allSeriesDataProvider, buildTotalSpots;
import 'pillar_create_dialog.dart';

class PillarDetailScreen extends ConsumerWidget {
  final String pillarId;
  final int? focusAssetId;
  const PillarDetailScreen({
    super.key,
    required this.pillarId,
    this.focusAssetId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final pillarsAsync = ref.watch(pillarsProvider);
    return Scaffold(
      appBar: AppBar(
        title: pillarsAsync.when(
          loading: () => const Text('…'),
          error: (e, _) => Text('$e'),
          data: (pillars) {
            final p = pillars.where((x) => x.id == pillarId).firstOrNull;
            if (p == null) return const Text('—');
            return Text(p.name);
          },
        ),
        actions: globalAppBarActions(context, ref, local: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: s.edit,
            onPressed: () async {
              final p = (pillarsAsync.value ?? const [])
                  .where((x) => x.id == pillarId)
                  .firstOrNull;
              if (p == null) return;
              await showDialog(
                context: context,
                builder: (_) => PillarCreateDialog(existing: p),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: s.delete,
            onPressed: () async {
              final p = (pillarsAsync.value ?? const [])
                  .where((x) => x.id == pillarId)
                  .firstOrNull;
              if (p == null) return;
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(s.delete),
                  content: Text(s.pillarDeleteConfirm),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.delete)),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(pillarServiceProvider).delete(p.id);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
          ),
        ]),
      ),
      body: _OverviewView(pillarId: pillarId, focusAssetId: focusAssetId),
    );
  }
}

class _AssetRowState {
  final int assetId;
  final double total;
  final double otherAssigned;
  double current;
  _AssetRowState({
    required this.assetId,
    required this.total,
    required this.otherAssigned,
    required this.current,
  });
  double get maxAvailable => total - otherAssigned;
  double get maxPercent =>
      total <= 0 ? 0 : (maxAvailable / total * 100).clamp(0.0, 100.0);
  double get currentPercent =>
      total <= 0 ? 0 : (current / total * 100).clamp(0.0, 100.0);
}

class _ChartViewState {
  Set<String> hidden = <String>{};
  bool hideComponents = false;
  double height = 320;
  double? zoomMinX;
  double? zoomMaxX;
  double? zoomMinY;
  double? zoomMaxY;
}

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
    final out = <int, _AssetRowState>{};
    for (final a in assets) {
      final total = await svc.totalQuantity(a.id);
      if (total <= 0) continue;
      final current = await svc.qtyFor(widget.pillarId, a.id);
      final unassigned = await svc.unassignedQty(a.id);
      final otherAssigned = total - unassigned - current;
      out[a.id] = _AssetRowState(
        assetId: a.id,
        total: total,
        otherAssigned: otherAssigned < 0 ? 0 : otherAssigned,
        current: current,
      );
    }
    final ordered = out.keys.toList()
      ..sort((aId, bId) {
        final aV = marketValues[aId] ?? 0;
        final bV = marketValues[bId] ?? 0;
        return bV.compareTo(aV);
      });
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
      await ref.read(pillarServiceProvider).assign(
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
    final baseCurrency = ref.watch(baseCurrencyProvider).value ?? 'EUR';
    final locale = ref.watch(appLocaleProvider).value ?? 'en';
    final language = locale.split('_').first;

    final assets = assetsAsync.value ?? const <Asset>[];
    final assetById = {for (final a in assets) a.id: a};
    final pillar = (pillarsAsync.value ?? const <Pillar>[])
        .where((p) => p.id == widget.pillarId)
        .firstOrNull;

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
        final hit = asset.name.toLowerCase().contains(q) ||
            (asset.ticker?.toLowerCase().contains(q) ?? false);
        if (!hit) continue;
      }
      visibleRows.add(r);
    }

    final fractions = _liveFractions();

    return Column(
      children: [
        if (pillar != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: _ObjectiveCard(
              pillar: pillar,
              value: pillarValue,
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
                label: Text(_onlyInPillar
                    ? s.pillarShowInPillarOnly
                    : s.pillarShowAllAssets),
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
            child: Row(children: [
              const Icon(Icons.error_outline, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!)),
            ]),
          ),
        Expanded(
          child: visibleRows.isEmpty
              ? Center(child: Text(s.pillarsEmptyTitle))
              : ListView.separated(
                  itemCount: visibleRows.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final row = visibleRows[i];
                    final asset = assetById[row.assetId];
                    return _AssetSliderRow(
                      key: ValueKey('pillar-row-${row.assetId}'),
                      row: row,
                      asset: asset,
                      assetMarketValue: marketValues[row.assetId] ?? 0,
                      baseCurrency: baseCurrency,
                      locale: locale,
                      onChanged: (newQty) {
                        setState(() => row.current = newQty);
                      },
                      onChangeEnd: () => _commit(row.assetId),
                      s: s,
                    );
                  },
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
    // Aggregate first: scale each per-asset series by the pillar's
    // fraction, then build ONE invested line and ONE market line via
    // carry-forward summation. Per-asset breakdown is intentionally
    // hidden — the chart shows pillar-level totals only.
    final scaledInvested = <List<FlSpot>>[];
    final scaledMarket = <List<FlSpot>>[];
    double? minX;
    void seenX(double x) {
      if (minX == null || x < minX!) minX = x;
    }
    for (final entry in fractions.entries) {
      final fraction = entry.value;
      if (fraction <= 0) continue;
      final inv = allData.assetInvested
          .where((x) => x.key == 'asset_invested:${entry.key}')
          .firstOrNull;
      final mkt = allData.assetMarket
          .where((x) => x.key == 'asset_market:${entry.key}')
          .firstOrNull;
      if (inv != null) {
        if (inv.spots.isNotEmpty) seenX(inv.spots.first.x);
        scaledInvested.add(
          inv.spots.map((p) => FlSpot(p.x, p.y * fraction)).toList(),
        );
      }
      if (mkt != null) {
        if (mkt.spots.isNotEmpty) seenX(mkt.spots.first.x);
        scaledMarket.add(
          mkt.spots.map((p) => FlSpot(p.x, p.y * fraction)).toList(),
        );
      }
    }
    // Trim leading empty area: drop spots before the pillar's first data
    // point and shift x so the chart's x=0 lines up with that date.
    final shift = minX ?? 0;
    List<FlSpot> trim(List<FlSpot> s) => s
        .where((p) => p.x >= shift)
        .map((p) => FlSpot(p.x - shift, p.y))
        .toList();
    final investedTotal = buildTotalSpots(scaledInvested.map(trim).toList());
    final marketTotal = buildTotalSpots(scaledMarket.map(trim).toList());

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
      firstDate: allData.firstDate.add(Duration(days: shift.toInt())),
      accounts: const [],
      assetInvested: const [],
      assetMarket: const [],
      assetGain: const [],
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
        keys.every(state.hidden.contains)
            ? state.hidden.removeAll(keys)
            : state.hidden.addAll(keys);
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

class _AssetSliderRow extends StatelessWidget {
  final _AssetRowState row;
  final Asset? asset;
  final double assetMarketValue;
  final String baseCurrency;
  final String locale;
  final void Function(double newQty) onChanged;
  final VoidCallback onChangeEnd;
  final AppStrings s;
  const _AssetSliderRow({
    super.key,
    required this.row,
    required this.asset,
    required this.assetMarketValue,
    required this.baseCurrency,
    required this.locale,
    required this.onChanged,
    required this.onChangeEnd,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    final qf = fmt.qtyFormat(locale);
    final amf = fmt.amountFormat(locale);
    final percent = row.currentPercent;
    final maxPct = row.maxPercent;
    final disabled = maxPct <= 0;
    final pf = NumberFormat.percentPattern(locale)..maximumFractionDigits = 1;
    final sliceValue = row.total <= 0
        ? 0.0
        : assetMarketValue * (row.current / row.total);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  asset == null
                      ? '#${row.assetId}'
                      : (asset!.ticker == null
                          ? asset!.name
                          : '${asset!.ticker}  ·  ${asset!.name}'),
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${amf.format(assetMarketValue)} $baseCurrency',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 8),
              Text(
                pf.format(percent / 100),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: percent.clamp(0.0, maxPct.clamp(0.001, 100.0)),
                  min: 0,
                  max: maxPct <= 0 ? 100 : maxPct,
                  divisions: maxPct <= 0 ? null : (maxPct.round().clamp(1, 100)),
                  onChanged: disabled
                      ? null
                      : (newPct) {
                          final newQty = row.total * newPct / 100.0;
                          onChanged(_round(newQty));
                        },
                  onChangeEnd: disabled ? null : (_) => onChangeEnd(),
                ),
              ),
              IconButton(
                tooltip: '0%',
                icon: const Icon(Icons.clear, size: 18),
                onPressed: row.current <= 1e-9
                    ? null
                    : () {
                        onChanged(0);
                        onChangeEnd();
                      },
              ),
              IconButton(
                tooltip: '${maxPct.round()}%',
                icon: const Icon(Icons.last_page, size: 18),
                onPressed: disabled
                    ? null
                    : () {
                        onChanged(_round(row.maxAvailable));
                        onChangeEnd();
                      },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 0),
            child: Text(
              '${s.pillarUnitsOf(qf.format(row.current), qf.format(row.total))} · ${amf.format(sliceValue)} $baseCurrency · ${s.pillarMaxPercent(maxPct.round())}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  double _round(double v) {
    final r = (v * 10000).round() / 10000;
    return r < 0 ? 0 : r;
  }
}

class _ObjectiveCard extends ConsumerWidget {
  final Pillar pillar;
  final double value;
  final String locale;
  final String baseCurrency;
  const _ObjectiveCard({
    required this.pillar,
    required this.value,
    required this.locale,
    required this.baseCurrency,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final hasTarget = pillar.targetValue != null && pillar.targetValue! > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.pillarObjective, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(s.pillarValue('${fmt.amountFormat(locale).format(value)} $baseCurrency')),
            if (hasTarget) ...[
              const SizedBox(height: 4),
              Text(s.pillarTarget('${fmt.amountFormat(locale).format(pillar.targetValue)} ${pillar.targetCurrency}')),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (value / pillar.targetValue!).clamp(0.0, 1.0),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
