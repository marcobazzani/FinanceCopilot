import 'dart:convert';

import '../utils/logger.dart';
import 'investing_com_service.dart' show InvestingSearchResult;

final _log = getLogger('InvestingPageParser');

/// Why a [canonicaliseInstrumentUrl] call rejected its input.
enum InstrumentUrlRejection { invalidFormat, wrongHost, unsupportedCategory }

/// Outcome of [canonicaliseInstrumentUrl] — either a clean canonical [Uri] or
/// a categorised [InstrumentUrlRejection] explaining why the input was rejected.
class InstrumentUrlOutcome {
  final Uri? uri;
  final InstrumentUrlRejection? rejection;
  const InstrumentUrlOutcome.ok(this.uri) : rejection = null;
  const InstrumentUrlOutcome.rejected(this.rejection) : uri = null;
}

const Set<String> kInstrumentUrlPrefixes = {
  'rates-bonds',
  'equities',
  'funds',
  'etfs',
  'bonds',
  'indices',
  'currencies',
  'commodities',
  'certificates',
};

const List<String> _kPageSuffixes = [
  '-historical-data',
  '-advanced-chart',
  '-technical',
  '-commentary',
  '-scoreboard',
  '-candlestick',
  '-profile',
  '-chart',
  '-news',
  '-analysis',
  '-financial-summary',
  '-earnings',
  '-ratings',
  '-dividends',
  '-holdings',
  '-components',
  '-user-rankings',
  '-opinion',
  '-forum',
];

/// Pre-validate and canonicalise a user-pasted instrument page address.
///
/// Strips query/fragment and any sub-page suffix (e.g. `-historical-data`)
/// from the last path segment, normalises the host to `www.investing.com`,
/// and verifies the path starts with one of [kInstrumentUrlPrefixes].
InstrumentUrlOutcome canonicaliseInstrumentUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return const InstrumentUrlOutcome.rejected(InstrumentUrlRejection.invalidFormat);

  final parsed = Uri.tryParse(trimmed);
  if (parsed == null) return const InstrumentUrlOutcome.rejected(InstrumentUrlRejection.invalidFormat);
  if (parsed.scheme != 'http' && parsed.scheme != 'https') {
    return const InstrumentUrlOutcome.rejected(InstrumentUrlRejection.invalidFormat);
  }
  if (parsed.host.isEmpty) {
    return const InstrumentUrlOutcome.rejected(InstrumentUrlRejection.invalidFormat);
  }

  final host = parsed.host.toLowerCase();
  if (!host.endsWith('investing.com')) {
    return const InstrumentUrlOutcome.rejected(InstrumentUrlRejection.wrongHost);
  }

  final segments = parsed.pathSegments;
  if (segments.isEmpty || !kInstrumentUrlPrefixes.contains(segments.first.toLowerCase())) {
    return const InstrumentUrlOutcome.rejected(InstrumentUrlRejection.unsupportedCategory);
  }

  // Strip a trailing sub-page suffix from the last segment (one pass).
  final last = segments.last;
  String trimmedLast = last;
  for (final suffix in _kPageSuffixes) {
    if (trimmedLast.endsWith(suffix)) {
      trimmedLast = trimmedLast.substring(0, trimmedLast.length - suffix.length);
      break;
    }
  }

  final canonicalPath = '/${[
    ...segments.sublist(0, segments.length - 1),
    trimmedLast,
  ].join('/')}';

  final canonical = Uri(
    scheme: 'https',
    host: 'www.investing.com',
    path: canonicalPath,
  );
  return InstrumentUrlOutcome.ok(canonical);
}

/// Parse an instrument page (bond / ETF / equity / fund) and extract the
/// real numeric pair id plus identifying metadata.
///
/// Returns null if the page doesn't carry the embedded JSON state we rely on
/// (Cloudflare interstitial, pages without `__NEXT_DATA__`, etc.).
InvestingSearchResult? parseInvestingPage(String html, Uri pageUrl) {
  final match = RegExp(
    r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>',
    dotAll: true,
  ).firstMatch(html);
  if (match == null) return null;

  final raw = match.group(1);
  if (raw == null || raw.isEmpty) return null;

  Map<String, dynamic> data;
  try {
    data = jsonDecode(raw) as Map<String, dynamic>;
  } catch (e) {
    _log.warning('failed to decode __NEXT_DATA__ JSON: $e');
    return null;
  }

  final state = _readPath(data, ['props', 'pageProps', 'state']);
  if (state is! Map<String, dynamic>) return null;

  final instrument = _findInstrument(state);
  if (instrument == null) return null;

  final base = instrument['base'];
  if (base is! Map) return null;
  final idStr = base['id'];
  final cid = int.tryParse(idStr?.toString() ?? '');
  if (cid == null) return null;

  final name = instrument['name'];
  final exchange = instrument['exchange'];
  final type = base['type']?.toString() ?? '';

  return InvestingSearchResult(
    cid: cid,
    description: _firstNonEmpty([
      _strField(name, 'fullName'),
      _strField(name, 'shortName'),
      _strField(name, 'parentName'),
      _strField(instrument['englishName'], 'fullName'),
    ]) ?? '',
    symbol: _strField(name, 'symbol') ?? '',
    exchange: _strField(exchange, 'exchange') ?? '',
    flag: _strField(exchange, 'flag') ?? '',
    type: type.isNotEmpty ? type : (base['typeDefine']?.toString() ?? ''),
    url: pageUrl.path.isNotEmpty ? pageUrl.path : null,
  );
}

/// Walk the [state] map looking for any `*Store` entry that contains an
/// `instrument` object with `base.id` set. Investing.com's Next.js bundles use
/// type-specific store names (`bondStore`, `etfStore`, `stockStore`,
/// `fundStore`, ...) but the inner shape is consistent.
Map<String, dynamic>? _findInstrument(Map<String, dynamic> state) {
  for (final entry in state.entries) {
    if (!entry.key.endsWith('Store')) continue;
    final v = entry.value;
    if (v is! Map) continue;
    final instrument = v['instrument'];
    if (instrument is! Map) continue;
    final base = instrument['base'];
    if (base is Map && base['id'] != null) {
      return Map<String, dynamic>.from(instrument);
    }
  }
  return null;
}

dynamic _readPath(dynamic root, List<String> path) {
  dynamic node = root;
  for (final p in path) {
    if (node is Map && node.containsKey(p)) {
      node = node[p];
    } else {
      return null;
    }
  }
  return node;
}

String? _strField(dynamic obj, String key) {
  if (obj is! Map) return null;
  final v = obj[key];
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

String? _firstNonEmpty(List<String?> values) {
  for (final v in values) {
    if (v != null && v.isNotEmpty) return v;
  }
  return null;
}
