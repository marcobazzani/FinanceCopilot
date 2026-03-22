import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../database/tables.dart';
import '../../services/investing_com_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/market_price_service.dart' show investingExchangeToCode, supportedExchanges;
import '../../services/providers.dart';
import '../../utils/formatters.dart' as fmt;
import '../../utils/logger.dart';
import 'asset_event_edit_screen.dart';
import 'dashboard_screen.dart' show currencySymbol;

final _log = getLogger('AssetDetailScreen');

/// Shows events for a single asset, with summary card + event list + edit.
class AssetDetailScreen extends ConsumerWidget {
  final Asset asset;
  const AssetDetailScreen({super.key, required this.asset});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsStream = ref.watch(assetEventsProvider(asset.id));
    final locale = ref.watch(appLocaleProvider).value ?? 'en_US';
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
            tooltip: 'Edit Asset',
            onPressed: () => _editAsset(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Wipe Events',
            onPressed: () => _confirmWipeEvents(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Delete Asset',
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
                      child: Text('ISIN: ${asset.isin}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                  if (asset.taxRate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Tax rate: ${(asset.taxRate! * 100).toStringAsFixed(1)}%',
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
                const Text('Events', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                eventsStream.when(
                  data: (events) => Text('${events.length} events', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
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
                  return const Center(
                    child: Text('No events yet.\nImport or add events manually.',
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  );
                }
                return ListView.separated(
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
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
                            amtFmt.format(ev.amount),
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
              error: (e, _) => Center(child: Text('Error: $e')),
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
      EventType.buy || EventType.contribute => Colors.blue,
      EventType.sell => Colors.orange,
      EventType.dividend || EventType.interest => Colors.green,
      EventType.split || EventType.vest => Colors.purple,
      EventType.revalue => Colors.teal,
      EventType.transferIn => Colors.indigo,
      EventType.transferOut => Colors.brown,
    };
  }

  Future<void> _editAsset(BuildContext context, WidgetRef ref) async {
    await showDialog(
      context: context,
      builder: (ctx) => _EditAssetDialog(ref: ref, asset: asset),
    );
  }

  Future<void> _confirmWipeEvents(BuildContext context, WidgetRef ref) async {
    final evCount = ref.read(assetEventsProvider(asset.id)).value?.length ?? 0;
    if (evCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No events to wipe.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wipe All Events?'),
        content: Text(
          'This will delete all $evCount events from "${asset.name}" '
          'but keep the asset itself.\n\nThis cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Wipe'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _log.warning('wiping events for asset ${asset.id}');
      final deleted = await ref.read(assetEventServiceProvider).deleteByAsset(asset.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Wiped $deleted events.')),
        );
      }
    }
  }

  Future<void> _confirmDeleteAsset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Asset?'),
        content: Text('Delete "${asset.name}" and all its events?\nThis cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
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
    const typeLabels = {
      'assetclass': 'Asset Class',
      'country': 'Geographic',
      'sector': 'Sector',
      'holding': 'Top Holdings',
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
        title: const Text('Composition', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                        'Source: $sourceLabel',
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
  late String _selectedExchange;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.asset.name);
    _tickerCtrl = TextEditingController(text: widget.asset.ticker ?? '');
    _isinCtrl = TextEditingController(text: widget.asset.isin ?? '');
    _selectedExchange = widget.asset.exchange ?? 'MIL';
    _isActive = widget.asset.isActive;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _tickerCtrl.dispose();
    _isinCtrl.dispose();
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
    _log.info('saving asset id=${widget.asset.id}, name=$name');
    await widget.ref.read(assetServiceProvider).update(
      widget.asset.id,
      AssetsCompanion(
        name: Value(name),
        ticker: Value(ticker.isNotEmpty ? ticker : null),
        isin: Value(isin.isNotEmpty ? isin : null),
        exchange: Value(_selectedExchange),
        isActive: Value(_isActive),
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
    return AlertDialog(
      title: const Text('Edit Asset'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tickerCtrl,
              decoration: const InputDecoration(
                labelText: 'Ticker',
                hintText: 'e.g. SWDA',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _isinCtrl,
              decoration: const InputDecoration(
                labelText: 'Identifier (ISIN, fund ID, etc.)',
                hintText: 'Optional',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedExchange,
              decoration: const InputDecoration(
                labelText: 'Stock Exchange',
                isDense: true,
              ),
              items: supportedExchanges.entries
                  .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedExchange = v);
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Active'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() {
            _searchCtrl.clear();
            _results = [];
            _searchMode = true;
          }),
          child: const Text('Search'),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _nameCtrl.text.trim().isNotEmpty ? _save : null,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildSearchDialog() {
    return AlertDialog(
      title: const Text('Search Asset'),
      content: SizedBox(
        width: 400,
        height: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                labelText: 'Search',
                hintText: 'Name, ISIN, ticker, or fund ID',
                prefixIcon: Icon(Icons.search),
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
                  separatorBuilder: (_, __) => const Divider(height: 1),
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
              const Expanded(
                child: Center(
                  child: Text('No results found', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              const Expanded(
                child: Center(
                  child: Text('Type at least 3 characters', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _searchMode = false),
          child: const Text('Back'),
        ),
      ],
    );
  }
}
