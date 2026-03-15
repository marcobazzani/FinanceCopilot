import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database.dart';
import '../../database/tables.dart';
import '../../services/providers.dart';
import 'asset_detail_screen.dart';

class AssetsScreen extends ConsumerWidget {
  const AssetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsAsync = ref.watch(assetsProvider);

    return Scaffold(
      body: assetsAsync.when(
        data: (assets) {
          if (assets.isEmpty) {
            return const Center(child: Text('No assets yet.\nImport asset events to get started.', textAlign: TextAlign.center));
          }
          return ListView.builder(
            itemCount: assets.length,
            itemBuilder: (ctx, i) {
              final asset = assets[i] as Asset;
              return ListTile(
                leading: Icon(_iconForType(asset.assetType)),
                title: Text(asset.name),
                subtitle: Text([
                  asset.assetType.name,
                  if (asset.ticker != null) asset.ticker!,
                  asset.currency,
                ].join(' · ')),
                trailing: const Icon(Icons.chevron_right),
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

  IconData _iconForType(AssetType type) {
    return switch (type) {
      AssetType.stockEtf || AssetType.bondEtf || AssetType.commEtf || AssetType.goldEtc || AssetType.monEtf => Icons.pie_chart,
      AssetType.stock => Icons.show_chart,
      AssetType.crypto => Icons.currency_bitcoin,
      AssetType.pension => Icons.elderly,
      AssetType.deposit => Icons.savings,
      AssetType.realEstate => Icons.home,
      AssetType.liability => Icons.credit_card,
      AssetType.cash => Icons.account_balance_wallet,
      AssetType.alternative => Icons.category,
    };
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    var selectedType = AssetType.stockEtf;
    var selectedValuation = ValuationMethod.marketPrice;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Asset'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. iShares MSCI World'),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<AssetType>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: AssetType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedType = v!),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<ValuationMethod>(
                value: selectedValuation,
                decoration: const InputDecoration(labelText: 'Valuation'),
                items: ValuationMethod.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedValuation = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await ref.read(assetServiceProvider).create(
                      name: nameCtrl.text.trim(),
                      assetType: selectedType,
                      valuationMethod: selectedValuation,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}
