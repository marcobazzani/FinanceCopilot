import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../database/database.dart';
import '../../../l10n/app_strings.dart';
import '../../../models/dashboard_chart.dart';
import 'package:finance_copilot/services/pillars/pillar_performance.dart';
import 'package:finance_copilot/services/pillars/pillar_service.dart';
import 'package:finance_copilot/services/portfolio/portfolio_rebalance_service.dart';
import '../../../services/providers/providers.dart';
import '../../widgets/global_app_bar_actions.dart';
import '../../widgets/privacy_text.dart';
import '../../../utils/formatters.dart' as fmt;
import '../dashboard/dashboard_screen.dart' show AllSeriesData, ChartCard, ChartSeries, allSeriesDataProvider;
import 'package:finance_copilot/ui/screens/allocation/allocation_tab.dart';
import 'pillar_create_dialog.dart';
import 'rebalance_preview_dialog.dart';

part 'pillar_detail_overview.dart';
part 'pillar_detail_cards.dart';

class PillarDetailScreen extends ConsumerStatefulWidget {
  final String pillarId;
  final int? focusAssetId;
  const PillarDetailScreen({
    super.key,
    required this.pillarId,
    this.focusAssetId,
  });

  @override
  ConsumerState<PillarDetailScreen> createState() => _PillarDetailScreenState();
}

class _PillarDetailScreenState extends ConsumerState<PillarDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _lastTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _lastTab) {
        _lastTab = _tabController.index;
        setState(() {});
      }
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
    return Scaffold(
      appBar: AppBar(
        title: pillarsAsync.when(
          loading: () => const Text('…'),
          error: (e, _) => Text('$e'),
          data: (pillars) {
            final p = pillars.where((x) => x.id == widget.pillarId).firstOrNull;
            if (p == null) return const Text('—');
            return Text(p.name);
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: s.overview),
            Tab(text: s.dashTabAssetsOverview),
          ],
        ),
        actions: globalAppBarActions(
          context,
          ref,
          local: [
            IconButton(
              icon: const Icon(Icons.balance),
              tooltip: s.rebalance,
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (_) => RebalancePreviewDialog(
                    pillarId: widget.pillarId,
                    initialScopeKind: PortfolioRebalanceScopeKind.currentPillar,
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: s.edit,
              onPressed: () async {
                final p = (pillarsAsync.value ?? const []).where((x) => x.id == widget.pillarId).firstOrNull;
                if (p == null) return;
                await showDialog(
                  context: context,
                  builder: (_) => PillarCreateDialog(existing: p),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: s.delete,
              onPressed: () async {
                final p = (pillarsAsync.value ?? const []).where((x) => x.id == widget.pillarId).firstOrNull;
                if (p == null) return;
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(s.delete),
                    content: Text(s.pillarDeleteConfirm),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.delete)),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(pillarServiceProvider).delete(p.id);
                  if (context.mounted) Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewView(pillarId: widget.pillarId, focusAssetId: widget.focusAssetId),
          _PillarAssetsOverviewTab(pillarId: widget.pillarId),
        ],
      ),
    );
  }
}

class _PillarAssetsOverviewTab extends ConsumerWidget {
  final String pillarId;

  const _PillarAssetsOverviewTab({required this.pillarId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final dataAsync = ref.watch(pillarAllocationDataProvider(pillarId));
    final compositionsAsync = ref.watch(assetCompositionsProvider);

    return dataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(s.error(e))),
      data: (data) => compositionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(s.error(e))),
        data: (compositions) => AllocationOverviewBody(
          assets: data.assets,
          marketValues: data.marketValues,
          baseCurrency: data.baseCurrency,
          compositions: compositions,
        ),
      ),
    );
  }
}

class _AssetRowState {
  final int assetId;
  final double total;
  final double otherAssigned;
  double current;
  _AssetRowState({
    required this.assetId,
    required this.total,
    required this.otherAssigned,
    required this.current,
  });
  double get maxAvailable => total - otherAssigned;
  double get maxPercent => total <= 0 ? 0 : (maxAvailable / total * 100).clamp(0.0, 100.0);
  double get currentPercent => total <= 0 ? 0 : (current / total * 100).clamp(0.0, 100.0);
}

class _ChartViewState {
  Set<String> hidden = <String>{};
  bool hideComponents = false;
  double height = 320;
  double? zoomMinX;
  double? zoomMaxX;
  double? zoomMinY;
  double? zoomMaxY;
}
