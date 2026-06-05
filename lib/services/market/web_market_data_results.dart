part of 'web_market_data_service.dart';

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
