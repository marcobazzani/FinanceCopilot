// Regression: a failed Cloudflare solve must not deadlock the market-data
// service.
//
// Pinned bug: _ensureWebView() set the `_cfSolving` mutex Completer, then
// awaited _solveHeadless() WITHOUT a try/finally. If the solve threw, the
// completer was left dangling — and every later _ensureWebView() call hit
// `if (_cfSolving != null) return _cfSolving!.future`, awaiting a future
// that never completed. Result: all price/FX sync hung permanently.

import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/market/web_market_data_service.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'a failed CF solve does not deadlock subsequent ensureWebView calls',
    () async {
      final svc = WebMarketDataService(
        db,
        solveHeadless: () async {
          throw Exception('simulated CF solve failure');
        },
      );

      // A failed solve must surface as `false`, not a thrown exception.
      final first = await svc.ensureWebViewForTest().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw StateError('first ensureWebView call hung'),
      );
      expect(first, isFalse);

      // ...and must not leave the solve-mutex completer dangling, which would
      // hang every subsequent call forever.
      final second = await svc.ensureWebViewForTest().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw StateError('second ensureWebView call deadlocked'),
      );
      expect(second, isFalse);
    },
  );

  group('nextCfSolveAction (managed challenge on API paths)', () {
    // Regression: the provider moved the Cloudflare challenge off the api-host
    // root page (which now loads unchallenged, yielding no cf_clearance) onto
    // the /api/financialdata/... paths themselves. The solve loop must probe
    // the API and, when the probe is blocked, navigate top-level to the API
    // URL — a fetch() can never pass a managed challenge.

    test('challenge interstitial still running -> wait', () {
      expect(
        nextCfSolveAction(
          title: 'Just a moment...',
          host: 'api.investing.com',
          probeStatus: null,
          challengeNavStarted: false,
        ),
        CfSolveAction.wait,
      );
    });

    test('bounced to www host -> navigate back to api host', () {
      expect(
        nextCfSolveAction(
          title: 'Markets',
          host: kProviderHost,
          probeStatus: null,
          challengeNavStarted: false,
        ),
        CfSolveAction.goToApiHost,
      );
    });

    test('API probe 200 -> solved', () {
      expect(
        nextCfSolveAction(
          title: '',
          host: 'api.investing.com',
          probeStatus: 200,
          challengeNavStarted: false,
        ),
        CfSolveAction.solved,
      );
    });

    test('unchallenged root page but API probe 403 -> start challenge navigation', () {
      expect(
        nextCfSolveAction(
          title: '',
          host: 'api.investing.com',
          probeStatus: 403,
          challengeNavStarted: false,
        ),
        CfSolveAction.startChallengeNav,
      );
    });

    test('probe JS error (-1) -> start challenge navigation', () {
      expect(
        nextCfSolveAction(
          title: null,
          host: 'api.investing.com',
          probeStatus: -1,
          challengeNavStarted: false,
        ),
        CfSolveAction.startChallengeNav,
      );
    });

    test('probe still blocked after challenge nav -> wait (no nav loop)', () {
      expect(
        nextCfSolveAction(
          title: '',
          host: 'api.investing.com',
          probeStatus: 403,
          challengeNavStarted: true,
        ),
        CfSolveAction.wait,
      );
    });

    test('probe 200 after challenge nav -> solved', () {
      expect(
        nextCfSolveAction(
          title: '',
          host: 'api.investing.com',
          probeStatus: 200,
          challengeNavStarted: true,
        ),
        CfSolveAction.solved,
      );
    });
  });

  test('non-JSON Dio API response falls back to JS fetch', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response(
              requestOptions: options,
              data: '<html>challenge</html>',
              statusCode: 200,
            ),
          );
        },
      ),
    );

    final svc = WebMarketDataService(
      db,
      dio: dio,
      jsFetchOverride: (url, domainId) async => {
        'data': [
          {'rowDateTimestamp': '2026-05-29', 'last_closeRaw': 123.45},
        ],
      },
    );

    final result = await svc.fetchWithDioThenJsForTest(
      'https://api.example.test/prices',
    );

    expect(result?['data'], isA<List>());
    expect((result!['data'] as List).single['last_closeRaw'], 123.45);
  });

  test('Dio timeout falls back to JS fetch', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException.connectionTimeout(
              timeout: const Duration(seconds: 20),
              requestOptions: options,
            ),
          );
        },
      ),
    );

    final svc = WebMarketDataService(
      db,
      dio: dio,
      jsFetchOverride: (url, domainId) async => {
        'data': [
          {'rowDateTimestamp': '2026-05-29', 'last_closeRaw': 321.0},
        ],
      },
    );

    final result = await svc.fetchWithDioThenJsForTest(
      'https://api.example.test/prices',
    );

    expect(result?['data'], isA<List>());
    expect((result!['data'] as List).single['last_closeRaw'], 321.0);
  });
}
