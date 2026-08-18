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
    _tabController = TabController(length: 3, vsync: this)
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
    final standardAsync = ref.watch(standardPillarsProvider);
    final virtualAsync = ref.watch(virtualPortfoliosProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.pillarsTitle),
        actions: globalAppBarActions(
          context,
          ref,
          local: _tabController.index == 0 ? [_rebalanceAction(context, s, standardAsync)] : const [],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: s.pillarTabPillars),
            Tab(text: s.pillarTabVirtualPortfolios),
            Tab(text: s.pillarTabPortfolioModels),
          ],
        ),
      ),
      floatingActionButton: switch (_tabController.index) {
        0 => FloatingActionButton(
          tooltip: s.pillarCreateTitle,
          onPressed: () => _openCreateDialog(context, PillarKind.standard),
          child: const Icon(Icons.add),
        ),
        1 => FloatingActionButton(
          tooltip: s.virtualPortfolioCreateTitle,
          onPressed: () => _openCreateDialog(context, PillarKind.virtual),
          child: const Icon(Icons.add),
        ),
        _ => FloatingActionButton(
          tooltip: s.portfolioModelCreateTitle,
          onPressed: () => _openModelDialog(context),
          child: const Icon(Icons.add),
        ),
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          _PillarList(pillarsAsync: standardAsync, kind: PillarKind.standard),
          _PillarList(pillarsAsync: virtualAsync, kind: PillarKind.virtual),
          const _PortfolioModelsTab(),
        ],
      ),
    );
  }

  Future<void> _openCreateDialog(BuildContext context, PillarKind kind) async {
    await showDialog(
      context: context,
      builder: (_) => PillarCreateDialog(kind: kind),
    );
  }

  Future<void> _openModelDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => const PortfolioModelDialog(),
    );
  }
}

/// Shared list body for both the Pillars tab and the Virtual Portfolios tab.
/// [kind] controls the empty-state copy and whether the Unassigned card is shown.
class _PillarList extends ConsumerWidget {
  final AsyncValue<List<Pillar>> pillarsAsync;
  final PillarKind kind;

  const _PillarList({required this.pillarsAsync, required this.kind});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final assignmentsAsync = ref.watch(pillarAssetsProvider);
    final performanceAsync = ref.watch(pillarPerformanceSnapshotsProvider);
    final unassignedFracs = ref.watch(unassignedFractionProvider).value ?? {};
    final baseCurrency = ref.watch(baseCurrencyProvider).value ?? 'EUR';
    final locale = ref.watch(appLocaleProvider).value ?? 'en';

    return pillarsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (pillars) {
        final assignments = assignmentsAsync.value ?? const [];
        final performanceByPillar = performanceAsync.value ?? const <String, PillarPerformanceSnapshot>{};

        int assetCount(String id) => assignments.where((x) => x.pillarId == id).length;

        if (pillars.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    kind == PillarKind.virtual ? Icons.folder_special_outlined : Icons.view_quilt_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    kind == PillarKind.virtual ? s.virtualPortfoliosEmptyTitle : s.pillarsEmptyTitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(kind == PillarKind.virtual ? s.virtualPortfoliosEmptyCta : s.pillarsEmptyCta),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => PillarCreateDialog(kind: kind),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Unassigned card only makes sense for standard pillars (the partition model).
        final showUnassigned = kind == PillarKind.standard;
        double unassignedValue = 0;
        int unassignedCount = 0;
        if (showUnassigned) {
          final marketValues = ref.watch(assetMarketValuesProvider).value ?? {};
          unassignedFracs.forEach((assetId, frac) {
            unassignedValue += (marketValues[assetId] ?? 0) * frac;
          });
          unassignedCount = unassignedFracs.values.where((f) => f > 0).length;
        }

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
            if (showUnassigned && unassignedValue > 0)
              _UnassignedCard(
                value: unassignedValue,
                assetCount: unassignedCount,
                baseCurrency: baseCurrency,
                locale: locale,
              ),
          ],
        );
      },
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
            _ValueAndCount(value: value, baseCurrency: baseCurrency, assetCount: assetCount, locale: locale, s: s),
            if (pillar.targetValue != null && pillar.targetValue! > 0) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 4),
              // Progress toward the target is a percentage (shape); the target
              // amount itself is money and stays masked.
              Row(
                children: [
                  Text('${(progress! * 100).toStringAsFixed(0)}% · ', style: Theme.of(context).textTheme.bodySmall),
                  PrivacyText(s.pillarTarget(fmtCur.format(pillar.targetValue)), style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
            const SizedBox(height: 4),
            _PerformanceSummary(s: s, locale: locale, baseCurrency: baseCurrency, snapshot: performance),
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

/// Pillar value plus how many assets it holds. The value is position size and
/// is masked; the asset count is a count of entities and stays readable.
class _ValueAndCount extends StatelessWidget {
  final double value;
  final String baseCurrency;
  final int assetCount;
  final String locale;
  final AppStrings s;

  const _ValueAndCount({
    required this.value,
    required this.baseCurrency,
    required this.assetCount,
    required this.locale,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PrivacyText('${fmt.amountFormat(locale).format(value)} $baseCurrency'),
        Text(' · ${s.pillarAssetCount(assetCount)}'),
      ],
    );
  }
}

/// Absolute return / TWRR / CAGR on one line. Only the return AMOUNT is masked;
/// the three percentages are shape, and blurring them to protect one number hid
/// exactly what privacy mode is supposed to keep visible.
class _PerformanceSummary extends StatelessWidget {
  final AppStrings s;
  final String locale;
  final String baseCurrency;
  final PillarPerformanceSnapshot? snapshot;

  const _PerformanceSummary({
    required this.s,
    required this.locale,
    required this.baseCurrency,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    final snap = snapshot;
    if (snap == null) {
      return Text('${s.pillarAbsoluteReturnShort} — · ${s.pillarTwrrShort} — · ${s.pillarCagrShort} —', style: style);
    }
    final percentFormat = NumberFormat.percentPattern(locale)
      ..minimumFractionDigits = 1
      ..maximumFractionDigits = 1;
    final absAmount = (snap.marketValue == 0 && snap.netInvested == 0)
        ? '—'
        : '${fmt.amountFormat(locale).format(snap.absoluteReturnAmount)} $baseCurrency';
    final absPct = snap.absoluteReturnPct == null ? '—' : percentFormat.format(snap.absoluteReturnPct);
    final twrr = snap.twrr == null ? '—' : percentFormat.format(snap.twrr);
    final cagr = snap.cagr == null ? '—' : percentFormat.format(snap.cagr);
    return Row(
      children: [
        Text('${s.pillarAbsoluteReturnShort} ', style: style),
        PrivacyText(absAmount, style: style),
        Expanded(
          child: Text(
            ' ($absPct) · ${s.pillarTwrrShort} $twrr · ${s.pillarCagrShort} $cagr',
            style: style,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
        subtitle: _ValueAndCount(value: value, baseCurrency: baseCurrency, assetCount: assetCount, locale: locale, s: s),
      ),
    );
  }
}

/// Builds the toolbar rebalance action. On desktop it renders as a menu of
/// scopes ("all" + one per standard pillar); on mobile it folds into the global
/// overflow and opens the same choices as a modal. Disabled when there are no
/// standard pillars. Virtual portfolios are excluded (they rebalance per-portfolio).
AppBarAction _rebalanceAction(
  BuildContext context,
  AppStrings s,
  AsyncValue<List<Pillar>> pillarsAsync,
) {
  final pillars = pillarsAsync.value ?? const <Pillar>[];

  void openPreview(String pillarId, PortfolioRebalanceScopeKind scope) {
    showDialog(
      context: context,
      builder: (_) => RebalancePreviewDialog(pillarId: pillarId, initialScopeKind: scope),
    );
  }

  return AppBarAction(
    icon: Icons.balance,
    tooltip: s.rebalance,
    // Disabled (no onPressed, no submenu) when there are no pillars to rebalance.
    submenu: pillars.isEmpty
        ? const []
        : [
            AppBarSubAction(
              label: s.rebalanceScopeAll,
              onSelected: () => openPreview(
                pillars.first.id,
                PortfolioRebalanceScopeKind.allAssociatedPillars,
              ),
            ),
            for (final (i, pillar) in pillars.indexed)
              AppBarSubAction(
                label: pillar.name,
                dividerBefore: i == 0,
                onSelected: () => openPreview(
                  pillar.id,
                  PortfolioRebalanceScopeKind.currentPillar,
                ),
              ),
          ],
  );
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
