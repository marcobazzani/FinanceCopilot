// The market-data and composition services are rebuilt by their providers
// whenever the database reloads (import, restore, wipe).
//
// Pinned leak: nothing released the instance being replaced — its HTTP
// clients, its persistent headless WebView and the timers of a Cloudflare
// solve in flight all outlived it, one more set per reload.

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/services/market/web_market_data_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';

/// Records whether its client was closed; never sends anything.
class _RecordingAdapter implements HttpClientAdapter {
  bool closed = false;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) =>
      throw UnimplementedError('no network in unit tests');

  @override
  void close({bool force = false}) => closed = true;
}

void main() {
  // A reload opens the next database before the previous one has closed.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test('a database reload disposes the services it replaces', () {
    final container = ProviderContainer(
      overrides: [
        // Production wiring, on an in-memory database.
        databaseProvider.overrideWith((ref) {
          ref.watch(dbReloadTrigger);
          final db = AppDatabase.forTesting(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
      ],
    );
    addTearDown(container.dispose);

    final market = container.read(marketPriceServiceProvider) as WebMarketDataService;
    final composition = container.read(compositionServiceProvider);
    final compositionHttp = _RecordingAdapter();
    composition.httpClientForTest.httpClientAdapter = compositionHttp;

    container.read(dbReloadTrigger.notifier).state++;

    final reloadedMarket = container.read(marketPriceServiceProvider) as WebMarketDataService;
    expect(reloadedMarket, isNot(same(market)));
    expect(container.read(compositionServiceProvider), isNot(same(composition)));
    expect(market.isDisposed, isTrue, reason: 'the replaced market-data service must release its WebView and client');
    expect(compositionHttp.closed, isTrue, reason: 'the replaced composition service must close its client');
    expect(reloadedMarket.isDisposed, isFalse);
  });

  test('tearing the container down disposes the live services', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);

    final market = container.read(marketPriceServiceProvider) as WebMarketDataService;
    final compositionHttp = _RecordingAdapter();
    container.read(compositionServiceProvider).httpClientForTest.httpClientAdapter = compositionHttp;

    container.dispose();

    expect(market.isDisposed, isTrue);
    expect(compositionHttp.closed, isTrue);
  });
}
