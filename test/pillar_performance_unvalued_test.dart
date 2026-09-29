// A pillar's performance compares its market value with the money put in. An
// asset held without a market value (no price, or no exchange rate to base)
// is missing from the market value; its contributions used to stay in the
// money put in, which read as a loss in the absolute return, the TWRR and the
// CAGR. It is left out of both sides, and counted.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/services/pillars/pillar_performance.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show AllSeriesData, ChartSeries;

AllSeriesData _data({required Map<int, List<FlSpot>> invested, required Map<int, List<FlSpot>> market}) {
  List<ChartSeries> series(Map<int, List<FlSpot>> source, String prefix) => [
    for (final e in source.entries) ChartSeries(key: '$prefix:${e.key}', name: '$prefix-${e.key}', color: Colors.blue, spots: e.value),
  ];
  return AllSeriesData(
    firstDate: DateTime(2024, 1, 1),
    accounts: const [],
    assetInvested: series(invested, 'asset_invested'),
    assetMarket: series(market, 'asset_market'),
    assetGain: const [],
    assetNet: const [],
    adjustments: const [],
    incomeAdjustments: const [],
    ephemeralInflows: const [],
    baseCurrency: 'EUR',
  );
}

void main() {
  final asOf = DateTime(2024, 1, 11);

  /// Asset 1: 100 in, worth 120 ten days later. Asset 2: 50 in, no value.
  final priced = {
    'invested': [const FlSpot(0, 100), const FlSpot(10, 100)],
    'market': [const FlSpot(0, 100), const FlSpot(10, 120)],
  };

  test('an asset with no market value at all: left out of both sides and counted', () {
    final snapshot = computePillarPerformanceSnapshot(
      asOfDate: asOf,
      allData: _data(
        invested: {
          1: priced['invested']!,
          2: const [FlSpot(0, 50), FlSpot(10, 50)],
        },
        market: {1: priced['market']!, 2: const []},
      ),
      fractions: const {1: 1, 2: 1},
    );

    expect(snapshot.marketValue, 120);
    expect(snapshot.netInvested, 100, reason: 'the 50 put into the unvalued asset is not set against a missing value');
    expect(snapshot.absoluteReturnAmount, 20);
    expect(snapshot.absoluteReturnPct, closeTo(0.2, 1e-9));
    expect(snapshot.twrr, closeTo(0.2, 1e-9));
    expect(snapshot.cagr, isNotNull);
    expect(snapshot.excludedAssetCount, 1);
  });

  test('an asset whose value stops before its contributions do (re-bought, never priced): left out', () {
    final snapshot = computePillarPerformanceSnapshot(
      asOfDate: asOf,
      allData: _data(
        invested: {
          1: priced['invested']!,
          2: const [FlSpot(0, 50), FlSpot(2, 0), FlSpot(6, 80), FlSpot(10, 80)],
        },
        // Sold on day 2 (an exact 0), bought back on day 6 with no price.
        market: {
          1: priced['market']!,
          2: const [FlSpot(2, 0), FlSpot(4, 0)],
        },
      ),
      fractions: const {1: 1, 2: 1},
    );

    expect(snapshot.marketValue, 120);
    expect(snapshot.netInvested, 100);
    expect(snapshot.excludedAssetCount, 1);
  });

  test('a closed position stays in: its zero value is exact', () {
    final snapshot = computePillarPerformanceSnapshot(
      asOfDate: asOf,
      allData: _data(
        invested: {
          1: priced['invested']!,
          2: const [FlSpot(0, 50), FlSpot(5, -10), FlSpot(10, -10)],
        },
        market: {
          1: priced['market']!,
          2: const [FlSpot(0, 50), FlSpot(5, 0), FlSpot(10, 0)],
        },
      ),
      fractions: const {1: 1, 2: 1},
    );

    expect(snapshot.netInvested, 90, reason: 'sold for 60 what cost 50: 10 of realised gain');
    expect(snapshot.marketValue, 120);
    expect(snapshot.excludedAssetCount, 0);
  });

  test('a pillar holding only unvalued assets: no figures, the count survives', () {
    final snapshot = computePillarPerformanceSnapshot(
      asOfDate: asOf,
      allData: _data(
        invested: {
          2: const [FlSpot(0, 50), FlSpot(10, 50)],
        },
        market: {2: const []},
      ),
      fractions: const {2: 1},
    );

    expect(snapshot.marketValue, 0);
    expect(snapshot.netInvested, 0);
    expect(snapshot.twrr, isNull);
    expect(snapshot.excludedAssetCount, 1);
  });

  test('the pillar history chart leaves it out of both lines too', () {
    final history = buildPillarScopedHistory(
      allData: _data(
        invested: {
          1: priced['invested']!,
          2: const [FlSpot(0, 50), FlSpot(10, 50)],
        },
        market: {1: priced['market']!, 2: const []},
      ),
      fractions: const {1: 1, 2: 1},
    );

    expect(history.investedTotal.map((p) => p.y), [100, 100]);
    expect(history.marketTotal.map((p) => p.y), [100, 120]);
    expect(history.excludedAssetCount, 1);
  });
}
