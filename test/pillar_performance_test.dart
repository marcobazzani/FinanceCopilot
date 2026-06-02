import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/market_price_service.dart';
import 'package:finance_copilot/services/pillar_performance.dart';
import 'package:finance_copilot/services/pillar_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show AllSeriesData, ChartSeries, allSeriesDataProvider;

void main() {
  group('computePillarPerformanceSnapshot', () {
    test('buy and hold pillar with no intermediate flows', () {
      final snapshot = computePillarPerformanceSnapshot(
        asOfDate: DateTime(2024, 1, 11),
        allData: _allSeriesData(
          invested: {
            1: [FlSpot(0, 100)],
          },
          market: {
            1: [FlSpot(0, 100), FlSpot(10, 120)],
          },
        ),
        fractions: const {1: 1},
      );

      expect(snapshot.marketValue, 120);
      expect(snapshot.netInvested, 100);
      expect(snapshot.absoluteReturnAmount, 20);
      expect(snapshot.absoluteReturnPct, closeTo(0.2, 1e-9));
      expect(snapshot.twrr, closeTo(0.2, 1e-9));
      expect(
        snapshot.cagr,
        closeTo(775.453551462582, 1e-6),
      );
      expect(snapshot.hasSufficientHistory, isTrue);
    });

    test('mid-period contribution changes twrr relative to simple gain', () {
      final snapshot = computePillarPerformanceSnapshot(
        asOfDate: DateTime(2024, 1, 11),
        allData: _allSeriesData(
          invested: {
            1: [FlSpot(0, 100), FlSpot(5, 150)],
          },
          market: {
            1: [FlSpot(0, 100), FlSpot(5, 155), FlSpot(10, 170)],
          },
        ),
        fractions: const {1: 1},
      );

      expect(snapshot.absoluteReturnPct, closeTo(0.1333333333, 1e-9));
      expect(snapshot.twrr, closeTo(0.1516129032, 1e-9));
      expect(snapshot.twrr, isNot(closeTo(snapshot.absoluteReturnPct!, 1e-4)));
    });

    test('withdrawals remain part of linked twrr math', () {
      final snapshot = computePillarPerformanceSnapshot(
        asOfDate: DateTime(2024, 1, 11),
        allData: _allSeriesData(
          invested: {
            1: [FlSpot(0, 100), FlSpot(5, 60)],
          },
          market: {
            1: [FlSpot(0, 100), FlSpot(5, 66), FlSpot(10, 72)],
          },
        ),
        fractions: const {1: 1},
      );

      expect(snapshot.absoluteReturnAmount, 12);
      expect(snapshot.absoluteReturnPct, closeTo(0.2, 1e-9));
      expect(snapshot.twrr, closeTo(0.1563636363, 1e-9));
      expect(snapshot.cagr, isNotNull);
    });

    test('zero ending net invested suppresses invalid percent and rates', () {
      final snapshot = computePillarPerformanceSnapshot(
        asOfDate: DateTime(2024, 1, 11),
        allData: _allSeriesData(
          invested: {
            1: [FlSpot(0, 100), FlSpot(10, 0)],
          },
          market: {
            1: [FlSpot(0, 100), FlSpot(10, 0)],
          },
        ),
        fractions: const {1: 1},
      );

      expect(snapshot.absoluteReturnPct, isNull);
      expect(snapshot.twrr, isNull);
      expect(snapshot.cagr, isNull);
    });

    test('single-point history is safe but insufficient', () {
      final snapshot = computePillarPerformanceSnapshot(
        asOfDate: DateTime(2024, 1, 1),
        allData: _allSeriesData(
          invested: {
            1: [FlSpot(0, 100)],
          },
          market: {
            1: [FlSpot(0, 100)],
          },
        ),
        fractions: const {1: 1},
      );

      expect(snapshot.hasSufficientHistory, isFalse);
      expect(snapshot.twrr, isNull);
      expect(snapshot.cagr, isNull);
    });
  });

  group('pillarPerformanceProvider', () {
    late AppDatabase db;
    late ProviderContainer container;
    late String pillarId;
    late Pillar pillar;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());

      final intermediaryId = await db
          .into(db.intermediaries)
          .insert(
            IntermediariesCompanion.insert(name: 'Broker'),
          );
      final assetId = await db
          .into(db.assets)
          .insert(
            AssetsCompanion.insert(
              name: 'Fund',
              assetType: AssetType.stockEtf,
              valuationMethod: ValuationMethod.eventDriven,
              intermediaryId: intermediaryId,
            ),
          );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2024, 1, 1),
              valueDate: DateTime(2024, 1, 1),
              type: EventType.buy,
              amount: 100,
              quantity: const Value(10),
              price: const Value(10),
            ),
          );
      pillarId = await PillarService(db).create(name: 'Retirement');
      await PillarService(db).assign(pillarId: pillarId, assetId: assetId, qty: 10);
      pillar = (await PillarService(db).getById(pillarId))!;

      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
          defaultTaxRateProvider.overrideWithValue(const AsyncData(0.26)),
          marketPriceServiceProvider.overrideWithValue(
            _TestMarketPriceService(db),
          ),
          currentDateProvider.overrideWith(
            (ref) => ref.watch(waybackDateProvider) ?? DateTime(2024, 1, 11),
          ),
          pillarsProvider.overrideWithValue(AsyncData([pillar])),
          allSeriesDataProvider.overrideWith((ref) async {
            final currentDate = ref.watch(currentDateProvider);
            return currentDate.day <= 6 ? _providerWaybackData() : _providerLiveData();
          }),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('batched list provider and family provider stay aligned and honor wayback', () async {
      final liveMap = await container.read(pillarPerformanceSnapshotsProvider.future);
      final liveDetail = await container.read(pillarPerformanceProvider(pillarId).future);
      expect(liveMap[pillarId]!.marketValue, 150);
      expect(liveDetail.marketValue, 150);
      expect(liveDetail.absoluteReturnPct, closeTo(0.5, 1e-9));

      container.read(waybackDateProvider.notifier).state = DateTime(2024, 1, 6);

      final waybackMap = await container.read(pillarPerformanceSnapshotsProvider.future);
      final waybackDetail = await container.read(pillarPerformanceProvider(pillarId).future);
      expect(waybackMap[pillarId]!.marketValue, 120);
      expect(waybackDetail.marketValue, 120);
      expect(waybackDetail.asOfDate, DateTime(2024, 1, 6));
      expect(waybackDetail.marketValue, lessThan(liveDetail.marketValue));
    });
  });
}

AllSeriesData _allSeriesData({
  required Map<int, List<FlSpot>> invested,
  required Map<int, List<FlSpot>> market,
}) {
  List<ChartSeries> seriesFrom(
    Map<int, List<FlSpot>> source,
    String prefix,
    Color color,
  ) {
    return source.entries
        .map(
          (entry) => ChartSeries(
            key: '$prefix:${entry.key}',
            name: '$prefix-${entry.key}',
            color: color,
            spots: entry.value,
          ),
        )
        .toList();
  }

  return AllSeriesData(
    firstDate: DateTime(2024, 1, 1),
    accounts: const [],
    assetInvested: seriesFrom(invested, 'asset_invested', Colors.orange),
    assetMarket: seriesFrom(market, 'asset_market', Colors.blue),
    assetGain: const [],
    assetNet: const [],
    adjustments: const [],
    incomeAdjustments: const [],
    ephemeralInflows: const [],
    baseCurrency: 'EUR',
  );
}

class _TestMarketPriceService extends MarketPriceService {
  _TestMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(
    String ticker,
    String currency,
    DateTime from,
  ) async => const {};
}

AllSeriesData _providerLiveData() => AllSeriesData(
  firstDate: DateTime(2024, 1, 1),
  accounts: const [],
  assetInvested: const [
    ChartSeries(
      key: 'asset_invested:1',
      name: 'invested',
      color: Colors.orange,
      spots: [FlSpot(0, 100)],
    ),
  ],
  assetMarket: const [
    ChartSeries(
      key: 'asset_market:1',
      name: 'market',
      color: Colors.blue,
      spots: [FlSpot(0, 100), FlSpot(10, 150)],
    ),
  ],
  assetGain: const [],
  assetNet: const [],
  adjustments: const [],
  incomeAdjustments: const [],
  ephemeralInflows: const [],
  baseCurrency: 'EUR',
);

AllSeriesData _providerWaybackData() => AllSeriesData(
  firstDate: DateTime(2024, 1, 1),
  accounts: const [],
  assetInvested: const [
    ChartSeries(
      key: 'asset_invested:1',
      name: 'invested',
      color: Colors.orange,
      spots: [FlSpot(0, 100)],
    ),
  ],
  assetMarket: const [
    ChartSeries(
      key: 'asset_market:1',
      name: 'market',
      color: Colors.blue,
      spots: [FlSpot(0, 100), FlSpot(5, 120)],
    ),
  ],
  assetGain: const [],
  assetNet: const [],
  adjustments: const [],
  incomeAdjustments: const [],
  ephemeralInflows: const [],
  baseCurrency: 'EUR',
);
