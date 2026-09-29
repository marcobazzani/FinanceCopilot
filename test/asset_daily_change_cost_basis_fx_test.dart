// The price change of a foreign-currency asset when the reference date
// predates its first buy (e.g. 'All'): the reference is what the position
// cost. It used to be the average buy price converted at TODAY's rate, so the
// change in base currency lost the currency gain or loss since purchase — a
// USD position bought at 0.91 EUR/USD, now at 0.85, price unchanged, showed
// 0% instead of −6.6% and disagreed with the gain on the Assets screen. The
// cost is now in base currency at the buys' own rates (the stored rate when
// usable, else the rate on the buy's value date); a buy without either
// leaves the asset out of the list, like every other missing rate.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

void main() {
  final bought = DateTime(2025, 3, 3);
  final today = DateTime(2025, 6, 2);
  final beforeAnyBuy = DateTime(2000, 1, 1);

  late AppDatabase db;
  late int broker;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
  });
  tearDown(() => db.close());

  Future<int> asset(String name, {String currency = 'USD'}) => db
      .into(db.assets)
      .insert(
        AssetsCompanion.insert(
          name: name,
          assetType: AssetType.stockEtf,
          valuationMethod: ValuationMethod.marketPrice,
          intermediaryId: broker,
          currency: Value(currency),
        ),
      );

  Future<void> trade(int assetId, DateTime on, EventType type, double qty, double price, {String currency = 'USD', double? rate}) => db
      .into(db.assetEvents)
      .insert(
        AssetEventsCompanion.insert(
          assetId: assetId,
          date: on,
          valueDate: on,
          type: type,
          amount: qty * price,
          quantity: Value(qty),
          price: Value(price),
          currency: Value(currency),
          exchangeRate: Value(rate),
        ),
      );

  Future<void> close(int assetId, DateTime on, double price, {String currency = 'USD'}) =>
      db.into(db.marketPrices).insert(MarketPricesCompanion.insert(assetId: assetId, date: on, closePrice: price, currency: currency));

  /// One EUR/USD quote on [on]: [usdInEur] euros per dollar, both directions.
  Future<void> usdRate(DateTime on, double usdInEur) async {
    await db.into(db.exchangeRates).insert(ExchangeRatesCompanion.insert(fromCurrency: 'USD', toCurrency: 'EUR', date: on, rate: usdInEur));
    await db.into(db.exchangeRates).insert(ExchangeRatesCompanion.insert(fromCurrency: 'EUR', toCurrency: 'USD', date: on, rate: 1 / usdInEur));
  }

  Future<ProviderContainer> container() async {
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
        nowProvider.overrideWithValue(() => today.add(const Duration(hours: 12))),
        marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
        assetsProvider.overrideWithValue(AsyncData(await AssetService(db).getAll())),
        assetStatsProvider.overrideWithValue(AsyncData(await AssetService(db).getStatsForAll())),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<List<AssetDailyChange>> changesSince(DateTime reference) async => (await container()).read(assetDailyChangesProvider(reference).future);

  double previousValue(AssetDailyChange c) => c.previousPrice * c.quantity / c.priceDivisor * c.previousFxRate;

  test('price unchanged, the dollar down from 0.91 to 0.85: the change is the currency loss', () async {
    final a = await asset('US Stock');
    await trade(a, bought, EventType.buy, 10, 100);
    await usdRate(bought, 0.91);
    await usdRate(today, 0.85);
    await close(a, bought, 100);
    await close(a, today, 100);

    final change = (await changesSince(beforeAnyBuy)).single;
    expect(change.pricePct, 0, reason: 'the price in dollars did not move');
    expect(previousValue(change), closeTo(910, 1e-9), reason: '1,000 USD at the 0.91 of the buy');
    expect(change.valueDiff, closeTo(850 - 910, 1e-9));
    expect(change.valueDiff / previousValue(change) * 100, closeTo(-6.593, 1e-3));
  });

  test('agrees with the gain on the Assets screen: market value minus the cost in base', () async {
    final a = await asset('US Stock');
    await trade(a, bought, EventType.buy, 10, 100);
    await trade(a, DateTime(2025, 4, 1), EventType.buy, 10, 120);
    await trade(a, DateTime(2025, 5, 2), EventType.sell, 5, 130);
    await usdRate(bought, 0.91);
    await usdRate(DateTime(2025, 4, 1), 0.8);
    await usdRate(today, 0.87);
    await close(a, today, 125);

    final c = await container();
    final change = (await c.read(assetDailyChangesProvider(beforeAnyBuy).future)).single;
    final marketValue = (await c.read(assetMarketValuesProvider.future))[a]!;
    final costInBase = (await c.read(convertedAssetStatsProvider.future))[a]!;
    expect(costInBase, closeTo((910 + 960) * 15 / 20, 1e-9));
    expect(previousValue(change), closeTo(costInBase, 1e-9));
    expect(change.valueDiff, closeTo(marketValue - costInBase, 1e-9));
  });

  test("a rate stored on the buy is the buy's rate", () async {
    final a = await asset('US Stock');
    // 1 EUR = 1.25 USD when bought: 1,000 USD cost 800 EUR. No quote that day.
    await trade(a, bought, EventType.buy, 10, 100, rate: 1.25);
    await usdRate(today, 0.85);
    await close(a, today, 100);

    final change = (await changesSince(beforeAnyBuy)).single;
    expect(change.previousFxRate, closeTo(0.8, 1e-12));
    expect(change.valueDiff, closeTo(850 - 800, 1e-9));
  });

  test('a buy without a rate of its own is left out, never valued at today\'s rate', () async {
    final a = await asset('US Stock');
    await trade(a, bought, EventType.buy, 10, 100);
    await usdRate(today, 0.85); // the only quote is after the buy
    await close(a, today, 100);

    expect(await changesSince(beforeAnyBuy), isEmpty);
  });

  test('pinned: a base-currency asset compares with its average buy price', () async {
    final a = await asset('EU Stock', currency: 'EUR');
    await trade(a, bought, EventType.buy, 10, 100, currency: 'EUR');
    await trade(a, DateTime(2025, 4, 1), EventType.buy, 10, 110, currency: 'EUR');
    await close(a, today, 120, currency: 'EUR');

    final change = (await changesSince(beforeAnyBuy)).single;
    expect(change.previousPrice, 105);
    expect(change.previousFxRate, 1.0);
    expect(change.todayFxRate, 1.0);
    expect(change.valueDiff, 120 * 20 - 105 * 20);
  });

  test('pinned: a reference after the first buy still uses the rate of the reference day', () async {
    final a = await asset('US Stock');
    await trade(a, bought, EventType.buy, 10, 100);
    await usdRate(bought, 0.91);
    await usdRate(DateTime(2025, 5, 2), 0.88);
    await usdRate(today, 0.85);
    await close(a, DateTime(2025, 5, 2), 105);
    await close(a, today, 100);

    final change = (await changesSince(DateTime(2025, 5, 2))).single;
    expect(change.previousPrice, 105);
    expect(change.previousFxRate, closeTo(0.88, 1e-12));
  });
}
