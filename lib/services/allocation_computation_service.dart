import 'dart:math';

import '../database/database.dart';

/// Groups assets by a field, sums market values, returns sorted descending map.
Map<String, double> groupByField(
  List<Asset> assets,
  Map<int, double> values,
  String Function(Asset) keyFn,
) {
  final map = <String, double>{};
  for (final asset in assets) {
    final val = values[asset.id];
    if (val == null || val == 0) continue;
    final key = keyFn(asset);
    map[key] = (map[key] ?? 0) + val;
  }
  final sorted = map.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return Map.fromEntries(sorted);
}

/// Drill-down for simple field grouping: for each group key, which assets
/// contribute.
Map<String, Map<String, double>> drillDownByField(
  List<Asset> assets,
  Map<int, double> values,
  String Function(Asset) keyFn,
) {
  final result = <String, Map<String, double>>{};
  for (final asset in assets) {
    final val = values[asset.id];
    if (val == null || val <= 0) continue;
    final key = keyFn(asset);
    result.putIfAbsent(key, () => {});
    result[key]![asset.name] = (result[key]![asset.name] ?? 0) + val;
  }
  return result;
}

/// Compute weighted breakdown using composition data.
Map<String, double> weightedBreakdown(
  List<Asset> assets,
  Map<int, double> marketValues,
  Map<int, List<AssetComposition>> compositions,
  String compositionType,
  String Function(Asset) fallback,
) {
  final result = <String, double>{};
  for (final asset in assets) {
    final mv = marketValues[asset.id] ?? 0;
    if (mv <= 0) continue;

    final comps = compositions[asset.id]
        ?.where((c) => c.type == compositionType)
        .toList();

    if (comps != null && comps.isNotEmpty) {
      for (final c in comps) {
        result[c.name] = (result[c.name] ?? 0) + mv * c.weight / 100;
      }
    } else {
      final key = fallback(asset);
      result[key] = (result[key] ?? 0) + mv;
    }
  }
  final sorted = result.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return Map.fromEntries(sorted);
}

/// Compute drill-down data: for each key in the breakdown, which assets
/// contribute. Returns `Map<sliceKey, Map<assetName, value>>`.
Map<String, Map<String, double>> drillDownData(
  List<Asset> assets,
  Map<int, double> marketValues,
  Map<int, List<AssetComposition>> compositions,
  String compositionType,
  String Function(Asset) fallback,
) {
  final result = <String, Map<String, double>>{};
  for (final asset in assets) {
    final mv = marketValues[asset.id] ?? 0;
    if (mv <= 0) continue;

    final comps = compositions[asset.id]
        ?.where((c) => c.type == compositionType)
        .toList();

    if (comps != null && comps.isNotEmpty) {
      for (final c in comps) {
        final contribution = mv * c.weight / 100;
        result.putIfAbsent(c.name, () => {});
        result[c.name]![asset.name] =
            (result[c.name]![asset.name] ?? 0) + contribution;
      }
    } else {
      final key = fallback(asset);
      result.putIfAbsent(key, () => {});
      result[key]![asset.name] = (result[key]![asset.name] ?? 0) + mv;
    }
  }
  return result;
}

/// Concentration metrics computed from a sorted (descending) list of holdings.
class ConcentrationResult {
  final double top1;
  final double top3;
  final double top5;
  final double hhi;

  /// 'diversified', 'moderate', or 'concentrated'
  final String classification;

  const ConcentrationResult({
    required this.top1,
    required this.top3,
    required this.top5,
    required this.hhi,
    required this.classification,
  });
}

/// Computes Top1/3/5 percentages and HHI from a sorted list of holdings.
ConcentrationResult computeConcentration(
  List<MapEntry<String, double>> holdings,
  double total,
) {
  final count = holdings.length;

  final top1 = count >= 1 ? holdings[0].value / total * 100 : 0.0;
  final top3 = count >= 3
      ? holdings.take(3).fold(0.0, (a, b) => a + b.value) / total * 100
      : (count > 0
          ? holdings.fold(0.0, (a, b) => a + b.value) / total * 100
          : 0.0);
  final top5 = count >= 5
      ? holdings.take(5).fold(0.0, (a, b) => a + b.value) / total * 100
      : (count > 0
          ? holdings.fold(0.0, (a, b) => a + b.value) / total * 100
          : 0.0);

  final hhi = total > 0
      ? holdings.fold(0.0, (sum, e) => sum + pow(e.value / total, 2)) * 10000
      : 0.0;

  final classification =
      hhi < 1500 ? 'diversified' : hhi < 2500 ? 'moderate' : 'concentrated';

  return ConcentrationResult(
    top1: top1,
    top3: top3,
    top5: top5,
    hhi: hhi,
    classification: classification,
  );
}
