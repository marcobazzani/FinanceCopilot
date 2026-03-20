import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../database/tables.dart';
import '../../services/market_price_service.dart' show supportedExchanges;
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
    final locale = ref.watch(appLocaleProvider).valueOrNull ?? 'en_US';
    final dateFmt = fmt.shortDateFormat(locale);
    final amtFmt = fmt.currencyFormat(locale, asset.currency);
    final baseCurrency = ref.watch(baseCurrencyProvider).valueOrNull ?? 'EUR';
    final showConverted = asset.currency != baseCurrency;
    final baseFmt = fmt.currencyFormat(locale, currencySymbol(baseCurrency));
    final convertedAmounts = showConverted
        ? ref.watch(convertedEventAmountsProvider(asset.id)).valueOrNull ?? {}
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
    final isinCtrl = TextEditingController(text: asset.isin ?? '');
    String? resolvedName = asset.name;
    String? resolvedTicker = asset.ticker;
    bool looking = false;
    String selectedExchange = asset.exchange ?? 'MIL';
    var isActive = asset.isActive;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Asset'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: isinCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ISIN / Fund ID',
                    hintText: 'e.g. IE00B4L5Y983 or 0P0000CWZR',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (v) async {
                    final isin = v.trim().toUpperCase();
                    if (isin.length == 12) {
                      setDialogState(() => looking = true);
                      final result = await ref.read(isinLookupServiceProvider).lookup(isin);
                      if (ctx.mounted) {
                        setDialogState(() {
                          resolvedName = result.name;
                          resolvedTicker = result.ticker;
                          looking = false;
                        });
                      }
                    } else {
                      setDialogState(() {
                        resolvedName = null;
                        resolvedTicker = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (looking)
                  const Row(children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Looking up ISIN...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ])
                else if (resolvedName != null || resolvedTicker != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (resolvedName != null)
                        Text(resolvedName!, style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (resolvedTicker != null)
                        Text('Ticker: $resolvedTicker', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  )
                else if (isinCtrl.text.trim().length >= 4 && isinCtrl.text.trim().length != 12)
                  const Text('Non-standard ID — will use as identifier',
                      style: TextStyle(color: Colors.orange, fontSize: 13))
                else if (isinCtrl.text.trim().length == 12)
                  const Text('ISIN not found — will keep current name',
                      style: TextStyle(color: Colors.orange, fontSize: 13)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedExchange,
                  decoration: const InputDecoration(
                    labelText: 'Stock Exchange',
                    isDense: true,
                  ),
                  items: supportedExchanges.entries
                      .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedExchange = v);
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (v) => setDialogState(() => isActive = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: isinCtrl.text.trim().length >= 4 && !looking
                  ? () async {
                      final isin = isinCtrl.text.trim().toUpperCase();
                      final name = resolvedName ?? asset.name;
                      _log.info('saving asset id=${asset.id}, isin=$isin');
                      await ref.read(assetServiceProvider).update(
                        asset.id,
                        AssetsCompanion(
                          name: Value(name),
                          ticker: Value(resolvedTicker),
                          isin: Value(isin),
                          exchange: Value(selectedExchange),
                          isActive: Value(isActive),
                          updatedAt: Value(DateTime.now()),
                        ),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  : null,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmWipeEvents(BuildContext context, WidgetRef ref) async {
    final evCount = ref.read(assetEventsProvider(asset.id)).valueOrNull?.length ?? 0;
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
