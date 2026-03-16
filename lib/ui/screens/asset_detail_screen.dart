import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../database/database.dart';
import '../../database/tables.dart';
import '../../services/providers.dart';
import '../../utils/logger.dart';
import 'asset_event_edit_screen.dart';

final _log = getLogger('AssetDetailScreen');

/// Shows events for a single asset, with summary card + event list + edit.
class AssetDetailScreen extends ConsumerWidget {
  final Asset asset;
  const AssetDetailScreen({super.key, required this.asset});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsStream = ref.watch(assetEventsProvider(asset.id));
    final dateFmt = DateFormat('dd/MM/yyyy');
    final amtFmt = NumberFormat.currency(locale: 'it_IT', symbol: asset.currency);

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
                      trailing: Text(
                        amtFmt.format(ev.amount),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: ev.amount >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                        ),
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
    final nameCtrl = TextEditingController(text: asset.name);
    final tickerCtrl = TextEditingController(text: asset.ticker ?? '');
    final isinCtrl = TextEditingController(text: asset.isin ?? '');
    final taxRateCtrl = TextEditingController(text: asset.taxRate?.toString() ?? '');
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
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 8),
                TextField(controller: tickerCtrl, decoration: const InputDecoration(labelText: 'Ticker')),
                const SizedBox(height: 8),
                TextField(
                  controller: isinCtrl,
                  decoration: const InputDecoration(labelText: 'ISIN'),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: taxRateCtrl,
                  decoration: const InputDecoration(labelText: 'Tax Rate (e.g. 0.26)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                _log.info('saving asset id=${asset.id}, name=${nameCtrl.text.trim()}');
                await ref.read(assetServiceProvider).update(
                  asset.id,
                  AssetsCompanion(
                    name: Value(nameCtrl.text.trim()),
                    ticker: Value(tickerCtrl.text.isNotEmpty ? tickerCtrl.text.trim() : null),
                    isin: Value(isinCtrl.text.isNotEmpty ? isinCtrl.text.trim().toUpperCase() : null),
                    taxRate: Value(taxRateCtrl.text.isNotEmpty ? double.tryParse(taxRateCtrl.text) : null),
                    isActive: Value(isActive),
                    updatedAt: Value(DateTime.now()),
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
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
