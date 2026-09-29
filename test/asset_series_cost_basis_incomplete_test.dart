// allSeriesDataProvider — an asset whose cost basis is incomplete.
//
// A buy or sell whose amount has no rate to base still moves the units held
// (the market value sees them) but its amount stays out of the invested line.
// The gain (market − invested) and the net value (invested + taxed gain) were
// then computed against that partial cost basis: a buy left out read as a
// gain as large as what it bought, and the net series fed it into the Net
// Asset Value and the FIRE progress. Those figures are not drawn for such an
// asset — its gain and net series carry no spots — and the asset is counted,
// so a total built from them says what it left out.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/account_service.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart'
    show AllSeriesData, ChartSeries, allSeriesDataProvider, costBasisIncompleteAssetIds, totalExclusions;

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

void main() {
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

  Future<int> asset(String name) async {
    final intermediaryId = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: '$name broker'));
    return db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: name,
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: intermediaryId,
          ),
        );
  }

  Future<void> trade(
    int assetId,
    DateTime on,
    EventType type, {
    required double amount,
    required double qty,
    String currency = 'EUR',
    bool withPrice = true,
  }) => db
      .into(db.assetEvents)
      .insert(
        AssetEventsCompanion.insert(
          assetId: assetId,
          date: on,
          valueDate: on,
          type: type,
          amount: amount,
          quantity: Value(qty),
          price: Value(withPrice ? amount / qty : null),
          currency: Value(currency),
        ),
      );

  Future<void> closes(int assetId, double close) async {
    for (var n = 0; n <= 3; n++) {
      await db.into(db.marketPrices).insert(MarketPricesCompanion.insert(assetId: assetId, date: day(n), closePrice: close, currency: 'EUR'));
    }
  }

  ChartSeries? series(List<ChartSeries> list, String key) => list.where((s) => s.key == key).firstOrNull;

  group('a buy without a rate to base', () {
    Future<(AllSeriesData, int)> seed() async {
      final a = await asset('Fund');
      // 10 units paid in USD, and there is no USD/EUR rate at all; 1 more in EUR.
      await trade(a, day(0), EventType.buy, amount: 1100, qty: 10, currency: 'USD');
      await trade(a, day(2), EventType.buy, amount: 100, qty: 1);
      await closes(a, 100);
      return ((await container.read(allSeriesDataProvider.future))!, a);
    }

    test('keeps its market value but draws no gain and no net value against the partial cost basis', () async {
      final (data, a) = await seed();

      expect(series(data.assetMarket, 'asset_market:$a')!.spots.map((s) => s.y), [1000, 1000, 1100, 1100], reason: 'the units are held');
      final gain = series(data.assetGain, 'asset_gain:$a');
      expect(gain, isNotNull, reason: 'the asset keeps its gain series, so a total built from it can count it');
      expect(gain!.spots, isEmpty, reason: '1,100 of value against 100 of cost is not a gain of 1,000');
      final net = series(data.assetNet, 'asset_net:$a');
      expect(net, isNotNull);
      expect(net!.spots, isEmpty, reason: 'the net value taxes that fake gain');
    });

    test('is left out of a Net Asset Value total and counted, never added at a wrong value', () async {
      final (data, a) = await seed();

      expect(totalExclusions(data.assetNet, data).unpricedAssetIds, {a});
      expect(costBasisIncompleteAssetIds(data), {a});
    });
  });

  test('a sell without a rate to base: the same', () async {
    final a = await asset('Fund');
    await trade(a, day(0), EventType.buy, amount: 1000, qty: 10);
    // The proceeds of 4 units came in USD: the invested line never goes down.
    await trade(a, day(1), EventType.sell, amount: 440, qty: 4, currency: 'USD');
    await closes(a, 100);

    final data = (await container.read(allSeriesDataProvider.future))!;
    expect(series(data.assetMarket, 'asset_market:$a')!.spots.last.y, closeTo(600, 1e-9));
    expect(series(data.assetGain, 'asset_gain:$a')!.spots, isEmpty, reason: '600 of value against 1,000 of cost is not a loss of 400');
    expect(series(data.assetNet, 'asset_net:$a')!.spots, isEmpty);
    expect(costBasisIncompleteAssetIds(data), {a});
  });

  test('every buy without a rate: gain and net series are still there, empty, and the asset is counted', () async {
    final a = await asset('Fund');
    await trade(a, day(0), EventType.buy, amount: 1100, qty: 10, currency: 'USD');
    await closes(a, 100);

    final data = (await container.read(allSeriesDataProvider.future))!;
    expect(series(data.assetMarket, 'asset_market:$a')!.spots, isNotEmpty);
    expect(
      series(data.assetInvested, 'asset_invested:$a')!.spots,
      isEmpty,
      reason: 'no amount converts: no invested figure (the line is kept so a total built from it counts the asset)',
    );
    expect(series(data.assetGain, 'asset_gain:$a')!.spots, isEmpty);
    expect(series(data.assetNet, 'asset_net:$a')!.spots, isEmpty, reason: 'a missing net series would drop it from the NAV silently');
    expect(totalExclusions(data.assetNet, data).unpricedAssetIds, {a});
    expect(costBasisIncompleteAssetIds(data), {a});
  });

  test('a complete cost basis keeps its gain and net value, and nothing is counted', () async {
    final complete = await asset('Complete');
    await trade(complete, day(0), EventType.buy, amount: 900, qty: 10);
    await closes(complete, 100);
    final incomplete = await asset('Incomplete');
    await trade(incomplete, day(0), EventType.buy, amount: 1100, qty: 10, currency: 'USD');
    await closes(incomplete, 100);

    final data = (await container.read(allSeriesDataProvider.future))!;
    expect(series(data.assetGain, 'asset_gain:$complete')!.spots.map((s) => s.y), everyElement(closeTo(100, 1e-9)));
    expect(series(data.assetNet, 'asset_net:$complete')!.spots.map((s) => s.y), everyElement(closeTo(900 + 100 * 0.74, 1e-9)));
    expect(costBasisIncompleteAssetIds(data), {incomplete}, reason: 'only the asset with an unconvertible buy');
  });

  test('an unpriced asset is counted as unpriced, not as an incomplete cost basis', () async {
    final a = await asset('Unpriced');
    // No close and no unit price on the buy: no market value at all.
    await trade(a, day(0), EventType.buy, amount: 1100, qty: 10, currency: 'USD', withPrice: false);

    final data = (await container.read(allSeriesDataProvider.future))!;
    expect(series(data.assetMarket, 'asset_market:$a')!.spots, isEmpty);
    expect(costBasisIncompleteAssetIds(data), isEmpty);
    expect(totalExclusions(data.assetNet, data).unpricedAssetIds, {a}, reason: 'still left out of the NAV and counted');
  });

  test('viewed before the unconvertible buy (wayback), the cost basis is complete', () async {
    final a = await asset('Fund');
    await trade(a, day(0), EventType.buy, amount: 900, qty: 10);
    await trade(a, day(2), EventType.buy, amount: 110, qty: 1, currency: 'USD');
    await closes(a, 100);
    container.read(waybackDateProvider.notifier).state = day(1);

    final data = (await container.read(allSeriesDataProvider.future))!;
    expect(series(data.assetGain, 'asset_gain:$a')!.spots.map((s) => s.y), everyElement(closeTo(100, 1e-9)));
    expect(costBasisIncompleteAssetIds(data), isEmpty);
  });
}
