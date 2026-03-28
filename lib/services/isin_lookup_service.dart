import '../utils/logger.dart';
import 'investing_com_service.dart';

final _log = getLogger('IsinLookupService');

/// A single exchange listing for an ISIN (from Investing.com search).
class IsinExchangeOption {
  final int cid;
  final String ticker;
  final String name;
  final String exchange; // Investing.com exchange name (e.g. "Milano", "London")
  final String? url;

  const IsinExchangeOption({
    required this.cid,
    required this.ticker,
    required this.name,
    required this.exchange,
    this.url,
  });
}

/// Result of an ISIN lookup: all available exchange listings.
class IsinLookupResult {
  final List<IsinExchangeOption> options;

  const IsinLookupResult({this.options = const []});

  bool get isEmpty => options.isEmpty;

  /// Pick the best option for a preferred exchange (e.g. "Milano").
  /// Falls back to first option if no match.
  IsinExchangeOption? bestFor(String? preferredExchange) {
    if (options.isEmpty) return null;
    if (preferredExchange != null) {
      final match = options.where((o) =>
          o.exchange.toLowerCase().contains(preferredExchange.toLowerCase())).firstOrNull;
      if (match != null) return match;
    }
    return options.first;
  }
}

/// Resolves ISINs to exchange listings via Investing.com search API.
class IsinLookupService {
  final InvestingComService _investing;
  final Map<String, IsinLookupResult> _cache = {};

  IsinLookupService(this._investing);

  /// Look up all exchange listings for a single ISIN.
  Future<IsinLookupResult> lookup(String isin) async {
    final key = isin.trim().toUpperCase();
    if (key.isEmpty) return const IsinLookupResult();
    if (_cache.containsKey(key)) return _cache[key]!;

    try {
      _log.info('lookup: searching Investing.com for ISIN=$key');
      final results = await _investing.search(key);

      final options = results
          .where((r) => r.symbol.isNotEmpty)
          .map((r) => IsinExchangeOption(
                cid: r.cid,
                ticker: r.symbol,
                name: r.description,
                exchange: r.exchange,
                url: r.url,
              ))
          .toList();

      _log.info('lookup: $key -> ${options.length} listings: ${options.map((o) => "${o.ticker}@${o.exchange}").join(", ")}');
      final result = IsinLookupResult(options: options);
      _cache[key] = result;
      return result;
    } catch (e) {
      _log.warning('lookup: failed for $key: $e');
      return const IsinLookupResult();
    }
  }

  /// Batch lookup for multiple ISINs.
  Future<Map<String, IsinLookupResult>> lookupBatch(List<String> isins) async {
    final results = <String, IsinLookupResult>{};
    for (final isin in isins) {
      results[isin.trim().toUpperCase()] = await lookup(isin);
    }
    return results;
  }

  void clearCache() => _cache.clear();
}
