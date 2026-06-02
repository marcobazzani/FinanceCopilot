import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/database.dart';
import '../../../database/tables.dart';
import '../../../services/providers/providers.dart';
import '../dashboard/dashboard_screen.dart' show ChartRoles, allSeriesDataProvider;

const double portfolioModelMiniPreferenceThreshold = 50000;

PortfolioModelVariant preferredBuiltInPortfolioVariantForLiquidAssets(
  double liquidInvestmentsPlusCash,
) {
  return liquidInvestmentsPlusCash > portfolioModelMiniPreferenceThreshold ? PortfolioModelVariant.full : PortfolioModelVariant.mini;
}

class PortfolioModelTreeYearGroup {
  final int year;
  final List<PortfolioModel> models;

  const PortfolioModelTreeYearGroup({
    required this.year,
    required this.models,
  });
}

class PortfolioModelTreeVariantGroup {
  final PortfolioModelVariant variant;
  final List<PortfolioModelTreeYearGroup> years;

  const PortfolioModelTreeVariantGroup({
    required this.variant,
    required this.years,
  });
}

class PortfolioModelTreeData {
  final List<PortfolioModelTreeVariantGroup> builtInGroups;
  final List<PortfolioModel> customModels;

  const PortfolioModelTreeData({
    required this.builtInGroups,
    required this.customModels,
  });
}

PortfolioModelTreeData buildPortfolioModelTreeData({
  required List<PortfolioModel> models,
  required PortfolioModelVariant preferredBuiltInVariant,
}) {
  final builtIn = models.where((m) => m.isBuiltIn).toList();
  final custom = models.where((m) => !m.isBuiltIn).toList()
    ..sort((a, b) {
      final sortCompare = a.sortOrder.compareTo(b.sortOrder);
      return sortCompare != 0 ? sortCompare : a.name.compareTo(b.name);
    });

  final otherBuiltInVariant = preferredBuiltInVariant == PortfolioModelVariant.mini ? PortfolioModelVariant.full : PortfolioModelVariant.mini;
  final variantOrder = <PortfolioModelVariant>[
    preferredBuiltInVariant,
    otherBuiltInVariant,
  ];

  final builtInGroups = <PortfolioModelTreeVariantGroup>[];
  for (final variant in variantOrder) {
    final variantModels = builtIn.where((m) => m.variant == variant).toList();
    if (variantModels.isEmpty) continue;

    final byYear = <int, List<PortfolioModel>>{};
    for (final model in variantModels) {
      byYear.putIfAbsent(model.year ?? 0, () => []).add(model);
    }
    final years = byYear.keys.toList()..sort();
    builtInGroups.add(
      PortfolioModelTreeVariantGroup(
        variant: variant,
        years: [
          for (final year in years)
            PortfolioModelTreeYearGroup(
              year: year,
              models: (byYear[year]!
                ..sort((a, b) {
                  final equityCompare = (a.equityPercent ?? 0).compareTo(b.equityPercent ?? 0);
                  return equityCompare != 0 ? equityCompare : a.name.compareTo(b.name);
                })),
            ),
        ],
      ),
    );
  }

  return PortfolioModelTreeData(
    builtInGroups: builtInGroups,
    customModels: custom,
  );
}

final preferredPortfolioModelVariantProvider = FutureProvider<PortfolioModelVariant>((ref) async {
  final allData = await ref.watch(allSeriesDataProvider.future);
  if (allData == null) return PortfolioModelVariant.full;
  final activeAssets = await ref.watch(activeAssetsProvider.future);
  final userCharts = ref.watch(dashboardChartsProvider);
  final liquidInvestmentsPlusCash =
      ChartRoles.valueForRole('cash', userCharts, allData, activeAssets) +
      ChartRoles.valueForRole(
        'liquid_investments',
        userCharts,
        allData,
        activeAssets,
      );
  return preferredBuiltInPortfolioVariantForLiquidAssets(
    liquidInvestmentsPlusCash,
  );
});
