import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../database/tables.dart';
import '../../services/investing_com_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/market_price_service.dart' show investingExchangeToCode, supportedExchanges;
import '../../services/providers/providers.dart';
import '../../utils/formatters.dart' as fmt;
import '../../utils/logger.dart';
import 'asset_event_edit_screen.dart';
import 'dashboard/dashboard_screen.dart' show currencySymbol;

final _log = getLogger('AssetDetailScreen');

/// Shows events for a single asset, with summary card + event list + edit.
class AssetDetailScreen extends ConsumerWidget {
  final Asset asset;
  const AssetDetailScreen({super.key, required this.asset});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    return ListTile(
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
                      subtitle: Text(dateFmt.format(ev.date), style: const TextStyle(fontSize: 12)),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AssetEventEditScreen(asset: asset)),
        ),
        child: const Icon(Icons.add),
      ),
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
    await showDialog(
      context: context,
      builder: (ctx) => _EditAssetDialog(ref: ref, asset: asset),
    );
  }

  Future<void> _confirmWipeEvents(BuildContext context, WidgetRef ref) async {
    final s = ref.read(appStringsProvider);
    final evCount = ref.read(assetEventsProvider(asset.id)).value?.length ?? 0;
    if (evCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.noEventsToWipe)),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.wipeAllEventsTitle),
        content: Text(
          '${s.wipeEventsBody(evCount, asset.name)}${s.cannotBeUndone}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.wipe),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _log.warning('wiping events for asset ${asset.id}');
      final deleted = await ref.read(assetEventServiceProvider).deleteByAsset(asset.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.wipedEvents(deleted))),
        );
      }
    }
  }

  Future<void> _confirmDeleteAsset(BuildContext context, WidgetRef ref) async {
    final s = ref.read(appStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteAssetTitle),
        content: Text(s.deleteAssetConfirm(asset.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _log.warning('deleting asset id=${asset.id}, name=${asset.name}');
      await ref.read(assetEventServiceProvider).deleteByAsset(asset.id);
      await ref.read(assetServiceProvider).delete(asset.id);
      if (context.mounted) Navigator.pop(context);
    }
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
    final entries = compositionsAsync.value?[assetId];
    if (entries == null || entries.isEmpty) return const SizedBox.shrink();

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

    if (byType.isEmpty) return const SizedBox.shrink();

    // Sort each group by weight descending
    for (final list in byType.values) {
      list.sort((a, b) => b.weight.compareTo(a.weight));
    }

    // Display order and labels
    final ss = ref.watch(appStringsProvider);
    final typeLabels = {
      'assetclass': ss.compositionAssetClass,
      'country': ss.compositionGeographic,
      'sector': ss.compositionSector,
      'holding': ss.compositionTopHoldings,
    };
    const typeOrder = ['assetclass', 'country', 'sector', 'holding'];

    // Derive source label from URL
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
        title: Text(ref.watch(appStringsProvider).composition, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        initiallyExpanded: false,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          for (final type in typeOrder)
            if (byType.containsKey(type)) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  typeLabels[type] ?? type,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
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
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
          // Source link
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
                      Icon(Icons.open_in_new, size: 14, color: Theme.of(context).colorScheme.primary),
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
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<InvestingSearchResult> _results = [];
  bool _searching = false;
  bool _searchMode = false;

  // Edit fields (pre-populated from asset)
  late final TextEditingController _nameCtrl;
  late final TextEditingController _tickerCtrl;
  late final TextEditingController _isinCtrl;
  late final TextEditingController _terCtrl;
  late String _selectedExchange;
  late bool _isActive;
  late InstrumentType _instrumentType;
  late AssetClass _assetClass;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.asset.name);
    _tickerCtrl = TextEditingController(text: widget.asset.ticker ?? '');
    _isinCtrl = TextEditingController(text: widget.asset.isin ?? '');
    _terCtrl = TextEditingController(text: widget.asset.ter?.toString() ?? '');
    _selectedExchange = widget.asset.exchange ?? 'MIL';
    _isActive = widget.asset.isActive;
    _instrumentType = widget.asset.instrumentType;
    _assetClass = widget.asset.assetClass;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _tickerCtrl.dispose();
    _isinCtrl.dispose();
    _terCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final service = widget.ref.read(marketPriceServiceProvider) as InvestingComService;
      try {
        final results = await service.search(query.trim());
        if (mounted && _searchCtrl.text.trim() == query.trim()) {
          setState(() {
            _results = results;
            _searching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _searching = false);
      }
    });
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
    final ter = double.tryParse(_terCtrl.text.trim());
    _log.info('saving asset id=${widget.asset.id}, name=$name');
    await widget.ref.read(assetServiceProvider).update(
      widget.asset.id,
      AssetsCompanion(
        name: Value(name),
        ticker: Value(ticker.isNotEmpty ? ticker : null),
        isin: Value(isin.isNotEmpty ? isin : null),
        exchange: Value(_selectedExchange),
        isActive: Value(_isActive),
        instrumentType: Value(_instrumentType),
        assetClass: Value(_assetClass),
        ter: Value(ter),
        updatedAt: Value(DateTime.now()),
      ),
    );
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
      title: Text(s.editAssetTitle),
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
                hintText: '0.22',
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
          ],
        ),
      ),
      actions: [
        if (widget.asset.valuationMethod != ValuationMethod.eventDriven)
          TextButton(
            onPressed: () => setState(() {
              _searchCtrl.clear();
              _results = [];
              _searchMode = true;
            }),
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

  Widget _buildSearchDialog() {
    final s = widget.ref.read(appStringsProvider);
    return AlertDialog(
      title: Text(s.searchAssetTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SizedBox(
          height: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  labelText: s.search,
                  hintText: s.searchAssetsHint,
                  prefixIcon: const Icon(Icons.search),
                ),
                autofocus: true,
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 12),
              if (_searching)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_results.isNotEmpty)
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final r = _results[i];
                      return ListTile(
                        dense: true,
                        title: Text(r.description, overflow: TextOverflow.ellipsis, maxLines: 1),
                        subtitle: Text(
                          '${r.symbol}  ·  ${r.type}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: Text(r.flag, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        onTap: () => _selectResult(r),
                      );
                    },
                  ),
                )
              else if (_searchCtrl.text.trim().length >= 3)
                Expanded(
                  child: Center(
                    child: Text(s.noResultsFound, style: const TextStyle(color: Colors.grey)),
                  ),
                )
              else
                Expanded(
                  child: Center(
                    child: Text(s.typeAtLeast3Chars, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                ),
            ],
          ),
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
