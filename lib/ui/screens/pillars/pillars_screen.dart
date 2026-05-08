import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../database/database.dart';
import '../../../services/providers/providers.dart';
import '../../widgets/global_app_bar_actions.dart';
import '../../widgets/privacy_text.dart';
import '../../../utils/formatters.dart' as fmt;
import 'pillar_create_dialog.dart';
import 'pillar_detail_screen.dart';

class PillarsScreen extends ConsumerWidget {
  const PillarsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final pillarsAsync = ref.watch(pillarsProvider);
    final assignmentsAsync = ref.watch(pillarAssetsProvider);
    final marketValues = ref.watch(assetMarketValuesProvider).value ?? {};
    final unassignedFracs = ref.watch(unassignedFractionProvider).value ?? {};
    final baseCurrency = ref.watch(baseCurrencyProvider).value ?? 'EUR';
    final locale = ref.watch(appLocaleProvider).value ?? 'en';

    return Scaffold(
      appBar: AppBar(
        title: Text(s.pillarsTitle),
        actions: globalAppBarActions(context, ref),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: s.pillarCreateTitle,
        onPressed: () => _openCreateDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: pillarsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (pillars) {
          final assignments = assignmentsAsync.value ?? const [];

          double valueOfPillar(String id) {
            double total = 0;
            for (final a in assignments.where((x) => x.pillarId == id)) {
              final mv = marketValues[a.assetId] ?? 0;
              final qty = a.quantity;
              // marketValues is full asset value; scale by share of total qty.
              // We don't know the asset's totalQty here without an extra read,
              // so derive ratio = stored qty / sum(all assignments + unassigned share).
              final ratio = _ratio(a.assetId, qty, assignments, unassignedFracs);
              total += mv * ratio;
            }
            return total;
          }

          double valueOfUnassigned() {
            double total = 0;
            unassignedFracs.forEach((assetId, frac) {
              final mv = marketValues[assetId] ?? 0;
              total += mv * frac;
            });
            return total;
          }

          int assetCount(String id) =>
              assignments.where((x) => x.pillarId == id).length;

          if (pillars.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.view_quilt_outlined, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text(s.pillarsEmptyTitle, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: Text(s.pillarsEmptyCta),
                      onPressed: () => _openCreateDialog(context, ref),
                    ),
                  ],
                ),
              ),
            );
          }

          final unassignedValue = valueOfUnassigned();

          return ListView(
            padding: const EdgeInsets.all(8),
            children: [
              for (final p in pillars)
                _PillarCard(
                  pillar: p,
                  value: valueOfPillar(p.id),
                  assetCount: assetCount(p.id),
                  baseCurrency: baseCurrency,
                  locale: locale,
                ),
              if (unassignedValue > 0)
                _UnassignedCard(
                  value: unassignedValue,
                  assetCount: unassignedFracs.values.where((f) => f > 0).length,
                  baseCurrency: baseCurrency,
                  locale: locale,
                ),
            ],
          );
        },
      ),
    );
  }

  double _ratio(
    int assetId,
    double storedQty,
    List<PillarAsset> all,
    Map<int, double> unassignedFracs,
  ) {
    // ratio = storedQty / totalQty, but we don't have totalQty directly here;
    // use: totalAssigned + unassignedFrac * totalQty = totalQty
    // → totalQty = totalAssigned / (1 - unassignedFrac)
    // when unassignedFrac < 1; otherwise we just return 0.
    final totalAssigned = all
        .where((x) => x.assetId == assetId)
        .fold<double>(0, (acc, x) => acc + x.quantity);
    final unassignedFrac = unassignedFracs[assetId] ?? 0;
    if (totalAssigned <= 0) return 0;
    if (unassignedFrac >= 1) return 0;
    final totalQty = totalAssigned / (1 - unassignedFrac);
    return totalQty <= 0 ? 0 : storedQty / totalQty;
  }

  Future<void> _openCreateDialog(BuildContext context, WidgetRef ref) async {
    await showDialog(
      context: context,
      builder: (_) => const PillarCreateDialog(),
    );
  }
}

class _PillarCard extends ConsumerWidget {
  final Pillar pillar;
  final double value;
  final int assetCount;
  final String baseCurrency;
  final String locale;

  const _PillarCard({
    required this.pillar,
    required this.value,
    required this.assetCount,
    required this.baseCurrency,
    required this.locale,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final fmtCur = NumberFormat.simpleCurrency(locale: locale, name: baseCurrency);
    final progress = (pillar.targetValue != null && pillar.targetValue! > 0)
        ? (value / pillar.targetValue!).clamp(0.0, 1.0)
        : null;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.view_quilt_outlined, size: 28),
        title: Text(pillar.name, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            PrivacyText('${fmt.amountFormat(locale).format(value)} $baseCurrency · ${s.pillarAssetCount(assetCount)}'),
            if (pillar.targetValue != null && pillar.targetValue! > 0) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 4),
              PrivacyText(
                '${(progress! * 100).toStringAsFixed(0)}% · ${s.pillarTarget(fmtCur.format(pillar.targetValue))}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PillarDetailScreen(pillarId: pillar.id),
          ));
        },
      ),
    );
  }
}

class _UnassignedCard extends ConsumerWidget {
  final double value;
  final int assetCount;
  final String baseCurrency;
  final String locale;
  const _UnassignedCard({
    required this.value,
    required this.assetCount,
    required this.baseCurrency,
    required this.locale,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: const Icon(Icons.help_outline, size: 28),
        title: Text(s.pillarUnassigned),
        subtitle: PrivacyText('${fmt.amountFormat(locale).format(value)} $baseCurrency · ${s.pillarAssetCount(assetCount)}'),
      ),
    );
  }
}
