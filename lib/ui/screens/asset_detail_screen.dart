import 'dart:async';
import 'dart:io';
import 'dart:math';
import '../../utils/dialogs.dart';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../database/database.dart';
import '../../database/tables.dart';
import '../../l10n/app_strings.dart';
import '../../services/composition_service.dart';
import '../../services/investing_com_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/market_price_service.dart' show investingExchangeToCode, supportedExchanges;
import '../../services/providers/providers.dart';
import '../../utils/formatters.dart' as fmt;
import '../../utils/logger.dart';
import 'asset_detail_charts_provider.dart';
import 'asset_event_edit_screen.dart';
import 'dashboard/dashboard_screen.dart' show ChartSeries, DragZoomWrapper, UnifiedChart, currencySymbol;
import '../widgets/asset_search.dart';
import '../widgets/selection/selectable_item.dart';
import '../widgets/selection/selection_action_bar.dart';
import '../widgets/selection/selection_controller.dart';

final _log = getLogger('AssetDetailScreen');

/// Shows events for a single asset, with summary card + event list + edit.
class AssetDetailScreen extends ConsumerStatefulWidget {
  final Asset asset;
  const AssetDetailScreen({super.key, required this.asset});

  @override
  ConsumerState<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends ConsumerState<AssetDetailScreen> {
  final _selection = SelectionController<int>();

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  Asset get asset => widget.asset;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final eventsStream = ref.watch(assetEventsProvider(asset.id));
    final locale = ref.watch(appLocaleProvider).value ?? Platform.localeName;
    final dateFmt = fmt.shortDateFormat(locale);
    final amtFmt = fmt.currencyFormat(locale, asset.currency);
    final baseCurrency = ref.watch(baseCurrencyProvider).value ?? 'EUR';
    final showConverted = asset.currency != baseCurrency;
    final baseFmt = fmt.currencyFormat(locale, currencySymbol(baseCurrency));
    final convertedAmounts = showConverted
        ? ref.watch(convertedEventAmountsProvider(asset.id)).value ?? {}
        : <int, double>{};

    return ListenableBuilder(
      listenable: _selection,
      builder: (lbCtx, _) {
        final events = eventsStream.value ?? const <AssetEvent>[];
        _selection.setOrderedIds(events.map((e) => e.id).toList());
        return Scaffold(
      appBar: AppBar(
        title: Text(asset.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: s.tooltipEditAsset,
            onPressed: () => _editAsset(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: s.tooltipWipeEvents,
            onPressed: () => _confirmWipeEvents(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: s.tooltipDeleteAsset,
            onPressed: () => _confirmDeleteAsset(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          // Asset info card
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (asset.ticker != null) ...[
                        Chip(label: Text(asset.ticker!), avatar: const Icon(Icons.label, size: 16)),
                        const SizedBox(width: 8),
                      ],
                      Chip(label: Text(asset.currency)),
                    ],
                  ),
                  if (asset.isin != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(s.isinPrefix(asset.isin!), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                  if (asset.taxRate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        s.taxRateLabel((asset.taxRate! * 100).toStringAsFixed(1)),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Asset charts (portfolio history + performance)
          _AssetChartSection(assetId: asset.id),
          // Composition breakdown
          _CompositionSection(assetId: asset.id),
          // Events header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(s.eventsLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                eventsStream.when(
                  data: (events) => Text(s.nEvents(events.length), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  loading: () => const SizedBox(),
                  error: (_, _) => const SizedBox(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Events list
          Expanded(
            child: eventsStream.when(
              data: (events) {
                if (events.isEmpty) {
                  return Center(
                    child: Text(s.noEventsYet,
                        textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                  );
                }
                return ListView.separated(
                  itemCount: events.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final ev = events[i];
                    final typeColor = _colorForEventType(ev.type);
                    return SelectableItem<int>(
                      controller: _selection,
                      id: ev.id,
                      child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: typeColor.withValues(alpha: 0.15),
                        child: Text(
                          ev.type.name.substring(0, 1).toUpperCase(),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: typeColor),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(ev.type.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: typeColor)),
                          if (ev.quantity != null) ...[
                            const SizedBox(width: 8),
                            Text('qty: ${ev.quantity!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                          if (ev.price != null) ...[
                            const SizedBox(width: 8),
                            Text('@ ${ev.price!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ],
                      ),
                      subtitle: Text(dateFmt.format(ev.valueDate), style: const TextStyle(fontSize: 12)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${ev.amount >= 0 ? '+' : ''}${amtFmt.format(ev.amount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: ev.amount >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                          ),
                          if (showConverted && convertedAmounts.containsKey(ev.id))
                            Text(
                              '≈ ${baseFmt.format(convertedAmounts[ev.id]!)}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                        ],
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AssetEventEditScreen(event: ev, asset: asset),
                        ),
                      ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(s.error(e))),
            ),
          ),
        ],
      ),
          bottomNavigationBar: _selection.active
              ? SelectionActionBar<int>(
                  controller: _selection,
                  visibleIds: events.map((e) => e.id).toList(),
                  onDelete: (ids) => ref.read(assetEventServiceProvider).deleteMany(ids.toList()),
                )
              : null,
          floatingActionButton: _selection.active
              ? null
              : FloatingActionButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AssetEventEditScreen(asset: asset)),
                  ),
                  child: const Icon(Icons.add),
                ),
        );
      },
    );
  }

  Color _colorForEventType(EventType type) {
    return switch (type) {
      EventType.buy => Colors.blue,
      EventType.sell => Colors.orange,
      EventType.revalue => Colors.teal,
    };
  }

  Future<void> _editAsset(BuildContext context, WidgetRef ref) async {
    // Pull the latest asset row from the live stream rather than reusing
    // `widget.asset` (the snapshot captured when the user first opened
    // this screen). Without this, fields edited in a previous dialog
    // session look "not saved" on reopen — the DB is updated but the
    // dialog re-initializes controllers from the stale snapshot.
    final live = ref.read(assetsProvider).value
            ?.firstWhere((a) => a.id == asset.id, orElse: () => asset) ??
        asset;
    await showDialog(
      context: context,
      builder: (ctx) => _EditAssetDialog(ref: ref, asset: live),
    );
  }

  Future<void> _confirmWipeEvents(BuildContext context, WidgetRef ref) async {
    final s = ref.read(appStringsProvider);
    final evCount = ref.read(assetEventsProvider(asset.id)).value?.length ?? 0;
    if (evCount == 0) {
      showInfoSnack(context, s.noEventsToWipe);
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: s.wipeAllEventsTitle,
      content: '${s.wipeEventsBody(evCount, asset.name)}${s.cannotBeUndone}',
      confirmLabel: s.wipe,
      cancelLabel: s.cancel,
      confirmColor: Colors.orange,
    );
    if (confirmed) {
      _log.warning('wiping events for asset ${asset.id}');
      final deleted = await ref.read(assetEventServiceProvider).deleteByAsset(asset.id);
      if (context.mounted) {
        showInfoSnack(context, s.wipedEvents(deleted));
      }
    }
  }

  Future<void> _confirmDeleteAsset(BuildContext context, WidgetRef ref) async {
    final s = ref.read(appStringsProvider);
    final confirmed = await showConfirmDialog(
      context,
      title: s.deleteAssetTitle,
      content: s.deleteAssetConfirm(asset.name),
      confirmLabel: s.delete,
      cancelLabel: s.cancel,
      confirmColor: Colors.red,
    );
    if (confirmed) {
      _log.warning('deleting asset id=${asset.id}, name=${asset.name}');
      await ref.read(assetEventServiceProvider).deleteByAsset(asset.id);
      await ref.read(assetServiceProvider).delete(asset.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

// ──────────────────────────────────────────────
// Asset chart cards (value + price)
// ──────────────────────────────────────────────

class _AssetChartSection extends ConsumerWidget {
  final int assetId;
  const _AssetChartSection({required this.assetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartDataAsync = ref.watch(singleAssetChartDataProvider(assetId));
    return chartDataAsync.when(
      data: (data) {
        if (data == null || data.marketSeries.spots.length < 2) {
          return const SizedBox.shrink();
        }
        final s = ref.watch(appStringsProvider);
        final locale = ref.watch(appLocaleProvider).value ?? Platform.localeName;
        final baseSymbol = currencySymbol(data.baseCurrency);
        final baseFmt = fmt.currencyFormat(locale, baseSymbol, decimalDigits: 0);
        final assetSymbol = currencySymbol(data.assetCurrency);
        final assetFmt = fmt.currencyFormat(locale, assetSymbol);
        return Column(
          children: [
            _AssetChartCard(
              title: s.colAsset,
              titleValue: baseFmt.format(data.marketSeries.spots.last.y),
              series: [data.investedSeries, data.marketSeries],
              firstDate: data.firstDate,
              currency: data.baseCurrency,
            ),
            if (data.priceSeries.spots.length >= 2)
              _AssetChartCard(
                title: s.colPrice,
                titleValue: assetFmt.format(data.priceSeries.spots.last.y),
                series: [data.priceSeries],
                firstDate: data.firstDate,
                currency: data.assetCurrency,
              ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Reusable collapsible chart card. Uses show/hide instead of ExpansionTile
/// children list to avoid animating the chart widget (which causes jank).
class _AssetChartCard extends ConsumerStatefulWidget {
  final String title;
  final String titleValue;
  final List<ChartSeries> series;
  final DateTime firstDate;
  final String currency; // for axis labels

  const _AssetChartCard({
    required this.title,
    required this.titleValue,
    required this.series,
    required this.firstDate,
    required this.currency,
  });

  @override
  ConsumerState<_AssetChartCard> createState() => _AssetChartCardState();
}

class _AssetChartCardState extends ConsumerState<_AssetChartCard> {
  bool _expanded = false;
  double? _zoomMinX, _zoomMaxX, _zoomMinY, _zoomMaxY;

  void _onZoom(double? minX, double? maxX, double? minY, double? maxY) {
    setState(() {
      _zoomMinX = minX;
      _zoomMaxX = maxX;
      _zoomMinY = minY;
      _zoomMaxY = maxY;
    });
  }

  @override
  Widget build(BuildContext context) {
    final allSpots = widget.series.expand((s) => s.spots).toList();
    if (allSpots.length < 2) return const SizedBox.shrink();

    final locale = ref.watch(appLocaleProvider).value ?? Platform.localeName;
    final language = locale.split('_').first;
    final isPrivate = ref.watch(privacyModeProvider);
    final s = ref.watch(appStringsProvider);
    final hasZoom = _zoomMinX != null || _zoomMinY != null;

    // X range from all series
    final lastX = allSpots.map((s) => s.x).reduce(max);

    // Y range from all series
    final allY = allSpots.map((s) => s.y).toList();
    final autoMinY = allY.reduce(min);
    final autoMaxY = allY.reduce(max);
    final autoRange = autoMaxY - autoMinY;
    final effectiveMinY = _zoomMinY ?? (autoRange > 0 ? autoMinY - autoRange * 0.05 : autoMinY - 100);
    final effectiveMaxY = _zoomMaxY ?? (autoRange > 0 ? autoMaxY + autoRange * 0.05 : autoMaxY + 100);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(child: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                  if (isPrivate)
                    const Text('****', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))
                  else
                    Text(widget.titleValue,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 8),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 20),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded ? Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: SizedBox(
                height: 220,
                child: Stack(
                  children: [
                    DragZoomWrapper(
                      xMin: _zoomMinX ?? 0,
                      xMax: _zoomMaxX ?? lastX,
                      yMin: effectiveMinY,
                      yMax: effectiveMaxY,
                      totalDays: lastX,
                      firstDate: widget.firstDate,
                      baseCurrency: widget.currency,
                      locale: locale,
                      onZoom: _onZoom,
                      zoomedY: _zoomMinY != null || _zoomMaxY != null,
                      child: UnifiedChart(
                        firstDate: widget.firstDate,
                        visible: widget.series,
                        totalSpots: widget.series.first.spots,
                        showTotal: false,
                        baseCurrency: widget.currency,
                        locale: locale,
                        language: language,
                        zoomMinX: _zoomMinX,
                        zoomMaxX: _zoomMaxX,
                        zoomMinY: _zoomMinY,
                        zoomMaxY: _zoomMaxY,
                        isPrivate: isPrivate,
                        zoomedX: _zoomMinX != null || _zoomMaxX != null,
                      ),
                    ),
                    if (hasZoom)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          icon: const Icon(Icons.zoom_out_map, size: 18),
                          onPressed: () => _onZoom(null, null, null, null),
                          tooltip: s.resetZoom,
                        ),
                      ),
                  ],
                ),
              ),
            ) : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Composition breakdown section
// ──────────────────────────────────────────────

class _CompositionSection extends ConsumerWidget {
  final int assetId;
  const _CompositionSection({required this.assetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compositionsAsync = ref.watch(assetCompositionsProvider);
    final ss = ref.watch(appStringsProvider);
    final entries = compositionsAsync.value?[assetId] ?? const <AssetComposition>[];
    // Panel is always rendered so manual assets (no fetched composition)
    // can still get rows added via the per-section pencil icons. The
    // ExpansionTile collapses to a single line when not expanded so this
    // is cheap visual real-estate even on assets with zero rows.

    // Extract source URL and separate from display data
    String? sourceUrl;
    final byType = <String, List<AssetComposition>>{};
    for (final e in entries) {
      if (e.type == 'source_url') {
        sourceUrl = e.name;
        continue;
      }
      byType.putIfAbsent(e.type, () => []).add(e);
    }

    // Sort each group by weight descending
    for (final list in byType.values) {
      list.sort((a, b) => b.weight.compareTo(a.weight));
    }

    final typeLabels = {
      'assetclass': ss.compositionAssetClass,
      'country': ss.compositionGeographic,
      'sector': ss.compositionSector,
      'holding': ss.compositionTopHoldings,
    };
    const typeOrder = ['assetclass', 'country', 'sector', 'holding'];

    String? sourceLabel;
    if (sourceUrl != null) {
      if (sourceUrl.contains('justetf.com')) {
        sourceLabel = 'justETF';
      } else if (sourceUrl.contains('stockanalysis.com')) {
        sourceLabel = 'Stock Analysis';
      } else if (sourceUrl.contains('investing.com')) {
        sourceLabel = 'Investing.com';
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        title: Row(
          children: [
            Text(ss.composition,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            // Refresh: wipes rows and re-runs sync to fetch fresh market
            // data. Hidden when there's no data yet — nothing to refresh
            // and the network call would only return rows for assets that
            // a market data provider can identify (typically by ISIN).
            if (entries.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: ss.compositionRefreshTooltip,
                onPressed: () => _confirmRefresh(context, ref, ss),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
          ],
        ),
        initiallyExpanded: false,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          for (final type in typeOrder) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Row(
                children: [
                  Text(
                    typeLabels[type] ?? type,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 14),
                    tooltip: ss.compositionEditTooltip,
                    onPressed: () => _openEditor(context, ref, type, byType[type] ?? const []),
                    padding: const EdgeInsets.all(2),
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            if (byType[type]?.isNotEmpty ?? false)
              ...byType[type]!.map((c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(c.name, style: const TextStyle(fontSize: 12)),
                        ),
                        SizedBox(
                          width: 80,
                          child: Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: (c.weight / 100).clamp(0, 1),
                                    minHeight: 6,
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 38,
                                child: Text(
                                  '${c.weight.toStringAsFixed(1)}%',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
          if (sourceUrl != null && sourceLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: InkWell(
                onTap: () => launchUrl(Uri.parse(sourceUrl!)),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_in_new,
                          size: 14, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        ss.sourceLabel(sourceLabel),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    String type,
    List<AssetComposition> existing,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _CompositionEditorDialog(
        assetId: assetId,
        type: type,
        initial: [for (final e in existing) CompositionEntry(e.name, e.weight)],
      ),
    );
  }

  Future<void> _confirmRefresh(
      BuildContext context, WidgetRef ref, AppStrings ss) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(ss.compositionRefreshTooltip),
        content: Text(ss.cannotBeUndone),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(ss.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(ss.update),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(compositionServiceProvider).clearAndResync(assetId);
  }
}

// ──────────────────────────────────────────────
// Composition editor dialog — one section at a time
// ──────────────────────────────────────────────

class _CompositionEditorDialog extends ConsumerStatefulWidget {
  final int assetId;
  final String type;
  final List<CompositionEntry> initial;
  const _CompositionEditorDialog({
    required this.assetId,
    required this.type,
    required this.initial,
  });

  @override
  ConsumerState<_CompositionEditorDialog> createState() =>
      _CompositionEditorDialogState();
}

class _CompositionEditorDialogState
    extends ConsumerState<_CompositionEditorDialog> {
  late final List<TextEditingController> _nameCtrls;
  late final List<TextEditingController> _weightCtrls;
  late final String _locale;

  @override
  void initState() {
    super.initState();
    _locale = ref.read(appLocaleProvider).value ?? Platform.localeName;
    final fmt = NumberFormat.decimalPattern(_locale);
    _nameCtrls = [
      for (final e in widget.initial) TextEditingController(text: e.name),
    ];
    _weightCtrls = [
      for (final e in widget.initial)
        TextEditingController(text: fmt.format(e.weight)),
    ];
    if (_nameCtrls.isEmpty) {
      _nameCtrls.add(TextEditingController());
      _weightCtrls.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    for (final c in _nameCtrls) {
      c.dispose();
    }
    for (final c in _weightCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _nameCtrls.add(TextEditingController());
      _weightCtrls.add(TextEditingController());
    });
  }

  void _deleteRow(int i) {
    setState(() {
      _nameCtrls.removeAt(i).dispose();
      _weightCtrls.removeAt(i).dispose();
    });
  }

  double get _sum {
    double total = 0;
    for (final c in _weightCtrls) {
      total += fmt.tryParseLocalized(c.text, locale: _locale) ?? 0;
    }
    return total;
  }

  Future<void> _save() async {
    final entries = <CompositionEntry>[];
    for (var i = 0; i < _nameCtrls.length; i++) {
      final name = _nameCtrls[i].text.trim();
      final weight = fmt.tryParseLocalized(_weightCtrls[i].text, locale: _locale);
      if (name.isEmpty || weight == null || weight <= 0) continue;
      entries.add(CompositionEntry(name, weight));
    }
    await ref
        .read(compositionServiceProvider)
        .setEntries(widget.assetId, widget.type, entries);
    if (mounted) Navigator.pop(context);
  }

  String _typeLabel(AppStrings ss) => switch (widget.type) {
        'assetclass' => ss.compositionAssetClass,
        'country' => ss.compositionGeographic,
        'sector' => ss.compositionSector,
        'holding' => ss.compositionTopHoldings,
        _ => widget.type,
      };

  @override
  Widget build(BuildContext context) {
    final ss = ref.read(appStringsProvider);
    final sum = _sum;
    final sumOk = (sum - 100).abs() < 0.5;
    return AlertDialog(
      title: Text('${ss.compositionEditTooltip} — ${_typeLabel(ss)}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _nameCtrls.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _nameCtrls[i],
                          decoration: InputDecoration(
                            labelText: ss.compositionEntryName,
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _weightCtrls[i],
                          decoration: InputDecoration(
                            labelText: ss.compositionEntryWeight,
                            isDense: true,
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => _deleteRow(i),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(ss.compositionAddRow),
                    onPressed: _addRow,
                  ),
                  Text(
                    'Σ ${sum.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: sumOk ? Colors.grey : Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (!sumOk)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    ss.compositionWeightWarning,
                    style: const TextStyle(fontSize: 11, color: Colors.orange),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(ss.cancel)),
        FilledButton(onPressed: _save, child: Text(ss.save)),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Edit Asset Dialog — search + manual, like create
// ──────────────────────────────────────────────

class _EditAssetDialog extends StatefulWidget {
  final WidgetRef ref;
  final Asset asset;
  const _EditAssetDialog({required this.ref, required this.asset});

  @override
  State<_EditAssetDialog> createState() => _EditAssetDialogState();
}

class _EditAssetDialogState extends State<_EditAssetDialog> {
  bool _searchMode = false;
  bool _unlocked = false;

  // Edit fields (pre-populated from asset)
  late final TextEditingController _nameCtrl;
  late final TextEditingController _tickerCtrl;
  late final TextEditingController _isinCtrl;
  late final TextEditingController _terCtrl;
  late String _selectedExchange;
  late bool _isActive;
  late InstrumentType _instrumentType;
  late AssetClass _assetClass;

  // Advanced (unlock-only) controllers / selections.
  // Header attributes only — composition (geographic / sector / asset-class
  // breakdown) is edited inline on the Composition panel itself, not here.
  // Asset.country / Asset.sector are an internal fallback for assets
  // without composition data and are NOT user concepts; we don't surface
  // them.
  late final TextEditingController _currencyCtrl;
  late final TextEditingController _taxRateCtrl;
  late AssetType _assetType;
  late ValuationMethod _valuationMethod;
  late int _intermediaryId;
  late bool _includeInNetWorth;

  /// Cached app locale used for formatting initial values and parsing
  /// what the user types. Captured once in [initState] so a setState
  /// rebuild can't shift the format under us mid-edit.
  late final String _locale;

  String _fmtDouble(double? v) =>
      v == null ? '' : NumberFormat.decimalPattern(_locale).format(v);

  @override
  void initState() {
    super.initState();
    _locale = widget.ref.read(appLocaleProvider).value ?? Platform.localeName;
    _nameCtrl = TextEditingController(text: widget.asset.name);
    _tickerCtrl = TextEditingController(text: widget.asset.ticker ?? '');
    _isinCtrl = TextEditingController(text: widget.asset.isin ?? '');
    _terCtrl = TextEditingController(text: _fmtDouble(widget.asset.ter));
    _selectedExchange = widget.asset.exchange ?? 'MIL';
    _isActive = widget.asset.isActive;
    _instrumentType = widget.asset.instrumentType;
    _assetClass = widget.asset.assetClass;

    _currencyCtrl = TextEditingController(text: widget.asset.currency);
    // taxRate is stored as a fraction (0.26 = 26%). The field/label say
    // "(%)" so we pre-fill and accept the percentage value (26), and
    // convert on save.
    _taxRateCtrl = TextEditingController(
      text: _fmtDouble(widget.asset.taxRate == null ? null : widget.asset.taxRate! * 100),
    );
    _assetType = widget.asset.assetType;
    _valuationMethod = widget.asset.valuationMethod;
    _intermediaryId = widget.asset.intermediaryId;
    _includeInNetWorth = widget.asset.includeInNetWorth;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tickerCtrl.dispose();
    _isinCtrl.dispose();
    _terCtrl.dispose();
    _currencyCtrl.dispose();
    _taxRateCtrl.dispose();
    super.dispose();
  }

  void _selectResult(InvestingSearchResult result) {
    final code = investingExchangeToCode[result.exchange];
    setState(() {
      _nameCtrl.text = result.description;
      _tickerCtrl.text = result.symbol;
      _selectedExchange = code ?? _selectedExchange;
      _searchMode = false;
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final ticker = _tickerCtrl.text.trim().toUpperCase();
    final isin = _isinCtrl.text.trim().toUpperCase();
    final ter = fmt.tryParseLocalized(_terCtrl.text, locale: _locale);
    _log.info('saving asset id=${widget.asset.id}, name=$name, unlocked=$_unlocked');
    final companion = AssetsCompanion(
      name: Value(name),
      ticker: Value(ticker.isNotEmpty ? ticker : null),
      isin: Value(isin.isNotEmpty ? isin : null),
      exchange: Value(_selectedExchange),
      isActive: Value(_isActive),
      instrumentType: Value(_instrumentType),
      assetClass: Value(_assetClass),
      ter: Value(ter),
      updatedAt: Value(DateTime.now()),
      // Advanced fields write only when the user explicitly unlocked the
      // dialog. This keeps the locked path byte-identical to the original
      // behavior and lets the pinning test stay untouched.
      assetType: _unlocked ? Value(_assetType) : const Value.absent(),
      valuationMethod: _unlocked ? Value(_valuationMethod) : const Value.absent(),
      intermediaryId: _unlocked ? Value(_intermediaryId) : const Value.absent(),
      currency: _unlocked
          ? Value(_currencyCtrl.text.trim().toUpperCase().isEmpty
              ? widget.asset.currency
              : _currencyCtrl.text.trim().toUpperCase())
          : const Value.absent(),
      taxRate: _unlocked
          ? Value(() {
              // User types percent (26) — store fraction (0.26).
              final v = fmt.tryParseLocalized(_taxRateCtrl.text, locale: _locale);
              return v == null ? null : v / 100;
            }())
          : const Value.absent(),
      includeInNetWorth: _unlocked ? Value(_includeInNetWorth) : const Value.absent(),
    );
    await widget.ref.read(assetServiceProvider).update(widget.asset.id, companion);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_searchMode) return _buildSearchDialog();
    return _buildEditDialog();
  }

  Widget _buildEditDialog() {
    final s = widget.ref.read(appStringsProvider);
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(s.editAssetTitle)),
          IconButton(
            icon: Icon(_unlocked ? Icons.lock_open : Icons.lock_outline, size: 20),
            tooltip: _unlocked ? s.assetLockEdit : s.assetUnlockEdit,
            onPressed: () => setState(() => _unlocked = !_unlocked),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: s.name),
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            if (widget.asset.valuationMethod != ValuationMethod.eventDriven) ...[
              TextField(
                controller: _tickerCtrl,
                decoration: InputDecoration(
                  labelText: s.tickerLabel,
                  hintText: s.tickerHint,
                ),
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _isinCtrl,
                decoration: InputDecoration(
                  labelText: s.isinLabel,
                  hintText: s.optional,
                ),
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 16),
            ],
            if (widget.asset.valuationMethod != ValuationMethod.eventDriven) DropdownButtonFormField<String>(
              initialValue: _selectedExchange,
              decoration: InputDecoration(
                labelText: s.stockExchange,
                isDense: true,
              ),
              items: supportedExchanges.entries
                  .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedExchange = v);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<InstrumentType>(
                    initialValue: _instrumentType,
                    decoration: InputDecoration(labelText: s.allocInstrument, isDense: true),
                    items: InstrumentType.values
                        .map((t) => DropdownMenuItem(value: t, child: Text(s.instrumentTypeLabel(t), style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                        _instrumentType = v;
                        _assetClass = defaultAssetClassFor(v);
                      });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<AssetClass>(
                    initialValue: _assetClass,
                    decoration: InputDecoration(labelText: s.allocAssetClass, isDense: true),
                    items: AssetClass.values
                        .map((c) => DropdownMenuItem(value: c, child: Text(s.assetClassLabel(c), style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _assetClass = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _terCtrl,
              decoration: InputDecoration(
                labelText: '${s.healthTer} (%)',
                // Hint formatted in the user's locale: "0,22" in it_IT,
                // "0.22" in en_US. Matches what the parser accepts.
                hintText: _fmtDouble(0.22),
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: Text(s.active),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              contentPadding: EdgeInsets.zero,
            ),
            if (_unlocked) ..._buildAdvancedFields(s),
          ],
        ),
      ),
      actions: [
        if (widget.asset.valuationMethod != ValuationMethod.eventDriven)
          TextButton(
            onPressed: () => setState(() => _searchMode = true),
            child: Text(s.search),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          onPressed: _nameCtrl.text.trim().isNotEmpty ? _save : null,
          child: Text(s.save),
        ),
      ],
    );
  }

  List<Widget> _buildAdvancedFields(AppStrings s) {
    final intermediariesAsync = widget.ref.watch(intermediariesProvider);
    final intermediaries = intermediariesAsync.value ?? const <Intermediary>[];
    return [
      const Divider(height: 24),
      DropdownButtonFormField<AssetType>(
        initialValue: _assetType,
        decoration: InputDecoration(labelText: s.assetTypeFieldLabel, isDense: true),
        items: AssetType.values
            .map((t) => DropdownMenuItem(value: t, child: Text(s.assetTypeLabel(t), style: const TextStyle(fontSize: 13))))
            .toList(),
        onChanged: (v) {
          if (v != null) setState(() => _assetType = v);
        },
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<ValuationMethod>(
        initialValue: _valuationMethod,
        decoration: InputDecoration(labelText: s.valuationMethodFieldLabel, isDense: true),
        items: ValuationMethod.values
            .map((m) => DropdownMenuItem(value: m, child: Text(s.valuationMethodLabel(m), style: const TextStyle(fontSize: 13))))
            .toList(),
        onChanged: (v) {
          if (v != null) setState(() => _valuationMethod = v);
        },
      ),
      const SizedBox(height: 12),
      if (intermediaries.isNotEmpty)
        DropdownButtonFormField<int>(
          initialValue: intermediaries.any((i) => i.id == _intermediaryId)
              ? _intermediaryId
              : intermediaries.first.id,
          decoration: InputDecoration(labelText: s.intermediary, isDense: true),
          items: intermediaries
              .map((i) => DropdownMenuItem(value: i.id, child: Text(i.name, style: const TextStyle(fontSize: 13))))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _intermediaryId = v);
          },
        ),
      const SizedBox(height: 12),
      TextField(
        controller: _currencyCtrl,
        decoration: InputDecoration(
          labelText: s.currencyFieldLabel,
          isDense: true,
          counterText: '',
        ),
        textCapitalization: TextCapitalization.characters,
        maxLength: 3,
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _taxRateCtrl,
        decoration: InputDecoration(
          labelText: s.taxRateOverrideLabel,
          // Field accepts the percentage directly to match the (%) label.
          // 26 → stored as 0.26 by _save.
          hintText: '26',
          isDense: true,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      const SizedBox(height: 8),
      SwitchListTile(
        title: Text(s.includeInNetWorthLabel),
        value: _includeInNetWorth,
        onChanged: (v) => setState(() => _includeInNetWorth = v),
        contentPadding: EdgeInsets.zero,
      ),
    ];
  }

  Widget _buildSearchDialog() {
    final s = widget.ref.read(appStringsProvider);
    return AlertDialog(
      title: Text(s.searchAssetTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: AssetSearchSection(
          widgetRef: widget.ref,
          onSelect: _selectResult,
          recoveryDefaultExchange: widget.asset.exchange ?? 'MIL',
          recoveryCacheKeyBuilder: (q) => widget.asset.isin?.isNotEmpty == true
              ? widget.asset.isin!
              : (widget.asset.ticker?.isNotEmpty == true
                  ? widget.asset.ticker!
                  : q.toUpperCase()),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _searchMode = false),
          child: Text(s.back),
        ),
      ],
    );
  }
}
