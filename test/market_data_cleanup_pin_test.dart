// Pins for the market-data clean-up:
// - the provider page address of an asset in the price-change list: the
//   settings row cached under its search term (ISIN, else ticker) and its
//   exchange (Milan when unset), a relative path made absolute on the
//   provider host; none without a search term or a cached row. One lookup,
//   owned by the market data service.
// - the close of a price-history row: a number or a numeric string, positive;
//   a row that is not an object is skipped instead of failing the lookup.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/market/web_market_data_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';

void main() {
  final bought = DateTime(2025, 3, 3);
  final today = DateTime(2025, 6, 2);

  late AppDatabase db;
  late int broker;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
  });
  tearDown(() => db.close());

  Future<int> asset(String name, {String? isin, String? ticker, String? exchange}) async {
    final id = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: name,
            isin: Value(isin),
            ticker: Value(ticker),
            exchange: Value(exchange),
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
            date: bought,
            valueDate: bought,
            type: EventType.buy,
            amount: 1000,
            quantity: const Value(10),
            price: const Value(100),
            currency: const Value('EUR'),
          ),
        );
    await db.into(db.marketPrices).insert(MarketPricesCompanion.insert(assetId: id, date: today, closePrice: 110, currency: 'EUR'));
    return id;
  }

  Future<void> putConfig(String key, String value) => db.into(db.appConfigs).insert(AppConfigsCompanion.insert(key: key, value: value));

  Future<Map<String, String?>> providerUrls(MarketPriceService service) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
        nowProvider.overrideWithValue(() => today.add(const Duration(hours: 12))),
        marketPriceServiceProvider.overrideWithValue(service),
        assetsProvider.overrideWithValue(AsyncData(await AssetService(db).getAll())),
        assetStatsProvider.overrideWithValue(AsyncData(await AssetService(db).getStatsForAll())),
      ],
    );
    addTearDown(container.dispose);
    final changes = await container.read(assetDailyChangesProvider(DateTime(2025, 6, 1)).future);
    return {for (final c in changes) c.name: c.providerUrl};
  }

  group('provider page address in the price-change list', () {
    test('cached under the ISIN, else the ticker, and the exchange (Milan when unset)', () async {
      await asset('World', isin: 'IE00B4L5Y983', ticker: 'SWDA');
      await asset('Enel', isin: '', ticker: 'ENEL', exchange: 'Milan');
      await asset('All World', ticker: 'VWCE', exchange: 'Xetra');
      await asset('Uncached', ticker: 'NONE', exchange: 'Xetra');
      await asset('No term');
      await putConfig('PROVIDER_URL_IE00B4L5Y983_Milan', '/etfs/ishares-msci-world');
      await putConfig('PROVIDER_URL_ENEL_Milan', '/equities/enel');
      await putConfig('PROVIDER_URL_VWCE_Xetra', 'https://example.org/etfs/vwce');
      // The ticker of an asset searched by ISIN is not its search term.
      await putConfig('PROVIDER_URL_SWDA_Milan', '/etfs/wrong');
      await putConfig('PROVIDER_URL_NONE_Milan', '/etfs/wrong-exchange');

      final service = WebMarketDataService(db);
      addTearDown(service.dispose);
      expect(await providerUrls(service), {
        'World': '$kProviderBase/etfs/ishares-msci-world',
        'Enel': '$kProviderBase/equities/enel',
        'All World': 'https://example.org/etfs/vwce',
        'Uncached': null,
        'No term': null,
      });
    });
  });

  group('the close of a price-history row', () {
    WebMarketDataService service(List<Object?> rows) =>
        WebMarketDataService(db, solveHeadless: () async => false, jsFetchOverride: (url, domainId) async => {'data': rows});

    test('pinned: the first positive close, a number or a numeric string', () async {
      await putConfig('PROVIDER_FX_CID_EUR/USD', '1');
      final svc = service([
        {'last_closeRaw': null},
        {'last_closeRaw': -2},
        {'last_closeRaw': 'n/a'},
        {'last_closeRaw': '1.0850'},
        {'last_closeRaw': 1.2},
      ]);
      addTearDown(svc.dispose);
      expect(await svc.getLiveFxRate('EUR', 'USD'), 1.085);
    });

    test('a row that is not an object is skipped, not the end of the lookup', () async {
      await putConfig('PROVIDER_FX_CID_EUR/USD', '1');
      final svc = service([
        'unexpected',
        null,
        [1.3],
        {'last_closeRaw': 1.2},
      ]);
      addTearDown(svc.dispose);
      expect(await svc.getLiveFxRate('EUR', 'USD'), 1.2);
    });
  });
}
