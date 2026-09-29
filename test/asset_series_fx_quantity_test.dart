// allSeriesDataProvider — asset invested / market series edge cases.
//
//  * A stored FX rate is only used when it was quoted against the CURRENT
//    base currency (`AssetEventService.isExchangeRateUsableFor`). After a
//    base change the old rates are kept on the events, stamped with the base
//    they belonged to; applying one to the new base produced a wrong cost
//    basis on the invested / gain / net series.
//  * A buy or sell whose amount cannot be converted (no FX rate) still moves
//    the held QUANTITY. Dropping the whole event also dropped its units, so
//    the market-value series showed a position the user does not hold.
//  * A market price stored with a clock time (a revalue materialised at
//    15:42) must land on its calendar day: an off-grid day key meant the
//    price was never picked up by the day-keyed series.

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
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show allSeriesDataProvider, AllSeriesData;

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

  Future<int> asset(String currency) async {
    final intermediaryId = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    return db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'Fund',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: intermediaryId,
            currency: Value(currency),
          ),
        );
  }

  Future<void> buy(
    int assetId,
    DateTime on, {
    required double amount,
    required double qty,
    String currency = 'EUR',
    double? rate,
    String? rateBase,
  }) => db
      .into(db.assetEvents)
      .insert(
        AssetEventsCompanion.insert(
          assetId: assetId,
          date: on,
          valueDate: on,
          type: EventType.buy,
          amount: amount,
          quantity: Value(qty),
          price: Value(amount / qty),
          currency: Value(currency),
          exchangeRate: Value(rate),
          exchangeRateBase: Value(rateBase),
        ),
      );

  Future<void> price(int assetId, DateTime on, double close, {String currency = 'EUR'}) =>
      db.into(db.marketPrices).insert(MarketPricesCompanion.insert(assetId: assetId, date: on, closePrice: close, currency: currency));

  Future<void> fx(String from, String to, DateTime on, double rate) =>
      db.into(db.exchangeRates).insert(ExchangeRatesCompanion.insert(fromCurrency: from, toCurrency: to, date: on, rate: rate));

  Map<int, double>? byX(AllSeriesData data, String key) {
    final series = [...data.assetInvested, ...data.assetMarket].where((s) => s.key == key);
    if (series.isEmpty) return null;
    return {for (final s in series.single.spots) s.x.toInt(): s.y};
  }

  group('stored FX rate of a buy', () {
    test('a rate stamped with a previous base is not applied; the rate history of the current base is', () async {
      final a = await asset('USD');
      // 2.0 was quoted against GBP, the base before the user switched to EUR.
      await buy(a, day(0), amount: 1000, qty: 10, currency: 'USD', rate: 2.0, rateBase: 'GBP');
      await fx('USD', 'EUR', day(0), 0.9);

      final data = await container.read(allSeriesDataProvider.future);
      expect(byX(data!, 'asset_invested:$a')?[0], closeTo(900, 1e-9), reason: '1000 USD × 0.9 from history, not 1000 / 2.0');
    });

    test('a rate stamped with the current base, or never stamped, is applied as stored', () async {
      final stamped = await asset('USD');
      await buy(stamped, day(0), amount: 1000, qty: 10, currency: 'USD', rate: 1.25, rateBase: 'EUR');
      final unstamped = await asset('USD');
      await buy(unstamped, day(0), amount: 1000, qty: 10, currency: 'USD', rate: 1.6);
      await fx('USD', 'EUR', day(0), 0.9);

      final data = await container.read(allSeriesDataProvider.future);
      expect(byX(data!, 'asset_invested:$stamped')?[0], closeTo(800, 1e-9), reason: '1000 / 1.25');
      expect(byX(data, 'asset_invested:$unstamped')?[0], closeTo(625, 1e-9), reason: '1000 / 1.6');
    });

    test('a stale-base rate with no history to replace it leaves the amount out, never falls back to it', () async {
      final a = await asset('EUR');
      await buy(a, day(0), amount: 1000, qty: 10, currency: 'USD', rate: 2.0, rateBase: 'GBP');
      await price(a, day(0), 100);

      final data = await container.read(allSeriesDataProvider.future);
      expect(byX(data!, 'asset_invested:$a'), isEmpty, reason: 'no usable rate: no invested figure (the line is kept, without spots)');
      expect(byX(data, 'asset_market:$a')?[0], closeTo(1000, 1e-9), reason: 'the 10 units are still held');
    });
  });

  group('buy or sell without an FX rate', () {
    test('its quantity still counts in the market value; only its amount leaves the invested series', () async {
      final a = await asset('EUR');
      // The first buy was paid in USD and there is no USD/EUR rate at all.
      await buy(a, day(0), amount: 1100, qty: 10, currency: 'USD');
      await buy(a, day(2), amount: 100, qty: 1);
      for (var n = 0; n <= 3; n++) {
        await price(a, day(n), 100);
      }

      final data = await container.read(allSeriesDataProvider.future);
      final market = byX(data!, 'asset_market:$a');
      expect(market?[0], closeTo(1000, 1e-9), reason: '10 units × 100');
      expect(market?[2], closeTo(1100, 1e-9), reason: '11 units × 100');
      expect(market?[3], closeTo(1100, 1e-9));
      final invested = byX(data, 'asset_invested:$a');
      expect(invested?[2], closeTo(100, 1e-9), reason: 'only the convertible buy is in the cost basis');
      expect(invested?.containsKey(0), isFalse);
    });

    test('a sell without a rate still reduces the quantity', () async {
      final a = await asset('EUR');
      await buy(a, day(0), amount: 1000, qty: 10);
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: a,
              date: day(1),
              valueDate: day(1),
              type: EventType.sell,
              amount: 440,
              quantity: const Value(4),
              currency: const Value('USD'),
            ),
          );
      for (var n = 0; n <= 3; n++) {
        await price(a, day(n), 100);
      }

      final data = await container.read(allSeriesDataProvider.future);
      final market = byX(data!, 'asset_market:$a');
      expect(market?[0], closeTo(1000, 1e-9));
      expect(market?[1], closeTo(600, 1e-9), reason: '10 − 4 units × 100');
      expect(market?[3], closeTo(600, 1e-9));
    });
  });

  test('a price stored with a clock time is applied on its calendar day', () async {
    final a = await asset('EUR');
    await buy(a, day(0), amount: 1000, qty: 10);
    await price(a, day(0), 100);
    // e.g. a revalue entered at 15:42, materialised at its value date.
    await price(a, DateTime(d0.year, d0.month, d0.day + 1, 15, 42), 110);

    final data = await container.read(allSeriesDataProvider.future);
    final market = data!.assetMarket.singleWhere((s) => s.key == 'asset_market:$a');
    expect(market.spots.map((s) => s.x), [0, 1, 3], reason: 'one point per calendar day, none off the day grid');
    expect(market.spots.map((s) => s.y), [closeTo(1000, 1e-9), closeTo(1100, 1e-9), closeTo(1100, 1e-9)]);
  });
}
