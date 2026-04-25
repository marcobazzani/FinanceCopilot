import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../database/database.dart';
import '../database/tables.dart';
import '../models/dashboard_chart.dart';

export '../models/dashboard_chart.dart';

/// Reads `assets/default_charts.json` and expands the category-based config
/// into runtime `DashboardChart` records. Negative ids by convention so they
/// never collide with DB-stored rows when both coexist (debug mode).
///
/// Categories supported by the expander:
///
/// | category                     | expands to                                               |
/// |------------------------------|----------------------------------------------------------|
/// | all_accounts                 | every active `account:<id>`                              |
/// | all_invested                 | every active `asset_invested:<id>`                       |
/// | all_market                   | every active `asset_market:<id>`                         |
/// | all_market_liquid            | `asset_market:<id>` for non-illiquid instrument types    |
/// | all_gain                     | every active `asset_gain:<id>`                           |
/// | outflow_value                | every outflow event's `adjustment_value:<id>`            |
/// | outflow_events               | every outflow event's `adjustment_events:<id>`           |
/// | non_ephemeral_inflow_value   | every non-ephemeral inflow's `income_adj_value:<id>`     |
/// | non_ephemeral_inflow_events  | every non-ephemeral inflow's `income_adj_events:<id>`    |
/// | ephemeral_inflow_value       | every ephemeral inflow's `ephemeral_inflow_value:<id>`   |
/// | ephemeral_inflow_events      | every ephemeral inflow's `ephemeral_inflow_events:<id>`  |
class DefaultChartsLoader {
  static const _illiquidTypes = {
    InstrumentType.pension,
    InstrumentType.realEstate,
    InstrumentType.alternative,
    InstrumentType.liability,
  };

  /// Asset-bundle path (overrideable for tests).
  final String assetPath;

  const DefaultChartsLoader({this.assetPath = 'assets/default_charts.json'});

  Future<List<DashboardChart>> load({
    required List<Account> activeAccounts,
    required List<Asset> activeAssets,
    required List<ExtraordinaryEvent> activeEvents,
  }) async {
    final raw = await rootBundle.loadString(assetPath);
    return parse(
      raw,
      activeAccounts: activeAccounts,
      activeAssets: activeAssets,
      activeEvents: activeEvents,
    );
  }

  /// Pure parser — useful for tests so they don't need a Flutter binding.
  List<DashboardChart> parse(
    String rawJson, {
    required List<Account> activeAccounts,
    required List<Asset> activeAssets,
    required List<ExtraordinaryEvent> activeEvents,
  }) {
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final charts = (decoded['charts'] as List).cast<Map<String, dynamic>>();
    final now = DateTime.now();
    final result = <DashboardChart>[];
    var nextId = -1; // negative ids never collide with DB rows
    for (var i = 0; i < charts.length; i++) {
      final chart = charts[i];
      final widgetType = (chart['role'] as String?) ??
          (chart['widgetType'] as String?) ??
          'chart';
      final title = (chart['title'] as String?) ?? '';
      // Accept three forms in JSON:
      //   "*"                                 → stored as "*"
      //   ["Cash", "Saving"]  (literal list)  → stored as JSON-encoded string
      //   "[\"Cash\", \"Saving\"]"            → stored as-is
      final rawSrc = chart['sourceChartIds'];
      final String? sourceChartIds;
      if (rawSrc == null) {
        sourceChartIds = null;
      } else if (rawSrc is String) {
        sourceChartIds = rawSrc;
      } else if (rawSrc is List) {
        sourceChartIds = jsonEncode(rawSrc);
      } else {
        sourceChartIds = null;
      }
      final categories = (chart['categories'] as List?) ?? const [];
      final seriesConfigs = <Map<String, dynamic>>[];
      for (final entry in categories) {
        final (name, sign) = _entry(entry);
        seriesConfigs.addAll(_expand(
          name,
          sign: sign,
          activeAccounts: activeAccounts,
          activeAssets: activeAssets,
          activeEvents: activeEvents,
        ));
      }
      result.add(DashboardChart(
        id: nextId--,
        title: title,
        widgetType: widgetType,
        sortOrder: i,
        seriesJson: jsonEncode(seriesConfigs),
        sourceChartIds: sourceChartIds,
        createdAt: now,
      ));
    }
    return result;
  }

  /// Decode either `"category_name"` or `{"category": "...", "sign": -1}`.
  (String name, int sign) _entry(dynamic entry) {
    if (entry is String) return (entry, 1);
    if (entry is Map<String, dynamic>) {
      final name = entry['category'] as String? ?? '';
      final sign = (entry['sign'] as num?)?.toInt() ?? 1;
      return (name, sign);
    }
    return ('', 1);
  }

  List<Map<String, dynamic>> _expand(
    String category, {
    required int sign,
    required List<Account> activeAccounts,
    required List<Asset> activeAssets,
    required List<ExtraordinaryEvent> activeEvents,
  }) {
    Map<String, dynamic> conf(String type, int id) =>
        sign == 1 ? {'type': type, 'id': id} : {'type': type, 'id': id, 'sign': sign};

    final outflows = activeEvents.where((e) => e.direction == EventDirection.outflow);
    final inflows = activeEvents.where((e) => e.direction == EventDirection.inflow);

    return switch (category) {
      'all_accounts' => activeAccounts.map((a) => conf('account', a.id)).toList(),
      'all_invested' => activeAssets.map((a) => conf('asset_invested', a.id)).toList(),
      'all_market' => activeAssets.map((a) => conf('asset_market', a.id)).toList(),
      'all_market_liquid' => activeAssets
          .where((a) => !_illiquidTypes.contains(a.instrumentType))
          .map((a) => conf('asset_market', a.id))
          .toList(),
      'all_gain' => activeAssets.map((a) => conf('asset_gain', a.id)).toList(),
      'outflow_value' => outflows.map((e) => conf('adjustment_value', e.id)).toList(),
      'outflow_events' => outflows.map((e) => conf('adjustment_events', e.id)).toList(),
      'non_ephemeral_inflow_value' => inflows
          .where((e) => !e.isEphemeral)
          .map((e) => conf('income_adj_value', e.id))
          .toList(),
      'non_ephemeral_inflow_events' => inflows
          .where((e) => !e.isEphemeral)
          .map((e) => conf('income_adj_events', e.id))
          .toList(),
      'ephemeral_inflow_value' => inflows
          .where((e) => e.isEphemeral)
          .map((e) => conf('ephemeral_inflow_value', e.id))
          .toList(),
      'ephemeral_inflow_events' => inflows
          .where((e) => e.isEphemeral)
          .map((e) => conf('ephemeral_inflow_events', e.id))
          .toList(),
      _ => const [],
    };
  }
}
