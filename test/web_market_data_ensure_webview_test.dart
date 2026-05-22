// Regression: a failed Cloudflare solve must not deadlock the market-data
// service.
//
// Pinned bug: _ensureWebView() set the `_cfSolving` mutex Completer, then
// awaited _solveHeadless() WITHOUT a try/finally. If the solve threw, the
// completer was left dangling — and every later _ensureWebView() call hit
// `if (_cfSolving != null) return _cfSolving!.future`, awaiting a future
// that never completed. Result: all price/FX sync hung permanently.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/web_market_data_service.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('a failed CF solve does not deadlock subsequent ensureWebView calls',
      () async {
    final svc = WebMarketDataService(db, solveHeadless: () async {
      throw Exception('simulated CF solve failure');
    });

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
  });
}
