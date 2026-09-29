// The price-change list needs the base-currency cost basis
// (convertedAssetStatsProvider, a walk over every asset's events) for one
// case only: a foreign-currency asset whose reference date precedes its first
// buy. It used to wait for that walk on every read, so every figure — a
// base-currency asset's too — waited for it and failed with it.
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

  Future<int> asset(String name, String currency) => db
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

  Future<void> buy(int assetId, DateTime on, double qty, double price, String currency) => db
      .into(db.assetEvents)
      .insert(
        AssetEventsCompanion.insert(
          assetId: assetId,
          date: on,
          valueDate: on,
          type: EventType.buy,
          amount: qty * price,
          quantity: Value(qty),
          price: Value(price),
          currency: Value(currency),
        ),
      );

  Future<void> close(int assetId, DateTime on, double price, String currency) =>
      db.into(db.marketPrices).insert(MarketPricesCompanion.insert(assetId: assetId, date: on, closePrice: price, currency: currency));

  Future<void> usdRate(DateTime on, double usdInEur) async {
    await db.into(db.exchangeRates).insert(ExchangeRatesCompanion.insert(fromCurrency: 'USD', toCurrency: 'EUR', date: on, rate: usdInEur));
    await db.into(db.exchangeRates).insert(ExchangeRatesCompanion.insert(fromCurrency: 'EUR', toCurrency: 'USD', date: on, rate: 1 / usdInEur));
  }

  var costBasisBuilds = 0;

  /// The price changes since [reference], with the cost basis answered by
  /// [costBasis] and every build of it counted in [costBasisBuilds].
  Future<List<AssetDailyChange>> changesSince(DateTime reference, Future<Map<int, double?>> Function() costBasis) async {
    costBasisBuilds = 0;
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
        nowProvider.overrideWithValue(() => today.add(const Duration(hours: 12))),
        marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
        assetsProvider.overrideWithValue(AsyncData(await AssetService(db).getAll())),
        assetStatsProvider.overrideWithValue(AsyncData(await AssetService(db).getStatsForAll())),
        convertedAssetStatsProvider.overrideWith((ref) {
          costBasisBuilds++;
          return costBasis();
        }),
      ],
    );
    addTearDown(c.dispose);
    return c.read(assetDailyChangesProvider(reference).future);
  }

  Future<Map<int, double?>> failingWalk() async => throw StateError('cost basis walk failed');

  test('a base-currency asset before its first buy: computed without the cost basis, which is never built', () async {
    final a = await asset('EU Stock', 'EUR');
    await buy(a, bought, 10, 100, 'EUR');
    await buy(a, DateTime(2025, 4, 1), 10, 110, 'EUR');
    await close(a, today, 120, 'EUR');

    final change = (await changesSince(beforeAnyBuy, failingWalk)).single;
    expect(change.previousPrice, 105, reason: 'the average buy price');
    expect(change.previousFxRate, 1.0);
    expect(change.valueDiff, 120 * 20 - 105 * 20);
    expect(costBasisBuilds, 0);
  });

  test('a foreign asset after its first buy: the reference-day rate, the cost basis is never built', () async {
    final a = await asset('US Stock', 'USD');
    await buy(a, bought, 10, 100, 'USD');
    await usdRate(bought, 0.91);
    await usdRate(DateTime(2025, 5, 2), 0.88);
    await usdRate(today, 0.85);
    await close(a, DateTime(2025, 5, 2), 105, 'USD');
    await close(a, today, 100, 'USD');

    final change = (await changesSince(DateTime(2025, 5, 2), failingWalk)).single;
    expect(change.previousPrice, 105);
    expect(change.previousFxRate, closeTo(0.88, 1e-12));
    expect(costBasisBuilds, 0);
  });

  test('a foreign asset before its first buy: the reference is its cost basis in base currency', () async {
    final eu = await asset('EU Stock', 'EUR');
    await buy(eu, bought, 10, 100, 'EUR');
    await close(eu, today, 100, 'EUR');
    final us = await asset('US Stock', 'USD');
    await buy(us, bought, 10, 100, 'USD');
    await usdRate(today, 0.85);
    await close(us, today, 100, 'USD');

    final changes = await changesSince(beforeAnyBuy, () async => {us: 910.0});
    final change = changes.singleWhere((c) => c.name == 'US Stock');
    expect(change.previousFxRate, closeTo(0.91, 1e-12), reason: '910 EUR paid for 1,000 USD');
    expect(change.valueDiff, closeTo(850 - 910, 1e-9));
    expect(changes.map((c) => c.name), ['EU Stock', 'US Stock']);
    expect(costBasisBuilds, 1);
  });

  test('a foreign asset before its first buy still fails with its cost basis, never valued without it', () async {
    final a = await asset('US Stock', 'USD');
    await buy(a, bought, 10, 100, 'USD');
    await usdRate(today, 0.85);
    await close(a, today, 100, 'USD');

    await expectLater(changesSince(beforeAnyBuy, failingWalk), throwsA(isA<StateError>()));
  });
}
