import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' show parse;

import '../database/database.dart';
import '../database/tables.dart';
import '../utils/logger.dart';
import 'web_market_data_service.dart';

final _log = getLogger('CompositionService');

/// Fetches asset composition/classification data from multiple public sources
/// and stores it in the asset_compositions table.
///
/// Sources (delegated to dedicated provider services):
/// - ETFs/ETCs: ETF profile provider (country/sector/holdings + focus)
/// - Individual stocks: stock-analysis provider (country, sector)
/// - Mutual/pension funds: market data provider's fund-holdings page
/// - Fallback: derives classification from asset name/type
class CompositionService {
  final AppDatabase _db;
  final Dio _dio;
  final WebMarketDataService? _providerService;

  CompositionService(this._db, {Dio? dio, WebMarketDataService? providerService}) : _dio = dio ?? Dio(), _providerService = providerService;

  static const _classToInstrument = {
    'Stock ETF': InstrumentType.etf,
    'Bond ETF': InstrumentType.etf,
    'Commodity ETF': InstrumentType.etf,
    'Gold ETC': InstrumentType.etc,
    'Money Market ETF': InstrumentType.etf,
    'ETF': InstrumentType.etf,
    'Stock': InstrumentType.stock,
    'Pension Fund': InstrumentType.pension,
  };
  static const _classToAssetClass = {
    'Stock ETF': AssetClass.equity,
    'Bond ETF': AssetClass.fixedIncome,
    'Commodity ETF': AssetClass.commodities,
    'Gold ETC': AssetClass.commodities,
    'Money Market ETF': AssetClass.moneyMarket,
    'ETF': AssetClass.equity,
    'Stock': AssetClass.equity,
    'Pension Fund': AssetClass.multiAsset,
  };

  static const _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  /// Sync composition data for all active assets.
  Future<void> syncCompositions() async {
    final assets = await (_db.select(_db.assets)..where((a) => a.isActive.equals(true))).get();

    _log.info('syncCompositions: ${assets.length} active assets');

    for (final asset in assets) {
      // Skip manual/eventDriven assets — composition is user-managed
      if (asset.valuationMethod == ValuationMethod.eventDriven) continue;

      // Skip if any composition rows already exist for this asset. Once
      // populated (by sync OR by manual edit on the Composition panel),
      // the data is treated as authoritative. To force a fresh fetch the
      // user clicks "Refresh from market", which clears the rows and
      // re-runs this method (see clearAndResync). Still fetch a missing
      // TER though — that's a single field, not the multi-row breakdown.
      final existing =
          await (_db.select(_db.assetCompositions)
                ..where((c) => c.assetId.equals(asset.id))
                ..limit(1))
              .getSingleOrNull();
      if (existing != null) {
        if (asset.ter == null && asset.isin != null) {
          await _fetchTerOnly(asset);
        }
        _log.fine('syncCompositions: ${asset.name} - rows exist, skipping');
        continue;
      }

      try {
        final data = await _fetchForAsset(asset);
        if (data.isEmpty) {
          _log.fine('syncCompositions: ${asset.name} - no data resolved');
          continue;
        }

        // Replace old data
        await (_db.delete(_db.assetCompositions)..where((c) => c.assetId.equals(asset.id))).go();

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

        // Auto-update instrumentType and assetClass from detected asset class
        final assetClassEntry = data.where((e) => e.type == 'assetclass').firstOrNull;
        if (assetClassEntry != null) {
          final newInstrument = _classToInstrument[assetClassEntry.name];
          final newAssetClass = _classToAssetClass[assetClassEntry.name];
          final updates = AssetsCompanion(
            instrumentType: newInstrument != null && newInstrument != asset.instrumentType ? Value(newInstrument) : const Value.absent(),
            assetClass: newAssetClass != null && newAssetClass != asset.assetClass ? Value(newAssetClass) : const Value.absent(),
          );
          if (updates.instrumentType.present || updates.assetClass.present) {
            await (_db.update(_db.assets)..where((a) => a.id.equals(asset.id))).write(updates);
            _log.info(
              'syncCompositions: ${asset.name} - updated classification '
              '-> instrument=${newInstrument ?? asset.instrumentType}, '
              'class=${newAssetClass ?? asset.assetClass}',
            );
          }
        }

        _log.info('syncCompositions: ${asset.name} - stored ${data.length} entries');
      } catch (e) {
        _log.warning('syncCompositions: ${asset.name} - failed: $e');
      }
    }

    _log.info('syncCompositions: done');
  }

  /// Replace every composition row for `(assetId, type)` with the given
  /// entries. Pass an empty `entries` to clear the section. `type` is one
  /// of: `'assetclass'`, `'country'`, `'sector'`, `'holding'`. Weights
  /// are percentages (0..100); callers should normalize before passing.
  /// Once any rows exist for an asset, [syncCompositions] skips it — so
  /// user edits stick until the user calls [clearAndResync].
  Future<void> setEntries(int assetId, String type, List<CompositionEntry> entries) async {
    _log.info('setEntries: assetId=$assetId type=$type count=${entries.length}');
    await _db.transaction(() async {
      await (_db.delete(_db.assetCompositions)..where((c) => c.assetId.equals(assetId) & c.type.equals(type))).go();
      if (entries.isNotEmpty) {
        await _db.batch((batch) {
          for (final e in entries) {
            batch.insert(
              _db.assetCompositions,
              AssetCompositionsCompanion.insert(
                assetId: assetId,
                type: type,
                name: e.name,
                weight: e.weight,
              ),
            );
          }
        });
      }
    });
  }

  /// Wipe an asset's composition rows and re-run sync for it. Backs the
  /// "Refresh from market" button on the Composition panel — it's the
  /// only way to opt back into automatic fetching once rows exist.
  Future<void> clearAndResync(int assetId) async {
    _log.info('clearAndResync: assetId=$assetId');
    await (_db.delete(_db.assetCompositions)..where((c) => c.assetId.equals(assetId))).go();
    await syncCompositions();
  }

  /// Route to the appropriate data source based on ISIN pattern and asset metadata.
  Future<List<_Entry>> _fetchForAsset(Asset asset) async {
    final isin = asset.isin ?? '';

    // Fund IDs starting with "0P" use the fund-holdings path on the market data provider.
    if (isin.startsWith('0P')) {
      return _fetchFundFromProvider(asset);
    }

    // Standard ISINs (2-letter country + 10 chars) → try the ETF profile
    // provider first.
    if (isin.length == 12 && RegExp(r'^[A-Z]{2}').hasMatch(isin)) {
      final etfResult = await _fetchEtf(asset);
      if (etfResult.isNotEmpty) return etfResult;

      // If the ETF provider didn't find it (e.g. it's a stock, not an
      // ETF), fall through to the stock-data provider via ticker.
      if (asset.ticker != null && asset.ticker!.isNotEmpty) {
        final stockResult = await _fetchStock(asset);
        if (stockResult.isNotEmpty) return stockResult;
      }
    }

    // Has ticker but no ISIN or non-standard ISIN → try the stock-data provider.
    if (asset.ticker != null && asset.ticker!.isNotEmpty) {
      final stockResult = await _fetchStock(asset);
      if (stockResult.isNotEmpty) return stockResult;
    }

    // Try the market data provider search as last resort
    return _fetchFundFromProvider(asset);
  }

  /// Quick TER-only fetch (ETF profile provider for ETFs, market data provider for funds).
  Future<void> _fetchTerOnly(Asset asset) async {
    // Try the ETF profile provider first (for ETFs/ETCs).
    final isin = asset.isin!;
    final url = 'https://www.justetf.com/en/etf-profile.html?isin=$isin';
    final html = await _fetchHtml(url);
    if (html != null) {
      final doc = parse(html);
      final terText = doc.querySelector('[data-testid="tl_etf-basics_value_ter"]')?.text.trim();
      if (terText != null) {
        final terMatch = RegExp(r'([\d,.]+)\s*%').firstMatch(terText);
        if (terMatch != null) {
          final ter = double.tryParse(terMatch.group(1)!.replaceAll(',', '.'));
          if (ter != null) {
            await (_db.update(_db.assets)..where((a) => a.id.equals(asset.id))).write(AssetsCompanion(ter: Value(ter)));
            _log.info('_fetchTerOnly: ${asset.name} - TER=$ter% (etf-provider)');
            return;
          }
        }
      }
    }

    // Try the market data provider (for funds/pension)
    final searchTerm = asset.isin ?? asset.ticker ?? asset.name;
    try {
      final searchUrl =
          '$kProviderApiBase/api/search/v2/search'
          '?q=${Uri.encodeComponent(searchTerm)}';
      final searchResp = await _dio.get(
        searchUrl,
        options: Options(
          headers: {'User-Agent': _userAgent, 'Accept': 'application/json', 'Domain-Id': 'www', 'Accept-Language': 'en-US,en;q=0.9'},
          responseType: ResponseType.json,
        ),
      );
      final quotes = (searchResp.data as Map<String, dynamic>)['quotes'] as List? ?? [];
      if (quotes.isEmpty) return;
      final fundPath = quotes[0]['url'] as String?;
      if (fundPath == null || fundPath.isEmpty) return;

      final fundHtml = await _fetchHtml('$kProviderBase$fundPath');
      if (fundHtml == null) return;
      final ter = parseTerFromProviderHtml(fundHtml);
      if (ter != null) {
        await (_db.update(_db.assets)..where((a) => a.id.equals(asset.id))).write(AssetsCompanion(ter: Value(ter)));
        _log.info('_fetchTerOnly: ${asset.name} - TER=$ter% (provider)');
      }
    } catch (e) {
      _log.fine('_fetchTerOnly: ${asset.name} - provider failed: $e');
    }
  }

  // ── ETFs/ETCs: ETF profile provider ─────────────────────

  Future<List<_Entry>> _fetchEtf(Asset asset) async {
    final isin = asset.isin!;
    final url = 'https://www.justetf.com/en/etf-profile.html?isin=$isin';
    _log.fine('fetchEtf: ${asset.name} from etf-provider ($isin)');

    final html = await _fetchHtml(url);
    if (html == null) return [];

    // Provider returns a redirect-to-search page when the fund is not in
    // its catalog. Detect via expected data-testid markers.
    if (!html.contains('data-testid="etf-basics_data_table"') && !html.contains('data-testid="etf-holdings_')) {
      _log.fine('fetchEtf: ${asset.name} - not found on etf-provider');
      return [];
    }

    final doc = parse(html);
    final entries = <_Entry>[];

    // Try to get structured composition (equity ETFs)
    entries.addAll(_parseEtfSection(doc, 'countries'));
    entries.addAll(_parseEtfSection(doc, 'sectors'));
    entries.addAll(_parseEtfHoldings(doc));

    // If no structured data (money market, commodity, gold, bond ETFs),
    // derive from the "Investment focus" field
    if (entries.isEmpty) {
      entries.addAll(_parseInvestmentFocus(doc, asset));
    }

    // Store the asset class from the Investment focus field
    final assetClass = _detectAssetClass(doc);
    if (assetClass != null) {
      entries.add(_Entry('assetclass', assetClass, 100));
    }

    // Extract TER and update asset
    final terText = doc.querySelector('[data-testid="tl_etf-basics_value_ter"]')?.text.trim();
    if (terText != null) {
      final terMatch = RegExp(r'([\d,.]+)\s*%').firstMatch(terText);
      if (terMatch != null) {
        final ter = double.tryParse(terMatch.group(1)!.replaceAll(',', '.'));
        if (ter != null && ter != asset.ter) {
          await (_db.update(_db.assets)..where((a) => a.id.equals(asset.id))).write(AssetsCompanion(ter: Value(ter)));
          _log.info('syncCompositions: ${asset.name} - updated TER to $ter%');
        }
      }
    }

    // Store source URL
    entries.add(_Entry('source_url', url, 0));

    return entries;
  }

  /// Parse the "Investment focus" field from the ETF profile provider.
  /// Format: "Equity, World" or "Money Market, EUR, Europe" or "Commodities, Broad market"
  List<_Entry> _parseInvestmentFocus(Document doc, Asset asset) {
    final entries = <_Entry>[];

    String? focus;

    // Primary: data-testid attribute for investment focus value
    focus = doc.querySelector('[data-testid="tl_etf-basics_value_investment-focus"]')?.text.trim();

    // Fallback: find the "Investment focus" label td, get its sibling
    if (focus == null || focus.isEmpty) {
      focus = doc.querySelectorAll('td').where((td) => td.text.trim() == 'Investment focus').firstOrNull?.nextElementSibling?.text.trim();
    }

    if (focus != null && focus.isNotEmpty) {
      _log.fine('parseInvestmentFocus: ${asset.name} -> "$focus"');
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
      final domicile = doc.querySelector('[data-testid="tl_etf-basics_value_fund-domicile"]')?.text.trim();
      if (domicile != null && domicile.isNotEmpty) {
        entries.add(_Entry('country', domicile, 100));
      }
    }

    entries.add(_Entry('holding', asset.name, 100));
    return entries;
  }

  /// Detect the real asset class from the provider's Investment focus field.
  /// Returns labels like "Stock ETF", "Bond ETF", "Commodity ETF", "Gold ETC", "Money Market ETF".
  String? _detectAssetClass(Document doc) {
    var focus = doc.querySelector('[data-testid="tl_etf-basics_value_investment-focus"]')?.text.trim().toLowerCase();
    focus ??= doc
        .querySelectorAll('td')
        .where((td) => td.text.trim() == 'Investment focus')
        .firstOrNull
        ?.nextElementSibling
        ?.text
        .trim()
        .toLowerCase();
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
      'world',
      'global',
      'europe',
      'usa',
      'us',
      'united states',
      'asia',
      'emerging',
      'japan',
      'china',
      'uk',
      'eurozone',
      'north america',
      'latin america',
      'africa',
      'pacific',
      'developed',
      'frontier',
    };
    final lower = text.toLowerCase();
    return geoTerms.any((t) => lower.contains(t));
  }

  // ── Individual Stocks: stock-data provider ────────────────

  Future<List<_Entry>> _fetchStock(Asset asset) async {
    final ticker = asset.ticker;
    if (ticker == null || ticker.isEmpty) return [];

    final url = 'https://stockanalysis.com/stocks/${ticker.toLowerCase()}/company/';
    _log.fine('fetchStock: ${asset.name} from stock-data provider ($ticker)');

    final html = await _fetchHtml(url);
    if (html == null) return [];

    final doc = parse(html);
    final entries = <_Entry>[];

    final sector = _extractTableValue(doc, 'Sector');
    if (sector != null) entries.add(_Entry('sector', sector, 100));

    final country = _extractTableValue(doc, 'Country');
    if (country != null) entries.add(_Entry('country', country, 100));

    entries.add(_Entry('holding', asset.name, 100));
    entries.add(_Entry('assetclass', 'Stock', 100));
    entries.add(_Entry('source_url', url, 0));

    // Need at least sector or country to consider it successful
    return entries.length > 3 ? entries : [];
  }

  // ── Mutual/Pension Funds: provider ──────────────────

  Future<List<_Entry>> _fetchFundFromProvider(Asset asset) async {
    // First, find the fund URL via the provider search API
    final searchTerm = asset.isin ?? asset.ticker ?? asset.name;
    _log.fine('fetchFund: ${asset.name} - searching the provider for "$searchTerm"');

    String? fundUrl;
    try {
      final searchUrl =
          '$kProviderApiBase/api/search/v2/search'
          '?q=${Uri.encodeComponent(searchTerm)}';
      final searchResp = await _dio.get(
        searchUrl,
        options: Options(
          headers: {'User-Agent': _userAgent, 'Accept': 'application/json', 'Domain-Id': 'www', 'Accept-Language': 'en-US,en;q=0.9'},
          responseType: ResponseType.json,
        ),
      );
      final quotes = (searchResp.data as Map<String, dynamic>)['quotes'] as List? ?? [];
      if (quotes.isNotEmpty) {
        fundUrl = quotes[0]['url'] as String?;
      }
    } catch (e) {
      _log.warning('fetchFund: search failed for ${asset.name}: $e');
      return [];
    }

    if (fundUrl == null || fundUrl.isEmpty) return [];

    final baseFundUrl = '$kProviderBase${fundUrl.replaceAll(RegExp(r'/$'), '')}';

    // Fetch main fund page for expenses/TER
    final mainHtml = await _fetchHtml(baseFundUrl);
    if (mainHtml != null) {
      final ter = parseTerFromProviderHtml(mainHtml);
      if (ter != null && ter != asset.ter) {
        await (_db.update(_db.assets)..where((a) => a.id.equals(asset.id))).write(AssetsCompanion(ter: Value(ter)));
        _log.info('fetchFund: ${asset.name} - updated TER to $ter% from the provider');
      }
    }

    // Fetch the holdings page
    final holdingsUrl = '$baseFundUrl-holdings';
    _log.fine('fetchFund: ${asset.name} -> $holdingsUrl');

    final html = await _fetchHtml(holdingsUrl);
    if (html == null) return [];

    final doc = parse(html);
    final entries = <_Entry>[];

    // Parse sector allocation from HTML table
    entries.addAll(_parseProviderSectors(doc));

    // Parse region allocation from Highcharts JSON (embedded in <script> tags)
    entries.addAll(_parseProviderRegions(doc));

    // Parse top holdings from HTML table
    entries.addAll(_parseProviderHoldings(doc));

    if (entries.isEmpty) {
      entries.add(_Entry('holding', asset.name, 100));
    }

    entries.add(_Entry('assetclass', 'Pension Fund', 100));
    entries.add(_Entry('source_url', holdingsUrl, 0));

    return entries;
  }

  /// Parse sector allocation from the provider's fund holdings page.
  List<_Entry> _parseProviderSectors(Document doc) {
    final entries = <_Entry>[];

    final sectorSection = doc.querySelector('.js-sector');
    if (sectorSection == null) return entries;

    for (final cell in sectorSection.querySelectorAll('td.left')) {
      final name = cell.text.trim();
      final weightText = cell.nextElementSibling?.text.trim();
      final weight = double.tryParse(weightText ?? '');
      if (name.isNotEmpty && weight != null && weight > 0) {
        entries.add(_Entry('sector', name, weight));
      }
    }

    return entries;
  }

  /// Parse region allocation from Highcharts JSON embedded in the page.
  /// Looks for: "renderTo":"regionAllocationPieChart1"..."data":[{"name":"...","y":...}]
  List<_Entry> _parseProviderRegions(Document doc) {
    final entries = <_Entry>[];

    // Scope search to <script> tags to avoid false matches in other HTML
    final scriptContent = doc.querySelectorAll('script').map((s) => s.text).join();

    final chartPattern = RegExp(
      r'regionAllocationPieChart1[^;]*"data":\[([^\]]+)\]',
    );
    final match = chartPattern.firstMatch(scriptContent);
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
      _log.fine('parseProviderRegions: JSON parse error: $e');
    }

    return entries;
  }

  /// Parse top holdings from the provider's fund holdings page.
  List<_Entry> _parseProviderHoldings(Document doc) {
    final entries = <_Entry>[];

    final rows = doc.querySelector('.genTbl')?.querySelectorAll('tr') ?? [];
    for (final row in rows.skip(1)) {
      // skip header row
      final cells = row.querySelectorAll('td');
      if (cells.length < 2) continue;
      final name = cells[0].text.trim();
      final weightText = cells[1].text.trim().replaceAll('%', '');
      final weight = double.tryParse(weightText);
      if (weight != null && weight > 0 && name.isNotEmpty && name != 'Name') {
        entries.add(_Entry('holding', name, weight));
      }
    }

    return entries;
  }

  // ── TER parsing from the market data provider HTML ─────────────────

  /// Extract TER/expense ratio from an the market data provider page HTML.
  ///
  /// Two known DOM patterns carry real TER data:
  ///  1. Fund pages: <span class="float_lang_base_1">Expenses</span>
  ///                 <span class="float_lang_base_2 bold">0.84%</span>
  ///  2. ETF/fund pages: JSON `"expenseRatio":0.2` in embedded data
  ///
  /// Returns null when neither pattern is found (bonds, stocks, etc.).
  @visibleForTesting
  double? parseTerFromProviderHtml(String html) {
    // 1. DOM: <span class="float_lang_base_1">Expenses</span>
    //         <span class="float_lang_base_2 ...">X.XX%</span>
    final doc = parse(html);
    for (final span in doc.querySelectorAll('span.float_lang_base_1')) {
      if (span.text.trim() != 'Expenses') continue;
      final next = span.nextElementSibling;
      if (next == null) continue;
      final text = next.text.trim();
      final m = RegExp(r'([\d,.]+)\s*%').firstMatch(text);
      if (m != null) {
        final ter = double.tryParse(m.group(1)!.replaceAll(',', '.'));
        if (ter != null && ter > 0 && ter < 10) return ter;
      }
    }

    // 2. JSON: "expenseRatio":0.2  (embedded in <script> or inline data)
    final jsonMatch = RegExp(r'"expenseRatio"\s*:\s*([\d.]+)').firstMatch(html);
    if (jsonMatch != null) {
      final ter = double.tryParse(jsonMatch.group(1)!);
      if (ter != null && ter > 0 && ter < 10) return ter;
    }

    return null;
  }

  // ── Shared helpers ────────────────────────────────────────

  /// Extract a value from an HTML table row: <td>Label</td><td>...Value...</td>
  String? _extractTableValue(Document doc, String label) {
    final labelTd = doc.querySelectorAll('td').where((td) => td.text.trim().toLowerCase() == label.toLowerCase()).firstOrNull;
    final text = labelTd?.nextElementSibling?.text.trim();
    return (text != null && text.isNotEmpty && text != '-') ? text : null;
  }

  Future<String?> _fetchHtml(String url) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent': _userAgent,
            'Accept-Encoding': 'gzip, deflate',
            'Accept-Language': 'en-US,en;q=0.9',
          },
          responseType: ResponseType.plain,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      return response.data as String;
    } on DioException catch (e) {
      // On CF-protected provider pages, fall back to WebView fetch
      if (e.response?.statusCode == 403 && _providerService != null && url.contains(kProviderHost)) {
        _log.fine('fetchHtml: Dio 403, trying WebView fetch for $url');
        return await _providerService.fetchHtml(url);
      }
      _log.warning('fetchHtml: $url - ${e.response?.statusCode ?? e.message}');
      return null;
    } catch (e) {
      _log.warning('fetchHtml: $url - $e');
      return null;
    }
  }

  // ── ETF provider HTML parsers ─────────────────────────────

  List<_Entry> _parseEtfSection(Document doc, String section) {
    final type = section == 'countries' ? 'country' : 'sector';
    final entries = <_Entry>[];

    final names = doc.querySelectorAll('[data-testid="tl_etf-holdings_${section}_value_name"]');
    final pcts = doc.querySelectorAll('[data-testid="tl_etf-holdings_${section}_value_percentage"]');

    for (var i = 0; i < min(names.length, pcts.length); i++) {
      final name = names[i].text.trim();
      final pctStr = pcts[i].text.trim().replaceAll('%', '');
      final weight = double.tryParse(pctStr);
      if (name.isNotEmpty && weight != null && weight > 0) {
        entries.add(_Entry(type, name, weight));
      }
    }

    return entries;
  }

  List<_Entry> _parseEtfHoldings(Document doc) {
    final entries = <_Entry>[];

    final links = doc.querySelectorAll('[data-testid="tl_etf-holdings_top-holdings_link_name"]');
    final pcts = doc.querySelectorAll('[data-testid="tl_etf-holdings_top-holdings_value_percentage"]');

    for (var i = 0; i < min(links.length, pcts.length); i++) {
      final name = (links[i].attributes['title'] ?? links[i].text).trim();
      final pctStr = pcts[i].text.trim().replaceAll('%', '');
      final weight = double.tryParse(pctStr);
      if (name.isNotEmpty && weight != null && weight > 0) {
        entries.add(_Entry('holding', name, weight));
      }
    }

    return entries;
  }
}

class _Entry {
  final String type;
  final String name;
  final double weight;
  const _Entry(this.type, this.name, this.weight);
}

/// Public input value type for [CompositionService.setEntries].
class CompositionEntry {
  final String name;
  final double weight;
  const CompositionEntry(this.name, this.weight);
}
