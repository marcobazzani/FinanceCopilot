import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../database/database.dart';
import '../../../database/tables.dart';
import '../../../l10n/app_strings.dart';
import 'package:finance_copilot/services/pillars/pillar_performance.dart';
import 'package:finance_copilot/services/portfolio/portfolio_rebalance_service.dart';
import '../../../services/providers/providers.dart';
import '../../widgets/global_app_bar_actions.dart';
import '../../widgets/privacy_text.dart';
import '../../../utils/formatters.dart' as fmt;
import 'pillar_create_dialog.dart';
import 'pillar_detail_screen.dart';
import 'portfolio_model_dialog.dart';
import 'rebalance_preview_dialog.dart';

class PillarsScreen extends ConsumerStatefulWidget {
  const PillarsScreen({super.key});

  @override
  ConsumerState<PillarsScreen> createState() => _PillarsScreenState();
}

class _PillarsScreenState extends ConsumerState<PillarsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) setState(() {});
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final pillarsAsync = ref.watch(pillarsProvider);
    final assignmentsAsync = ref.watch(pillarAssetsProvider);
    final performanceAsync = ref.watch(pillarPerformanceSnapshotsProvider);
    final unassignedFracs = ref.watch(unassignedFractionProvider).value ?? {};
    final baseCurrency = ref.watch(baseCurrencyProvider).value ?? 'EUR';
    final locale = ref.watch(appLocaleProvider).value ?? 'en';

    return Scaffold(
      appBar: AppBar(
        title: Text(s.pillarsTitle),
        actions: globalAppBarActions(
          context,
          ref,
          local: _tabController.index == 0
              ? [
                  _RebalanceToolbarMenu(
                    pillarsAsync: pillarsAsync,
                    onSelected: (choice) async {
                      final fallbackPillarId = pillarsAsync.value?.isNotEmpty == true ? pillarsAsync.value!.first.id : null;
                      await showDialog(
                        context: context,
                        builder: (_) => RebalancePreviewDialog(
                          pillarId: choice.pillarId ?? fallbackPillarId!,
                          initialScopeKind: choice.scopeKind,
                        ),
                      );
                    },
                  ),
                ]
              : const [],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: s.pillarTabPillars),
            Tab(text: s.pillarTabPortfolioModels),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: _tabController.index == 0 ? s.pillarCreateTitle : s.portfolioModelCreateTitle,
        onPressed: () => _tabController.index == 0 ? _openCreateDialog(context, ref) : _openModelDialog(context),
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          pillarsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (pillars) {
              final assignments = assignmentsAsync.value ?? const [];
              final performanceByPillar = performanceAsync.value ?? const <String, PillarPerformanceSnapshot>{};

              double valueOfUnassigned() {
                final marketValues = ref.watch(assetMarketValuesProvider).value ?? {};
                double total = 0;
                unassignedFracs.forEach((assetId, frac) {
                  final mv = marketValues[assetId] ?? 0;
                  total += mv * frac;
                });
                return total;
              }

              int assetCount(String id) => assignments.where((x) => x.pillarId == id).length;

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
                      performance: performanceByPillar[p.id],
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
          const _PortfolioModelsTab(),
        ],
      ),
    );
  }

  Future<void> _openCreateDialog(BuildContext context, WidgetRef ref) async {
    await showDialog(
      context: context,
      builder: (_) => const PillarCreateDialog(),
    );
  }

  Future<void> _openModelDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => const PortfolioModelDialog(),
    );
  }
}

class _PillarCard extends ConsumerWidget {
  final Pillar pillar;
  final PillarPerformanceSnapshot? performance;
  final int assetCount;
  final String baseCurrency;
  final String locale;

  const _PillarCard({
    required this.pillar,
    required this.performance,
    required this.assetCount,
    required this.baseCurrency,
    required this.locale,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final value = performance?.marketValue ?? 0;
    final fmtCur = NumberFormat.simpleCurrency(locale: locale, name: baseCurrency);
    final progress = (pillar.targetValue != null && pillar.targetValue! > 0) ? (value / pillar.targetValue!).clamp(0.0, 1.0) : null;
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
            const SizedBox(height: 4),
            PrivacyText(
              _pillarPerformanceSummary(
                s: s,
                locale: locale,
                baseCurrency: baseCurrency,
                snapshot: performance,
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PillarDetailScreen(pillarId: pillar.id),
            ),
          );
        },
      ),
    );
  }
}

String _pillarPerformanceSummary({
  required AppStrings s,
  required String locale,
  required String baseCurrency,
  required PillarPerformanceSnapshot? snapshot,
}) {
  if (snapshot == null) {
    return '${s.pillarAbsoluteReturnShort} — · ${s.pillarTwrrShort} — · ${s.pillarCagrShort} —';
  }
  final amountFormat = fmt.amountFormat(locale);
  final percentFormat = NumberFormat.percentPattern(locale)
    ..minimumFractionDigits = 1
    ..maximumFractionDigits = 1;
  final absAmount = (snapshot.marketValue == 0 && snapshot.netInvested == 0)
      ? '—'
      : '${amountFormat.format(snapshot.absoluteReturnAmount)} $baseCurrency';
  final absPct = snapshot.absoluteReturnPct == null ? '—' : percentFormat.format(snapshot.absoluteReturnPct);
  final twrr = snapshot.twrr == null ? '—' : percentFormat.format(snapshot.twrr);
  final cagr = snapshot.cagr == null ? '—' : percentFormat.format(snapshot.cagr);
  return '${s.pillarAbsoluteReturnShort} $absAmount ($absPct) · '
      '${s.pillarTwrrShort} $twrr · '
      '${s.pillarCagrShort} $cagr';
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

class _RebalanceChoice {
  final String? pillarId;
  final PortfolioRebalanceScopeKind scopeKind;

  const _RebalanceChoice.current(this.pillarId) : scopeKind = PortfolioRebalanceScopeKind.currentPillar;
  const _RebalanceChoice.all() : pillarId = null, scopeKind = PortfolioRebalanceScopeKind.allAssociatedPillars;
}

class _RebalanceToolbarMenu extends ConsumerWidget {
  final AsyncValue<List<Pillar>> pillarsAsync;
  final ValueChanged<_RebalanceChoice> onSelected;

  const _RebalanceToolbarMenu({
    required this.pillarsAsync,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final pillars = pillarsAsync.value ?? const <Pillar>[];
    if (pillars.isEmpty) {
      return IconButton(
        tooltip: s.rebalance,
        icon: const Icon(Icons.balance),
        onPressed: null,
      );
    }
    return PopupMenuButton<_RebalanceChoice>(
      tooltip: s.rebalance,
      icon: const Icon(Icons.balance),
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem<_RebalanceChoice>(
          value: const _RebalanceChoice.all(),
          child: Text(s.rebalanceScopeAll),
        ),
        const PopupMenuDivider(),
        for (final pillar in pillars)
          PopupMenuItem<_RebalanceChoice>(
            value: _RebalanceChoice.current(pillar.id),
            child: Text(pillar.name),
          ),
      ],
    );
  }
}

class _PortfolioModelsTab extends ConsumerWidget {
  const _PortfolioModelsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final modelsAsync = ref.watch(portfolioModelsProvider);
    return modelsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(s.error(e))),
      data: (models) {
        if (models.isEmpty) {
          return Center(child: Text(s.portfolioModelsEmpty));
        }
        final builtIn = models.where((m) => m.isBuiltIn).toList();
        final custom = models.where((m) => !m.isBuiltIn).toList();
        final builtInYears = builtIn.map((m) => m.year ?? 0).toSet().toList()..sort();
        return ListView(
          padding: const EdgeInsets.all(8),
          children: [
            if (builtIn.isNotEmpty) ...[
              _SectionHeader(label: s.portfolioModelsBuiltIn),
              for (final year in builtInYears)
                _BuiltInYearGroup(
                  s: s,
                  year: year,
                  models: builtIn.where((m) => (m.year ?? 0) == year).toList(),
                ),
            ],
            if (custom.isNotEmpty) ...[
              _SectionHeader(label: s.portfolioModelsCustom),
              for (final model in custom) _PortfolioModelCard(model: model),
            ],
          ],
        );
      },
    );
  }
}

class _BuiltInYearGroup extends StatelessWidget {
  final AppStrings s;
  final int year;
  final List<PortfolioModel> models;

  const _BuiltInYearGroup({
    required this.s,
    required this.year,
    required this.models,
  });

  @override
  Widget build(BuildContext context) {
    final variants = [PortfolioModelVariant.mini, PortfolioModelVariant.full];
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      childrenPadding: const EdgeInsets.only(left: 8),
      title: Text('$year'),
      children: [
        for (final variant in variants)
          _BuiltInVariantGroup(
            s: s,
            variant: variant,
            models: models.where((m) => m.variant == variant).toList()..sort((a, b) => (a.equityPercent ?? 0).compareTo(b.equityPercent ?? 0)),
          ),
      ],
    );
  }
}

class _BuiltInVariantGroup extends StatelessWidget {
  final AppStrings s;
  final PortfolioModelVariant variant;
  final List<PortfolioModel> models;

  const _BuiltInVariantGroup({
    required this.s,
    required this.variant,
    required this.models,
  });

  @override
  Widget build(BuildContext context) {
    if (models.isEmpty) return const SizedBox.shrink();
    final title = switch (variant) {
      PortfolioModelVariant.full => s.portfolioModelFull,
      PortfolioModelVariant.mini => s.portfolioModelMini,
      PortfolioModelVariant.custom => s.portfolioModelCustom,
    };
    final equityGroups = <int, List<PortfolioModel>>{};
    for (final model in models) {
      equityGroups.putIfAbsent(model.equityPercent ?? 0, () => []).add(model);
    }
    final equities = equityGroups.keys.toList()..sort();
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding: const EdgeInsets.only(left: 8),
        title: Text(title),
        children: [
          for (final equity in equities)
            _BuiltInEquityGroup(
              equityPercent: equity,
              models: equityGroups[equity]!..sort((a, b) => a.name.compareTo(b.name)),
            ),
        ],
      ),
    );
  }
}

class _BuiltInEquityGroup extends StatelessWidget {
  final int equityPercent;
  final List<PortfolioModel> models;

  const _BuiltInEquityGroup({
    required this.equityPercent,
    required this.models,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding: const EdgeInsets.only(left: 8),
        title: Text('$equityPercent%'),
        children: [
          for (final model in models) _BuiltInModelTile(model: model),
        ],
      ),
    );
  }
}

class _BuiltInModelTile extends ConsumerWidget {
  final PortfolioModel model;

  const _BuiltInModelTile({required this.model});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final itemsAsync = ref.watch(portfolioModelItemsProvider(model.id));
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.only(left: 16, bottom: 8),
      leading: const Icon(Icons.inventory_2_outlined),
      title: Text(model.name),
      subtitle: Text(_subtitle(s, model)),
      children: itemsAsync.when(
        loading: () => const [
          Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          ),
        ],
        error: (e, _) => [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(s.error(e)),
          ),
        ],
        data: (items) => [
          for (final item in items)
            ListTile(
              dense: true,
              title: Text(item.isin),
              subtitle: Text(item.description),
              trailing: Text('${item.targetWeight.toStringAsFixed(2)}%'),
            ),
        ],
      ),
    );
  }

  String _subtitle(AppStrings s, PortfolioModel model) {
    final parts = <String>[];
    if (model.year != null) parts.add(s.portfolioModelYear(model.year!));
    if (model.equityPercent != null) {
      parts.add(s.portfolioModelEquity(model.equityPercent!));
    }
    parts.add(switch (model.variant) {
      PortfolioModelVariant.full => s.portfolioModelFull,
      PortfolioModelVariant.mini => s.portfolioModelMini,
      PortfolioModelVariant.custom => s.portfolioModelCustom,
    });
    return parts.join(' · ');
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
      child: Text(label, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _PortfolioModelCard extends ConsumerWidget {
  final PortfolioModel model;

  const _PortfolioModelCard({required this.model});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final itemsAsync = ref.watch(portfolioModelItemsProvider(model.id));
    return Card(
      child: ExpansionTile(
        leading: Icon(model.isBuiltIn ? Icons.inventory_2_outlined : Icons.tune),
        title: Text(model.name),
        subtitle: Text(_subtitle(s, model)),
        trailing: model.isBuiltIn
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: s.edit,
                    icon: const Icon(Icons.edit),
                    onPressed: () => _edit(context, ref),
                  ),
                  IconButton(
                    tooltip: s.delete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(context, ref),
                  ),
                ],
              ),
        children: itemsAsync.when(
          loading: () => const [
            Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
          ],
          error: (e, _) => [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(s.error(e)),
            ),
          ],
          data: (items) => [
            for (final item in items)
              ListTile(
                dense: true,
                title: Text(item.isin),
                subtitle: Text(item.description),
                trailing: Text('${item.targetWeight.toStringAsFixed(2)}%'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final items = await ref.read(portfolioModelServiceProvider).getItems(model.id);
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (_) => PortfolioModelDialog(existing: model, existingItems: items),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final s = ref.read(appStringsProvider);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.delete),
        content: Text(s.portfolioModelDeleteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.delete)),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(portfolioModelServiceProvider).deleteCustomModel(model.id);
    }
  }

  String _subtitle(AppStrings s, PortfolioModel model) {
    final parts = <String>[];
    if (model.year != null) parts.add(s.portfolioModelYear(model.year!));
    if (model.equityPercent != null) {
      parts.add(s.portfolioModelEquity(model.equityPercent!));
    }
    parts.add(switch (model.variant) {
      PortfolioModelVariant.full => s.portfolioModelFull,
      PortfolioModelVariant.mini => s.portfolioModelMini,
      PortfolioModelVariant.custom => s.portfolioModelCustom,
    });
    return parts.join(' · ');
  }
}
