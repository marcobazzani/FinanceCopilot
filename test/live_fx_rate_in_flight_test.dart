// A live FX rate is fetched once per currency pair even when several callers
// ask for it at the same time — the asset valuations ask per asset while the
// rate sync runs, all for the same few pairs. Offline: every request goes
// through the service's JS-fetch test seam.
//
// Pinned bug: `getLiveFxRate` only reused a rate once it was cached, so the
// parallel callers each ran their own pair search and price-history request.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/market/web_market_data_service.dart';

Map<String, dynamic> _eurUsdSearch() =>
    jsonDecode(File('test/fixtures/instrument_search_eurusd.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  bool isSearch(String url) => url.contains(kProviderSearchHost);

  /// A service whose every request waits for [gate] (so calls overlap) and
  /// lands in [requested]. Search finds EUR/USD only; histories close at 1.085.
  WebMarketDataService service(List<String> requested, {Future<void>? gate}) => WebMarketDataService(
    db,
    solveHeadless: () async => false,
    jsFetchOverride: (url, domainId) async {
      requested.add(url);
      await gate;
      if (isSearch(url)) {
        return Uri.parse(url).queryParameters['query'] == 'EUR/USD' ? _eurUsdSearch() : {'instruments': const []};
      }
      return {
        'data': [
          {'last_closeRaw': 1.085},
        ],
      };
    },
  );

  test('callers asking for one pair at the same time share a single lookup', () async {
    final requested = <String>[];
    final gate = Completer<void>();
    final svc = service(requested, gate: gate.future);

    final rates = [for (var i = 0; i < 5; i++) svc.getLiveFxRate('EUR', 'USD')];
    await pumpEventQueue();
    gate.complete();

    expect(await Future.wait(rates), List.filled(5, 1.085));
    expect(requested.where(isSearch), hasLength(1), reason: 'one pair search');
    expect(requested.where((url) => !isSearch(url)), hasLength(1), reason: 'one price-history request');
  });

  test('the shared lookup is not kept once done: the rate comes from the cache, a miss is asked again', () async {
    final requested = <String>[];
    final svc = service(requested);

    expect(await svc.getLiveFxRate('EUR', 'USD'), 1.085);
    final afterFirst = requested.length;
    expect(await svc.getLiveFxRate('EUR', 'USD'), 1.085);
    expect(requested, hasLength(afterFirst), reason: 'a fresh rate is served from memory');

    expect(await svc.getLiveFxRate('EUR', 'XYZ'), isNull);
    final afterMiss = requested.length;
    expect(await svc.getLiveFxRate('EUR', 'XYZ'), isNull);
    expect(requested.length, greaterThan(afterMiss), reason: 'a pair without a rate is looked up again');
  });

  test('different pairs never share a lookup', () async {
    final requested = <String>[];
    final gate = Completer<void>();
    final svc = service(requested, gate: gate.future);

    final usd = svc.getLiveFxRate('EUR', 'USD');
    final xyz = svc.getLiveFxRate('EUR', 'XYZ');
    await pumpEventQueue();
    gate.complete();

    expect(await usd, 1.085);
    expect(await xyz, isNull);
    expect(
      requested.where(isSearch).map((url) => Uri.parse(url).queryParameters['query']),
      containsAll(['EUR/USD', 'EUR/XYZ', 'XYZ/EUR']),
    );
  });

  test('the same currency on both sides needs no lookup', () async {
    final requested = <String>[];
    expect(await service(requested).getLiveFxRate('EUR', 'EUR'), 1.0);
    expect(requested, isEmpty);
  });
}
