// The base-currency cost basis converts every buy from the currency it was
// recorded in — also for an asset whose own currency is the base one. Such an
// asset used to take its stats' cost basis as is, which adds up each buy's
// amount unconverted: a buy recorded in another currency without a rate for
// its day gave a cost basis — and so a gain — that could not be known.
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
            name: 'EU Fund',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: broker,
            currency: const Value('EUR'),
          ),
        );
  });
  tearDown(() => db.close());

  Future<void> event(DateTime day, EventType type, double amount, double? qty, {String currency = 'EUR'}) => db
      .into(db.assetEvents)
      .insert(
        AssetEventsCompanion.insert(
          assetId: assetId,
          date: day,
          valueDate: day,
          type: type,
          amount: amount,
          quantity: Value(qty),
          currency: Value(currency),
        ),
      );

  Future<double?> convertedCostBasis() async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
        marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
        assetsProvider.overrideWithValue(AsyncData(await AssetService(db).getAll())),
        assetStatsProvider.overrideWithValue(AsyncData(await AssetService(db).getStatsForAll())),
      ],
    );
    addTearDown(container.dispose);
    final converted = await container.read(convertedAssetStatsProvider.future);
    expect(converted.containsKey(assetId), isTrue, reason: 'the asset is reported');
    return converted[assetId];
  }

  test('pinned: every buy in the base currency — the same cost basis as the asset stats', () async {
    await event(DateTime(2025, 1, 6), EventType.buy, 99.99, 3);
    await event(DateTime(2025, 1, 9), EventType.buy, 312.75, 7.5);
    await event(DateTime(2025, 1, 11), EventType.sell, 150.1, 2.25);
    await event(DateTime(2025, 1, 14), EventType.buy, 50.5, null);
    await event(DateTime(2025, 1, 18), EventType.sell, 170.3, -4.1);
    await event(DateTime(2025, 1, 18), EventType.buy, 59.3814, 1.3);

    final stats = await AssetService(db).getStatsForAll();
    expect(await convertedCostBasis(), stats[assetId]!.totalInvested);
  });

  test('a buy recorded in another currency with no rate for its day: the cost basis is unknown, not its unconverted amount', () async {
    await event(DateTime(2025, 1, 10), EventType.buy, 1000, 10, currency: 'USD');

    expect(await convertedCostBasis(), isNull, reason: '1000 USD is not a cost of 1000 EUR');
  });

  test('a buy recorded in another currency with a rate for its day: converted at that rate', () async {
    await db
        .into(db.exchangeRates)
        .insert(ExchangeRatesCompanion.insert(fromCurrency: 'EUR', toCurrency: 'USD', date: DateTime(2025, 1, 2), rate: 1.25));
    await event(DateTime(2025, 1, 10), EventType.buy, 1000, 10, currency: 'USD');
    await event(DateTime(2025, 2, 10), EventType.buy, 500, 5);

    expect(await convertedCostBasis(), 1000 / 1.25 + 500);
  });
}
