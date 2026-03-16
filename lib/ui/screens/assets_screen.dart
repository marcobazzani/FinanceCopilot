import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../database/database.dart';
import '../../services/asset_service.dart';
import '../../services/providers.dart';
import 'asset_detail_screen.dart';

final _amtFormat = NumberFormat('#,##0.00', 'it_IT');
final _qtyFormat = NumberFormat('#,##0.####', 'it_IT');

class AssetsScreen extends ConsumerWidget {
  const AssetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsAsync = ref.watch(assetsProvider);
    final statsAsync = ref.watch(assetStatsProvider);

    return Scaffold(
      body: assetsAsync.when(
        data: (assets) {
          if (assets.isEmpty) {
            return const Center(
              child: Text('No assets yet.\nImport asset events to get started.',
                  textAlign: TextAlign.center),
            );
          }

          final stats = statsAsync.valueOrNull ?? {};

          return ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: assets.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex--;
              final reordered = List<Asset>.from(assets);
              final item = reordered.removeAt(oldIndex);
              reordered.insert(newIndex, item);
              ref
                  .read(assetServiceProvider)
                  .reorder(reordered.map((a) => a.id).toList());
            },
            itemBuilder: (ctx, i) {
              final asset = assets[i] as Asset;
              final stat = stats[asset.id];

              return _AssetTile(
                key: ValueKey(asset.id),
                asset: asset,
                stats: stat,
                index: i,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AssetDetailScreen(asset: asset),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final isinCtrl = TextEditingController();
    String? resolvedName;
    String? resolvedTicker;
    bool looking = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Asset'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: isinCtrl,
                decoration: const InputDecoration(
                  labelText: 'ISIN',
                  hintText: 'e.g. IE00B4L5Y983',
                ),
                textCapitalization: TextCapitalization.characters,
                autofocus: true,
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
              else if (isinCtrl.text.trim().length == 12)
                const Text('ISIN not found — will use ISIN as name',
                    style: TextStyle(color: Colors.orange, fontSize: 13)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: isinCtrl.text.trim().length == 12 && !looking
                  ? () async {
                      final isin = isinCtrl.text.trim().toUpperCase();
                      final name = resolvedName ?? isin;
                      await ref.read(assetServiceProvider).create(
                            name: name,
                            ticker: resolvedTicker,
                            isin: isin,
                          );
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  : null,
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetTile extends StatelessWidget {
  final Asset asset;
  final AssetStats? stats;
  final int index;
  final VoidCallback onTap;

  const _AssetTile({
    super.key,
    required this.asset,
    required this.stats,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM yyyy');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Drag handle
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.drag_handle, color: Colors.grey, size: 20),
              ),
            ),
            // Asset icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: asset.isActive
                    ? theme.colorScheme.primaryContainer
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.pie_chart,
                size: 20,
                color: asset.isActive
                    ? theme.colorScheme.onPrimaryContainer
                    : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + ticker
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          asset.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: asset.isActive ? null : Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (asset.ticker != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          asset.ticker!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Stats line
                  _buildStatsLine(context, dateFormat),
                ],
              ),
            ),
            // Right side: invested value + quantity
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (stats != null && stats!.totalInvested > 0)
                  Text(
                    '${_amtFormat.format(stats!.totalInvested)} ${asset.currency}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: asset.isActive
                          ? theme.colorScheme.primary
                          : Colors.grey,
                    ),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      asset.currency,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (stats != null && stats!.totalQuantity != 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'qty ${_qtyFormat.format(stats!.totalQuantity)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
                if (!asset.isActive) ...[
                  const SizedBox(height: 2),
                  Text('Inactive',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: Colors.grey)),
                ],
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsLine(BuildContext context, DateFormat dateFormat) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: Colors.grey.shade600,
      fontSize: 12,
    );

    if (stats == null || stats!.eventCount == 0) {
      return Text('No events yet', style: style);
    }

    final parts = <InlineSpan>[];

    // Event count
    parts.add(TextSpan(
      text: '${stats!.eventCount} events',
      style: style,
    ));

    // Date range
    if (stats!.firstDate != null) {
      parts.add(TextSpan(
        text: '  ·  Since ${dateFormat.format(stats!.firstDate!)}',
        style: style,
      ));
    }
    if (stats!.lastDate != null) {
      parts.add(TextSpan(
        text: '  ·  Last ${dateFormat.format(stats!.lastDate!)}',
        style: style,
      ));
    }

    return RichText(
      text: TextSpan(children: parts),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}
