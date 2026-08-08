// An import that cannot resolve an instrument leaves the raw ISIN as the asset
// name (e.g. an asset literally called "IE00BSPLC413"). While provider search
// was broken that was every imported asset. Once search works the cid resolves
// from the ISIN and prices flow again, but nothing ever revisited the name, so
// the ISIN stayed on screen forever.
//
// These tests pin the backfill and — just as importantly — pin that it refuses
// to touch a name the user could have chosen.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/market/web_market_data_service.dart';

Map<String, dynamic> _payload(List<Map<String, dynamic>> instruments) => {'instruments': instruments};

Map<String, dynamic> _zprv({String exchange = 'Xetra', String symbol = 'ZPRV'}) => {
  'id': 1122287,
  'symbol': symbol,
  'exchange_short_name': exchange,
  'long_name': 'State Street SPDR MSCI USA Small Cap Value Weighted UCITS ETF USD Acc',
  'short_name': 'SPDR MSCI USA Small Cap Value Weighted UCITS',
  'country': 'Germany',
  'type': 'etf',
  'link': '/etfs/spdr-msci-usa-scap-value-weighted',
  'ISIN': 'IE00BSPLC413',
};

void main() {
  late AppDatabase db;
  late int intermediaryId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    intermediaryId = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'BG Saxo'));
  });
  tearDown(() => db.close());

  Future<int> insertAsset({required String name, String? isin, String? ticker, String? exchange}) => db
      .into(db.assets)
      .insert(
        AssetsCompanion.insert(
          name: name,
          assetType: AssetType.stockEtf,
          valuationMethod: ValuationMethod.marketPrice,
          isin: Value(isin),
          ticker: Value(ticker),
          exchange: Value(exchange),
          intermediaryId: intermediaryId,
        ),
      );

  WebMarketDataService service(Map<String, dynamic> payload) => WebMarketDataService(db, jsFetchOverride: (url, domainId) async => payload);

  Future<Asset> reload(int id) => (db.select(db.assets)..where((a) => a.id.equals(id))).getSingle();

  group('hasUnresolvedName', () {
    test('name equal to the ISIN or ticker counts as unresolved', () async {
      final byIsin = await reload(await insertAsset(name: 'IE00BSPLC413', isin: 'IE00BSPLC413'));
      final byTicker = await reload(await insertAsset(name: 'ZPRV', ticker: 'ZPRV'));
      // Case differences still mean "never resolved".
      final lower = await reload(await insertAsset(name: 'ie00bsplc413', isin: 'IE00BSPLC413'));

      expect(WebMarketDataService.hasUnresolvedName(byIsin), isTrue);
      expect(WebMarketDataService.hasUnresolvedName(byTicker), isTrue);
      expect(WebMarketDataService.hasUnresolvedName(lower), isTrue);
    });

    test('a real name is never considered unresolved', () async {
      final named = await reload(await insertAsset(name: 'My retirement ETF', isin: 'IE00BSPLC413', ticker: 'ZPRV'));
      expect(WebMarketDataService.hasUnresolvedName(named), isFalse);
    });
  });

  group('name backfill during price sync', () {
    test('replaces a raw ISIN name with the provider name', () async {
      final id = await insertAsset(name: 'IE00BSPLC413', isin: 'IE00BSPLC413', exchange: 'Xetra');

      await service(_payload([_zprv()])).syncPrices();

      final asset = await reload(id);
      expect(asset.name, 'State Street SPDR MSCI USA Small Cap Value Weighted UCITS ETF USD Acc');
    });

    test('fills a blank ticker and exchange but never overwrites existing ones', () async {
      final blank = await insertAsset(name: 'IE00BSPLC413', isin: 'IE00BSPLC413');
      // Broker-supplied ticker/exchange are more authoritative than a search
      // hit, so they must survive untouched.
      final held = await insertAsset(name: 'IE00BSPLC413', isin: 'IE00BSPLC413', ticker: 'USSC', exchange: 'London');

      await service(_payload([_zprv()])).syncPrices();

      final filled = await reload(blank);
      expect(filled.ticker, 'ZPRV');
      expect(filled.exchange, 'Xetra');

      final kept = await reload(held);
      expect(kept.ticker, 'USSC', reason: 'broker ticker must win over the search hit');
      expect(kept.exchange, 'London', reason: 'broker exchange must win over the search hit');
      expect(kept.name, isNot('IE00BSPLC413'), reason: 'the name is still backfilled');
    });

    test('leaves a user-chosen name alone', () async {
      final id = await insertAsset(name: 'Small cap bucket', isin: 'IE00BSPLC413', exchange: 'Xetra');
      await service(_payload([_zprv()])).syncPrices();
      expect((await reload(id)).name, 'Small cap bucket');
    });

    test('keeps the raw name when the provider returns nothing', () async {
      // Never invent a name: an empty search leaves the asset exactly as it was
      // so the unresolved state stays visible instead of being papered over.
      final id = await insertAsset(name: 'IE00BSPLC413', isin: 'IE00BSPLC413');
      await service(_payload(const [])).syncPrices();
      expect((await reload(id)).name, 'IE00BSPLC413');
    });

    test('prefers the listing on the exchange the asset is held at', () async {
      final id = await insertAsset(name: 'IE00BSPLC413', isin: 'IE00BSPLC413', exchange: 'London');
      await service(
        _payload([
          _zprv(),
          {..._zprv(), 'id': 1172199, 'symbol': 'USSC', 'exchange_short_name': 'London'},
        ]),
      ).syncPrices();

      final asset = await reload(id);
      // Exchange already set, so only the name changes — but the London
      // listing is the one that must have been chosen.
      expect(asset.exchange, 'London');
      expect(asset.name, contains('Small Cap Value Weighted'));
    });
  });
}
