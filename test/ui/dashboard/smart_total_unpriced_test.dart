// The smart total leaves out an asset it cannot value: when the series that
// stands for the asset's value — its net series if visible, else its market
// series — has no spots (no price or exchange rate), the asset adds nothing
// and its invested line does not stand in (cost is not value). Such assets
// are reported as unpriced by the total's exclusions (totalExclusions), so a
// total can say what it left out.
//
// Priced assets keep the rules pinned in smart_total_test.dart.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/models/dashboard_chart.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart';

void main() {
  ChartSeries series(String key, List<FlSpot> spots, {bool rightAxis = false}) =>
      ChartSeries(key: key, name: key, color: const Color(0xFF2196F3), spots: spots, rightAxis: rightAxis);

  // No account, adjustment or cost basis without a rate: what the total leaves
  // out comes from the series alone.
  final noRateGaps = AllSeriesData(
    firstDate: DateTime(2026, 1, 1),
    accounts: const [],
    assetInvested: const [],
    assetMarket: const [],
    assetGain: const [],
    assetNet: const [],
    adjustments: const [],
    incomeAdjustments: const [],
    ephemeralInflows: const [],
    baseCurrency: 'EUR',
  );
  Set<int> unpricedAssetIds(List<ChartSeries> visible) => totalExclusions(visible, noRateGaps).unpricedAssetIds;

  final account = series('account:1', const [FlSpot(0, 100), FlSpot(10, 200)]);
  // Asset 5: priced.
  final invested5 = series('asset_invested:5', const [FlSpot(0, 1000)]);
  final market5 = series('asset_market:5', const [FlSpot(0, 1100), FlSpot(10, 1300)]);
  final net5 = series('asset_net:5', const [FlSpot(0, 1050), FlSpot(10, 1200)]);
  // Asset 6: bought, never priced — its market and net series have no spots.
  final invested6 = series('asset_invested:6', const [FlSpot(0, 500), FlSpot(10, 500)]);
  final market6 = series('asset_market:6', const []);
  final net6 = series('asset_net:6', const []);

  group('pinned: priced assets', () {
    test('market over invested, net over both; nothing reported as unpriced', () {
      expect(smartTotalSeries([account, invested5, market5]).map((s) => s.key), ['account:1', 'asset_market:5']);
      expect(smartTotalSeries([account, invested5, market5, net5]).map((s) => s.key), ['account:1', 'asset_net:5']);
      expect(buildSmartTotalSpots([account, invested5, market5]), const [FlSpot(0, 1200), FlSpot(10, 1500)]);
      expect(unpricedAssetIds([account, invested5, market5, net5]), isEmpty);
    });

    test('an invested-only chart (Saving) counts the invested series and reports nothing', () {
      expect(smartTotalSeries([account, invested5, invested6]).map((s) => s.key), ['account:1', 'asset_invested:5', 'asset_invested:6']);
      expect(unpricedAssetIds([account, invested5, invested6]), isEmpty);
    });
  });

  group('an asset without a price', () {
    test('is left out of the total: its invested line does not stand in for the missing market value', () {
      final visible = [account, invested5, market5, invested6, market6];
      expect(smartTotalSeries(visible).map((s) => s.key), ['account:1', 'asset_market:5']);
      expect(buildSmartTotalSpots(visible), const [FlSpot(0, 1200), FlSpot(10, 1500)]);
      expect(unpricedAssetIds(visible), {6});
    });

    test('an empty net series leaves it out as well, and it is counted once', () {
      final visible = [account, invested6, market6, net6];
      expect(smartTotalSeries(visible).map((s) => s.key), ['account:1']);
      expect(unpricedAssetIds(visible), {6});
    });

    test('a chart made only of unpriced assets has no total at all', () {
      expect(buildSmartTotalSpots([market6]), isEmpty);
      expect(unpricedAssetIds([market6]), {6});
    });

    test('a right-axis series never counts, priced or not', () {
      final rightAxis = series('asset_market:7', const [], rightAxis: true);
      expect(unpricedAssetIds([account, rightAxis]), isEmpty);
    });
  });

  test('role resolvers: an unpriced asset is not reported as counting toward the role total', () {
    final firstDate = DateTime(2026, 1, 1);
    final allData = AllSeriesData(
      firstDate: firstDate,
      accounts: [account],
      assetInvested: [invested5, invested6],
      assetMarket: [market5, market6],
      assetGain: const [],
      assetNet: [net5, net6],
      adjustments: const [],
      incomeAdjustments: const [],
      ephemeralInflows: const [],
      baseCurrency: 'EUR',
    );
    final chart = DashboardChart(
      id: 1,
      title: 'Portfolio',
      widgetType: 'portfolio',
      sortOrder: 0,
      seriesJson: '[{"type":"asset_market","id":5},{"type":"asset_market","id":6}]',
      createdAt: firstDate,
    );
    expect(ChartRoles.assetIdsForRoleTotal('portfolio', [chart], allData, const []), {5});
    expect(ChartRoles.valueForRole('portfolio', [chart], allData, const []), 1300);
  });
}
