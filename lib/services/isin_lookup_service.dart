import 'package:dio/dio.dart';

import '../utils/logger.dart';

final _log = getLogger('IsinLookupService');

/// Result of an ISIN lookup: ticker symbol and asset name.
class IsinLookupResult {
  final String? ticker;
  final String? name;

  const IsinLookupResult({this.ticker, this.name});

  bool get isEmpty => ticker == null && name == null;
}

/// Resolves ISIN codes to ticker symbols and asset names via the OpenFIGI API.
/// Free, no API key required for basic use (rate limit: ~20 req/min unauthenticated).
class IsinLookupService {
  static const _baseUrl = 'https://api.openfigi.com/v3/mapping';
  final Dio _dio;

  /// In-memory cache to avoid redundant API calls within a session.
  final Map<String, IsinLookupResult> _cache = {};

  IsinLookupService({Dio? dio}) : _dio = dio ?? Dio();

  /// Look up a single ISIN. Returns cached result if available.
  Future<IsinLookupResult> lookup(String isin) async {
    final key = isin.trim().toUpperCase();
    if (key.isEmpty) return const IsinLookupResult();

    if (_cache.containsKey(key)) {
      _log.fine('lookup: cache hit for $key');
      return _cache[key]!;
    }

    try {
      _log.info('lookup: querying OpenFIGI for ISIN=$key');
      final response = await _dio.post(
        _baseUrl,
        data: [
          {'idType': 'ID_ISIN', 'idValue': key}
        ],
        options: Options(
          headers: {'Content-Type': 'application/json'},
          responseType: ResponseType.json,
        ),
      );

      final data = response.data as List;
      if (data.isEmpty) {
        _log.info('lookup: empty response for $key');
        final result = const IsinLookupResult();
        _cache[key] = result;
        return result;
      }

      final firstResult = data[0] as Map<String, dynamic>;

      // Check for error (e.g. no results)
      if (firstResult.containsKey('error')) {
        _log.info('lookup: API error for $key: ${firstResult['error']}');
        final result = const IsinLookupResult();
        _cache[key] = result;
        return result;
      }

      final entries = firstResult['data'] as List? ?? [];
      if (entries.isEmpty) {
        _log.info('lookup: no data entries for $key');
        final result = const IsinLookupResult();
        _cache[key] = result;
        return result;
      }

      // Pick the best match: prefer equity, then first result
      Map<String, dynamic>? best;
      for (final entry in entries) {
        final e = entry as Map<String, dynamic>;
        final sector = (e['marketSector'] ?? '').toString().toLowerCase();
        if (sector == 'equity') {
          best = e;
          break;
        }
      }
      best ??= entries[0] as Map<String, dynamic>;

      final ticker = best['ticker']?.toString();
      final name = best['name']?.toString();
      _log.info('lookup: resolved $key → ticker=$ticker, name=$name');

      final result = IsinLookupResult(ticker: ticker, name: name);
      _cache[key] = result;
      return result;
    } on DioException catch (e) {
      _log.warning('lookup: network error for $key: ${e.message}');
      return const IsinLookupResult();
    } catch (e, stack) {
      _log.warning('lookup: unexpected error for $key', e, stack);
      return const IsinLookupResult();
    }
  }

  /// Batch lookup for multiple ISINs. Returns a map of ISIN → result.
  /// OpenFIGI supports up to 10 items per request (unauthenticated).
  Future<Map<String, IsinLookupResult>> lookupBatch(List<String> isins) async {
    final results = <String, IsinLookupResult>{};
    final uncached = <String>[];

    for (final isin in isins) {
      final key = isin.trim().toUpperCase();
      if (key.isEmpty) continue;
      if (_cache.containsKey(key)) {
        results[key] = _cache[key]!;
      } else {
        uncached.add(key);
      }
    }

    if (uncached.isEmpty) return results;

    // OpenFIGI allows up to 10 items per request without API key
    const batchSize = 10;
    for (var i = 0; i < uncached.length; i += batchSize) {
      final batch = uncached.sublist(i, (i + batchSize).clamp(0, uncached.length));
      _log.info('lookupBatch: querying ${batch.length} ISINs (batch ${i ~/ batchSize + 1})');

      try {
        final response = await _dio.post(
          _baseUrl,
          data: batch.map((isin) => {'idType': 'ID_ISIN', 'idValue': isin}).toList(),
          options: Options(
            headers: {'Content-Type': 'application/json'},
            responseType: ResponseType.json,
          ),
        );

        final data = response.data as List;
        for (var j = 0; j < batch.length && j < data.length; j++) {
          final isin = batch[j];
          final entry = data[j] as Map<String, dynamic>;

          if (entry.containsKey('error') || entry['data'] == null) {
            final result = const IsinLookupResult();
            _cache[isin] = result;
            results[isin] = result;
            continue;
          }

          final entries = entry['data'] as List;
          if (entries.isEmpty) {
            final result = const IsinLookupResult();
            _cache[isin] = result;
            results[isin] = result;
            continue;
          }

          // Pick best match: prefer equity
          Map<String, dynamic>? best;
          for (final e in entries) {
            final m = e as Map<String, dynamic>;
            if ((m['marketSector'] ?? '').toString().toLowerCase() == 'equity') {
              best = m;
              break;
            }
          }
          best ??= entries[0] as Map<String, dynamic>;

          final result = IsinLookupResult(
            ticker: best['ticker']?.toString(),
            name: best['name']?.toString(),
          );
          _cache[isin] = result;
          results[isin] = result;
          _log.fine('lookupBatch: $isin → ticker=${result.ticker}, name=${result.name}');
        }
      } on DioException catch (e) {
        _log.warning('lookupBatch: network error: ${e.message}');
        // Cache empties to avoid retrying
        for (final isin in batch) {
          if (!results.containsKey(isin)) {
            _cache[isin] = const IsinLookupResult();
            results[isin] = const IsinLookupResult();
          }
        }
      }
    }

    return results;
  }

  /// Clear the in-memory cache.
  void clearCache() => _cache.clear();
}
