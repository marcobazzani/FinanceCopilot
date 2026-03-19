import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../database/database.dart';
import '../utils/logger.dart';
import 'market_price_service.dart';

final _log = getLogger('InvestingComService');

/// Investing.com exchange name mapping.
/// Keys match internal exchange codes in `assets.exchange`.
/// Investing.com exchange names (as returned by their search API).
/// Multiple names per exchange code since the API uses Italian names.
const _exchangeNames = <String, List<String>>{
  'MIL': ['Milano'],
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
  'SIX': ['Svizzera'],
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

  /// Cloudflare cookies obtained from headless WebView.
  Map<String, String> _cfCookies = {};
  String _userAgent = '';
  DateTime? _cookiesObtainedAt;

  InvestingComService(super.db, {Dio? dio}) : _dio = dio ?? Dio();

  // ──────────────────────────────────────────────
  // Cloudflare cookie resolution via headless WebView
  // ──────────────────────────────────────────────

  /// Whether cookies are still valid (~30 min window to be safe).
  bool get _hasFreshCookies =>
      _cookiesObtainedAt != null &&
      DateTime.now().difference(_cookiesObtainedAt!).inMinutes < 30 &&
      _cfCookies.isNotEmpty;

  /// Solve the Cloudflare challenge using a headless InAppWebView.
  /// Returns true if cookies were obtained successfully.
  Future<bool> _solveCloudflareCookies() async {
    if (_hasFreshCookies) return true;

    _log.info('Solving Cloudflare challenge via headless WebView...');

    final completer = Completer<bool>();

    HeadlessInAppWebView? headless;
    Timer? timeout;

    headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri('https://www.investing.com/'),
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        // Don't set custom user agent — Cloudflare detects it
      ),
      onLoadStop: (controller, url) async {
        // Check if we've passed Cloudflare (page title won't be "Just a moment...")
        final title = await controller.getTitle();
        if (title != null && !title.contains('Just a moment')) {
          // Extract cookies
          final cookieManager = CookieManager.instance();
          final cookies = await cookieManager.getCookies(
            url: WebUri('https://www.investing.com/'),
          );

          _cfCookies = {};
          for (final cookie in cookies) {
            _cfCookies[cookie.name] = cookie.value.toString();
          }

          // Get the user agent the WebView used
          _userAgent = await controller.evaluateJavascript(
                source: 'navigator.userAgent',
              ) as String? ??
              '';

          _cookiesObtainedAt = DateTime.now();
          _log.info(
              'Cloudflare solved: ${_cfCookies.length} cookies, UA: ${_userAgent.substring(0, 50)}...');

          timeout?.cancel();
          await headless?.dispose();
          if (!completer.isCompleted) completer.complete(true);
        }
      },
    );

    // Timeout after 15 seconds
    timeout = Timer(const Duration(seconds: 15), () async {
      _log.warning('Cloudflare challenge timed out');
      await headless?.dispose();
      if (!completer.isCompleted) completer.complete(false);
    });

    await headless.run();
    return completer.future;
  }

  /// Build Dio options with Cloudflare cookies + matching UA.
  Options _apiOptions() {
    final cookieStr =
        _cfCookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
    return Options(
      responseType: ResponseType.json,
      headers: {
        'User-Agent': _userAgent,
        'Cookie': cookieStr,
        'Accept': 'application/json',
        'Origin': 'https://www.investing.com',
        'Referer': 'https://www.investing.com/',
        'Domain-Id': 'it',
      },
    );
  }

  // ──────────────────────────────────────────────
  // Investing.com API: Search
  // ──────────────────────────────────────────────

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

    // Search without type filter — works reliably across all instrument types
    final url =
        'https://api.investing.com/api/search/v2/search?q=$ticker';

    _log.info('search: $ticker on ${exchangeNameList.first}');

    final response = await _dio.get(
      url,
      options: Options(
        responseType: ResponseType.json,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
              'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json',
          'Origin': 'https://www.investing.com',
          'Referer': 'https://www.investing.com/',
          'Domain-Id': 'it',
        },
      ),
    );
    final data = response.data as Map<String, dynamic>;
    final quotes = (data['quotes'] as List?) ?? [];

    _log.info('search: got ${quotes.length} results for $ticker');

    for (final q in quotes) {
      final qExchange = (q['exchange'] as String?) ?? '';
      final qSymbol = (q['symbol'] as String?) ?? '';
      if (qSymbol.toUpperCase() == ticker.toUpperCase() &&
          exchangeNameList.any((name) => name.toLowerCase() == qExchange.toLowerCase())) {
        final cid = q['id'] as int;

        // Cache the cid
        await db.customStatement(
          'INSERT OR REPLACE INTO app_configs (key, value, description) VALUES (?, ?, ?)',
          [cidKey, cid.toString(), 'Investing.com cid for $ticker on ${exchangeNameList.first}'],
        );

        _log.info('search: found $ticker → cid=$cid ($qExchange)');
        return cid;
      }
    }

    _log.warning('search: $ticker not found on ${exchangeNameList.first} '
        '(candidates: ${quotes.map((q) => '${q['symbol']}@${q['exchange']}').join(', ')})');
    return null;
  }

  // ──────────────────────────────────────────────
  // Investing.com API: Historical prices
  // ──────────────────────────────────────────────

  Future<Map<DateTime, double>> _fetchByCid(
      int cid, DateTime from) async {
    final fromStr =
        '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
    final now = DateTime.now();
    final toStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final url = 'https://api.investing.com/api/financialdata/historical/$cid'
        '?start-date=$fromStr&end-date=$toStr&time-frame=Daily&add-missing-rows=false';

    _log.info('fetch: cid=$cid from $fromStr to $toStr');

    final response = await _dio.get(url, options: _apiOptions());
    final data = response.data;

    if (data is String) {
      _log.warning('fetch: got non-JSON response for cid=$cid (Cloudflare block?)');
      return {};
    }
    final dataMap = data as Map<String, dynamic>;
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

    _log.info('fetch: got ${prices.length} prices for cid=$cid');
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
    return _fetchByCid(cid, from);
  }

  @override
  Future<void> syncPrices({bool forceToday = false}) async {
    try {
      final assets = await (db.select(db.assets)
            ..where((a) => a.isActive.equals(true))
            ..where((a) => a.ticker.isNotNull()))
          .get();

      _log.info('syncPrices: found ${assets.length} active assets with tickers');
      if (assets.isEmpty) return;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Step 1: Resolve all cids first (search API doesn't need CF cookies)
      // Also detect gaps: if firstBuy < firstPrice, we need to backfill.
      final assetCids = <Asset, int>{};
      final backfillRanges = <int, DateTime>{}; // assetId → backfill-from date
      for (final asset in assets) {
        final ticker = asset.ticker;
        if (ticker == null || ticker.isEmpty) continue;

        final lastDate = await getLastSyncDate(asset.id);
        final firstBuy = await getFirstBuyDate(asset.id);
        final firstPrice = await getFirstPriceDate(asset.id);
        final defaultFrom = firstBuy ?? DateTime(2020, 1, 1);

        // Check if we need to backfill a gap (firstBuy before firstPrice)
        final needsBackfill = firstBuy != null &&
            firstPrice != null &&
            firstBuy.isBefore(firstPrice);

        final from = lastDate != null
            ? lastDate.add(const Duration(days: 1))
            : defaultFrom;

        final needsForward = forceToday || from.isBefore(now);

        if (!needsForward && !needsBackfill) {
          _log.fine('syncPrices: ${asset.name} already up to date');
          continue;
        }

        if (needsBackfill) {
          backfillRanges[asset.id] = firstBuy;
          _log.info('syncPrices: ${asset.name} needs backfill from '
              '${firstBuy.toIso8601String().substring(0, 10)} to '
              '${firstPrice!.toIso8601String().substring(0, 10)}');
        }

        final cid = await _searchCid(ticker, asset.exchange ?? 'MIL');
        if (cid != null) {
          assetCids[asset] = cid;
        }

        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (assetCids.isEmpty) {
        _log.info('syncPrices: no assets need syncing');
        return;
      }

      // Step 2: Solve Cloudflare for historical API access
      final cfOk = await _solveCloudflareCookies();
      if (!cfOk) {
        _log.warning('syncPrices: could not solve Cloudflare, aborting');
        return;
      }

      // Step 3: Fetch historical prices for each asset
      for (final entry in assetCids.entries) {
        final asset = entry.key;
        final cid = entry.value;

        try {
          // Backfill gap if needed (firstBuy → firstPrice)
          final backfillFrom = backfillRanges[asset.id];
          if (backfillFrom != null) {
            final firstPrice = await getFirstPriceDate(asset.id);
            if (firstPrice != null) {
              _log.info('syncPrices: backfilling ${asset.name} from '
                  '${backfillFrom.toIso8601String().substring(0, 10)}');
              final gapPrices = await _fetchByCid(cid, backfillFrom);
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
                _log.info('syncPrices: backfilled ${gapPrices.length} prices for ${asset.name}');
              }
              await Future.delayed(const Duration(milliseconds: 1500));
            }
          }

          // Forward fetch (incremental or forceToday)
          final lastDate = await getLastSyncDate(asset.id);
          final firstBuy = await getFirstBuyDate(asset.id);
          final defaultFrom = firstBuy ?? DateTime(2020, 1, 1);

          DateTime from;
          if (lastDate != null) {
            if (forceToday) {
              final lastPlus1 = lastDate.add(const Duration(days: 1));
              from = today.isAfter(lastPlus1) ? lastPlus1 : today;
            } else {
              from = lastDate.add(const Duration(days: 1));
            }
          } else {
            from = defaultFrom;
          }

          if (forceToday || from.isBefore(now)) {
            final prices = await _fetchByCid(cid, from);
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
              _log.info(
                  'syncPrices: stored ${prices.length} prices for ${asset.name}');
            }
          }
        } catch (e) {
          _log.warning(
              'syncPrices: failed for ${asset.name} (cid=$cid): $e');
        }

        await Future.delayed(const Duration(milliseconds: 1500));
      }

      _log.info('syncPrices: done');
    } catch (e, stack) {
      _log.warning('syncPrices: error', e, stack);
    }
  }
}
