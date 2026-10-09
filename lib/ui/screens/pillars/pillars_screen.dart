import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../database/database.dart';
import '../../../database/tables.dart';
import '../../../l10n/app_strings.dart';
import 'package:finance_copilot/services/pillars/pillar_performance.dart';
import 'package:finance_copilot/services/portfolio/portfolio_rebalance_service.dart';
import '../../../services/providers/providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/footnote.dart';
import '../../widgets/global_app_bar_actions.dart';
import '../../widgets/mobile_pull_to_refresh.dart';
import '../../widgets/privacy_text.dart';
import '../../widgets/swipe_to_delete.dart';
import '../../../utils/formatters.dart' as fmt;
import '../dashboard/dashboard_screen.dart' show currencySymbol;
import 'pillar_create_dialog.dart';
import 'pillar_detail_screen.dart';
import 'portfolio_model_dialog.dart';
import 'portfolio_model_tree_data.dart';
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
      error: (e, _) => Center(child: Text(s.error(e))),
      data: (pillars) {
        final assignments = assignmentsAsync.value ?? const [];
        final performanceByPillar = performanceAsync.value ?? const <String, PillarPerformanceSnapshot>{};

        int assetCount(String id) => assignments.where((x) => x.pillarId == id).length;

        if (pillars.isEmpty) {
          final isVirtual = kind == PillarKind.virtual;
          return Padding(
            padding: const EdgeInsets.all(32),
            child: EmptyState(
              icon: isVirtual ? Icons.folder_special_outlined : Icons.view_quilt_outlined,
              message: isVirtual ? s.virtualPortfoliosEmptyTitle : s.pillarsEmptyTitle,
              actionLabel: isVirtual ? s.virtualPortfoliosEmptyCta : s.pillarsEmptyCta,
              onAction: () => showDialog(
                context: context,
                builder: (_) => PillarCreateDialog(kind: kind),
              ),
            ),
          );
        }

        // Unassigned card only makes sense for standard pillars (the partition model).
        // An asset without a price or exchange rate has no value: it is left
        // out of the card's value (never counted as 0) and counted under it.
        final showUnassigned = kind == PillarKind.standard;
        double unassignedValue = 0;
        int unassignedCount = 0;
        int unassignedUnpriced = 0;
        if (showUnassigned) {
          final marketValues = ref.watch(assetMarketValuesProvider).value;
          if (marketValues != null) {
            unassignedFracs.forEach((assetId, frac) {
              if (frac <= 0) return;
              unassignedCount++;
              final mv = marketValues[assetId];
              if (mv == null) {
                unassignedUnpriced++;
              } else {
                unassignedValue += mv * frac;
              }
            });
          }
        }

        return MobilePullToRefresh(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(8),
            children: [
              for (final p in pillars)
                SwipeToDelete.custom(
                  key: ValueKey('dismiss_pillar_${p.id}'),
                  // The same confirmation as the pillar's own trashcan.
                  confirmAndDelete: () => confirmAndDeletePillar(context, ref, p),
                  child: _PillarCard(
                    pillar: p,
                    performance: performanceByPillar[p.id],
                    assetCount: assetCount(p.id),
                    baseCurrency: baseCurrency,
                    locale: locale,
                  ),
                ),
              if (showUnassigned && (unassignedValue > 0 || unassignedUnpriced > 0))
                _UnassignedCard(
                  value: unassignedCount > unassignedUnpriced ? unassignedValue : null,
                  assetCount: unassignedCount,
                  unpricedCount: unassignedUnpriced,
                  baseCurrency: baseCurrency,
                  locale: locale,
                ),
            ],
          ),
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
    final snap = performance;
    // The value and the performance leave out the assets without a value
    // (counted under the card); the asset count does not.
    final excluded = snap?.excludedAssetCount ?? 0;
    // Unknown while the performance loads or when it failed, and when every
    // asset is left out: a dash, not 0.
    final value = (snap == null || (excluded > 0 && snap.marketValue == 0 && snap.netInvested == 0)) ? null : snap.marketValue;
    // The target is stored in its own currency, not the base one.
    final fmtCur = fmt.currencyFormat(locale, currencySymbol(pillar.targetCurrency));
    final hasTarget = pillar.targetValue != null && pillar.targetValue! > 0;
    // The progress compares the value with the target in the same currency;
    // without the value or an exchange rate for the target there is none.
    final targetInBase = pillarTargetInBase(ref, pillar, baseCurrency);
    final progress = (value == null || targetInBase == null) ? null : (value / targetInBase).clamp(0.0, 1.0);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.view_quilt_outlined, size: 28),
        title: Text(pillar.name, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            _ValueAndCount(value: value, baseCurrency: baseCurrency, assetCount: assetCount, locale: locale, s: s),
            if (hasTarget) ...[
              const SizedBox(height: 6),
              if (progress != null) ...[
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 4),
              ],
              // Progress toward the target is a percentage (shape); the target
              // amount itself is money and stays masked.
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${progress == null ? '—' : NumberFormat.percentPattern(locale).format(progress)} · ',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  PrivacyText(s.pillarTarget(fmtCur.format(pillar.targetValue)), style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
            const SizedBox(height: 4),
            _PerformanceSummary(s: s, locale: locale, baseCurrency: baseCurrency, snapshot: performance),
            if (excluded > 0) Footnote(s.pillarValueAndPerformanceExcluded(excluded)),
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
/// is masked; an unknown value (null) is a plain dash. The asset count is a
/// count of entities and stays readable.
class _ValueAndCount extends StatelessWidget {
  final double? value;
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
    // Wrap so a long amount plus the asset count degrades to a second line
    // instead of overflowing the ListTile subtitle.
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (value == null) const Text('—') else PrivacyText('${fmt.amountFormat(locale).format(value)} $baseCurrency'),
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
  /// Value of the priced assets; null when none of them has one.
  final double? value;
  final int assetCount;

  /// Assets left out of [value]: no price or exchange rate.
  final int unpricedCount;
  final String baseCurrency;
  final String locale;
  const _UnassignedCard({
    required this.value,
    required this.assetCount,
    required this.unpricedCount,
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ValueAndCount(value: value, baseCurrency: baseCurrency, assetCount: assetCount, locale: locale, s: s),
            if (unpricedCount > 0) Footnote(s.pillarUnpricedExcluded(unpricedCount)),
          ],
        ),
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
          return Padding(
            padding: const EdgeInsets.all(32),
            child: EmptyState(icon: Icons.inventory_2_outlined, message: s.portfolioModelsEmpty),
          );
        }
        // Mini first: the order the tab has always listed the variants in.
        final tree = buildPortfolioModelTreeData(models: models, preferredBuiltInVariant: PortfolioModelVariant.mini);
        final years = {
          for (final variant in tree.builtInGroups)
            for (final group in variant.years) group.year,
        }.toList()..sort();
        return MobilePullToRefresh(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(8),
            children: [
              if (years.isNotEmpty) ...[
                _SectionHeader(label: s.portfolioModelsBuiltIn),
                for (final year in years) _BuiltInYearGroup(s: s, year: year, variants: tree.builtInGroups),
              ],
              if (tree.customModels.isNotEmpty) ...[
                _SectionHeader(label: s.portfolioModelsCustom),
                for (final model in tree.customModels)
                  SwipeToDelete.custom(
                    key: ValueKey('dismiss_model_${model.id}'),
                    confirmAndDelete: () => confirmAndDeletePortfolioModel(context, ref, model),
                    child: _PortfolioModelTile(model: model),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// How far a model tile, and each level of the built-in tree, indents its
/// children.
const _nestedIndent = EdgeInsetsDirectional.only(start: 16);

class _BuiltInYearGroup extends StatelessWidget {
  final AppStrings s;
  final int year;

  /// Every built-in variant with its models by year, in the tab's order.
  final List<PortfolioModelTreeVariantGroup> variants;

  const _BuiltInYearGroup({
    required this.s,
    required this.year,
    required this.variants,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      childrenPadding: _nestedIndent,
      title: Text('$year', style: const TextStyle(fontWeight: FontWeight.w600)),
      children: [
        for (final variant in variants)
          if (variant.years.where((group) => group.year == year).firstOrNull case final group?)
            _BuiltInVariantGroup(s: s, variant: variant.variant, models: group.models),
      ],
    );
  }
}

class _BuiltInVariantGroup extends StatelessWidget {
  final AppStrings s;
  final PortfolioModelVariant variant;

  /// Sorted by equity, then name.
  final List<PortfolioModel> models;

  const _BuiltInVariantGroup({
    required this.s,
    required this.variant,
    required this.models,
  });

  @override
  Widget build(BuildContext context) {
    final equityGroups = <int, List<PortfolioModel>>{};
    for (final model in models) {
      equityGroups.putIfAbsent(model.equityPercent ?? 0, () => []).add(model);
    }
    return ExpansionTile(
      childrenPadding: _nestedIndent,
      title: Text(portfolioModelVariantLabel(s, variant), style: const TextStyle(fontWeight: FontWeight.w600)),
      children: [
        for (final MapEntry(key: equity, value: group) in equityGroups.entries) _BuiltInEquityGroup(equityPercent: equity, models: group),
      ],
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
    return ExpansionTile(
      childrenPadding: _nestedIndent,
      title: Text('$equityPercent%', style: const TextStyle(fontWeight: FontWeight.w600)),
      children: [
        for (final model in models) _PortfolioModelTile(model: model),
      ],
    );
  }
}

/// The rows of an expanded portfolio model — ISIN, description and target
/// weight (in the locale) — or a progress bar / error line while they load.
List<Widget> _portfolioModelItemTiles(AppStrings s, String locale, AsyncValue<List<PortfolioModelItem>> itemsAsync) => itemsAsync.when(
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
        trailing: Text('${NumberFormat('0.00', locale).format(item.targetWeight)}%'),
      ),
  ],
);

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

/// A portfolio model: its rows when expanded. A built-in model is read-only;
/// a custom one then offers the action that edits it in its dialog (which
/// also deletes it; the row swipes to delete as well).
class _PortfolioModelTile extends ConsumerWidget {
  final PortfolioModel model;

  const _PortfolioModelTile({required this.model});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final locale = ref.watch(appLocaleProvider).value ?? 'en';
    final itemsAsync = ref.watch(portfolioModelItemsProvider(model.id));
    return ExpansionTile(
      childrenPadding: _nestedIndent,
      leading: Icon(model.isBuiltIn ? Icons.inventory_2_outlined : Icons.tune),
      title: Text(model.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(portfolioModelSummary(s, model), style: Theme.of(context).textTheme.bodySmall),
      children: [
        ..._portfolioModelItemTiles(s, locale, itemsAsync),
        if (!model.isBuiltIn)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              icon: const Icon(Icons.edit),
              label: Text(s.edit),
              onPressed: () => _edit(context, ref),
            ),
          ),
      ],
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
}
