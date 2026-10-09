// [totalExclusions] counts every contributor a total leaves out. An asset
// series without spots adds nothing to a total, so the asset is counted
// whatever the reason its series is empty:
//  * a gain series (the Gain / Performance chart): an incomplete cost basis
//    when the units are valued (a buy or sell without a rate: counted as
//    such), no market value at all otherwise (no price or rate: counted as
//    unpriced — it used to be dropped without a word);
//  * an invested line (the Saving and Invested charts): none of the asset's
//    amounts converts to base — also when the asset has no price, which used
//    to leave it out of the Saving total uncounted.
// Each asset is counted once, however many totals and reasons leave it out.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart';

void main() {
  ChartSeries series(String key, List<FlSpot> spots) => ChartSeries(key: key, name: key, color: const Color(0xFF2196F3), spots: spots);

  AllSeriesData data({
    List<ChartSeries> invested = const [],
    List<ChartSeries> market = const [],
    List<ChartSeries> gain = const [],
    List<ChartSeries> net = const [],
  }) => AllSeriesData(
    firstDate: DateTime(2026, 1, 1),
    accounts: const [],
    assetInvested: invested,
    assetMarket: market,
    assetGain: gain,
    assetNet: net,
    adjustments: const [],
    incomeAdjustments: const [],
    ephemeralInflows: const [],
    baseCurrency: 'EUR',
  );

  group('a gain series without spots', () {
    test('of an asset without any market value: counted as unpriced', () {
      final d = data(
        invested: [
          series('asset_invested:6', const [FlSpot(0, 500)]),
        ],
        market: [series('asset_market:6', const [])],
        gain: [series('asset_gain:6', const [])],
      );
      final gain = totalExclusions(d.assetGain, d);
      expect(gain.unpricedAssetIds, {6});
      expect(gain.costBasisIncompleteAssetIds, isEmpty);
      expect(gain.excludedFromTotalCount, 1);
    });

    test('pinned: of a valued asset: counted as an incomplete cost basis', () {
      final d = data(
        market: [
          series('asset_market:5', const [FlSpot(0, 500)]),
        ],
        gain: [series('asset_gain:5', const [])],
      );
      final gain = totalExclusions(d.assetGain, d);
      expect(gain.costBasisIncompleteAssetIds, {5});
      expect(gain.unpricedAssetIds, isEmpty);
      expect(gain.excludedFromTotalCount, 1);
    });
  });

  test('pinned: a gain series with spots counts nothing', () {
    final d = data(
      invested: [
        series('asset_invested:5', const [FlSpot(0, 400)]),
      ],
      market: [
        series('asset_market:5', const [FlSpot(0, 500)]),
      ],
      gain: [
        series('asset_gain:5', const [FlSpot(0, 100)]),
      ],
    );
    expect(totalExclusions(d.assetGain, d).excludedFromTotalCount, 0);
    expect(totalExclusions(d.assetInvested, d).excludedFromTotalCount, 0);
  });

  test('an invested line without spots of an asset without a price: counted as an incomplete cost basis', () {
    final d = data(
      invested: [series('asset_invested:7', const [])],
      market: [series('asset_market:7', const [])],
      gain: [series('asset_gain:7', const [])],
      net: [series('asset_net:7', const [])],
    );
    final saving = totalExclusions(d.assetInvested, d);
    expect(saving.costBasisIncompleteAssetIds, {7});
    expect(saving.excludedFromTotalCount, 1);
    expect(
      saving
          .union(totalExclusions(d.assetGain, d))
          .union(totalExclusions(d.assetMarket, d))
          .union(totalExclusions(d.assetNet, d))
          .excludedFromTotalCount,
      1,
      reason: 'one asset, however many totals leave it out',
    );
  });

  test('pinned: an invested line with spots, standing in a total for an asset without a price, counts nothing', () {
    // A Saving total adds up what was paid; the asset's cost is whole.
    final d = data(
      invested: [
        series('asset_invested:8', const [FlSpot(0, 1000)]),
      ],
      market: [series('asset_market:8', const [])],
    );
    expect(totalExclusions(d.assetInvested, d).excludedFromTotalCount, 0);
  });
}
