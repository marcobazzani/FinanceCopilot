import 'dart:convert';

import '../database/database.dart';
import '../database/tables.dart';
import '../models/dashboard_chart.dart';

/// Thrown when a chart's `series_json` cannot be expressed as a clean union
/// of categories — e.g. only some accounts ticked rather than all. The
/// exporter refuses to emit anything in that case so the JSON asset stays
/// instance-agnostic.
class PartialCategoryExportException implements Exception {
  final String chartTitle;
  final String reason;
  PartialCategoryExportException(this.chartTitle, this.reason);
  @override
  String toString() => 'PartialCategoryExportException: $chartTitle — $reason';
}

/// Serialise the live DB chart layout back into the category-based JSON
/// schema consumed by `assets/default_charts.json`. Each chart's series
/// list must equal the union of zero or more *full* categories; partial
/// selections are rejected.
class DefaultChartsExporter {
  static const _illiquidTypes = {
    InstrumentType.pension,
    InstrumentType.realEstate,
    InstrumentType.alternative,
    InstrumentType.liability,
  };

  String export({
    required List<DashboardChart> charts,
    required List<Account> activeAccounts,
    required List<Asset> activeAssets,
    required List<ExtraordinaryEvent> activeEvents,
  }) {
    final outflows = activeEvents.where((e) => e.direction == EventDirection.outflow).toList();
    final inflows = activeEvents.where((e) => e.direction == EventDirection.inflow).toList();
    final nonEphemeralInflows = inflows.where((e) => !e.isEphemeral).toList();
    final ephemeralInflows = inflows.where((e) => e.isEphemeral).toList();

    final categoryFullSets = <String, Set<String>>{
      'all_accounts':
          {for (final a in activeAccounts.where((a) => a.isActive)) 'account:${a.id}'},
      'all_invested':
          {for (final a in activeAssets) 'asset_invested:${a.id}'},
      'all_market':
          {for (final a in activeAssets) 'asset_market:${a.id}'},
      'all_market_liquid': {
        for (final a in activeAssets)
          if (!_illiquidTypes.contains(a.instrumentType)) 'asset_market:${a.id}'
      },
      'all_gain':
          {for (final a in activeAssets) 'asset_gain:${a.id}'},
      'outflow_value':
          {for (final e in outflows) 'adjustment_value:${e.id}'},
      'outflow_events':
          {for (final e in outflows) 'adjustment_events:${e.id}'},
      'non_ephemeral_inflow_value':
          {for (final e in nonEphemeralInflows) 'income_adj_value:${e.id}'},
      'non_ephemeral_inflow_events':
          {for (final e in nonEphemeralInflows) 'income_adj_events:${e.id}'},
      'ephemeral_inflow_value':
          {for (final e in ephemeralInflows) 'ephemeral_inflow_value:${e.id}'},
      'ephemeral_inflow_events':
          {for (final e in ephemeralInflows) 'ephemeral_inflow_events:${e.id}'},
    };

    // Categories competing for the same key prefix: prefer the more specific
    // (smaller) category when the chart's series matches both. Today only
    // `all_market_liquid` is a strict subset of `all_market`.
    final categoriesByPrefix = <String, List<String>>{};
    final keyToCategoryCandidates = <String, List<String>>{};
    for (final entry in categoryFullSets.entries) {
      for (final key in entry.value) {
        final prefix = key.split(':').first;
        categoriesByPrefix.putIfAbsent(prefix, () => []);
        if (!categoriesByPrefix[prefix]!.contains(entry.key)) {
          categoriesByPrefix[prefix]!.add(entry.key);
        }
        keyToCategoryCandidates.putIfAbsent(key, () => []).add(entry.key);
      }
    }

    final exported = <Map<String, dynamic>>[];
    for (final chart in charts) {
      final entry = <String, dynamic>{};
      // Distinguish role-tagged charts ("cash"/"saving"/...) from generic.
      const roleTypes = {'cash', 'saving', 'portfolio', 'liquid_investments'};
      if (roleTypes.contains(chart.widgetType)) {
        entry['role'] = chart.widgetType;
      } else {
        entry['widgetType'] = chart.widgetType;
      }
      entry['title'] = chart.title;
      if (chart.sourceChartIds != null) {
        // Combined-overlay charts: emit either "*" (when the source set
        // covers every non-combined non-widget chart in the export) or a
        // JSON-encoded list of source-chart **titles**. Never int ids —
        // ids are in-memory only and would be meaningless after a rebuild.
        entry['sourceChartIds'] =
            _normalizeSourceChartIds(chart.sourceChartIds!, charts);
      }
      // Price Changes and combined-overlay charts have no series — skip
      // category resolution entirely.
      if (chart.widgetType == 'price_changes' || chart.sourceChartIds != null) {
        exported.add(entry);
        continue;
      }
      entry['categories'] = _resolveCategories(chart, categoryFullSets);
      exported.add(entry);
    }

    final output = {
      'version': 1,
      'charts': exported,
    };
    return const JsonEncoder.withIndent('  ').convert(output);
  }

  /// Normalize a combined chart's `sourceChartIds` for export.
  ///
  /// Input forms:
  ///   - `"*"` → emit `"*"`.
  ///   - JSON list of int ids → translate to titles, then either `"*"` (if
  ///     it covers every bucket-2 non-combined chart) or a JSON list of
  ///     titles.
  ///   - JSON list of strings → already titles; pass through (with the
  ///     same `"*"` collapse when covering every chart).
  String _normalizeSourceChartIds(
    String src,
    List<DashboardChart> allCharts,
  ) {
    if (src == '*') return '*';
    final pool = allCharts
        .where((c) => c.widgetType != 'price_changes' && c.sourceChartIds == null)
        .toList();
    final titlesById = {for (final c in pool) c.id: c.title};

    List<String> titles;
    try {
      final decoded = jsonDecode(src);
      if (decoded is! List) return '*';
      if (decoded.every((e) => e is int)) {
        titles = [
          for (final id in decoded.cast<int>())
            if (titlesById.containsKey(id)) titlesById[id]!,
        ];
      } else if (decoded.every((e) => e is String)) {
        final knownTitles = pool.map((c) => c.title).toSet();
        titles = [
          for (final t in decoded.cast<String>())
            if (knownTitles.contains(t)) t,
        ];
      } else {
        return '*';
      }
    } catch (_) {
      return '*';
    }

    // Collapse to "*" when the title set equals every available chart.
    final coverAll = pool.every((c) => titles.contains(c.title)) &&
        titles.length == pool.length;
    return coverAll ? '*' : jsonEncode(titles);
  }

  List<dynamic> _resolveCategories(
    DashboardChart chart,
    Map<String, Set<String>> categoryFullSets,
  ) {
    // Decode {type, id, sign?} entries and group by sign so signs flow
    // through to the output unchanged.
    final List<dynamic> raw;
    try {
      raw = jsonDecode(chart.seriesJson) as List;
    } catch (_) {
      throw PartialCategoryExportException(chart.title, 'invalid series_json');
    }

    final positive = <String>{}; // "type:id" with sign +1
    final negative = <String>{}; // "type:id" with sign -1
    for (final item in raw) {
      if (item is! Map<String, dynamic>) continue;
      final type = item['type'] as String?;
      final id = item['id'] as int?;
      if (type == null || id == null) continue;
      final sign = (item['sign'] as num?)?.toInt() ?? 1;
      final key = '$type:$id';
      (sign == -1 ? negative : positive).add(key);
    }

    final result = <dynamic>[];
    final remaining = {...positive};
    final remainingNeg = {...negative};

    // Greedy match by largest-category-first; skip categories that don't
    // wholly fit. Categories supersede each other only when one is a strict
    // subset of another, in which case the smaller one matches first if
    // its keys equal a subset of the chart's selection AND the larger
    // wouldn't entirely fit.
    final candidates = categoryFullSets.entries
        .where((e) => e.value.isNotEmpty)
        .toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    for (final cand in candidates) {
      // Does the positive selection contain ALL of this category?
      if (cand.value.every(remaining.contains)) {
        result.add(cand.key);
        remaining.removeAll(cand.value);
      } else if (cand.value.every(remainingNeg.contains)) {
        result.add({'category': cand.key, 'sign': -1});
        remainingNeg.removeAll(cand.value);
      }
    }

    if (remaining.isNotEmpty || remainingNeg.isNotEmpty) {
      final leftover = [
        ...remaining.map((k) => '+$k'),
        ...remainingNeg.map((k) => '-$k'),
      ].join(', ');
      throw PartialCategoryExportException(
        chart.title,
        'series does not match any clean category union — leftover: $leftover',
      );
    }
    return result;
  }
}
