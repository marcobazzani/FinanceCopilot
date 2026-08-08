// Pins the instrument-search contract at the parsing level, using payloads
// captured verbatim from the provider (test/fixtures/instrument_search_*.json).
//
// Background: instrument search used to call `api/search/v2/search` and read a
// `quotes` array. The provider moved instrument search to its own host and the
// legacy endpoint now answers 200 with a permanently EMPTY `quotes` array — so
// every lookup silently returned zero results. Assets could no longer be
// created from a search and imports could not resolve a name or cid, while
// already-resolved assets kept pricing from their cached cid, which is what
// hid the breakage.
//
// These tests are offline and deterministic (they never touch the network), so
// they run on every CI job. The companion live check that catches a FUTURE
// upstream move is integration_test/provider_search_contract_test.dart.

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/market/isin_lookup_service.dart';
import 'package:finance_copilot/services/market/web_market_data_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Map<String, dynamic> fixture(String name) =>
      jsonDecode(File('test/fixtures/instrument_search_$name.json').readAsStringSync()) as Map<String, dynamic>;

  /// Service wired to a canned response, capturing the URL it asked for.
  (WebMarketDataService, List<String>) serviceReturning(Map<String, dynamic> payload) {
    final requested = <String>[];
    final svc = WebMarketDataService(
      db,
      jsFetchOverride: (url, domainId) async {
        requested.add(url);
        return payload;
      },
    );
    return (svc, requested);
  }

  group('instrument search endpoint', () {
    test('queries the instrument-search host, not the legacy search API', () async {
      final (svc, requested) = serviceReturning(fixture('swda'));
      await svc.search('SWDA');

      expect(requested, hasLength(1), reason: 'one catalogue call replaces the old www+it pair');
      final url = requested.single;
      expect(url, WebMarketDataService.searchUrlFor('SWDA'));
      expect(url, contains(kProviderSearchHost));
      expect(url, contains('/pd-instruments/v1/instruments/search'));
      expect(url, contains('query=SWDA'));
      expect(url, contains('domain_id=1'));
      // The legacy endpoint answers 200 with an empty `quotes`, so hitting it
      // fails silently — it must not come back.
      expect(url, isNot(contains('/api/search/v2/search')));
    });

    test('query is percent-encoded', () async {
      final (svc, requested) = serviceReturning(fixture('eurusd'));
      await svc.search('EUR/USD');
      expect(requested.single, contains('query=EUR%2FUSD'));
    });

    test('maps every field an ETF listing needs', () async {
      final (svc, _) = serviceReturning(fixture('swda'));
      final results = await svc.search('SWDA');

      expect(results, hasLength(2));
      final milan = results.firstWhere((r) => r.exchange == 'Milan');
      // `id` is the cid the pricing path keys off.
      expect(milan.cid, 46925);
      expect(milan.symbol, 'SWDA');
      expect(milan.description, 'iShares Core MSCI World UCITS ETF USD (Acc)');
      expect(milan.type, 'etf');
      expect(milan.url, '/etfs/ishares-msci-world---acc?cid=46925');
      expect(milan.flag, 'Italy');
      // ISIN now arrives with the search hit, so resolveListingsByIsin can
      // verify a match without fetching the instrument page.
      expect(milan.isin, 'IE00B4L5Y983');

      expect(results.firstWhere((r) => r.exchange == 'London').cid, 995447);
    });

    test('de-duplicates repeated cids', () async {
      final swda = fixture('swda');
      final first = (swda['instruments'] as List).first;
      final (svc, _) = serviceReturning({
        'instruments': [first, first],
      });
      expect(await svc.search('SWDA'), hasLength(1));
    });

    test('currency pairs resolve a symbol even though the field is absent', () async {
      // Currency entries carry no `symbol`; the FX cid lookup matches
      // `r.symbol` against "EUR/USD", so display_symbol must fill in or every
      // new FX pair silently loses its rate.
      final payload = fixture('eurusd');
      expect(
        (payload['instruments'] as List).single,
        isNot(contains('symbol')),
        reason: 'fixture must keep reproducing the absent-symbol shape',
      );

      final (svc, _) = serviceReturning(payload);
      final fx = (await svc.search('EURUSD')).single;
      expect(fx.cid, 1);
      expect(fx.symbol, 'EUR/USD');
      expect(fx.description, 'Euro US Dollar');
    });

    test('skips entries without a usable integer id instead of throwing', () async {
      final (svc, _) = serviceReturning({
        'instruments': [
          {'symbol': 'NOID'},
          {'id': 'not-an-int', 'symbol': 'BADID'},
          {'id': 46925, 'symbol': 'OK', 'exchange_short_name': 'Milan'},
        ],
      });
      final results = await svc.search('mixed');
      expect(results.map((r) => r.symbol), ['OK']);
    });

    test('a missing or malformed payload yields no results, never an exception', () async {
      for (final payload in <Map<String, dynamic>>[
        {},
        {'instruments': null},
        {'quotes': []}, // the legacy shape
      ]) {
        final (svc, _) = serviceReturning(payload);
        expect(await svc.search('SWDA'), isEmpty);
      }
    });
  });

  group('instrument classification', () {
    test('plural title-case equities classify as stock, not ETF', () async {
      // The provider returns `Equities` for stocks while most other classes are
      // lowercase singular. Stripping a trailing "s" yields "equitie", which is
      // absent from the type map and silently fell back to ETF.
      final (svc, _) = serviceReturning(fixture('enel'));
      final enel = (await svc.search('ENEL')).single;
      expect(enel.type, 'Equities');
      expect(enel.isin, 'IT0003128367');

      final option = IsinExchangeOption(
        cid: enel.cid,
        ticker: enel.symbol,
        name: enel.description,
        exchange: enel.exchange,
        typeName: enel.type,
      );
      expect(option.classification, (InstrumentType.stock, AssetClass.equity));
    });

    test('normaliseProviderType handles every shape the provider emits', () {
      const cases = {
        'Equities': 'equity',
        'equities': 'equity',
        'ETFs': 'etf',
        'etf': 'etf',
        'Stocks - Milano': 'stock', // legacy compound form
        'bond': 'bond',
        'fund': 'fund',
        'currency': 'currency',
        'etc': 'etc',
      };
      cases.forEach((raw, expected) {
        expect(normaliseProviderType(raw), expected, reason: 'normaliseProviderType("$raw")');
      });
    });

    test('classification is stable for the types that map to a real instrument', () {
      expect(classifyFromProviderType('Equities'), (InstrumentType.stock, AssetClass.equity));
      expect(classifyFromProviderType('etf'), (InstrumentType.etf, AssetClass.equity));
      expect(classifyFromProviderType('bond'), (InstrumentType.bond, AssetClass.fixedIncome));
      expect(classifyFromProviderType('etc'), (InstrumentType.etc, AssetClass.commodities));
      expect(classifyFromProviderType('fund'), (InstrumentType.fund, AssetClass.multiAsset));
    });
  });
}
