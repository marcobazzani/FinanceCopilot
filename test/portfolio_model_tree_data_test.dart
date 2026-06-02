import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/ui/screens/pillars/portfolio_model_tree_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('preferredBuiltInPortfolioVariantForLiquidAssets', () {
    test('prefers mini at or below 50000', () {
      expect(
        preferredBuiltInPortfolioVariantForLiquidAssets(50000),
        PortfolioModelVariant.mini,
      );
      expect(
        preferredBuiltInPortfolioVariantForLiquidAssets(12500),
        PortfolioModelVariant.mini,
      );
    });

    test('prefers full above 50000', () {
      expect(
        preferredBuiltInPortfolioVariantForLiquidAssets(50000.01),
        PortfolioModelVariant.full,
      );
    });
  });

  group('buildPortfolioModelTreeData', () {
    test('orders built-in groups by preferred variant and keeps custom at root', () {
      final tree = buildPortfolioModelTreeData(
        models: [
          _model(
            id: 'full_2026_60',
            name: '60 Portfolio',
            variant: PortfolioModelVariant.full,
            year: 2026,
            equityPercent: 60,
          ),
          _model(
            id: 'mini_2026_60',
            name: 'Mini 60 Portfolio',
            variant: PortfolioModelVariant.mini,
            year: 2026,
            equityPercent: 60,
          ),
          _model(
            id: 'custom_a',
            name: 'My Custom',
            variant: PortfolioModelVariant.custom,
            isBuiltIn: false,
            sortOrder: 2,
          ),
          _model(
            id: 'custom_b',
            name: 'AAA Custom',
            variant: PortfolioModelVariant.custom,
            isBuiltIn: false,
            sortOrder: 1,
          ),
        ],
        preferredBuiltInVariant: PortfolioModelVariant.full,
      );

      expect(
        tree.builtInGroups.map((group) => group.variant).toList(),
        [PortfolioModelVariant.full, PortfolioModelVariant.mini],
      );
      expect(
        tree.customModels.map((model) => model.id).toList(),
        ['custom_b', 'custom_a'],
      );
    });

    test('groups by year and lists models directly without equity folders', () {
      final tree = buildPortfolioModelTreeData(
        models: [
          _model(
            id: 'full_2025_40',
            name: '40 Portfolio',
            variant: PortfolioModelVariant.full,
            year: 2025,
            equityPercent: 40,
          ),
          _model(
            id: 'full_2025_60',
            name: '60 Portfolio',
            variant: PortfolioModelVariant.full,
            year: 2025,
            equityPercent: 60,
          ),
          _model(
            id: 'full_2026_20',
            name: '20 Portfolio',
            variant: PortfolioModelVariant.full,
            year: 2026,
            equityPercent: 20,
          ),
        ],
        preferredBuiltInVariant: PortfolioModelVariant.full,
      );

      expect(tree.builtInGroups, hasLength(1));
      expect(
        tree.builtInGroups.single.years.map((group) => group.year).toList(),
        [2025, 2026],
      );
      expect(
        tree.builtInGroups.single.years.first.models.map((model) => model.id).toList(),
        ['full_2025_40', 'full_2025_60'],
      );
    });
  });
}

PortfolioModel _model({
  required String id,
  required String name,
  required PortfolioModelVariant variant,
  bool isBuiltIn = true,
  int? year,
  int? equityPercent,
  int sortOrder = 0,
}) {
  final now = DateTime(2026, 6, 2);
  return PortfolioModel(
    id: id,
    name: name,
    isBuiltIn: isBuiltIn,
    year: year,
    equityPercent: equityPercent,
    variant: variant,
    sortOrder: sortOrder,
    createdAt: now,
    updatedAt: now,
  );
}
