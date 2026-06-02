import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../database/database.dart';
import '../utils/formatters.dart' show formatYmd;
import '../utils/logger.dart';
import 'web_page_parser.dart';
import 'market_price_service.dart';

final _log = getLogger('WebMarketDataService');

/// Provider host. Centralised so callers and tests don't sprinkle the
/// literal across the codebase. The host is data — replacing it would
/// change which provider we integrate with.
const kProviderHost = 'www.investing.com';
const kProviderApiHost = 'api.investing.com';
const kProviderBase = 'https://$kProviderHost';
const kProviderApiBase = 'https://$kProviderApiHost';

/// Result from the market data provider search API.
class ProviderSearchResult {
  final int cid;
  final String description;
  final String symbol;
  final String exchange;
  final String flag;
  final String type;
  final String? url; // relative URL path, e.g. "/equities/amazon-com-inc"
  final String? isin;

  const ProviderSearchResult({
    required this.cid,
    required this.description,
    required this.symbol,
    required this.exchange,
    required this.flag,
    required this.type,
    this.url,
    this.isin,
  });
}

/// Outcome of [WebMarketDataService.resolveFromInstrumentUrl].
sealed class UrlResolveResult {
  const UrlResolveResult();
}

class UrlResolveOk extends UrlResolveResult {
  final ProviderSearchResult result;
  const UrlResolveOk(this.result);
}

class UrlResolveInvalidFormat extends UrlResolveResult {
  const UrlResolveInvalidFormat();
}

class UrlResolveWrongHost extends UrlResolveResult {
  const UrlResolveWrongHost();
}

class UrlResolveUnsupportedCategory extends UrlResolveResult {
  const UrlResolveUnsupportedCategory();
}

class UrlResolveFetchFailed extends UrlResolveResult {
  const UrlResolveFetchFailed();
}

class UrlResolveParseFailed extends UrlResolveResult {
  const UrlResolveParseFailed();
}

/// the market data provider exchange name mapping.
/// Synonyms accepted when filtering search results by exchange. Keys are
/// the canonical English name we store in `assets.exchange` and use as
/// the cache-key suffix; values are the alternative spellings the
/// provider may return (Italian-locale variants, etc.).
const _exchangeSynonyms = <String, List<String>>{
  'Milan': ['Milan', 'Milano'],
  'NYSE': ['NYSE', 'NASDAQ'], // provider lists AMZN as NASDAQ even though it's NYSE
  'NASDAQ': ['NASDAQ'],
  'AMEX': ['AMEX'],
  'Xetra': ['Xetra'],
  'Frankfurt': ['Frankfurt', 'Francoforte'],
  'London': ['London', 'Londra'],
  'Amsterdam': ['Amsterdam'],
  'Paris': ['Paris', 'Parigi'],
  'Brussels': ['Brussels', 'Bruxelles'],
  'Lisbon': ['Lisbon', 'Lisbona'],
  'Switzerland': ['Switzerland', 'Svizzera'],
  'Toronto': ['Toronto'],
  'Hong Kong': ['Hong Kong'],
  'Tokyo': ['Tokyo'],
};

/// Fetches historical prices from the market data provider.
///
/// Uses a headless WebView to solve Cloudflare challenges, then makes
/// direct API calls with the obtained cookies via Dio.
class WebMarketDataService extends MarketPriceService {
  final Dio _dio;
  final Future<String?> Function(Uri)? _pageFetcher;
  final Future<Map<String, dynamic>?> Function(String url, String domainId)? _jsFetchOverride;

  /// Test seam: when non-null, [_ensureWebView] calls this instead of the
  /// real headless-WebView Cloudflare solve.
  final Future<bool> Function()? _solveOverride;

  /// Persistent headless WebView for CF-protected API calls.
  HeadlessInAppWebView? _webView;
  InAppWebViewController? _webViewController;
  DateTime? _webViewReadyAt;
  String _cfCookieStr = '';
  String _cfUserAgent = '';

  /// True after Dio gets a 403 — all subsequent fetches use JS fetch.
  bool _dioBlocked = false;

  /// [pageFetcher] is a test seam: when non-null, [resolveFromInstrumentUrl]
  /// uses it instead of the built-in Dio + WebView fetch path.
  /// [solveHeadless] is a test seam for the Cloudflare solve step.
  WebMarketDataService(
    super.db, {
    Dio? dio,
    Future<String?> Function(Uri)? pageFetcher,
    Future<bool> Function()? solveHeadless,
    @visibleForTesting Future<Map<String, dynamic>?> Function(String url, String domainId)? jsFetchOverride,
  }) : _dio = dio ?? Dio(),
       _pageFetcher = pageFetcher,
       _solveOverride = solveHeadless,
       _jsFetchOverride = jsFetchOverride;

  // ──────────────────────────────────────────────
  // Headless WebView: solve CF + make API calls in same browser context
  // ──────────────────────────────────────────────

  /// Whether the WebView is ready (CF solved, not expired).
  bool get _isWebViewReady =>
      _webViewController != null && _webViewReadyAt != null && DateTime.now().difference(_webViewReadyAt!).inMinutes < 30;

  /// Mutex: only one CF solve at a time.
  Completer<bool>? _cfSolving;

  /// Cookie extraction callback for headless WebView.
  Future<void> _onCfSolved(InAppWebViewController controller) async {
    _webViewController = controller;
    _webViewReadyAt = DateTime.now();
    try {
      final cookieManager = CookieManager.instance();
      // Collect cookies from both www and api domains
      final merged = <String, String>{};
      for (final domain in ['$kProviderBase/', '$kProviderApiBase/']) {
        final cookies = await cookieManager.getCookies(url: WebUri(domain));
        for (final c in cookies) {
          merged[c.name] = c.value.toString();
        }
      }
      _cfCookieStr = merged.entries.map((e) => '${e.key}=${e.value}').join('; ');
      _cfUserAgent = await controller.evaluateJavascript(source: 'navigator.userAgent') as String? ?? '';
      final hasCf = merged.containsKey('cf_clearance');
      _log.info('Cloudflare solved - ${merged.length} cookies (cf_clearance: $hasCf)');
    } catch (e) {
      _log.warning('Failed to extract cookies: $e');
    }
  }

  /// Ensure WebView is running and CF is solved.
  /// After solving, probes Dio once to check if it works or gets 403.
  Future<bool> _ensureWebView() async {
    if (_isWebViewReady) return true;
    if (_cfSolving != null) return _cfSolving!.future;
    final solving = Completer<bool>();
    _cfSolving = solving;
    var result = false;
    try {
      result = await (_solveOverride ?? _solveHeadless)();
      // Probe Dio once so all subsequent calls know whether to use Dio or JS
      if (result && !_dioBlocked) {
        try {
          final headers = Map<String, String>.from(_browserHeaders);
          if (_cfUserAgent.isNotEmpty) headers['User-Agent'] = _cfUserAgent;
          if (_cfCookieStr.isNotEmpty) headers['Cookie'] = _cfCookieStr;
          await _dio.get(
            '$kProviderApiBase/api/financialdata/historical/46925?startDate=2026-04-01&endDate=2026-04-02&interval=Daily',
            options: Options(headers: headers, validateStatus: (s) => s != null && s < 400),
          );
          _log.info('Dio probe: OK - using Dio for API calls');
        } on DioException catch (e) {
          if (e.response?.statusCode == 403) {
            _dioBlocked = true;
            _log.info('Dio probe: 403 - all fetches will use WebView JS');
          }
        } catch (_) {}
      }
    } catch (e) {
      // A failed CF solve must not leave the mutex completer dangling —
      // that would hang every subsequent _ensureWebView call forever.
      _log.warning('_ensureWebView: CF solve failed: $e');
      result = false;
    } finally {
      solving.complete(result);
      _cfSolving = null;
    }
    return result;
  }

  /// Test seam: exercises [_ensureWebView] directly so the CF-solve mutex
  /// lifecycle can be verified without a real headless WebView.
  Future<bool> ensureWebViewForTest() => _ensureWebView();

  Future<bool> _solveHeadless() async {
    _log.info('Solving CF via headless WebView...');
    if (_webView != null) {
      try {
        await _webView!.dispose();
      } catch (_) {}
      _webView = null;
      _webViewController = null;
    }
    _dioBlocked = false; // reset — will probe after solve
    final completer = Completer<bool>();
    Timer? timeout;
    bool navigatedToApi = false;
    _webView = HeadlessInAppWebView(
      // Start on the api host so subsequent fetch() calls are same-origin.
      initialUrlRequest: URLRequest(url: WebUri('$kProviderApiBase/')),
      initialSettings: InAppWebViewSettings(javaScriptEnabled: true),
      onLoadStop: (controller, url) async {
        if (completer.isCompleted) return;
        final title = await controller.getTitle();
        final urlStr = url?.toString() ?? '';
        _log.fine('CF headless onLoadStop: url=$urlStr title=$title');

        // If CF challenge is still running, wait
        if (title != null && title.contains('Just a moment')) return;

        // If we landed on www (redirect), navigate to api for same-origin
        if (urlStr.contains(kProviderHost) && !navigatedToApi) {
          navigatedToApi = true;
          _log.info('CF solved on www, navigating to api host for same-origin...');
          await controller.loadUrl(
            urlRequest: URLRequest(url: WebUri('$kProviderApiBase/')),
          );
          return;
        }

        await _onCfSolved(controller);
        timeout?.cancel();
        completer.complete(true);
      },
    );
    timeout = Timer(const Duration(seconds: 30), () async {
      _log.warning('CF headless timed out');
      try {
        await _webView?.dispose();
      } catch (_) {}
      _webView = null;
      if (!completer.isCompleted) completer.complete(false);
    });
    await _webView!.run();
    return completer.future;
  }

  /// Fetch API data by running fetch() inside the WebView's JS context.
  /// Same-origin since the WebView is loaded on the api host.
  Future<Map<String, dynamic>?> _fetchViaJsFetch(String url, {String domainId = 'www'}) async {
    if (_jsFetchOverride != null) {
      return _jsFetchOverride(url, domainId);
    }
    if (_webViewController == null) return null;
    try {
      final js =
          '''
        (async () => {
          try {
            const r = await fetch('$url', {
              headers: { 'domain-id': '$domainId' }
            });
            if (!r.ok) return JSON.stringify({__error: r.status});
            return JSON.stringify(await r.json());
          } catch(e) {
            return JSON.stringify({__error: e.toString()});
          }
        })()
      ''';
      final result = await _webViewController!.callAsyncJavaScript(
        functionBody:
            '''
          const r = await fetch('$url', {
            headers: { 'domain-id': '$domainId' }
          });
          if (!r.ok) return {__error: r.status};
          return await r.json();
        ''',
      );
      if (result == null || result.value == null) {
        // Fallback to evaluateJavascript for platforms where callAsyncJavaScript
        // doesn't work as expected
        final resultStr = await _webViewController!.evaluateJavascript(source: js);
        if (resultStr == null) return null;
        final decoded = jsonDecode(resultStr is String ? resultStr : resultStr.toString());
        if (decoded is Map<String, dynamic> && decoded.containsKey('__error')) {
          _log.warning('_fetchViaJsFetch: $url -> error ${decoded['__error']}');
          return null;
        }
        return decoded as Map<String, dynamic>;
      }
      final value = result.value;
      if (value is Map<String, dynamic>) {
        if (value.containsKey('__error')) {
          _log.warning('_fetchViaJsFetch: $url -> error ${value['__error']}');
          return null;
        }
        return value;
      }
      // If returned as string, decode it
      if (value is String) {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic> && decoded.containsKey('__error')) {
          _log.warning('_fetchViaJsFetch: $url -> error ${decoded['__error']}');
          return null;
        }
        return decoded as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      _log.fine('_fetchViaJsFetch: $url -> $e');
      return null;
    }
  }

  /// Fetch HTML via the WebView's JS context (bypasses CF for pages like
  /// the provider's equities pages that block plain Dio). Used by CompositionService.
  Future<String?> fetchHtml(String url) async {
    if (!_isWebViewReady) {
      final ok = await _ensureWebView();
      if (!ok) return null;
    }
    if (_webViewController == null) return null;
    try {
      final result = await _webViewController!.evaluateJavascript(
        source:
            '''
        (async () => {
          try {
            const r = await fetch('$url');
            if (!r.ok) return null;
            return await r.text();
          } catch(e) { return null; }
        })()
      ''',
      );
      return result is String && result.isNotEmpty ? result : null;
    } catch (e) {
      _log.fine('fetchHtml: $url -> $e');
      return null;
    }
  }

  /// Headers that mimic a real browser's XHR call (from Edge HAR analysis).
  static const _browserHeaders = {
    'Accept': '*/*',
    'Accept-Language': 'en-US,en;q=0.9',
    'Origin': kProviderBase,
    'Referer': '$kProviderBase/',
    'Domain-Id': 'www',
    'sec-ch-ua': '"Chromium";v="131", "Not-A.Brand";v="24"',
    'sec-ch-ua-mobile': '?0',
    'sec-ch-ua-platform': '"Windows"',
    'sec-fetch-dest': 'empty',
    'sec-fetch-mode': 'cors',
    'sec-fetch-site': 'same-site',
  };

  /// Make a CF-protected API call.
  /// Tries Dio first (faster, supports parallel). If Dio gets 403 (e.g. TLS
  /// fingerprinting on Windows), switches permanently to JS fetch via headless
  /// WebView for the rest of the session.
  Future<Map<String, dynamic>?> _webViewFetch(String url, {String domainId = 'www'}) async {
    // Ensure WebView is ready (solves CF, caches cookies, probes Dio)
    if (!_isWebViewReady) {
      final ok = await _ensureWebView();
      if (!ok) return null;
    }

    // If Dio is known to be blocked, go straight to JS fetch
    if (_dioBlocked) {
      return await _fetchViaJsFetch(url, domainId: domainId);
    }

    return _fetchWithDioThenJs(url, domainId: domainId);
  }

  @visibleForTesting
  Future<Map<String, dynamic>?> fetchWithDioThenJsForTest(
    String url, {
    String domainId = 'www',
  }) => _fetchWithDioThenJs(url, domainId: domainId);

  Future<Map<String, dynamic>?> _fetchWithDioThenJs(String url, {String domainId = 'www'}) async {
    try {
      final headers = Map<String, String>.from(_browserHeaders);
      headers['User-Agent'] = _cfUserAgent.isNotEmpty
          ? _cfUserAgent
          : 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
      if (_cfCookieStr.isNotEmpty) {
        headers['Cookie'] = _cfCookieStr;
      }

      final response = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.json,
          headers: headers,
        ),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      _log.info('_webViewFetch: Dio returned non-JSON response, switching to JS fetch');
      _dioBlocked = true;
      return await _fetchViaJsFetch(url, domainId: domainId);
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        _dioBlocked = true;
        _log.info('_webViewFetch: Dio 403, switching to JS fetch');
        return await _fetchViaJsFetch(url, domainId: domainId);
      }
      _log.info('_webViewFetch: Dio ${e.response?.statusCode}, switching to JS fetch');
      _dioBlocked = true;
      return await _fetchViaJsFetch(url, domainId: domainId);
    } catch (e) {
      _log.fine('_webViewFetch: failed - $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────
  // the market data provider API: Search
  // ──────────────────────────────────────────────

  /// Search the market data provider for any query (name, ISIN, ticker, fund ID).
  /// Searches both international (www) and Italian (it) domains, merges results.
  /// Type names always come from the English (www) domain for consistent classification.
  Future<List<ProviderSearchResult>> search(String query) async {
    final url = '$kProviderApiBase/api/search/v2/search?q=${Uri.encodeComponent(query)}';

    _log.info('search: $query');

    // Search via _webViewFetch (Dio or JS depending on _dioBlocked)
    final results = <int, ProviderSearchResult>{};
    try {
      final wwwData = await _webViewFetch(url, domainId: 'www');
      final wwwQuotes = (wwwData?['quotes'] as List?) ?? [];
      for (final q in wwwQuotes) {
        final r = _parseSearchResult(q);
        results[r.cid] = r;
      }
    } catch (e) {
      _log.warning('search: www domain failed: $e');
    }

    // Also search Italian domain for local instruments (bonds, funds)
    try {
      final itData = await _webViewFetch(url, domainId: 'it');
      final itQuotes = (itData?['quotes'] as List?) ?? [];
      for (final q in itQuotes) {
        final r = _parseSearchResult(q);
        if (!results.containsKey(r.cid)) {
          results[r.cid] = r;
        }
      }
    } catch (e) {
      _log.warning('search: it domain failed: $e');
    }

    _log.info('search: got ${results.length} results for $query');
    return results.values.toList();
  }

  /// Resolve exchange listings for [isin] even when the search index does not
  /// match the raw ISIN. Every returned listing is verified against the
  /// instrument page ISIN before it can be used for pricing or asset creation.
  Future<List<ProviderSearchResult>> resolveListingsByIsin({
    required String isin,
    String? description,
    String? preferredTicker,
    String? preferredExchange,
    Iterable<String> extraQueries = const [],
  }) async {
    final targetIsin = isin.trim().toUpperCase();
    if (targetIsin.isEmpty) return const [];

    final byCid = <int, ProviderSearchResult>{};
    final detailsByCid = <int, ProviderSearchResult?>{};
    final canonicalPreferredExchange = _canonicalExchange(preferredExchange);
    final cached = await _cachedPreferredListing(
      isin: targetIsin,
      preferredTicker: preferredTicker,
      preferredExchange: canonicalPreferredExchange,
    );
    if (cached != null) byCid[cached.cid] = cached;

    final queries = _instrumentLookupQueries(
      isin: targetIsin,
      description: description,
      preferredTicker: preferredTicker,
      extraQueries: extraQueries,
    );

    for (final query in queries) {
      final results = await search(query);
      final isExactIsinQuery = query.trim().toUpperCase() == targetIsin;
      for (final candidate in results) {
        if (isExactIsinQuery || _matchesPreferredListing(candidate, preferredTicker, canonicalPreferredExchange)) {
          final listing = _trustedSearchListing(candidate, targetIsin);
          byCid[listing.cid] = listing;
          await _cacheResolvedListing(targetIsin, listing);
          continue;
        }

        final details = detailsByCid.putIfAbsent(
          candidate.cid,
          () => candidate.isin == targetIsin ? candidate : null,
        );
        final resolved = details ?? await resolveSearchResultDetails(candidate);
        detailsByCid[candidate.cid] = resolved;
        final resolvedIsin = (resolved?.isin ?? candidate.isin)?.trim().toUpperCase();
        if (resolvedIsin != targetIsin) continue;

        final listing = _mergeSearchAndPageResult(
          candidate,
          resolved,
          targetIsin,
        );
        byCid[listing.cid] = listing;
        await _cacheResolvedListing(targetIsin, listing);
      }
    }

    return byCid.values.toList()..sort((a, b) {
      final byExchange = a.exchange.compareTo(b.exchange);
      if (byExchange != 0) return byExchange;
      return a.symbol.compareTo(b.symbol);
    });
  }

  /// Fetch historical prices for an already-resolved listing. This avoids
  /// resolving the ticker again through a default exchange before an asset row
  /// exists locally.
  Future<Map<DateTime, double>> fetchHistoricalPricesForListing(
    ProviderSearchResult listing,
    DateTime from,
  ) async {
    if (listing.cid <= 0) return const {};
    final label = listing.symbol.trim().isNotEmpty ? listing.symbol : listing.description;
    return _fetchByCid(listing.cid, from, label: label);
  }

  List<String> _instrumentLookupQueries({
    required String isin,
    required String? description,
    required String? preferredTicker,
    required Iterable<String> extraQueries,
  }) {
    final seen = <String>{};
    final queries = <String>[];

    void add(String value) {
      final normalized = _squashLookupWhitespace(value);
      if (normalized.length < 3) return;
      final key = normalized.toLowerCase();
      if (seen.add(key)) queries.add(normalized);
    }

    add(isin);
    final ticker = preferredTicker?.trim();
    if (ticker != null && ticker.isNotEmpty) {
      add(ticker);
    }
    final desc = description?.trim();
    if (desc != null && desc.isNotEmpty) {
      add(desc);
      add(_removeInstrumentLookupNoise(desc));
      final significantPrefix = _significantLookupTokens(desc).take(6).join(' ');
      add(significantPrefix);
    }
    for (final query in extraQueries) {
      add(query);
    }
    return queries;
  }

  Future<ProviderSearchResult?> _cachedPreferredListing({
    required String isin,
    required String? preferredTicker,
    required String? preferredExchange,
  }) async {
    final ticker = preferredTicker?.trim();
    final exchange = preferredExchange?.trim();
    if (ticker == null || ticker.isEmpty || exchange == null || exchange.isEmpty) return null;
    final cidRow = await db
        .customSelect(
          'SELECT value FROM app_configs WHERE key = ?',
          variables: [Variable.withString('PROVIDER_CID_${isin}_$exchange')],
        )
        .getSingleOrNull();
    final cid = cidRow == null ? null : int.tryParse(cidRow.read<String>('value'));
    if (cid == null || cid <= 0) return null;

    final urlRow = await db
        .customSelect(
          'SELECT value FROM app_configs WHERE key = ?',
          variables: [Variable.withString('PROVIDER_URL_${isin}_$exchange')],
        )
        .getSingleOrNull();
    final typeRow = await db
        .customSelect(
          'SELECT value FROM app_configs WHERE key = ?',
          variables: [Variable.withString('PROVIDER_TYPE_${isin}_$exchange')],
        )
        .getSingleOrNull();
    var type = typeRow?.read<String>('value') ?? '';
    if (type.isEmpty) {
      final recovered = await _recoverListingType(
        ticker: ticker,
        exchange: exchange,
        cid: cid,
      );
      type = recovered ?? '';
    }

    return ProviderSearchResult(
      cid: cid,
      description: '',
      symbol: ticker,
      exchange: exchange,
      flag: '',
      type: type,
      url: urlRow?.read<String>('value'),
      isin: isin,
    );
  }

  Future<String?> _recoverListingType({
    required String ticker,
    required String exchange,
    required int cid,
  }) async {
    final candidates = await search(ticker);
    for (final candidate in candidates) {
      if (candidate.cid == cid) return candidate.type;
      if (candidate.symbol.trim().toUpperCase() == ticker.toUpperCase() && _canonicalExchange(candidate.exchange) == exchange) {
        return candidate.type;
      }
    }
    return null;
  }

  bool _matchesPreferredListing(
    ProviderSearchResult candidate,
    String? preferredTicker,
    String? preferredExchange,
  ) {
    final ticker = preferredTicker?.trim().toUpperCase();
    final exchange = preferredExchange?.trim();
    if (ticker == null || ticker.isEmpty || exchange == null || exchange.isEmpty) return false;
    return candidate.symbol.trim().toUpperCase() == ticker && _canonicalExchange(candidate.exchange) == exchange;
  }

  ProviderSearchResult _trustedSearchListing(ProviderSearchResult candidate, String verifiedIsin) {
    return ProviderSearchResult(
      cid: candidate.cid,
      description: candidate.description,
      symbol: candidate.symbol,
      exchange: _canonicalExchange(candidate.exchange) ?? candidate.exchange,
      flag: candidate.flag,
      type: candidate.type,
      url: candidate.url,
      isin: verifiedIsin,
    );
  }

  String? _canonicalExchange(String? exchange) {
    final value = exchange?.trim();
    if (value == null || value.isEmpty) return null;
    return exchangeSynonyms[value] ?? value;
  }

  static final _lookupNoiseWords = RegExp(
    r'\b(UCITS|ETF|ETC|ETN|ACC|DIST|DR|USD|EUR|GBP|CHF|HEDGED|CLASS|1C)\b',
    caseSensitive: false,
  );

  static String _removeInstrumentLookupNoise(String value) => _squashLookupWhitespace(value.replaceAll(_lookupNoiseWords, ' '));

  static Iterable<String> _significantLookupTokens(String value) sync* {
    for (final token in _squashLookupWhitespace(value).split(' ')) {
      if (token.isEmpty) continue;
      if (_lookupNoiseWords.hasMatch(token)) continue;
      yield token;
    }
  }

  static String _squashLookupWhitespace(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

  ProviderSearchResult _mergeSearchAndPageResult(
    ProviderSearchResult searchResult,
    ProviderSearchResult? pageResult,
    String verifiedIsin,
  ) {
    String firstNonEmpty(String? preferred, String fallback) {
      final value = preferred?.trim();
      return value == null || value.isEmpty ? fallback : value;
    }

    return ProviderSearchResult(
      cid: pageResult?.cid ?? searchResult.cid,
      description: firstNonEmpty(pageResult?.description, searchResult.description),
      symbol: firstNonEmpty(pageResult?.symbol, searchResult.symbol),
      exchange:
          exchangeSynonyms[firstNonEmpty(pageResult?.exchange, searchResult.exchange)] ??
          firstNonEmpty(pageResult?.exchange, searchResult.exchange),
      flag: firstNonEmpty(pageResult?.flag, searchResult.flag),
      type: firstNonEmpty(pageResult?.type, searchResult.type),
      url: pageResult?.url ?? searchResult.url,
      isin: verifiedIsin,
    );
  }

  Future<void> _cacheResolvedListing(String isin, ProviderSearchResult listing) async {
    final exchange = exchangeSynonyms[listing.exchange] ?? listing.exchange;
    if (exchange.isEmpty) return;
    final cidKey = 'PROVIDER_CID_${isin}_$exchange';
    await db
        .into(db.appConfigs)
        .insertOnConflictUpdate(
          AppConfigsCompanion.insert(
            key: cidKey,
            value: listing.cid.toString(),
            description: Value('the market data provider cid for $isin on $exchange'),
          ),
        );
    if (listing.url != null && listing.url!.isNotEmpty) {
      final urlKey = 'PROVIDER_URL_${isin}_$exchange';
      await db
          .into(db.appConfigs)
          .insertOnConflictUpdate(
            AppConfigsCompanion.insert(
              key: urlKey,
              value: listing.url!,
              description: Value('the market data provider URL for $isin'),
            ),
          );
    }
    if (listing.type.trim().isNotEmpty) {
      final typeKey = 'PROVIDER_TYPE_${isin}_$exchange';
      await db
          .into(db.appConfigs)
          .insertOnConflictUpdate(
            AppConfigsCompanion.insert(
              key: typeKey,
              value: listing.type,
              description: Value('the market data provider type for $isin'),
            ),
          );
    }
  }

  /// Resolve a user-pasted instrument page URL into an [ProviderSearchResult]
  /// by fetching the page and parsing its embedded `__NEXT_DATA__` JSON.
  ///
  /// Used when the search API has an indexing gap (some bonds / niche
  /// instruments are reachable by URL but missing from the search corpus).
  /// Caches the resolved cid and URL under the existing
  /// `PROVIDER_CID_<cacheKey>_<exchange>` / `PROVIDER_URL_<cacheKey>_<exchange>`
  /// keys so subsequent [_searchCid] calls hit cache.
  Future<UrlResolveResult> resolveFromInstrumentUrl(
    Uri url, {
    required String cacheKey,
    required String exchange,
  }) async {
    return resolveFromInstrumentUrlString(
      url.toString(),
      cacheKey: cacheKey,
      exchange: exchange,
    );
  }

  /// String overload that runs canonicalisation up-front and surfaces
  /// categorised rejection reasons for the UI.
  Future<UrlResolveResult> resolveFromInstrumentUrlString(
    String raw, {
    required String cacheKey,
    required String exchange,
  }) async {
    final outcome = canonicaliseInstrumentUrl(raw);
    if (outcome.uri == null) {
      switch (outcome.rejection!) {
        case InstrumentUrlRejection.invalidFormat:
          return const UrlResolveInvalidFormat();
        case InstrumentUrlRejection.wrongHost:
          return const UrlResolveWrongHost();
        case InstrumentUrlRejection.unsupportedCategory:
          return const UrlResolveUnsupportedCategory();
      }
    }
    final canonical = outcome.uri!;

    String? html;
    try {
      html = await (_pageFetcher ?? _fetchInstrumentPage)(canonical);
    } catch (e) {
      _log.fine('resolveFromInstrumentUrl: fetch threw: $e');
      return const UrlResolveFetchFailed();
    }
    if (html == null || html.isEmpty) {
      return const UrlResolveFetchFailed();
    }

    final parsed = parseProviderPage(html, canonical);
    if (parsed == null) {
      return const UrlResolveParseFailed();
    }

    // Cache cid + URL so future _searchCid calls short-circuit.
    final cidKey = 'PROVIDER_CID_${cacheKey}_$exchange';
    final urlKey = 'PROVIDER_URL_${cacheKey}_$exchange';
    await db
        .into(db.appConfigs)
        .insertOnConflictUpdate(
          AppConfigsCompanion.insert(
            key: cidKey,
            value: parsed.cid.toString(),
            description: Value('the market data provider cid for $cacheKey on $exchange'),
          ),
        );
    if (parsed.url != null && parsed.url!.isNotEmpty) {
      await db
          .into(db.appConfigs)
          .insertOnConflictUpdate(
            AppConfigsCompanion.insert(
              key: urlKey,
              value: parsed.url!,
              description: Value('the market data provider URL for $cacheKey'),
            ),
          );
    }
    _log.info('resolveFromInstrumentUrl: $cacheKey on $exchange -> cid=${parsed.cid}');
    return UrlResolveOk(parsed);
  }

  /// Resolve a search hit to its instrument-page metadata without writing
  /// cache rows. This is used by UI flows that need the canonical ISIN after
  /// a generic name/ticker search.
  Future<ProviderSearchResult?> resolveSearchResultDetails(
    ProviderSearchResult result,
  ) async {
    final rawUrl = result.url?.trim();
    if (rawUrl == null || rawUrl.isEmpty) return null;

    final absoluteUrl = rawUrl.startsWith('http') ? rawUrl : '$kProviderBase$rawUrl';
    final outcome = canonicaliseInstrumentUrl(absoluteUrl);
    final canonical = outcome.uri;
    if (canonical == null) return null;

    String? html;
    try {
      html = await (_pageFetcher ?? _fetchInstrumentPage)(canonical);
    } catch (e) {
      _log.fine('resolveSearchResultDetails: fetch threw: $e');
      return null;
    }
    if (html == null || html.isEmpty) return null;

    return parseProviderPage(html, canonical);
  }

  /// Fetch an instrument page HTML. Plain Dio first (works for most pages and
  /// avoids cross-origin fetch limits); if blocked (403), fall back to the
  /// CF-aware WebView fetch.
  Future<String?> _fetchInstrumentPage(Uri url) async {
    try {
      final response = await _dio.get<String>(
        url.toString(),
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
                'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml',
            'Accept-Language': 'en-US,en;q=0.9',
          },
          responseType: ResponseType.plain,
          followRedirects: true,
          validateStatus: (s) => s != null && s < 400,
        ),
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        _log.info('_fetchInstrumentPage: 403, retrying via WebView for ${url.path}');
        return await fetchHtml(url.toString());
      }
      _log.fine('_fetchInstrumentPage: ${e.response?.statusCode} for ${url.path}');
      return null;
    } catch (e) {
      _log.fine('_fetchInstrumentPage: $e');
      return null;
    }
  }

  static ProviderSearchResult _parseSearchResult(dynamic q) {
    final exchange = (q['exchange'] as String?) ?? '';
    final typeName = (q['typeName'] as String?) ?? (q['type'] as String?) ?? '';
    return ProviderSearchResult(
      cid: q['id'] as int,
      description: (q['description'] as String?) ?? '',
      symbol: (q['symbol'] as String?) ?? '',
      exchange: exchange,
      flag: (q['flag'] as String?) ?? '',
      type: typeName.isNotEmpty ? typeName : exchange,
      url: q['url'] as String?,
    );
  }

  /// Search for a ticker/ISIN on the market data provider, filtered by exchange.
  /// Returns the market data provider cid (instrument ID) or null.
  /// When [searchTerm] is an ISIN (12 chars, starts with 2 letters),
  /// matches by exchange only (ISIN results have exchange-specific symbols).
  Future<int?> _searchCid(String searchTerm, String exchange) async {
    // Check cached cid first
    final cidKey = 'PROVIDER_CID_${searchTerm}_$exchange';
    final cidRow = await db
        .customSelect(
          'SELECT value FROM app_configs WHERE key = ?',
          variables: [Variable.withString(cidKey)],
        )
        .getSingleOrNull();
    if (cidRow != null) {
      final cached = int.tryParse(cidRow.read<String>('value'));
      if (cached != null) return cached;
    }

    final exchangeNameList = _exchangeSynonyms[exchange] ?? [exchange];
    final isIsin = searchTerm.length == 12 && RegExp(r'^[A-Z]{2}\w{10}$').hasMatch(searchTerm);

    _log.info('searchCid: $searchTerm on ${exchangeNameList.first} (isIsin=$isIsin)');

    final results = await search(searchTerm);

    // Cache helper
    Future<int> cacheAndReturn(ProviderSearchResult r) async {
      await db
          .into(db.appConfigs)
          .insertOnConflictUpdate(
            AppConfigsCompanion.insert(
              key: cidKey,
              value: r.cid.toString(),
              description: Value('the market data provider cid for $searchTerm on ${exchangeNameList.first}'),
            ),
          );
      if (r.url != null && r.url!.isNotEmpty) {
        final urlKey = 'PROVIDER_URL_${searchTerm}_$exchange';
        await db
            .into(db.appConfigs)
            .insertOnConflictUpdate(
              AppConfigsCompanion.insert(
                key: urlKey,
                value: r.url!,
                description: Value('the market data provider URL for $searchTerm'),
              ),
            );
      }
      _log.info('searchCid: found $searchTerm -> cid=${r.cid} symbol=${r.symbol} (${r.exchange})');
      return r.cid;
    }

    if (isIsin) {
      // ISIN search: match by exchange only (symbols differ per exchange)
      for (final r in results) {
        if (exchangeNameList.any((name) => name.toLowerCase() == r.exchange.toLowerCase())) {
          return cacheAndReturn(r);
        }
      }
      // No exchange match -- take first result as fallback
      if (results.isNotEmpty) {
        _log.warning(
          'searchCid: ISIN $searchTerm - no exchange match for ${exchangeNameList.first}, '
          'using first result: ${results.first.symbol}@${results.first.exchange}',
        );
        return cacheAndReturn(results.first);
      }
    } else {
      // Ticker search: match by symbol AND exchange
      for (final r in results) {
        if (r.symbol.toUpperCase() == searchTerm.toUpperCase() &&
            exchangeNameList.any((name) => name.toLowerCase() == r.exchange.toLowerCase())) {
          return cacheAndReturn(r);
        }
      }
    }

    _log.warning(
      'searchCid: $searchTerm not found on ${exchangeNameList.first} '
      '(candidates: ${results.map((r) => '${r.symbol}@${r.exchange}').join(', ')})',
    );
    return null;
  }

  // ──────────────────────────────────────────────
  // the market data provider API: Live FX rate
  // ──────────────────────────────────────────────

  /// Cache of FX pair cids: "EUR/USD" → cid
  final _fxCidCache = <String, int>{};

  /// In-memory cache of live FX rates with 10-min TTL.
  final _fxRateCache = <String, (double, DateTime)>{};
  static const _fxRateTtl = Duration(minutes: 10);

  /// In-memory cache of live asset prices (assetId -> (price, fetchedAt)).
  final _livePriceCache = <int, (double, DateTime)>{};

  @override
  void onTodayPriceSynced(int assetId, double price, DateTime date) {
    _livePriceCache[assetId] = (price, date);
  }

  /// Whether the live price for [assetId] was fetched within the last 15 minutes.
  /// If true, the market is considered open; otherwise closed.
  bool isMarketOpen(int assetId) {
    final cached = _livePriceCache[assetId];
    if (cached == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final priceDate = cached.$2;
    final priceDay = DateTime(priceDate.year, priceDate.month, priceDate.day);
    return !priceDay.isBefore(today);
  }

  /// Get today's live price for an asset, persisting it to the DB.
  /// Returns the cached value if fresh (< 10 min), otherwise fetches from API.
  /// Falls back to the latest stored price in the DB.
  Future<double?> getLivePrice(int assetId) async {
    // Check cache
    final cached = _livePriceCache[assetId];
    if (cached != null && DateTime.now().difference(cached.$2) < _fxRateTtl) {
      return cached.$1;
    }

    // Resolve CID for this asset (ISIN-first, same logic as syncPrices/_searchCid)
    final assetRow = await db
        .customSelect(
          'SELECT ticker, isin, exchange, currency FROM assets WHERE id = ?',
          variables: [Variable.withInt(assetId)],
        )
        .getSingleOrNull();
    if (assetRow == null) return getPrice(assetId, DateTime.now());

    final isin = assetRow.readNullable<String>('isin');
    final ticker = assetRow.readNullable<String>('ticker');
    final exchange = assetRow.readNullable<String>('exchange') ?? 'Milan';
    final currency = assetRow.read<String>('currency');
    final searchTerm = (isin?.isNotEmpty == true) ? isin! : (ticker ?? '');
    if (searchTerm.isEmpty) return getPrice(assetId, DateTime.now());

    final cidKey = 'PROVIDER_CID_${searchTerm}_$exchange';
    final cidRow = await db
        .customSelect(
          'SELECT value FROM app_configs WHERE key = ?',
          variables: [Variable.withString(cidKey)],
        )
        .getSingleOrNull();
    final cid = cidRow != null ? int.tryParse(cidRow.read<String>('value')) : null;
    if (cid == null) return getPrice(assetId, DateTime.now());

    // Fetch last 3 days via WebView (same browser context as CF solve)
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 3));
    final fromStr = '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
    final toStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final url =
        '$kProviderApiBase/api/financialdata/historical/$cid'
        '?start-date=$fromStr&end-date=$toStr&time-frame=Daily&add-missing-rows=false';

    final data = await _webViewFetch(url);
    if (data != null) {
      final rows = (data['data'] as List?) ?? [];
      for (final row in rows) {
        final closeRaw = row['last_closeRaw'];
        if (closeRaw == null) continue;
        double? price;
        if (closeRaw is num) {
          price = closeRaw.toDouble();
        } else if (closeRaw is String) {
          price = double.tryParse(closeRaw);
        }
        if (price != null && price > 0) {
          final dateStr = row['rowDateTimestamp'] as String?;
          final priceDate = dateStr != null ? DateTime.tryParse(dateStr) : null;
          _livePriceCache[assetId] = (price, priceDate ?? now);
          // Persist to DB for offline access
          final day = DateTime(now.year, now.month, now.day);
          final c = MarketPricesCompanion(
            assetId: Value(assetId),
            date: Value(day),
            closePrice: Value(price),
            currency: Value(currency),
          );
          unawaited(
            db
                .into(db.marketPrices)
                .insertOnConflictUpdate(c)
                .then(
                  (_) {},
                  onError: (e) => _log.warning('Failed to persist live price for asset $assetId: $e'),
                ),
          );
          return price;
        }
      }
    }

    return getPrice(assetId, DateTime.now());
  }

  /// Get the live exchange rate from [from] to [to] via the market data provider.
  /// Searches for the currency pair, then fetches the latest price.
  Future<double?> getLiveFxRate(String from, String to) async {
    if (from == to) return 1.0;

    final pairKey = '$from/$to';
    final inversePairKey = '$to/$from';

    // Check cache
    final cached = _fxRateCache[pairKey];
    if (cached != null && DateTime.now().difference(cached.$2) < _fxRateTtl) {
      return cached.$1;
    }

    // Try direct pair first, then inverse
    var rate = await _fetchFxRate(pairKey);
    if (rate != null) {
      _fxRateCache[pairKey] = (rate, DateTime.now());
      _persistFxRate(from, to, rate);
      return rate;
    }

    rate = await _fetchFxRate(inversePairKey);
    if (rate != null) {
      final invRate = 1.0 / rate;
      _fxRateCache[pairKey] = (invRate, DateTime.now());
      _persistFxRate(from, to, invRate);
      return invRate;
    }

    return null;
  }

  /// Persist an FX rate (both directions) to the DB for offline access.
  /// Uses DoNothing on conflict so syncRates (which uses DoUpdate) always wins,
  /// ensuring a single consistent quoting convention (EUR/X) across devices.
  void _persistFxRate(String from, String to, double rate) {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    db
        .into(db.exchangeRates)
        .insert(
          ExchangeRatesCompanion(
            fromCurrency: Value(from),
            toCurrency: Value(to),
            date: Value(day),
            rate: Value(rate),
          ),
          onConflict: DoNothing(),
        )
        .then((_) {}, onError: (e) => _log.warning('Failed to persist FX rate $from/$to: $e'));
    db
        .into(db.exchangeRates)
        .insert(
          ExchangeRatesCompanion(
            fromCurrency: Value(to),
            toCurrency: Value(from),
            date: Value(day),
            rate: Value(1.0 / rate),
          ),
          onConflict: DoNothing(),
        )
        .then((_) {}, onError: (e) => _log.warning('Failed to persist FX rate $to/$from: $e'));
  }

  Future<double?> _fetchFxRate(String pairKey) async {
    try {
      // Resolve cid for currency pair
      var cid = _fxCidCache[pairKey];
      if (cid == null) {
        // Also check DB cache
        final cidKey = 'PROVIDER_FX_CID_$pairKey';
        final cidRow = await db
            .customSelect(
              'SELECT value FROM app_configs WHERE key = ?',
              variables: [Variable.withString(cidKey)],
            )
            .getSingleOrNull();
        if (cidRow != null) {
          cid = int.tryParse(cidRow.read<String>('value'));
        }

        if (cid == null) {
          final results = await search(pairKey);
          for (final r in results) {
            if (r.symbol.replaceAll(' ', '') == pairKey.replaceAll('/', '') || r.symbol == pairKey) {
              cid = r.cid;
              break;
            }
          }
          if (cid == null) return null;

          // Cache in DB
          await db
              .into(db.appConfigs)
              .insertOnConflictUpdate(
                AppConfigsCompanion.insert(
                  key: cidKey,
                  value: cid.toString(),
                  description: Value('the market data provider FX cid for $pairKey'),
                ),
              );
        }
        _fxCidCache[pairKey] = cid;
      }

      // Fetch via WebView (same browser context as CF solve)
      final now = DateTime.now();
      final from = now.subtract(const Duration(days: 3));
      final fromStr = '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
      final toStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final url =
          '$kProviderApiBase/api/financialdata/historical/$cid'
          '?start-date=$fromStr&end-date=$toStr&time-frame=Daily&add-missing-rows=false';

      final data = await _webViewFetch(url);
      if (data == null) return null;

      final rows = (data['data'] as List?) ?? [];
      for (final row in rows) {
        final closeRaw = row['last_closeRaw'];
        if (closeRaw == null) continue;
        double? price;
        if (closeRaw is num) {
          price = closeRaw.toDouble();
        } else if (closeRaw is String) {
          price = double.tryParse(closeRaw);
        }
        if (price != null && price > 0) return price;
      }
      return null;
    } catch (e) {
      _log.warning('_fetchFxRate: $pairKey failed - $e');
      return null;
    }
  }

  /// Fetch historical FX rates for a currency pair from [since] to today.
  /// Returns a map of date → rate (closing price).
  Future<Map<DateTime, double>> fetchHistoricalFxRates(String from, String to, DateTime since) async {
    final pairKey = '$from/$to';
    // Resolve CID (same pattern as _fetchFxRate)
    var cid = _fxCidCache[pairKey];
    if (cid == null) {
      final cidKey = 'PROVIDER_FX_CID_$pairKey';
      final cidRow = await db
          .customSelect(
            'SELECT value FROM app_configs WHERE key = ?',
            variables: [Variable.withString(cidKey)],
          )
          .getSingleOrNull();
      if (cidRow != null) {
        cid = int.tryParse(cidRow.read<String>('value'));
      }
      if (cid == null) {
        final results = await search(pairKey);
        for (final r in results) {
          if (r.symbol.replaceAll(' ', '') == pairKey.replaceAll('/', '') || r.symbol == pairKey) {
            cid = r.cid;
            break;
          }
        }
        if (cid == null) return {};
        await db
            .into(db.appConfigs)
            .insertOnConflictUpdate(
              AppConfigsCompanion.insert(
                key: cidKey,
                value: cid.toString(),
                description: Value('the market data provider FX cid for $pairKey'),
              ),
            );
      }
      _fxCidCache[pairKey] = cid;
    }
    return _fetchByCid(cid, since, label: pairKey);
  }

  // ──────────────────────────────────────────────
  // the market data provider API: Historical prices
  // ──────────────────────────────────────────────

  Future<Map<DateTime, double>> _fetchByCid(int cid, DateTime from, {String? label}) async {
    final tag = label ?? 'cid=$cid';
    final fromStr = '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
    final now = DateTime.now();
    final toStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final url =
        '$kProviderApiBase/api/financialdata/historical/$cid'
        '?start-date=$fromStr&end-date=$toStr&time-frame=Daily&add-missing-rows=false';

    _log.info('fetch: $tag (cid=$cid) from $fromStr to $toStr');

    final dataMap = await _webViewFetch(url);
    if (dataMap == null) {
      _log.fine('fetch: $tag (cid=$cid) - WebView fetch returned null');
      return {};
    }
    final rows = (dataMap['data'] as List?) ?? [];

    final prices = <DateTime, double>{};
    for (final row in rows) {
      // Use raw fields — they have proper types (ISO date, numeric close)
      final dateStr = row['rowDateTimestamp'] as String?;
      final closeRaw = row['last_closeRaw'];
      if (dateStr == null || closeRaw == null) continue;

      final dt = DateTime.tryParse(dateStr);
      if (dt == null) continue;
      final day = DateTime(dt.year, dt.month, dt.day);

      double? price;
      if (closeRaw is num) {
        price = closeRaw.toDouble();
      } else if (closeRaw is String) {
        price = double.tryParse(closeRaw);
      }
      if (price == null || price <= 0) continue;

      prices[day] = price;
    }

    _log.info('fetch: $tag (cid=$cid) -> ${prices.length} prices');
    return prices;
  }

  // ──────────────────────────────────────────────
  // MarketPriceService interface
  // ──────────────────────────────────────────────

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async {
    // Look up the asset's exchange to resolve the CID
    final row = await db
        .customSelect(
          'SELECT exchange FROM assets WHERE ticker = ? LIMIT 1',
          variables: [Variable.withString(ticker)],
        )
        .getSingleOrNull();
    final exchange = row?.readNullable<String>('exchange') ?? 'Milan';

    final cid = await _searchCid(ticker, exchange);
    if (cid == null) return {};
    return _fetchByCid(cid, from, label: ticker);
  }

  /// Human-readable label for an asset: "Name [TICKER] (ISIN)".
  static String _assetLabel(Asset asset) {
    final parts = [asset.name];
    if (asset.ticker != null && asset.ticker!.isNotEmpty) {
      parts.add('[${asset.ticker}]');
    }
    if (asset.isin != null && asset.isin!.isNotEmpty && asset.isin != asset.ticker) {
      parts.add('(${asset.isin})');
    }
    return parts.join(' ');
  }

  /// Backfill missing the market data provider URLs for assets that already have cached CIDs.
  Future<void> _backfillMissingUrls(List<Asset> assets) async {
    final missing = <(String, String, int)>[]; // (searchTerm, exchange, cachedCid)
    for (final asset in assets) {
      final searchTerm = (asset.isin?.isNotEmpty == true) ? asset.isin! : asset.ticker;
      if (searchTerm == null || searchTerm.isEmpty) continue;
      final exchange = asset.exchange ?? 'Milan';
      final urlKey = 'PROVIDER_URL_${searchTerm}_$exchange';
      final urlRow = await db
          .customSelect(
            'SELECT value FROM app_configs WHERE key = ?',
            variables: [Variable.withString(urlKey)],
          )
          .getSingleOrNull();
      if (urlRow != null) continue; // already has URL

      final cidKey = 'PROVIDER_CID_${searchTerm}_$exchange';
      final cidRow = await db
          .customSelect(
            'SELECT value FROM app_configs WHERE key = ?',
            variables: [Variable.withString(cidKey)],
          )
          .getSingleOrNull();
      if (cidRow == null) continue; // no CID cached, will be resolved later
      final cid = int.tryParse(cidRow.read<String>('value'));
      if (cid == null) continue;

      missing.add((searchTerm, exchange, cid));
    }

    if (missing.isEmpty) return;
    _log.info('backfillUrls: ${missing.length} assets missing URLs');

    await _runBatched(missing, _maxConcurrency, (record) async {
      final (searchTerm, exchange, cid) = record;
      try {
        final results = await search(searchTerm);
        for (final r in results) {
          if (r.cid == cid && r.url != null && r.url!.isNotEmpty) {
            final urlKey = 'PROVIDER_URL_${searchTerm}_$exchange';
            await db
                .into(db.appConfigs)
                .insertOnConflictUpdate(
                  AppConfigsCompanion.insert(
                    key: urlKey,
                    value: r.url!,
                    description: Value('the market data provider URL for $searchTerm'),
                  ),
                );
            _log.info('backfillUrls: cached URL for $searchTerm -> ${r.url}');
            break;
          }
        }
      } catch (e) {
        _log.warning('backfillUrls: failed for $searchTerm: $e');
      }
    });
  }

  /// Max concurrent HTTP requests to the market data provider to avoid rate-limiting.
  static const _maxConcurrency = 3;

  /// Buffer subtracted from firstBuy on initial sync. Covers a long weekend
  /// or holiday cluster so a single non-trading day around the buy date
  /// doesn't yield an empty fetch window.
  static const _initialSyncBuffer = Duration(days: 14);

  /// Default fetch start when no prior price has been stored. Subtracts
  /// [_initialSyncBuffer] from the asset's first buy so a holiday/weekend
  /// around the buy date still captures the prior trading day.
  static DateTime initialSyncDefaultFrom(DateTime? firstBuy) => firstBuy?.subtract(_initialSyncBuffer) ?? DateTime(2020, 1, 1);

  @override
  Future<void> syncPrices({bool forceToday = false}) async {
    try {
      final assets =
          await (db.select(db.assets)
                ..where((a) => a.isActive.equals(true))
                ..where((a) => a.ticker.isNotNull() | a.isin.isNotNull()))
              .get();

      _log.info('syncPrices: found ${assets.length} active assets with ticker/ISIN');
      if (assets.isEmpty) return;

      final now = DateTime.now();

      // Step 0: Backfill missing URLs for assets with cached CIDs
      await _backfillMissingUrls(assets);

      // Step 1: Resolve CIDs in parallel (search API doesn't need CF cookies)
      final candidates = <(Asset, String)>[]; // (asset, searchTerm)
      final backfillRanges = <int, DateTime>{}; // assetId → backfill-from date
      for (final asset in assets) {
        final searchTerm = (asset.isin?.isNotEmpty == true) ? asset.isin! : asset.ticker;
        if (searchTerm == null || searchTerm.isEmpty) continue;

        final lastDate = await getLastSyncDate(asset.id);
        final firstBuy = await getFirstBuyDate(asset.id);
        final firstPrice = await getFirstPriceDate(asset.id);
        final defaultFrom = initialSyncDefaultFrom(firstBuy);

        final needsBackfill = firstBuy != null && firstPrice != null && firstBuy.isBefore(firstPrice);

        // Re-fetch from lastDate (not +1) so that an intraday price stored
        // during trading hours gets corrected with the actual close.
        final from = lastDate ?? defaultFrom;

        final needsForward = forceToday || from.isBefore(now);

        if (!needsForward && !needsBackfill) {
          _log.fine('syncPrices: ${_assetLabel(asset)} - already up to date');
          continue;
        }

        if (needsBackfill) {
          backfillRanges[asset.id] = firstBuy;
          _log.info(
            'syncPrices: ${_assetLabel(asset)} - needs backfill from '
            '${formatYmd(firstBuy)} to '
            '${formatYmd(firstPrice)}',
          );
        }

        candidates.add((asset, searchTerm));
      }

      if (candidates.isEmpty) {
        _log.info('syncPrices: no assets need syncing');
        return;
      }

      // Resolve CIDs with bounded concurrency
      final assetCids = <Asset, int>{};
      await _runBatched(candidates, _maxConcurrency, (record) async {
        final (asset, searchTerm) = record;
        final label = _assetLabel(asset);
        final cid = await _searchCid(searchTerm, asset.exchange ?? 'Milan');
        if (cid != null) {
          assetCids[asset] = cid;
          _log.info('syncPrices: $label - resolved cid=$cid');
        } else {
          _log.warning('syncPrices: $label - could not resolve CID, skipping');
        }
      });

      if (assetCids.isEmpty) {
        _log.info('syncPrices: no assets need syncing');
        return;
      }

      // Step 2: Ensure WebView is ready (solves CF if needed)
      final cfOk = await _ensureWebView();
      if (!cfOk) {
        _log.warning('syncPrices: could not solve Cloudflare, aborting');
        return;
      }

      // Step 3: Fetch historical prices in parallel with bounded concurrency
      final entries = assetCids.entries.toList();
      await _runBatched(entries, _maxConcurrency, (entry) async {
        final asset = entry.key;
        final cid = entry.value;
        final label = _assetLabel(asset);

        try {
          // Backfill gap if needed (firstBuy → firstPrice)
          final backfillFrom = backfillRanges[asset.id];
          if (backfillFrom != null) {
            final firstPrice = await getFirstPriceDate(asset.id);
            if (firstPrice != null) {
              _log.info(
                'syncPrices: $label - backfilling from '
                '${formatYmd(backfillFrom)}',
              );
              final gapPrices = await _fetchByCid(cid, backfillFrom, label: label);
              if (gapPrices.isNotEmpty) {
                await db.batch((batch) {
                  for (final p in gapPrices.entries) {
                    final c = MarketPricesCompanion(
                      assetId: Value(asset.id),
                      date: Value(p.key),
                      closePrice: Value(p.value),
                      currency: Value(asset.currency),
                    );
                    batch.insert(db.marketPrices, c, onConflict: DoUpdate((_) => c));
                  }
                });
                _log.info('syncPrices: $label - backfilled ${gapPrices.length} prices');
              }
            }
          }

          // Forward fetch (incremental or forceToday)
          final lastDate = await getLastSyncDate(asset.id);
          final firstBuy = await getFirstBuyDate(asset.id);
          final defaultFrom = initialSyncDefaultFrom(firstBuy);

          // Re-fetch from lastDate (not +1) so that an intraday price stored
          // during trading hours gets corrected with the actual close.
          final from = lastDate ?? defaultFrom;

          if (forceToday || from.isBefore(now)) {
            final prices = await _fetchByCid(cid, from, label: label);
            if (prices.isNotEmpty) {
              await db.batch((batch) {
                for (final p in prices.entries) {
                  final c = MarketPricesCompanion(
                    assetId: Value(asset.id),
                    date: Value(p.key),
                    closePrice: Value(p.value),
                    currency: Value(asset.currency),
                  );
                  batch.insert(db.marketPrices, c, onConflict: DoUpdate((_) => c));
                }
              });
              _log.info('syncPrices: $label - stored ${prices.length} prices');
            }
          }
        } catch (e) {
          _log.warning('syncPrices: $label (cid=$cid) - failed: $e');
        }
      });

      _log.info('syncPrices: done');
    } catch (e, stack) {
      _log.warning('syncPrices: error', e, stack);
    }
  }

  /// Run [action] on each item with at most [maxConcurrent] in-flight at once.
  static Future<void> _runBatched<T>(
    List<T> items,
    int maxConcurrent,
    Future<void> Function(T) action,
  ) async {
    var index = 0;
    Future<void> worker() async {
      while (true) {
        final i = index++;
        if (i >= items.length) return;
        await action(items[i]);
      }
    }

    await Future.wait(
      List.generate(
        maxConcurrent.clamp(1, items.length),
        (_) => worker(),
      ),
    );
  }
}
