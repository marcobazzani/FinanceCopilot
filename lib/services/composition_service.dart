import 'dart:convert';

import 'package:dio/dio.dart';

import '../database/database.dart';
import '../utils/logger.dart';

final _log = getLogger('CompositionService');

/// Fetches asset composition/classification data from multiple public sources
/// and stores it in the asset_compositions table.
///
/// Sources:
/// - ETFs/ETCs: justETF (country/sector/holdings breakdown + investment focus)
/// - Individual stocks: stockanalysis.com (country, sector)
/// - Mutual/pension funds: investing.com fund holdings page (sector, region, top holdings)
/// - Fallback: derives classification from asset name/type
class CompositionService {
  final AppDatabase _db;
  final Dio _dio;

  CompositionService(this._db, {Dio? dio}) : _dio = dio ?? Dio();

  static const _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  /// Sync composition data for all active assets.
  Future<void> syncCompositions() async {
    final assets = await (_db.select(_db.assets)
          ..where((a) => a.isActive.equals(true)))
        .get();

    _log.info('syncCompositions: ${assets.length} active assets');

    for (final asset in assets) {
      // Skip if we have recent data (< 7 days old)
      final existing = await (_db.select(_db.assetCompositions)
            ..where((c) => c.assetId.equals(asset.id))
            ..limit(1))
          .getSingleOrNull();
      if (existing != null) {
        final age = DateTime.now().difference(existing.updatedAt);
        if (age.inDays < 7) {
          _log.fine('syncCompositions: ${asset.name} — fresh (${age.inDays}d), skipping');
          continue;
        }
      }

      try {
        final data = await _fetchForAsset(asset);
        if (data.isEmpty) {
          _log.fine('syncCompositions: ${asset.name} — no data resolved');
          continue;
        }

        // Replace old data
        await (_db.delete(_db.assetCompositions)
              ..where((c) => c.assetId.equals(asset.id)))
            .go();

        await _db.batch((batch) {
          for (final entry in data) {
            batch.insert(
              _db.assetCompositions,
              AssetCompositionsCompanion.insert(
                assetId: asset.id,
                type: entry.type,
                name: entry.name,
                weight: entry.weight,
              ),
            );
          }
        });

        _log.info('syncCompositions: ${asset.name} — stored ${data.length} entries');
      } catch (e) {
        _log.warning('syncCompositions: ${asset.name} — failed: $e');
      }
    }

    _log.info('syncCompositions: done');
  }

  /// Route to the appropriate data source based on ISIN pattern and asset metadata.
  Future<List<_Entry>> _fetchForAsset(Asset asset) async {
    final isin = asset.isin ?? '';

    // Morningstar fund IDs start with "0P" — use investing.com fund holdings
    if (isin.startsWith('0P')) {
      return _fetchFundFromInvestingCom(asset);
    }

    // Standard ISINs (2-letter country + 10 chars) → try justETF first
    if (isin.length == 12 && RegExp(r'^[A-Z]{2}').hasMatch(isin)) {
      final etfResult = await _fetchEtf(asset);
      if (etfResult.isNotEmpty) return etfResult;

      // If justETF didn't find it (e.g. it's a stock, not an ETF),
      // try stockanalysis.com using ticker
      if (asset.ticker != null && asset.ticker!.isNotEmpty) {
        final stockResult = await _fetchStock(asset);
        if (stockResult.isNotEmpty) return stockResult;
      }
    }

    // Has ticker but no ISIN or non-standard ISIN → try stockanalysis
    if (asset.ticker != null && asset.ticker!.isNotEmpty) {
      final stockResult = await _fetchStock(asset);
      if (stockResult.isNotEmpty) return stockResult;
    }

    // Try investing.com search as last resort
    return _fetchFundFromInvestingCom(asset);
  }

  // ── ETFs/ETCs: justETF ──────────────────────────────────

  Future<List<_Entry>> _fetchEtf(Asset asset) async {
    final isin = asset.isin!;
    final url = 'https://www.justetf.com/en/etf-profile.html?isin=$isin';
    _log.fine('fetchEtf: ${asset.name} from justETF ($isin)');

    final html = await _fetchHtml(url);
    if (html == null) return [];

    // Check if justETF actually has this fund (redirect to search = not found)
    if (!html.contains('data-testid="etf-basics_data_table"') &&
        !html.contains('data-testid="etf-holdings_')) {
      _log.fine('fetchEtf: ${asset.name} — not found on justETF');
      return [];
    }

    final entries = <_Entry>[];

    // Try to get structured composition (equity ETFs)
    entries.addAll(_parseJustEtfSection(html, 'countries'));
    entries.addAll(_parseJustEtfSection(html, 'sectors'));
    entries.addAll(_parseJustEtfHoldings(html));

    // If no structured data (money market, commodity, gold, bond ETFs),
    // derive from the "Investment focus" field
    if (entries.isEmpty) {
      entries.addAll(_parseInvestmentFocus(html, asset));
    }

    // Store the asset class from the Investment focus field
    final assetClass = _detectAssetClass(html);
    if (assetClass != null) {
      entries.add(_Entry('assetclass', assetClass, 100));
    }

    // Store source URL
    entries.add(_Entry('source_url', url, 0));

    return entries;
  }

  /// Parse the "Investment focus" field from justETF.
  /// Format: "Equity, World" or "Money Market, EUR, Europe" or "Commodities, Broad market"
  List<_Entry> _parseInvestmentFocus(String html, Asset asset) {
    final entries = <_Entry>[];

    String? focus;

    // Primary: data-testid attribute for investment focus value
    final testIdPattern = RegExp(
      r'data-testid="tl_etf-basics_value_investment-focus"[^>]*>([^<]+)',
    );
    focus = testIdPattern.firstMatch(html)?.group(1)?.trim();

    // Fallback: plain table cell
    if (focus == null || focus.isEmpty) {
      final focusPattern = RegExp(
        r'Investment focus</td>\s*<td[^>]*>\s*([^<]+)',
      );
      focus = focusPattern.firstMatch(html)?.group(1)?.trim();
    }

    if (focus != null && focus.isNotEmpty) {
      _log.fine('parseInvestmentFocus: ${asset.name} → "$focus"');
      final parts = focus.split(',').map((s) => s.trim()).toList();

      if (parts.isNotEmpty) {
        entries.add(_Entry('sector', parts[0], 100));
      }

      for (final part in parts.skip(1)) {
        if (_isGeographic(part)) {
          entries.add(_Entry('country', part, 100));
        }
      }
    }

    // Fund domicile as country fallback
    if (!entries.any((e) => e.type == 'country')) {
      final dm = RegExp(r'data-testid="tl_etf-basics_value_fund-domicile"[^>]*>([^<]+)')
          .firstMatch(html);
      final domicile = dm?.group(1)?.trim();
      if (domicile != null && domicile.isNotEmpty) {
        entries.add(_Entry('country', domicile, 100));
      }
    }

    entries.add(_Entry('holding', asset.name, 100));
    return entries;
  }

  /// Detect the real asset class from justETF's Investment focus field.
  /// Returns labels like "Stock ETF", "Bond ETF", "Commodity ETF", "Gold ETC", "Money Market ETF".
  String? _detectAssetClass(String html) {
    final testIdPattern = RegExp(
      r'data-testid="tl_etf-basics_value_investment-focus"[^>]*>([^<]+)',
    );
    var focus = testIdPattern.firstMatch(html)?.group(1)?.trim().toLowerCase();
    focus ??= RegExp(r'Investment focus</td>\s*<td[^>]*>\s*([^<]+)')
        .firstMatch(html)?.group(1)?.trim().toLowerCase();
    if (focus == null) return null;

    if (focus.contains('money market')) return 'Money Market ETF';
    if (focus.contains('precious metal') || focus.contains('gold')) return 'Gold ETC';
    if (focus.contains('commodit')) return 'Commodity ETF';
    if (focus.contains('bond') || focus.contains('government') || focus.contains('fixed income')) return 'Bond ETF';
    if (focus.contains('equity') || focus.contains('stock')) return 'Stock ETF';
    return 'ETF';
  }

  bool _isGeographic(String text) {
    const geoTerms = {
      'world', 'global', 'europe', 'usa', 'us', 'united states',
      'asia', 'emerging', 'japan', 'china', 'uk', 'eurozone',
      'north america', 'latin america', 'africa', 'pacific',
      'developed', 'frontier',
    };
    final lower = text.toLowerCase();
    return geoTerms.any((t) => lower.contains(t));
  }

  // ── Individual Stocks: stockanalysis.com ──────────────────

  Future<List<_Entry>> _fetchStock(Asset asset) async {
    final ticker = asset.ticker;
    if (ticker == null || ticker.isEmpty) return [];

    final url = 'https://stockanalysis.com/stocks/${ticker.toLowerCase()}/company/';
    _log.fine('fetchStock: ${asset.name} from stockanalysis.com ($ticker)');

    final html = await _fetchHtml(url);
    if (html == null) return [];

    final entries = <_Entry>[];

    final sector = _extractTableValue(html, 'Sector');
    if (sector != null) entries.add(_Entry('sector', sector, 100));

    final country = _extractTableValue(html, 'Country');
    if (country != null) entries.add(_Entry('country', country, 100));

    entries.add(_Entry('holding', asset.name, 100));
    entries.add(_Entry('assetclass', 'Stock', 100));
    entries.add(_Entry('source_url', url, 0));

    // Need at least sector or country to consider it successful
    return entries.length > 3 ? entries : [];
  }

  // ── Mutual/Pension Funds: investing.com ──────────────────

  Future<List<_Entry>> _fetchFundFromInvestingCom(Asset asset) async {
    // First, find the fund URL via investing.com search API
    final searchTerm = asset.isin ?? asset.ticker ?? asset.name;
    _log.fine('fetchFund: ${asset.name} — searching investing.com for "$searchTerm"');

    String? fundUrl;
    try {
      final searchUrl = 'https://api.investing.com/api/search/v2/search'
          '?q=${Uri.encodeComponent(searchTerm)}';
      final searchResp = await _dio.get(searchUrl, options: Options(
        headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
        responseType: ResponseType.json,
      ));
      final quotes = (searchResp.data as Map<String, dynamic>)['quotes'] as List? ?? [];
      if (quotes.isNotEmpty) {
        fundUrl = quotes[0]['url'] as String?;
      }
    } catch (e) {
      _log.warning('fetchFund: search failed for ${asset.name}: $e');
      return [];
    }

    if (fundUrl == null || fundUrl.isEmpty) return [];

    // Fetch the holdings page
    final holdingsUrl = 'https://www.investing.com${fundUrl.replaceAll(RegExp(r'/$'), '')}-holdings';
    _log.fine('fetchFund: ${asset.name} → $holdingsUrl');

    final html = await _fetchHtml(holdingsUrl);
    if (html == null) return [];

    final entries = <_Entry>[];

    // Parse sector allocation from HTML table
    entries.addAll(_parseInvestingComSectors(html));

    // Parse region allocation from Highcharts JSON
    entries.addAll(_parseInvestingComRegions(html));

    // Parse top holdings from HTML table
    entries.addAll(_parseInvestingComHoldings(html));

    if (entries.isEmpty) {
      entries.add(_Entry('holding', asset.name, 100));
    }

    entries.add(_Entry('assetclass', 'Pension Fund', 100));
    entries.add(_Entry('source_url', holdingsUrl, 0));

    return entries;
  }

  /// Parse sector allocation from investing.com fund holdings page.
  /// Format: <td class="left">Technology</td><td class="right">30.880</td>
  List<_Entry> _parseInvestingComSectors(String html) {
    final entries = <_Entry>[];

    // Find the sector allocation section
    final sectorStart = html.indexOf('js-sector');
    if (sectorStart < 0) return entries;

    // Find the next closing table after the sector start
    final sectionEnd = html.indexOf('</table>', sectorStart);
    if (sectionEnd < 0) return entries;
    final section = html.substring(sectorStart, sectionEnd);

    final rowPattern = RegExp(
      r'<td class="left">([^<]+)</td>\s*<td class="right">([^<]+)</td>',
    );

    for (final match in rowPattern.allMatches(section)) {
      final name = _decodeHtml(match.group(1)!.trim());
      final weight = double.tryParse(match.group(2)!.trim());
      if (weight != null && weight > 0) {
        entries.add(_Entry('sector', name, weight));
      }
    }

    return entries;
  }

  /// Parse region allocation from Highcharts JSON embedded in the page.
  /// Looks for: "renderTo":"regionAllocationPieChart1"..."data":[{"name":"...","y":...}]
  List<_Entry> _parseInvestingComRegions(String html) {
    final entries = <_Entry>[];

    final chartPattern = RegExp(
      r'regionAllocationPieChart1[^;]*"data":\[([^\]]+)\]',
    );
    final match = chartPattern.firstMatch(html);
    if (match == null) return entries;

    try {
      final dataJson = '[${match.group(1)}]';
      final data = jsonDecode(dataJson) as List;
      for (final item in data) {
        final name = item['name'] as String?;
        final y = (item['y'] as num?)?.toDouble();
        if (name != null && y != null && y > 0) {
          entries.add(_Entry('country', name, y));
        }
      }
    } catch (e) {
      _log.fine('parseInvestingComRegions: JSON parse error: $e');
    }

    return entries;
  }

  /// Parse top holdings from investing.com fund holdings page.
  List<_Entry> _parseInvestingComHoldings(String html) {
    final entries = <_Entry>[];

    // Top holdings table has class "genTbl" and contains rows with holding name + weight%
    // Pattern: <td ...>Name</td> ... <td ...>XX.XX%</td>
    final holdingsStart = html.indexOf('Top Holdings');
    if (holdingsStart < 0) return entries;

    // Find the holdings table
    final tableStart = html.indexOf('<table', holdingsStart);
    final tableEnd = html.indexOf('</table>', tableStart);
    if (tableStart < 0 || tableEnd < 0) return entries;
    final table = html.substring(tableStart, tableEnd);

    final rowPattern = RegExp(
      r'<td[^>]*>\s*(?:<a[^>]*>)?\s*([^<]+?)\s*(?:</a>)?\s*</td>\s*'
      r'<td[^>]*>\s*([0-9.]+)\s*%?\s*</td>',
    );

    for (final match in rowPattern.allMatches(table)) {
      final name = _decodeHtml(match.group(1)!.trim());
      final weight = double.tryParse(match.group(2)!.trim());
      if (weight != null && weight > 0 && name.isNotEmpty && name != 'Name') {
        entries.add(_Entry('holding', name, weight));
      }
    }

    return entries;
  }

  // ── Shared helpers ────────────────────────────────────────

  /// Extract a value from an HTML table row: <td>Label</td><td>...Value...</td>
  String? _extractTableValue(String html, String label) {
    final pattern = RegExp(
      '>$label</td>\\s*<td[^>]*>([\\s\\S]*?)</td>',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(html);
    if (match == null) return null;

    final text = match.group(1)!
        .replaceAll(RegExp(r'<!--.*?-->'), '')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();
    return (text.isNotEmpty && text != '-') ? text : null;
  }

  Future<String?> _fetchHtml(String url) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent': _userAgent,
            'Accept-Encoding': 'gzip, deflate',
          },
          responseType: ResponseType.plain,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      return response.data as String;
    } catch (e) {
      _log.warning('fetchHtml: $url — $e');
      return null;
    }
  }

  // ── justETF HTML parsers ──────────────────────────────────

  List<_Entry> _parseJustEtfSection(String html, String section) {
    final type = section == 'countries' ? 'country' : 'sector';
    final entries = <_Entry>[];

    final rowPattern = RegExp(
      r'data-testid="tl_etf-holdings_' + section + r'_value_name"[^>]*>([^<]+)</td>'
      r'[\s\S]*?'
      r'data-testid="tl_etf-holdings_' + section + r'_value_percentage"[^>]*>([^<]+)</span>',
    );

    for (final match in rowPattern.allMatches(html)) {
      final name = _decodeHtml(match.group(1)!.trim());
      final pctStr = match.group(2)!.trim().replaceAll('%', '');
      final weight = double.tryParse(pctStr);
      if (weight != null && weight > 0) {
        entries.add(_Entry(type, name, weight));
      }
    }

    return entries;
  }

  List<_Entry> _parseJustEtfHoldings(String html) {
    final entries = <_Entry>[];

    final linkPattern = RegExp(
      r'data-testid="tl_etf-holdings_top-holdings_link_name"[^>]*title="([^"]+)"'
      r'[\s\S]*?'
      r'data-testid="tl_etf-holdings_top-holdings_value_percentage"[^>]*>([^<]+)</span>',
    );

    for (final match in linkPattern.allMatches(html)) {
      final name = _decodeHtml(match.group(1)!.trim());
      final pctStr = match.group(2)!.trim().replaceAll('%', '');
      final weight = double.tryParse(pctStr);
      if (weight != null && weight > 0) {
        entries.add(_Entry('holding', name, weight));
      }
    }

    return entries;
  }

  String _decodeHtml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'");
  }
}

class _Entry {
  final String type;
  final String name;
  final double weight;
  const _Entry(this.type, this.name, this.weight);
}
