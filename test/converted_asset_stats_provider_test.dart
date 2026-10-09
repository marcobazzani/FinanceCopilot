// Regression: `convertedAssetStatsProvider` must apply the SAME
// moving-average-cost algorithm as `AssetService._computeAssetStats` to
// foreign-currency assets, not a separate lifetime-average formula.
//
// Before this fix, the foreign-currency path summed every buy's
// base-currency amount and quantity over the asset's ENTIRE history,
// divided once for a lifetime average, then multiplied by the currently
// held quantity. That blends a fully-disposed lot's cost into a
// re-opened position — the same bug fixed for same-currency assets in
// AssetService, but re-implemented (and re-broken) separately here.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/asset_event_service.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';

class _TestMarketPriceService extends MarketPriceService {
  _TestMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late int intermediaryId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    intermediaryId = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
        marketPriceServiceProvider.overrideWithValue(_TestMarketPriceService(db)),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<int> seedUsdAsset() => db
      .into(db.assets)
      .insert(
        AssetsCompanion.insert(
          name: 'US Fund',
          assetType: AssetType.stockEtf,
          valuationMethod: ValuationMethod.marketPrice,
          intermediaryId: intermediaryId,
          currency: const Value('USD'),
        ),
      );

  Future<void> seedEurUsdRate(DateTime date, double eurToUsd) async {
    await db
        .into(db.exchangeRates)
        .insert(
          ExchangeRatesCompanion.insert(fromCurrency: 'EUR', toCurrency: 'USD', date: date, rate: eurToUsd),
        );
    await db
        .into(db.exchangeRates)
        .insert(
          ExchangeRatesCompanion.insert(fromCurrency: 'USD', toCurrency: 'EUR', date: date, rate: 1 / eurToUsd),
        );
  }

  test(
    'a foreign-currency position re-opened after full liquidation is NOT blended with the disposed lot',
    () async {
      final assetId = await seedUsdAsset();
      await seedEurUsdRate(DateTime(2026, 1, 1), 1.0);
      await seedEurUsdRate(DateTime(2026, 1, 3), 1.0);

      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2026, 1, 1),
              valueDate: DateTime(2026, 1, 1),
              type: EventType.buy,
              amount: 100,
              quantity: const Value(1),
              currency: const Value('USD'),
            ),
          );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2026, 1, 2),
              valueDate: DateTime(2026, 1, 2),
              type: EventType.sell,
              amount: 100,
              quantity: const Value(1),
              currency: const Value('USD'),
            ),
          );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2026, 1, 3),
              valueDate: DateTime(2026, 1, 3),
              type: EventType.buy,
              amount: 200,
              quantity: const Value(1),
              currency: const Value('USD'),
            ),
          );

      final stats = await AssetService(db).getStatsForAll();
      final asset = await AssetService(db).getById(assetId);
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
          marketPriceServiceProvider.overrideWithValue(_TestMarketPriceService(db)),
          assetsProvider.overrideWithValue(AsyncData([asset])),
          assetStatsProvider.overrideWithValue(AsyncData(stats)),
        ],
      );

      final converted = await container.read(convertedAssetStatsProvider.future);
      // 1 share @ 200 USD, EUR/USD=1.0 → 200 EUR — the disposed 100 EUR lot
      // must NOT be blended in (that would give the old, wrong 150).
      expect(converted[assetId], 200);
    },
  );

  test(
    'a base currency change preserves the stored rate but resolves a fresh one for the new base (regression)',
    () async {
      final assetId = await seedUsdAsset();
      // EUR/USD = 2.0 (what the event carries, quoted while EUR was base) and
      // GBP/USD = 4.0 (the rate that must be used once GBP becomes base).
      await db
          .into(db.exchangeRates)
          .insert(ExchangeRatesCompanion.insert(fromCurrency: 'GBP', toCurrency: 'USD', date: DateTime(2026, 1, 1), rate: 4));
      await db
          .into(db.exchangeRates)
          .insert(ExchangeRatesCompanion.insert(fromCurrency: 'USD', toCurrency: 'GBP', date: DateTime(2026, 1, 1), rate: 0.25));

      final eventId = await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2026, 1, 1),
              valueDate: DateTime(2026, 1, 1),
              type: EventType.buy,
              amount: 100,
              quantity: const Value(1),
              currency: const Value('USD'),
              exchangeRate: const Value(2.0), // quoted while base was EUR
            ),
          );

      final events = await db.select(db.assetEvents).get();
      var testContainer = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          baseCurrencyProvider.overrideWithValue(const AsyncData('GBP')),
          marketPriceServiceProvider.overrideWithValue(_TestMarketPriceService(db)),
          assetEventsProvider(assetId).overrideWithValue(AsyncData(events)),
        ],
      );
      addTearDown(testContainer.dispose);

      // Before the base change is registered, the unstamped rate reads as
      // "quoted against the current base" — that is the whole reason the
      // settings hook must stamp it.
      final stale = await testContainer.read(convertedEventAmountsProvider(assetId).future);
      expect(stale[eventId], 50, reason: '100 / 2.0 — the EUR-quoted rate taken at face value');

      // Simulate the settings-save hook: stamp the OUTGOING base.
      await AssetEventService(db).stampExchangeRateBase('EUR');
      testContainer.dispose();
      testContainer = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          baseCurrencyProvider.overrideWithValue(const AsyncData('GBP')),
          marketPriceServiceProvider.overrideWithValue(_TestMarketPriceService(db)),
          assetEventsProvider(assetId).overrideWithValue(AsyncData(await db.select(db.assetEvents).get())),
        ],
      );
      addTearDown(testContainer.dispose);

      final fresh = await testContainer.read(convertedEventAmountsProvider(assetId).future);
      expect(fresh[eventId], 25, reason: '100 / 4.0 — the correct GBP/USD rate is resolved instead');

      // The original rate is still on the row: it is user/broker-supplied data
      // in the general case, and deleting it to force a re-resolve would be
      // unrecoverable.
      final after = await db.select(db.assetEvents).get();
      final row = after.firstWhere((e) => e.id == eventId);
      expect(row.exchangeRate, 2.0, reason: 'the EUR-quoted rate must survive the base change');
      expect(row.exchangeRateBase, 'EUR', reason: 'and must now record which base it belonged to');
    },
  );

  test('a cash-only contribution is not dropped when another buy carries a quantity', () async {
    final assetId = await seedUsdAsset();
    await seedEurUsdRate(DateTime(2026, 1, 1), 1.0);
    await seedEurUsdRate(DateTime(2026, 2, 1), 1.0);

    // A contribution with no per-share quantity, then a normal 2-share buy.
    await db
        .into(db.assetEvents)
        .insert(
          AssetEventsCompanion.insert(
            assetId: assetId,
            date: DateTime(2026, 1, 1),
            valueDate: DateTime(2026, 1, 1),
            type: EventType.buy,
            amount: 100,
            currency: const Value('USD'),
          ),
        );
    await db
        .into(db.assetEvents)
        .insert(
          AssetEventsCompanion.insert(
            assetId: assetId,
            date: DateTime(2026, 2, 1),
            valueDate: DateTime(2026, 2, 1),
            type: EventType.buy,
            amount: 200,
            quantity: const Value(2),
            currency: const Value('USD'),
          ),
        );

    final stats = await AssetService(db).getStatsForAll();
    final asset = await AssetService(db).getById(assetId);
    final testContainer = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
        marketPriceServiceProvider.overrideWithValue(_TestMarketPriceService(db)),
        assetsProvider.overrideWithValue(AsyncData([asset])),
        assetStatsProvider.overrideWithValue(AsyncData(stats)),
      ],
    );
    addTearDown(testContainer.dispose);

    final converted = await testContainer.read(convertedAssetStatsProvider.future);
    expect(
      converted[assetId],
      300,
      reason: 'nothing was sold — the 100 cash contribution plus the 200 share purchase are both invested',
    );
  });
}
