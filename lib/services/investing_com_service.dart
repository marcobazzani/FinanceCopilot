import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../database/database.dart';
import '../utils/logger.dart';
import 'market_price_service.dart';

final _log = getLogger('InvestingComService');

/// Result from the Investing.com search API.
class InvestingSearchResult {
  final int cid;
  final String description;
  final String symbol;
  final String exchange;
  final String flag;
  final String type;
  final String? url; // relative URL path, e.g. "/equities/amazon-com-inc"

  const InvestingSearchResult({
    required this.cid,
    required this.description,
    required this.symbol,
    required this.exchange,
    required this.flag,
    required this.type,
    this.url,
  });
}

/// Investing.com exchange name mapping.
/// Keys match internal exchange codes in `assets.exchange`.
/// Investing.com exchange names (as returned by their search API).
/// Multiple names per exchange code since the API uses Italian names.
const _exchangeNames = <String, List<String>>{
  'MIL': ['Milano', 'Milan'],
  'NYQ': ['NASDAQ', 'NYSE'],  // Investing.com lists AMZN as NASDAQ even though it's NYQ
  'NMS': ['NASDAQ'],
  'NYS': ['NYSE'],
  'ASE': ['AMEX'],
  'XETRA': ['Xetra'],
  'FRA': ['Francoforte', 'Frankfurt'],
  'LON': ['London', 'Londra'],
  'AMS': ['Amsterdam'],
  'PAR': ['Parigi', 'Paris'],
  'BRU': ['Bruxelles', 'Brussels'],
  'LIS': ['Lisbona', 'Lisbon'],
  'SIX': ['Svizzera', 'Switzerland'],
  'TSE': ['Toronto'],
  'HKG': ['Hong Kong'],
  'TYO': ['Tokyo'],
};

/// Fetches historical prices from Investing.com.
///
/// Uses a headless WebView to solve Cloudflare challenges, then makes
/// direct API calls with the obtained cookies via Dio.
class InvestingComService extends MarketPriceService {
  final Dio _dio;

  /// Persistent headless WebView for CF-protected API calls.
  HeadlessInAppWebView? _webView;
  InAppWebViewController? _webViewController;
  DateTime? _webViewReadyAt;

  InvestingComService(super.db, {Dio? dio}) : _dio = dio ?? Dio();

  // ──────────────────────────────────────────────
  // Headless WebView: solve CF + make API calls in same browser context
  // ──────────────────────────────────────────────

  /// Whether the WebView is ready (CF solved, not expired).
  bool get _isWebViewReady =>
      _webViewController != null &&
      _webViewReadyAt != null &&
      DateTime.now().difference(_webViewReadyAt!).inMinutes < 30;

  /// Mutex: only one CF solve at a time.
  Completer<bool>? _cfSolving;

  /// Ensure the headless WebView is running and CF is solved.
  Future<bool> _ensureWebView() async {
    if (_isWebViewReady) return true;
    if (_cfSolving != null) return _cfSolving!.future;
    _cfSolving = Completer<bool>();

    _log.info('Solving Cloudflare challenge via headless WebView...');

    // Dispose old WebView if any
    if (_webView != null) {
      try { await _webView!.dispose(); } catch (_) {}
      _webView = null;
      _webViewController = null;
    }

    final completer = Completer<bool>();
    Timer? timeout;

    _webView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri('https://www.investing.com/'),
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
      ),
      onLoadStop: (controller, url) async {
        final title = await controller.getTitle();
        if (title != null && !title.contains('Just a moment')) {
          _webViewController = controller;
          _webViewReadyAt = DateTime.now();
          _log.info('Cloudflare solved — WebView ready');
          timeout?.cancel();
          if (!completer.isCompleted) completer.complete(true);
        }
      },
    );

    timeout = Timer(const Duration(seconds: 30), () async {
      _log.warning('Cloudflare challenge timed out');
      try { await _webView?.dispose(); } catch (_) {}
      _webView = null;
      _webViewController = null;
      if (!completer.isCompleted) completer.complete(false);
    });

    await _webView!.run();
    final result = await completer.future;
    _cfSolving?.complete(result);
    _cfSolving = null;
    return result;
  }

  /// Make a CF-protected API call.
  /// Uses Dio with cookies extracted from the WebView.
  Future<Map<String, dynamic>?> _webViewFetch(String url) async {
    if (!_isWebViewReady) {
      final ok = await _ensureWebView();
      if (!ok) return null;
    }

    try {
      // Extract fresh cookies + UA from the live WebView
      final cookieManager = CookieManager.instance();
      final cookies = await cookieManager.getCookies(
        url: WebUri('https://www.investing.com/'),
      );
      final cookieStr = cookies.map((c) => '${c.name}=${c.value}').join('; ');
      final ua = await _webViewController!.evaluateJavascript(
        source: 'navigator.userAgent',
      ) as String? ?? '';

      final response = await _dio.get(url, options: Options(
        responseType: ResponseType.json,
        headers: {
          'User-Agent': ua,
          'Cookie': cookieStr,
          'Accept': 'application/json',
          'Origin': 'https://www.investing.com',
          'Referer': 'https://www.investing.com/',
          'Domain-Id': 'www',
        },
      ));

      final data = response.data;
      if (data is String) return null;
      return data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        _log.fine('_webViewFetch: 403 — will re-solve CF');
        _webViewReadyAt = null;
      } else {
        _log.fine('_webViewFetch: ${e.response?.statusCode ?? "error"}');
      }
      return null;
    } catch (e) {
      _log.fine('_webViewFetch: failed — $e');
      return null;
    }
  }


  // ──────────────────────────────────────────────
  // Investing.com API: Search
  // ──────────────────────────────────────────────

  static Options _searchOptions() => Options(
        responseType: ResponseType.json,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
              'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json',
          'Origin': 'https://www.investing.com',
          'Referer': 'https://www.investing.com/',
          'Domain-Id': 'it',
        },
      );

  /// Search Investing.com for any query (name, ISIN, ticker, fund ID).
  /// Returns a list of search results.
  Future<List<InvestingSearchResult>> search(String query) async {
    final url =
        'https://api.investing.com/api/search/v2/search?q=${Uri.encodeComponent(query)}';

    _log.info('search: $query');

    final response = await _dio.get(url, options: _searchOptions());
    final data = response.data as Map<String, dynamic>;
    final quotes = (data['quotes'] as List?) ?? [];

    _log.info('search: got ${quotes.length} results for $query');

    return quotes.map((q) {
      final exchange = (q['exchange'] as String?) ?? '';
      final typeName = (q['typeName'] as String?) ?? '';
      return InvestingSearchResult(
        cid: q['id'] as int,
        description: (q['description'] as String?) ?? '',
        symbol: (q['symbol'] as String?) ?? '',
        exchange: exchange,
        flag: (q['flag'] as String?) ?? '',
        type: typeName.isNotEmpty ? '$typeName - $exchange' : exchange,
        url: q['url'] as String?,
      );
    }).toList();
  }

  /// Search for a ticker on Investing.com, filtered by exchange.
  /// Returns the Investing.com cid (instrument ID) or null.
  Future<int?> _searchCid(String ticker, String exchange) async {
    // Check cached cid first
    final cidKey = 'INVESTING_CID_${ticker}_$exchange';
    final cidRow = await db.customSelect(
      'SELECT value FROM app_configs WHERE key = ?',
      variables: [Variable.withString(cidKey)],
    ).getSingleOrNull();
    if (cidRow != null) {
      final cached = int.tryParse(cidRow.read<String>('value'));
      if (cached != null) return cached;
    }

    final exchangeNameList = _exchangeNames[exchange] ?? [exchange];

    _log.info('searchCid: $ticker on ${exchangeNameList.first}');

    final results = await search(ticker);

    for (final r in results) {
      if (r.symbol.toUpperCase() == ticker.toUpperCase() &&
          exchangeNameList.any((name) => name.toLowerCase() == r.exchange.toLowerCase())) {
        // Cache the cid and URL
        await db.into(db.appConfigs).insertOnConflictUpdate(AppConfigsCompanion.insert(
          key: cidKey, value: r.cid.toString(), description: Value('Investing.com cid for $ticker on ${exchangeNameList.first}'),
        ));
        if (r.url != null && r.url!.isNotEmpty) {
          final urlKey = 'INVESTING_URL_${ticker}_$exchange';
          await db.into(db.appConfigs).insertOnConflictUpdate(AppConfigsCompanion.insert(
            key: urlKey, value: r.url!, description: Value('Investing.com URL for $ticker'),
          ));
        }

        _log.info('searchCid: found $ticker → cid=${r.cid} (${r.exchange})');
        return r.cid;
      }
    }

    _log.warning('searchCid: $ticker not found on ${exchangeNameList.first} '
        '(candidates: ${results.map((r) => '${r.symbol}@${r.exchange}').join(', ')})');
    return null;
  }

  // ──────────────────────────────────────────────
  // Investing.com API: Live FX rate
  // ──────────────────────────────────────────────

  /// Cache of FX pair cids: "EUR/USD" → cid
  final _fxCidCache = <String, int>{};

  /// In-memory cache of live FX rates with 10-min TTL.
  final _fxRateCache = <String, (double, DateTime)>{};
  static const _fxRateTtl = Duration(minutes: 10);

  /// In-memory cache of live asset prices (assetId → (price, fetchedAt)).
  /// These are NOT stored to the DB — used only for display.
  final _livePriceCache = <int, (double, DateTime)>{};

  /// Get today's live price for an asset without storing it to the DB.
  /// Returns the cached value if fresh (< 10 min), otherwise fetches from API.
  /// Falls back to the latest stored price in the DB.
  Future<double?> getLivePrice(int assetId) async {
    // Check cache
    final cached = _livePriceCache[assetId];
    if (cached != null && DateTime.now().difference(cached.$2) < _fxRateTtl) {
      return cached.$1;
    }

    // Resolve CID for this asset
    final assetRow = await db.customSelect(
      'SELECT ticker, exchange FROM assets WHERE id = ?',
      variables: [Variable.withInt(assetId)],
    ).getSingleOrNull();
    if (assetRow == null) return getPrice(assetId, DateTime.now());

    final ticker = assetRow.readNullable<String>('ticker');
    final exchange = assetRow.readNullable<String>('exchange') ?? 'MIL';
    final searchTerm = ticker ?? '';
    if (searchTerm.isEmpty) return getPrice(assetId, DateTime.now());

    final cidKey = 'INVESTING_CID_${searchTerm}_$exchange';
    final cidRow = await db.customSelect(
      'SELECT value FROM app_configs WHERE key = ?',
      variables: [Variable.withString(cidKey)],
    ).getSingleOrNull();
    final cid = cidRow != null ? int.tryParse(cidRow.read<String>('value')) : null;
    if (cid == null) return getPrice(assetId, DateTime.now());

    // Fetch last 3 days via WebView (same browser context as CF solve)
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 3));
    final fromStr = '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
    final toStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final url = 'https://api.investing.com/api/financialdata/historical/$cid'
        '?start-date=$fromStr&end-date=$toStr&time-frame=Daily&add-missing-rows=false';

    final data = await _webViewFetch(url);
    if (data != null) {
      final rows = (data['data'] as List?) ?? [];
      for (final row in rows) {
        final closeRaw = row['last_closeRaw'];
        if (closeRaw == null) continue;
        double? price;
        if (closeRaw is num) price = closeRaw.toDouble();
        else if (closeRaw is String) price = double.tryParse(closeRaw);
        if (price != null && price > 0) {
          _livePriceCache[assetId] = (price, DateTime.now());
          return price;
        }
      }
    }

    return getPrice(assetId, DateTime.now());
  }

  /// Get the live exchange rate from [from] to [to] via Investing.com.
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
      return rate;
    }

    rate = await _fetchFxRate(inversePairKey);
    if (rate != null) {
      final invRate = 1.0 / rate;
      _fxRateCache[pairKey] = (invRate, DateTime.now());
      return invRate;
    }

    return null;
  }

  Future<double?> _fetchFxRate(String pairKey) async {
    try {
      // Resolve cid for currency pair
      var cid = _fxCidCache[pairKey];
      if (cid == null) {
        // Also check DB cache
        final cidKey = 'INVESTING_FX_CID_$pairKey';
        final cidRow = await db.customSelect(
          'SELECT value FROM app_configs WHERE key = ?',
          variables: [Variable.withString(cidKey)],
        ).getSingleOrNull();
        if (cidRow != null) {
          cid = int.tryParse(cidRow.read<String>('value'));
        }

        if (cid == null) {
          final results = await search(pairKey);
          for (final r in results) {
            if (r.symbol.replaceAll(' ', '') == pairKey.replaceAll('/', '') ||
                r.symbol == pairKey) {
              cid = r.cid;
              break;
            }
          }
          if (cid == null) return null;

          // Cache in DB
          await db.into(db.appConfigs).insertOnConflictUpdate(AppConfigsCompanion.insert(
            key: cidKey, value: cid.toString(), description: Value('Investing.com FX cid for $pairKey'),
          ));
        }
        _fxCidCache[pairKey] = cid;
      }

      // Fetch via WebView (same browser context as CF solve)
      final now = DateTime.now();
      final from = now.subtract(const Duration(days: 3));
      final fromStr = '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
      final toStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final url = 'https://api.investing.com/api/financialdata/historical/$cid'
          '?start-date=$fromStr&end-date=$toStr&time-frame=Daily&add-missing-rows=false';

      final data = await _webViewFetch(url);
      if (data == null) return null;

      final rows = (data['data'] as List?) ?? [];
      for (final row in rows) {
        final closeRaw = row['last_closeRaw'];
        if (closeRaw == null) continue;
        double? price;
        if (closeRaw is num) price = closeRaw.toDouble();
        else if (closeRaw is String) price = double.tryParse(closeRaw);
        if (price != null && price > 0) return price;
      }
      return null;
    } catch (e) {
      _log.warning('_fetchFxRate: $pairKey failed — $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────
  // Investing.com API: Historical prices
  // ──────────────────────────────────────────────

  Future<Map<DateTime, double>> _fetchByCid(
      int cid, DateTime from, {String? label}) async {
    final tag = label ?? 'cid=$cid';
    final fromStr =
        '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
    final now = DateTime.now();
    final toStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final url = 'https://api.investing.com/api/financialdata/historical/$cid'
        '?start-date=$fromStr&end-date=$toStr&time-frame=Daily&add-missing-rows=false';

    _log.info('fetch: $tag (cid=$cid) from $fromStr to $toStr');

    final dataMap = await _webViewFetch(url);
    if (dataMap == null) {
      _log.fine('fetch: $tag (cid=$cid) — WebView fetch returned null');
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

      // Never store today's price — market may still be open.
      // Today's price is fetched live via getLivePrice() for display only.
      final nowDt = DateTime.now();
      if (!day.isBefore(DateTime(nowDt.year, nowDt.month, nowDt.day))) continue;

      double? price;
      if (closeRaw is num) {
        price = closeRaw.toDouble();
      } else if (closeRaw is String) {
        price = double.tryParse(closeRaw);
      }
      if (price == null || price <= 0) continue;

      prices[day] = price;
    }

    _log.info('fetch: $tag (cid=$cid) → ${prices.length} prices');
    return prices;
  }

  // ──────────────────────────────────────────────
  // MarketPriceService interface
  // ──────────────────────────────────────────────

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(
      String ticker, String currency, DateTime from) async {
    // Look up the asset's exchange to resolve the CID
    final row = await db.customSelect(
      'SELECT exchange FROM assets WHERE ticker = ? LIMIT 1',
      variables: [Variable.withString(ticker)],
    ).getSingleOrNull();
    final exchange = row?.readNullable<String>('exchange') ?? 'MIL';

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

  /// Backfill missing Investing.com URLs for assets that already have cached CIDs.
  Future<void> _backfillMissingUrls(List<Asset> assets) async {
    final missing = <(String, String, int)>[]; // (searchTerm, exchange, cachedCid)
    for (final asset in assets) {
      final searchTerm = (asset.ticker?.isNotEmpty == true) ? asset.ticker! : asset.isin;
      if (searchTerm == null || searchTerm.isEmpty) continue;
      final exchange = asset.exchange ?? 'MIL';
      final urlKey = 'INVESTING_URL_${searchTerm}_$exchange';
      final urlRow = await db.customSelect(
        'SELECT value FROM app_configs WHERE key = ?',
        variables: [Variable.withString(urlKey)],
      ).getSingleOrNull();
      if (urlRow != null) continue; // already has URL

      final cidKey = 'INVESTING_CID_${searchTerm}_$exchange';
      final cidRow = await db.customSelect(
        'SELECT value FROM app_configs WHERE key = ?',
        variables: [Variable.withString(cidKey)],
      ).getSingleOrNull();
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
            final urlKey = 'INVESTING_URL_${searchTerm}_$exchange';
            await db.into(db.appConfigs).insertOnConflictUpdate(AppConfigsCompanion.insert(
              key: urlKey, value: r.url!, description: Value('Investing.com URL for $searchTerm'),
            ));
            _log.info('backfillUrls: cached URL for $searchTerm → ${r.url}');
            break;
          }
        }
      } catch (e) {
        _log.warning('backfillUrls: failed for $searchTerm: $e');
      }
    });
  }

  @override
  /// Max concurrent HTTP requests to Investing.com to avoid rate-limiting.
  static const _maxConcurrency = 3;

  Future<void> syncPrices({bool forceToday = false}) async {
    try {
      final assets = await (db.select(db.assets)
            ..where((a) => a.isActive.equals(true))
            ..where((a) => a.ticker.isNotNull() | a.isin.isNotNull()))
          .get();

      _log.info('syncPrices: found ${assets.length} active assets with ticker/ISIN');
      if (assets.isEmpty) return;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Step 0: Backfill missing URLs for assets with cached CIDs
      await _backfillMissingUrls(assets);

      // Step 1: Resolve CIDs in parallel (search API doesn't need CF cookies)
      final candidates = <(Asset, String)>[]; // (asset, searchTerm)
      final backfillRanges = <int, DateTime>{}; // assetId → backfill-from date
      for (final asset in assets) {
        final searchTerm = (asset.ticker?.isNotEmpty == true) ? asset.ticker! : asset.isin;
        if (searchTerm == null || searchTerm.isEmpty) continue;

        final lastDate = await getLastSyncDate(asset.id);
        final firstBuy = await getFirstBuyDate(asset.id);
        final firstPrice = await getFirstPriceDate(asset.id);
        final defaultFrom = firstBuy ?? DateTime(2020, 1, 1);

        final needsBackfill = firstBuy != null &&
            firstPrice != null &&
            firstBuy.isBefore(firstPrice);

        // Re-fetch from lastDate (not +1) so that an intraday price stored
        // during trading hours gets corrected with the actual close.
        final from = lastDate ?? defaultFrom;

        final needsForward = forceToday || from.isBefore(now);

        if (!needsForward && !needsBackfill) {
          _log.fine('syncPrices: ${_assetLabel(asset)} — already up to date');
          continue;
        }

        if (needsBackfill) {
          backfillRanges[asset.id] = firstBuy;
          _log.info('syncPrices: ${_assetLabel(asset)} — needs backfill from '
              '${firstBuy.toIso8601String().substring(0, 10)} to '
              '${firstPrice!.toIso8601String().substring(0, 10)}');
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
        final cid = await _searchCid(searchTerm, asset.exchange ?? 'MIL');
        if (cid != null) {
          assetCids[asset] = cid;
          _log.info('syncPrices: $label — resolved cid=$cid');
        } else {
          _log.warning('syncPrices: $label — could not resolve CID, skipping');
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
              _log.info('syncPrices: $label — backfilling from '
                  '${backfillFrom.toIso8601String().substring(0, 10)}');
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
                    batch.insert(db.marketPrices, c,
                        onConflict: DoUpdate((_) => c));
                  }
                });
                _log.info('syncPrices: $label — backfilled ${gapPrices.length} prices');
              }
            }
          }

          // Forward fetch (incremental or forceToday)
          final lastDate = await getLastSyncDate(asset.id);
          final firstBuy = await getFirstBuyDate(asset.id);
          final defaultFrom = firstBuy ?? DateTime(2020, 1, 1);

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
                  batch.insert(db.marketPrices, c,
                      onConflict: DoUpdate((_) => c));
                }
              });
              _log.info('syncPrices: $label — stored ${prices.length} prices');
            }
          }
        } catch (e) {
          _log.warning('syncPrices: $label (cid=$cid) — failed: $e');
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
    await Future.wait(List.generate(
      maxConcurrent.clamp(1, items.length),
      (_) => worker(),
    ));
  }
}
