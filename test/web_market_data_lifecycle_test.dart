// Lifetime of the market-data service's WebView context and network client.
//
// Pinned bugs:
//  * `_fetchViaJsFetch` re-read the `_webViewController` field after awaiting
//    the first script. A Cloudflare re-solve nulls that field while a fetch is
//    in flight, so the fallback script hit a null check, the error was
//    swallowed, and the fetch silently returned nothing although the page had
//    answered.
//  * The provider rebuilds the service whenever the DB reloads (import,
//    restore, wipe), and nothing released the replaced instance: its network
//    client, its headless WebView and the timers of a solve in flight all
//    lived on. `dispose()` releases them.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/market/web_market_data_service.dart';

/// A solved WebView page: the first script ([callAsyncJavaScript]) yields no
/// value, as on platforms where it is unsupported, so the fetch falls back to
/// [evaluateJavascript], which answers [payload].
class _FakeWebViewController implements InAppWebViewController {
  _FakeWebViewController(this.payload, {this.onFirstScript});

  final Map<String, dynamic> payload;

  /// Runs while the first script is in flight.
  final void Function()? onFirstScript;

  int scripts = 0;

  @override
  Future<CallAsyncJavaScriptResult?> callAsyncJavaScript({
    required String functionBody,
    Map<String, dynamic> arguments = const <String, dynamic>{},
    ContentWorld? contentWorld,
  }) async {
    scripts++;
    onFirstScript?.call();
    return null;
  }

  @override
  Future<dynamic> evaluateJavascript({required String source, ContentWorld? contentWorld}) async {
    scripts++;
    return jsonEncode(payload);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Headless WebViews whose page never finishes loading, so a Cloudflare solve
/// started on one stays in flight until its timeout (or a dispose).
class _StalledWebViewPlatform extends InAppWebViewPlatform {
  final created = <_StalledHeadlessWebView>[];

  @override
  PlatformHeadlessInAppWebView createPlatformHeadlessInAppWebView(PlatformHeadlessInAppWebViewCreationParams params) {
    final webView = _StalledHeadlessWebView(params);
    created.add(webView);
    return webView;
  }
}

class _StalledHeadlessWebView extends PlatformHeadlessInAppWebView {
  _StalledHeadlessWebView(super.params) : super.implementation();

  bool disposed = false;

  @override
  Future<void> run() async {}

  @override
  Future<void> dispose() async => disposed = true;
}

/// Records whether the service closed its HTTP client; never sends anything.
class _RecordingAdapter implements HttpClientAdapter {
  bool closed = false;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) =>
      throw UnimplementedError('no network in unit tests');

  @override
  void close({bool force = false}) => closed = true;
}

/// A client the provider refuses (403), so every API call goes through the
/// WebView's JS context.
Dio _blockedDio() => Dio()
  ..interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.reject(
        DioException.badResponse(
          statusCode: 403,
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 403),
        ),
      ),
    ),
  );

const _prices = {
  'data': [
    {'rowDateTimestamp': '2026-05-29', 'last_closeRaw': 101.5},
  ],
};

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('a re-solve detaching the WebView mid-fetch does not drop the page answer', () async {
    final svc = WebMarketDataService(db, dio: _blockedDio());
    final controller = _FakeWebViewController(
      _prices,
      // What `_solveHeadless` does to the field when a re-solve starts.
      onFirstScript: () => svc.webViewControllerForTest = null,
    );
    svc.webViewControllerForTest = controller;

    final result = await svc.fetchWithDioThenJsForTest('https://api.example.test/prices');

    expect(controller.scripts, 2, reason: 'the fallback script must run on the page the fetch started on');
    expect((result?['data'] as List?)?.single['last_closeRaw'], 101.5);
  });

  group('dispose', () {
    test('closes the network client, once', () {
      final adapter = _RecordingAdapter();
      final svc = WebMarketDataService(db, dio: Dio()..httpClientAdapter = adapter);

      expect(svc.isDisposed, isFalse);
      svc.dispose();
      svc.dispose(); // a second call is a no-op

      expect(adapter.closed, isTrue);
      expect(svc.isDisposed, isTrue);
    });

    test('a disposed service never starts another Cloudflare solve', () async {
      var solves = 0;
      final svc = WebMarketDataService(
        db,
        dio: Dio()..httpClientAdapter = _RecordingAdapter(),
        solveHeadless: () async {
          solves++;
          return true;
        },
      );

      svc.dispose();

      expect(await svc.ensureWebViewForTest(), isFalse);
      expect(solves, 0, reason: 'a replaced instance must not spawn a WebView nobody will dispose');
    });

    test('detaches the solved WebView, so later fetches never reach it', () async {
      final svc = WebMarketDataService(db, dio: _blockedDio());
      final controller = _FakeWebViewController(_prices);
      svc.webViewControllerForTest = controller;

      svc.dispose();
      final result = await svc.fetchWithDioThenJsForTest('https://api.example.test/prices');

      expect(result, isNull);
      expect(controller.scripts, 0);
    });

    test('releases a solve in flight and disposes its headless WebView', () async {
      final platform = _StalledWebViewPlatform();
      InAppWebViewPlatform.instance = platform;
      final svc = WebMarketDataService(db, dio: Dio()..httpClientAdapter = _RecordingAdapter());

      final solving = svc.ensureWebViewForTest();
      // Let the solve create its WebView and start waiting on the page.
      await pumpEventQueue();
      expect(platform.created, hasLength(1));

      svc.dispose();

      // Without the release, callers (price sync awaits this with no timeout)
      // would wait on a page that will never load again.
      expect(await solving.timeout(const Duration(seconds: 5)), isFalse);
      expect(platform.created.single.disposed, isTrue);
    });
  });
}
