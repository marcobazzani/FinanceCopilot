// Pins the moving-average cost basis computed from an asset's events, in the
// asset's currency (AssetService stats) and in the base currency with each
// buy converted at its own rate (convertedAssetStatsProvider). Expected
// figures are exact doubles captured from the implementation before the two
// copies of the pool were merged into one: the merge must be bit-identical.
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

/// One event: (day offset, type, amount, quantity, stored EUR→USD rate).
typedef _Ev = (int, EventType, double, double?, double?);

/// Fractional amounts and quantities, partial sells, a cash-only
/// contribution, a revalue, a sell stored with a negative quantity, and two
/// same-day events (id order decides).
const List<_Ev> _mixed = [
  (0, EventType.buy, 99.99, 3, null),
  (3, EventType.buy, 312.75, 7.5, 1.0873),
  (5, EventType.sell, 150.1, 2.25, null),
  (8, EventType.buy, 50.5, null, null),
  (9, EventType.revalue, 900, null, null),
  (12, EventType.sell, 170.3, -4.1, null),
  (12, EventType.buy, 59.3814, 1.3, null),
  (20, EventType.buy, 1234.567, 17.77, 1.1111),
  (25, EventType.sell, 400, 6.6, null),
];

/// Everything sold, then bought back at another price.
const List<_Ev> _reopened = [
  (0, EventType.buy, 100.37, 1.7, null),
  (2, EventType.sell, 190, 1.7, null),
  (4, EventType.buy, 211.11, 1.3, null),
  (6, EventType.buy, 33.3, 0.45, null),
];

/// More sold than the pool holds, plus a cash-only contribution.
const List<_Ev> _oversold = [
  (0, EventType.buy, 20.2, 2, null),
  (1, EventType.buy, 7.77, null, null),
  (2, EventType.sell, 45, 3, null),
];

void main() {
  final d0 = DateTime(2025, 1, 6);
  DateTime day(int n) => d0.add(Duration(days: n));

  late AppDatabase db;
  late int broker;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    // EUR→USD history: one rate per week, both directions stored.
    for (final (n, rate) in [(0, 1.0342), (7, 1.0417), (14, 1.0299), (21, 1.0486)]) {
      await db.into(db.exchangeRates).insert(ExchangeRatesCompanion.insert(fromCurrency: 'EUR', toCurrency: 'USD', date: day(n), rate: rate));
      await db
          .into(db.exchangeRates)
          .insert(ExchangeRatesCompanion.insert(fromCurrency: 'USD', toCurrency: 'EUR', date: day(n), rate: 1 / rate));
    }
  });
  tearDown(() => db.close());

  Future<int> seed(String name, String currency, List<_Ev> events) async {
    final id = await db
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
    for (final (n, type, amount, qty, rate) in events) {
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: id,
              date: day(n),
              valueDate: day(n),
              type: type,
              amount: amount,
              quantity: Value(qty),
              currency: Value(currency),
              exchangeRate: Value(rate),
            ),
          );
    }
    return id;
  }

  test('asset currency: cost basis and held quantity', () async {
    final mixed = await seed('Mixed', 'EUR', _mixed);
    final reopened = await seed('Reopened', 'EUR', _reopened);
    final oversold = await seed('Oversold', 'EUR', _oversold);

    final stats = await AssetService(db).getStatsForAll();
    expect(stats[mixed]!.totalInvested, _expected['eur.mixed.invested']);
    expect(stats[mixed]!.totalQuantity, _expected['eur.mixed.qty']);
    expect(stats[mixed]!.eventCount, 9);
    expect(stats[reopened]!.totalInvested, _expected['eur.reopened.invested']);
    expect(stats[reopened]!.totalQuantity, _expected['eur.reopened.qty']);
    expect(stats[oversold]!.totalInvested, _expected['eur.oversold.invested']);
    expect(stats[oversold]!.totalQuantity, _expected['eur.oversold.qty']);

    final watched = await AssetService(db).watchStatsForAll().first;
    expect(watched[mixed]!.totalInvested, _expected['eur.mixed.invested']);
  });

  test('base currency: each buy converted at its own rate, then the same pool', () async {
    final mixed = await seed('Mixed', 'USD', _mixed);
    final reopened = await seed('Reopened', 'USD', _reopened);
    final oversold = await seed('Oversold', 'USD', _oversold);

    final assets = await AssetService(db).getAll();
    final stats = await AssetService(db).getStatsForAll();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
        marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
        assetsProvider.overrideWithValue(AsyncData(assets)),
        assetStatsProvider.overrideWithValue(AsyncData(stats)),
      ],
    );
    addTearDown(container.dispose);

    final converted = await container.read(convertedAssetStatsProvider.future);
    expect(converted[mixed], _expected['base.mixed']);
    expect(converted[reopened], _expected['base.reopened']);
    expect(converted[oversold], _expected['base.oversold']);
  });
}

const _expected = <String, double>{
  'eur.mixed.invested': 1093.422157844223,
  'eur.mixed.qty': 16.619999999999997,
  'eur.reopened.invested': 244.41000000000003,
  'eur.reopened.qty': 1.75,
  'eur.oversold.invested': 7.77,
  'eur.oversold.qty': -1.0,
  'base.mixed': 993.3022844142872,
  'base.reopened': 236.32759620963066,
  'base.oversold': 7.513053567975246,
};
