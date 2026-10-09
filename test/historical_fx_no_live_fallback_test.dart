// A past amount converted at TODAY's rate is a wrong figure: the cost of a
// buy made when the rate was different is not what it would cost today.
// When no rate exists on or before the event's day (and none is stored on
// the event), the base-currency cost basis and the per-event "≈" amount are
// unknown — not converted with the live rate, as they used to be.
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
  late AppDatabase db;
  late int assetId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    assetId = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'US Fund',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: broker,
            currency: const Value('USD'),
          ),
        );
  });
  tearDown(() => db.close());

  Future<int> buy(DateTime day, double amount, double qty) => db
      .into(db.assetEvents)
      .insert(
        AssetEventsCompanion.insert(
          assetId: assetId,
          date: day,
          valueDate: day,
          type: EventType.buy,
          amount: amount,
          quantity: Value(qty),
          currency: const Value('USD'),
        ),
      );

  /// EUR→USD stored on [day] only (both directions): the latest stored rate
  /// is what a live lookup falls back to offline.
  Future<void> rateOn(DateTime day, double eurUsd) async {
    await db.into(db.exchangeRates).insert(ExchangeRatesCompanion.insert(fromCurrency: 'EUR', toCurrency: 'USD', date: day, rate: eurUsd));
    await db.into(db.exchangeRates).insert(ExchangeRatesCompanion.insert(fromCurrency: 'USD', toCurrency: 'EUR', date: day, rate: 1 / eurUsd));
  }

  Future<ProviderContainer> containerFor() async {
    final assets = await AssetService(db).getAll();
    final stats = await AssetService(db).getStatsForAll();
    final events = await db.select(db.assetEvents).get();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
        marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
        assetsProvider.overrideWithValue(AsyncData(assets)),
        assetStatsProvider.overrideWithValue(AsyncData(stats)),
        assetEventsProvider(assetId).overrideWithValue(AsyncData(events)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('no rate on or before the buy day: the cost basis is unknown, not converted at the latest rate', () async {
    await buy(DateTime(2024, 1, 10), 1000, 10);
    await rateOn(DateTime(2024, 6, 3), 1.25);

    final container = await containerFor();
    final converted = await container.read(convertedAssetStatsProvider.future);
    expect(converted.containsKey(assetId), isTrue, reason: 'the asset is reported');
    expect(converted[assetId], isNull, reason: '1000 USD at a June rate (800 EUR) is not what a January buy cost');
  });

  test('no rate on or before the buy day: no "≈" amount for that event', () async {
    final january = await buy(DateTime(2024, 1, 10), 1000, 10);
    final july = await buy(DateTime(2024, 7, 1), 500, 5);
    await rateOn(DateTime(2024, 6, 3), 1.25);

    final container = await containerFor();
    final amounts = await container.read(convertedEventAmountsProvider(assetId).future);
    expect(amounts.containsKey(january), isFalse);
    expect(amounts[july], 500 / 1.25, reason: 'a rate on or before the July buy exists');
  });

  test('a rate on or before every buy: converted at each buy\'s own rate', () async {
    await rateOn(DateTime(2024, 1, 2), 1.1);
    await buy(DateTime(2024, 1, 10), 1100, 10);
    await rateOn(DateTime(2024, 6, 3), 1.25);
    await buy(DateTime(2024, 7, 1), 500, 5);

    final container = await containerFor();
    final converted = await container.read(convertedAssetStatsProvider.future);
    expect(converted[assetId], 1100 / 1.1 + 500 / 1.25);
  });
}
