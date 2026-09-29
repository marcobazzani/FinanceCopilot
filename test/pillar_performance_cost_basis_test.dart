// A pillar's performance compares its market value with the money put in. An
// asset whose cost basis is incomplete — a buy or sell whose amount has no
// rate to base, left out of the money put in while its units are in the
// market value — read as a gain as large as what that buy bought. It is left
// out of both sides and counted, like an asset without a market value.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/account_service.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/pillars/pillar_performance.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show AllSeriesData, ChartSeries, allSeriesDataProvider;

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

AllSeriesData _data({
  required Map<int, List<FlSpot>> invested,
  required Map<int, List<FlSpot>> market,
  required Map<int, List<FlSpot>> gain,
}) {
  List<ChartSeries> series(Map<int, List<FlSpot>> source, String prefix) => [
    for (final e in source.entries) ChartSeries(key: '$prefix:${e.key}', name: '$prefix-${e.key}', color: Colors.blue, spots: e.value),
  ];
  return AllSeriesData(
    firstDate: DateTime(2024, 1, 1),
    accounts: const [],
    assetInvested: series(invested, 'asset_invested'),
    assetMarket: series(market, 'asset_market'),
    assetGain: series(gain, 'asset_gain'),
    assetNet: const [],
    adjustments: const [],
    incomeAdjustments: const [],
    ephemeralInflows: const [],
    baseCurrency: 'EUR',
  );
}

void main() {
  final asOf = DateTime(2024, 1, 11);

  /// Asset 1: 100 in, worth 120 ten days later. Asset 2: worth 110, of which
  /// only 10 of cost converted to base — its gain series has no spots.
  final data = _data(
    invested: {
      1: const [FlSpot(0, 100), FlSpot(10, 100)],
      2: const [FlSpot(0, 10), FlSpot(10, 10)],
    },
    market: {
      1: const [FlSpot(0, 100), FlSpot(10, 120)],
      2: const [FlSpot(0, 100), FlSpot(10, 110)],
    },
    gain: {
      1: const [FlSpot(0, 0), FlSpot(10, 20)],
      2: const [],
    },
  );

  test('an asset with an incomplete cost basis is left out of both sides of the performance, and counted', () {
    final snapshot = computePillarPerformanceSnapshot(asOfDate: asOf, allData: data, fractions: const {1: 1, 2: 1});

    expect(snapshot.marketValue, 120);
    expect(snapshot.netInvested, 100, reason: 'the 10 converted of what asset 2 cost is not what it cost');
    expect(snapshot.absoluteReturnAmount, 20, reason: 'asset 2 would add a return of 100 it never made');
    expect(snapshot.absoluteReturnPct, closeTo(0.2, 1e-9));
    expect(snapshot.twrr, closeTo(0.2, 1e-9));
    expect(snapshot.excludedAssetCount, 1);
  });

  test('the pillar history chart leaves it out of both lines too', () {
    final history = buildPillarScopedHistory(allData: data, fractions: const {1: 1, 2: 1});

    expect(history.investedTotal.map((p) => p.y), [100, 100]);
    expect(history.marketTotal.map((p) => p.y), [100, 120]);
    expect(history.excludedAssetCount, 1);
  });

  test('an asset outside the pillar is not counted', () {
    final snapshot = computePillarPerformanceSnapshot(asOfDate: asOf, allData: data, fractions: const {1: 1});

    expect(snapshot.excludedAssetCount, 0);
    expect(snapshot.marketValue, 120);
  });

  group('from the dashboard series', () {
    final d0 = DateTime(2026, 1, 5);
    DateTime day(int n) => DateTime(d0.year, d0.month, d0.day + n);
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
          defaultTaxRateProvider.overrideWithValue(const AsyncData(0.26)),
          nowProvider.overrideWithValue(() => day(3)),
          marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
          accountsProvider.overrideWithValue(const AsyncData(<Account>[])),
          accountStatsProvider.overrideWithValue(const AsyncData(<int, AccountStats>{})),
          assetsProvider.overrideWithValue(const AsyncData(<Asset>[])),
          assetStatsProvider.overrideWithValue(const AsyncData(<int, AssetStats>{})),
          extraordinaryEventsProvider.overrideWithValue(const AsyncData(<ExtraordinaryEvent>[])),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    Future<int> fund(String name, {required String buyCurrency}) async {
      final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: '$name broker'));
      final id = await db
          .into(db.assets)
          .insert(
            AssetsCompanion.insert(
              name: name,
              assetType: AssetType.stockEtf,
              valuationMethod: ValuationMethod.marketPrice,
              intermediaryId: broker,
            ),
          );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: id,
              date: day(0),
              valueDate: day(0),
              type: EventType.buy,
              amount: 1000,
              quantity: const Value(10),
              price: const Value(100),
              currency: Value(buyCurrency),
            ),
          );
      for (var n = 0; n <= 3; n++) {
        await db
            .into(db.marketPrices)
            .insert(MarketPricesCompanion.insert(assetId: id, date: day(n), closePrice: 100.0 + 10 * n, currency: 'EUR'));
      }
      return id;
    }

    test('a fund bought in a currency without a rate is left out and counted', () async {
      final inEur = await fund('Bought in EUR', buyCurrency: 'EUR');
      // No USD/EUR rate at all: its 1,000 USD never reach the money put in.
      final inUsd = await fund('Bought in USD', buyCurrency: 'USD');

      final allData = (await container.read(allSeriesDataProvider.future))!;
      final snapshot = computePillarPerformanceSnapshot(asOfDate: day(3), allData: allData, fractions: {inEur: 1, inUsd: 1});

      expect(snapshot.excludedAssetCount, 1);
      expect(snapshot.marketValue, closeTo(1300, 1e-9), reason: 'only the fund whose cost is known');
      expect(snapshot.netInvested, closeTo(1000, 1e-9));
      expect(snapshot.absoluteReturnPct, closeTo(0.3, 1e-9), reason: 'the USD fund read as a 1,300 gain on nothing');
    });
  });
}
