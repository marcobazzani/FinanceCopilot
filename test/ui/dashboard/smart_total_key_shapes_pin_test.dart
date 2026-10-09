// Pins how the smart total reads series keys: only a '<type>:<integer id>' key
// names an asset, so only such keys supersede one another or report an asset
// as unpriced; any other shape is an ordinary series counted as it is. The
// pillar history chart relies on the synthetic id -1 ('asset_market:-1'
// supersedes 'asset_invested:-1').
//
// The priced/unpriced rules themselves are pinned in smart_total_test.dart and
// smart_total_unpriced_test.dart.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart';

void main() {
  ChartSeries series(String key, List<FlSpot> spots) => ChartSeries(key: key, name: key, color: const Color(0xFF2196F3), spots: spots);

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

  test('a key that is not <type>:<id> names no asset: it counts as it is and supersedes nothing', () {
    final visible = [
      series('asset_invested:5', const [FlSpot(0, 100)]),
      series('asset_market:5:1', const [FlSpot(0, 1000)]),
      series('asset_net:x', const [FlSpot(0, 10000)]),
      series('asset_market', const [FlSpot(0, 100000)]),
      series('asset_market:', const [FlSpot(0, 1000000)]),
    ];
    expect(smartTotalSeries(visible).map((s) => s.key), [
      'asset_invested:5',
      'asset_market:5:1',
      'asset_net:x',
      'asset_market',
      'asset_market:',
    ]);
    expect(buildSmartTotalSpots(visible), const [FlSpot(0, 1111100)]);
    expect(unpricedAssetIds(visible), isEmpty);
  });

  test('an empty series under a key without an id is not an unpriced asset', () {
    final visible = [
      series('account:1', const [FlSpot(0, 10)]),
      series('asset_market:x', const []),
      series('asset_net:5:1', const []),
      series('asset_market', const []),
    ];
    expect(smartTotalSeries(visible).map((s) => s.key), ['account:1', 'asset_market:x', 'asset_net:5:1', 'asset_market']);
    expect(unpricedAssetIds(visible), isEmpty);
  });

  test('the synthetic id -1: its market series supersedes its invested one, and an empty one is unpriced', () {
    final invested = series('asset_invested:-1', const [FlSpot(0, 100)]);
    expect(
      smartTotalSeries([
        invested,
        series('asset_market:-1', const [FlSpot(0, 120)]),
      ]).map((s) => s.key),
      ['asset_market:-1'],
    );
    expect(unpricedAssetIds([invested, series('asset_market:-1', const [])]), {-1});
    expect(
      smartTotalSeries([
        invested,
        series('asset_net:-1', const [FlSpot(0, 110)]),
      ]).map((s) => s.key),
      ['asset_net:-1'],
    );
  });

  test('other types with an id are ordinary series, whatever their spots', () {
    final visible = [
      series('asset_gain:5', const []),
      series('adjustment_value:5', const [FlSpot(0, -50)]),
      series('asset_invested:5', const [FlSpot(0, 100)]),
    ];
    expect(smartTotalSeries(visible).map((s) => s.key), ['asset_gain:5', 'adjustment_value:5', 'asset_invested:5']);
    // None of them stands for the asset's value. The empty gain still counts
    // it as unpriced, by the total's own rule for a gain series: no market
    // value to draw the gain from (total_exclusions_empty_asset_series_test).
    expect(unpricedAssetIds(visible), {5});
  });
}
