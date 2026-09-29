// Pins the plumbing of the market data service that several code paths share:
// the currency-pair id lookup, the price-history request and its parsing, the
// settings rows the service caches (key, value and description), the search
// term it derives from an asset, and the reachability probe. Offline: every
// request goes through the service's test seams.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/market/web_market_data_service.dart';

String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _history(int cid, DateTime from, DateTime to, {required bool missingRows}) =>
    '$kProviderApiBase/api/financialdata/historical/$cid'
    '?start-date=${_ymd(from)}&end-date=${_ymd(to)}&time-frame=Daily&add-missing-rows=$missingRows';

Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/instrument_search_$name.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  late AppDatabase db;
  late int broker;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
  });
  tearDown(() => db.close());

  /// A service answering search requests with [search] (per query, default
  /// none) and history requests with [history]; every URL lands in [requested].
  WebMarketDataService service(
    List<String> requested, {
    Map<String, Map<String, dynamic>> search = const {},
    List<Map<String, dynamic>> history = const [],
    Dio? dio,
    Future<bool> Function()? solve,
  }) => WebMarketDataService(
    db,
    dio: dio,
    solveHeadless: solve ?? () async => false,
    jsFetchOverride: (url, domainId) async {
      requested.add(url);
      if (url.contains(kProviderSearchHost)) return search[Uri.parse(url).queryParameters['query']] ?? {'instruments': const []};
      return {'data': history};
    },
  );

  Future<void> putConfig(String key, String value) => db.into(db.appConfigs).insert(AppConfigsCompanion.insert(key: key, value: value));

  Future<Map<String, (String, String?)>> configs() async => {
    for (final c in await db.select(db.appConfigs).get())
      if (c.key.startsWith('PROVIDER_')) c.key: (c.value, c.description),
  };

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
          intermediaryId: broker,
        ),
      );

  List<String> searchedQueries(List<String> requested) => [
    for (final url in requested)
      if (url.contains(kProviderSearchHost)) Uri.parse(url).queryParameters['query']!,
  ];

  group('currency pair id', () {
    final closes = [
      {'last_closeRaw': null},
      {'last_closeRaw': 0},
      {'last_closeRaw': 'n/a'},
      {'last_closeRaw': '1.0850'},
      {'last_closeRaw': 1.2},
    ];

    test('a cached pair id: one three-day history request, the first positive close', () async {
      await putConfig('PROVIDER_FX_CID_EUR/USD', '1');
      final requested = <String>[];
      final rate = await service(requested, history: closes).getLiveFxRate('EUR', 'USD');

      final now = DateTime.now();
      expect(rate, 1.085);
      expect(requested, [_history(1, now.subtract(const Duration(days: 3)), now, missingRows: false)]);
    });

    test('an unknown pair is searched once and cached in the settings and in memory', () async {
      final requested = <String>[];
      final svc = service(requested, search: {'EUR/USD': _fixture('eurusd')}, history: closes);

      expect(await svc.getLiveFxRate('EUR', 'USD'), 1.085);
      expect(searchedQueries(requested), ['EUR/USD']);
      expect((await configs())['PROVIDER_FX_CID_EUR/USD'], ('1', 'the market data provider FX cid for EUR/USD'));

      requested.clear();
      await svc.fetchHistoricalFxRates('EUR', 'USD', DateTime(2026, 1, 5));
      expect(requested, [_history(1, DateTime(2026, 1, 5), DateTime.now(), missingRows: true)], reason: 'no second search');
    });

    test('the price history resolves an uncached pair the same way', () async {
      final requested = <String>[];
      await service(requested, search: {'EUR/USD': _fixture('eurusd')}).fetchHistoricalFxRates('EUR', 'USD', DateTime(2026, 1, 5));

      expect(searchedQueries(requested), ['EUR/USD']);
      expect(requested.last, _history(1, DateTime(2026, 1, 5), DateTime.now(), missingRows: true));
      expect((await configs())['PROVIDER_FX_CID_EUR/USD'], ('1', 'the market data provider FX cid for EUR/USD'));
    });

    test('a pair nobody lists: no live rate, an empty history, nothing cached', () async {
      final requested = <String>[];
      final svc = service(requested);

      expect(await svc.getLiveFxRate('EUR', 'XYZ'), isNull);
      expect(requested, hasLength(2), reason: 'the pair, then its inverse');
      expect(searchedQueries(requested), ['EUR/XYZ', 'XYZ/EUR']);

      requested.clear();
      expect(await svc.fetchHistoricalFxRates('EUR', 'XYZ', DateTime(2026, 1, 5)), isEmpty);
      expect(searchedQueries(requested), ['EUR/XYZ']);
      expect(requested, hasLength(1), reason: 'no history request without an id');
      expect(await configs(), isEmpty);
    });

    test('a failing settings read: the live rate is null, the price history throws', () async {
      await db.customStatement('DROP TABLE app_configs');
      final svc = service(<String>[], search: {'EUR/USD': _fixture('eurusd')}, history: closes);

      expect(await svc.getLiveFxRate('EUR', 'USD'), isNull);
      await expectLater(svc.fetchHistoricalFxRates('EUR', 'USD', DateTime(2026, 1, 5)), throwsA(anything));
    });
  });

  test('price history rows without a date, with an unreadable date or without a positive close are skipped', () async {
    await putConfig('PROVIDER_FX_CID_EUR/USD', '1');
    final requested = <String>[];
    final prices = await service(
      requested,
      history: [
        {'rowDateTimestamp': '2026-03-02T00:00:00Z', 'last_closeRaw': 1.08},
        {'rowDateTimestamp': '2026-03-03T15:30:00Z', 'last_closeRaw': '1.09'},
        {'rowDateTimestamp': null, 'last_closeRaw': 1.1},
        {'rowDateTimestamp': 'not a date', 'last_closeRaw': 1.1},
        {'rowDateTimestamp': '2026-03-04T00:00:00Z', 'last_closeRaw': 0},
        {'rowDateTimestamp': '2026-03-05T00:00:00Z', 'last_closeRaw': -1},
        {'rowDateTimestamp': '2026-03-06T00:00:00Z', 'last_closeRaw': 'n/a'},
        {'rowDateTimestamp': '2026-03-09T00:00:00Z'},
      ],
    ).fetchHistoricalFxRates('EUR', 'USD', DateTime(2026, 3, 1));

    expect(prices, {DateTime(2026, 3, 2): 1.08, DateTime(2026, 3, 3): 1.09});
  });

  group('settings rows the service caches', () {
    test('a ticker resolved by search: its id and page address', () async {
      await insertAsset(name: 'World', ticker: 'SWDA', exchange: 'Milan');
      final requested = <String>[];
      await service(requested, search: {'SWDA': _fixture('swda')}).fetchHistoricalPrices('SWDA', 'EUR', DateTime(2026, 3, 1));

      expect(await configs(), {
        'PROVIDER_CID_SWDA_Milan': ('46925', 'the market data provider cid for SWDA on Milan'),
        'PROVIDER_URL_SWDA_Milan': ('/etfs/ishares-msci-world---acc?cid=46925', 'the market data provider URL for SWDA'),
      });
      expect(requested.last, _history(46925, DateTime(2026, 3, 1), DateTime.now(), missingRows: true));
    });

    test('a listing verified by ISIN: its id, page address and type per exchange', () async {
      final requested = <String>[];
      await service(requested, search: {'IE00B4L5Y983': _fixture('swda')}).resolveListingsByIsin(isin: 'IE00B4L5Y983');

      final rows = await configs();
      expect(rows['PROVIDER_CID_IE00B4L5Y983_Milan'], ('46925', 'the market data provider cid for IE00B4L5Y983 on Milan'));
      expect(rows['PROVIDER_URL_IE00B4L5Y983_Milan'], (
        '/etfs/ishares-msci-world---acc?cid=46925',
        'the market data provider URL for IE00B4L5Y983',
      ));
      expect(rows['PROVIDER_TYPE_IE00B4L5Y983_Milan'], ('etf', 'the market data provider type for IE00B4L5Y983'));
      expect(rows['PROVIDER_CID_IE00B4L5Y983_London'], ('995447', 'the market data provider cid for IE00B4L5Y983 on London'));
    });

    test('an instrument page resolved from its address: its id and address', () async {
      final html = File('test/fixtures/instrument_page_be0000351602.html').readAsStringSync();
      final svc = WebMarketDataService(db, pageFetcher: (uri) async => html);
      final result = await svc.resolveFromInstrumentUrlString(
        '$kProviderBase/rates-bonds/be0000351602',
        cacheKey: 'BE0000351602',
        exchange: 'MIL',
      );

      final url = (result as UrlResolveOk).result.url;
      expect(url, isNotNull);
      expect(await configs(), {
        'PROVIDER_CID_BE0000351602_MIL': ('1181400', 'the market data provider cid for BE0000351602 on MIL'),
        'PROVIDER_URL_BE0000351602_MIL': (url!, 'the market data provider URL for BE0000351602'),
      });
    });

    test('a cached id missing its page address gets it back from search during a sync', () async {
      await insertAsset(name: 'World', isin: 'IE00B4L5Y983', ticker: 'SWDA', exchange: 'Milan');
      await putConfig('PROVIDER_CID_IE00B4L5Y983_Milan', '46925');
      final requested = <String>[];
      await service(requested, search: {'IE00B4L5Y983': _fixture('swda')}).syncPrices();

      expect(
        (await configs())['PROVIDER_URL_IE00B4L5Y983_Milan'],
        ('/etfs/ishares-msci-world---acc?cid=46925', 'the market data provider URL for IE00B4L5Y983'),
      );
    });
  });

  test('a cached listing is offered with its stored address and type', () async {
    await putConfig('PROVIDER_CID_IE00B4L5Y983_Milan', '46925');
    await putConfig('PROVIDER_URL_IE00B4L5Y983_Milan', '/etfs/world');
    await putConfig('PROVIDER_TYPE_IE00B4L5Y983_Milan', 'etf');
    final requested = <String>[];
    final listings = await service(
      requested,
    ).resolveListingsByIsin(isin: 'IE00B4L5Y983', preferredTicker: 'SWDA', preferredExchange: 'Milan');

    final cached = listings.single;
    expect(
      (cached.cid, cached.symbol, cached.exchange, cached.url, cached.type, cached.isin),
      (
        46925,
        'SWDA',
        'Milan',
        '/etfs/world',
        'etf',
        'IE00B4L5Y983',
      ),
    );
  });

  group('the search term of an asset is its ISIN, else its ticker', () {
    test('price sync', () async {
      await insertAsset(name: 'World', isin: 'IE00B4L5Y983', ticker: 'SWDA', exchange: 'Milan');
      await insertAsset(name: 'Enel SpA', isin: '', ticker: 'ENEL', exchange: 'Milan');
      await insertAsset(name: 'All World', ticker: 'VWCE', exchange: 'Xetra');
      final requested = <String>[];
      await service(requested).syncPrices();

      expect(searchedQueries(requested).toSet(), {'IE00B4L5Y983', 'ENEL', 'VWCE'});
    });

    test('name backfill of assets still named after their identifier', () async {
      await insertAsset(name: 'IE00BSPLC413', isin: 'IE00BSPLC413', exchange: 'Xetra');
      await insertAsset(name: 'ZPRV', isin: '', ticker: 'ZPRV', exchange: 'Xetra');
      final requested = <String>[];
      await service(requested).syncPrices();

      expect(searchedQueries(requested).toSet(), {'IE00BSPLC413', 'ZPRV'});
    });

    test('address backfill of a cached id', () async {
      await insertAsset(name: 'Enel SpA', isin: '', ticker: 'ENEL', exchange: 'Milan');
      await putConfig('PROVIDER_CID_ENEL_Milan', '32237');
      final requested = <String>[];
      await service(requested).syncPrices();

      expect(searchedQueries(requested), ['ENEL'], reason: 'the address backfill; the id itself is cached');
    });
  });

  test('the reachability probe asks for a week of one liquid instrument', () async {
    final probed = <String>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            probed.add(options.uri.toString());
            handler.resolve(Response(requestOptions: options, statusCode: 200, data: const {'data': []}));
          },
        ),
      );
    final svc = WebMarketDataService(db, dio: dio, solveHeadless: () async => true);

    expect(await svc.ensureWebViewForTest(), isTrue);
    final now = DateTime.now();
    expect(probed, [_history(46925, now.subtract(const Duration(days: 7)), now, missingRows: false)]);
  });
}
