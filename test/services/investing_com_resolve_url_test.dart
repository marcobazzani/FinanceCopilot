import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/investing_com_service.dart';

void main() {
  late AppDatabase db;
  late String bondHtml;
  late String etfHtml;

  setUpAll(() {
    bondHtml = File('test/fixtures/instrument_page_be0000351602.html').readAsStringSync();
    etfHtml = File('test/fixtures/instrument_page_ivv_etf.html').readAsStringSync();
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<String?> Function(Uri) staticFetcher(Map<String, String> bodies, {List<Uri>? capture}) {
    return (uri) async {
      capture?.add(uri);
      return bodies[uri.toString()];
    };
  }

  Future<String?> Function(Uri) failingFetcher({List<Uri>? capture}) {
    return (uri) async {
      capture?.add(uri);
      return null;
    };
  }

  Future<String?> readCached(AppDatabase db, String key) async {
    final row = await db.customSelect(
      'SELECT value FROM app_configs WHERE key = ?',
      variables: [Variable.withString(key)],
    ).getSingleOrNull();
    return row?.read<String>('value');
  }

  group('resolveFromInstrumentUrl', () {
    test('happy path — bond URL returns ok and writes cache', () async {
      final captured = <Uri>[];
      final svc = InvestingComService(
        db,
        pageFetcher: staticFetcher(
          {'https://www.investing.com/rates-bonds/be0000351602': bondHtml},
          capture: captured,
        ),
      );

      final r = await svc.resolveFromInstrumentUrlString(
        'https://www.investing.com/rates-bonds/be0000351602',
        cacheKey: 'BE0000351602',
        exchange: 'MIL',
      );

      expect(r, isA<UrlResolveOk>());
      final ok = r as UrlResolveOk;
      expect(ok.result.cid, 1181400);
      expect(ok.result.description, 'Belgium 0 22-Oct-2027');
      expect(ok.result.exchange, 'Milan');
      expect(ok.result.type.toLowerCase(), contains('bond'));

      expect(captured.single, Uri.parse('https://www.investing.com/rates-bonds/be0000351602'));
      expect(await readCached(db, 'INVESTING_CID_BE0000351602_MIL'), '1181400');
      expect(await readCached(db, 'INVESTING_URL_BE0000351602_MIL'), isNotNull);
    });

    test('happy path — query string is stripped before fetch', () async {
      final captured = <Uri>[];
      final svc = InvestingComService(
        db,
        pageFetcher: staticFetcher(
          {'https://www.investing.com/etfs/ishares-core-s-p-500': etfHtml},
          capture: captured,
        ),
      );

      final r = await svc.resolveFromInstrumentUrlString(
        'https://www.investing.com/etfs/ishares-core-s-p-500?cid=949553&utm_source=foo',
        cacheKey: 'IE00B4L5Y983',
        exchange: 'MIL',
      );

      expect(r, isA<UrlResolveOk>());
      expect((r as UrlResolveOk).result.cid, 949553);
      expect(captured.single.queryParameters, isEmpty);
    });

    test('happy path — -historical-data suffix is stripped before fetch', () async {
      final captured = <Uri>[];
      final svc = InvestingComService(
        db,
        pageFetcher: staticFetcher(
          {'https://www.investing.com/rates-bonds/be0000351602': bondHtml},
          capture: captured,
        ),
      );

      final r = await svc.resolveFromInstrumentUrlString(
        'https://www.investing.com/rates-bonds/be0000351602-historical-data',
        cacheKey: 'BE0000351602',
        exchange: 'MIL',
      );

      expect(r, isA<UrlResolveOk>());
      expect(captured.single.path, '/rates-bonds/be0000351602');
    });

    test('rejection — wrong host returns UrlResolveWrongHost without fetching', () async {
      final captured = <Uri>[];
      final svc = InvestingComService(
        db,
        pageFetcher: staticFetcher({}, capture: captured),
      );

      final r = await svc.resolveFromInstrumentUrlString(
        'https://www.example.com/rates-bonds/foo',
        cacheKey: 'FOO',
        exchange: 'MIL',
      );

      expect(r, isA<UrlResolveWrongHost>());
      expect(captured, isEmpty);
      expect(await readCached(db, 'INVESTING_CID_FOO_MIL'), isNull);
    });

    test('rejection — unsupported path category', () async {
      final captured = <Uri>[];
      final svc = InvestingComService(
        db,
        pageFetcher: staticFetcher({}, capture: captured),
      );

      final r = await svc.resolveFromInstrumentUrlString(
        'https://www.investing.com/news/stock-market-news/foo',
        cacheKey: 'FOO',
        exchange: 'MIL',
      );

      expect(r, isA<UrlResolveUnsupportedCategory>());
      expect(captured, isEmpty);
    });

    test('rejection — invalid format (non-http scheme)', () async {
      final svc = InvestingComService(db, pageFetcher: failingFetcher());
      final r = await svc.resolveFromInstrumentUrlString(
        'ftp://www.investing.com/rates-bonds/foo',
        cacheKey: 'FOO',
        exchange: 'MIL',
      );
      expect(r, isA<UrlResolveInvalidFormat>());
    });

    test('failure — fetcher returns null gives UrlResolveFetchFailed', () async {
      final svc = InvestingComService(db, pageFetcher: failingFetcher());
      final r = await svc.resolveFromInstrumentUrlString(
        'https://www.investing.com/rates-bonds/be0000351602',
        cacheKey: 'BE0000351602',
        exchange: 'MIL',
      );
      expect(r, isA<UrlResolveFetchFailed>());
      expect(await readCached(db, 'INVESTING_CID_BE0000351602_MIL'), isNull);
    });

    test('failure — page without __NEXT_DATA__ gives UrlResolveParseFailed', () async {
      final svc = InvestingComService(
        db,
        pageFetcher: staticFetcher({
          'https://www.investing.com/rates-bonds/foo': '<html><body>Just a moment...</body></html>',
        }),
      );
      final r = await svc.resolveFromInstrumentUrlString(
        'https://www.investing.com/rates-bonds/foo',
        cacheKey: 'FOO',
        exchange: 'MIL',
      );
      expect(r, isA<UrlResolveParseFailed>());
    });

    test('idempotent cache — repeated calls keep one row per key', () async {
      final svc = InvestingComService(
        db,
        pageFetcher: staticFetcher(
          {'https://www.investing.com/rates-bonds/be0000351602': bondHtml},
        ),
      );

      for (var i = 0; i < 3; i++) {
        final r = await svc.resolveFromInstrumentUrlString(
          'https://www.investing.com/rates-bonds/be0000351602',
          cacheKey: 'BE0000351602',
          exchange: 'MIL',
        );
        expect(r, isA<UrlResolveOk>());
      }

      final rows = await db.customSelect(
        "SELECT key FROM app_configs WHERE key LIKE 'INVESTING_%_BE0000351602_MIL'",
      ).get();
      // exactly two rows: the cid + the URL
      expect(rows.length, 2);
    });
  });
}
