import 'dart:math';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';

/// Groups assets by a field, sums market values, returns sorted descending map.
///
/// Skips non-positive values (negative liabilities and zeros). Allocation
/// pie charts can't render negative slices meaningfully and the drill-down
/// helpers (`drillDownByField`, `weightedBreakdown`, `drillDownData`) all
/// already exclude them — keeping this consistent so a slice's value
/// matches what the drill-down shows.
Map<String, double> groupByField(
  List<Asset> assets,
  Map<int, double> values,
  String Function(Asset) keyFn,
) {
  final map = <String, double>{};
  for (final asset in assets) {
    final val = values[asset.id];
    if (val == null || val <= 0) continue;
    final key = keyFn(asset);
    map[key] = (map[key] ?? 0) + val;
  }
  final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return Map.fromEntries(sorted);
}

/// The total the allocation charts split: the positive values of [assets],
/// the very holdings every slice is drawn from. A liability or an asset
/// without a value is in no slice, so it is not in the total either and the
/// slices add up to 100%.
double allocationTotal(List<Asset> assets, Map<int, double> values) {
  var total = 0.0;
  for (final asset in assets) {
    final val = values[asset.id];
    if (val != null && val > 0) total += val;
  }
  return total;
}

/// Held [assets] (ids in [heldIds]) without a value in [values] — no price
/// or exchange rate. They are in no slice and no total, and are counted under
/// the charts rather than silently dropped.
int unvaluedAssetCount(List<Asset> assets, Map<int, double> values, {required Set<int> heldIds}) =>
    assets.where((a) => heldIds.contains(a.id) && !values.containsKey(a.id)).length;

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
    // No value (no price or exchange rate; see [unvaluedAssetCount]) or a
    // liability: in no slice.
    final mv = marketValues[asset.id];
    if (mv == null || mv <= 0) continue;

    final comps = compositions[asset.id]?.where((c) => c.type == compositionType).toList();

    if (comps != null && comps.isNotEmpty) {
      for (final c in comps) {
        result[c.name] = (result[c.name] ?? 0) + mv * c.weight / 100;
      }
    } else {
      final key = fallback(asset);
      result[key] = (result[key] ?? 0) + mv;
    }
  }
  final sorted = result.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
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
    // Same holdings as [weightedBreakdown]: nothing for an unvalued asset.
    final mv = marketValues[asset.id];
    if (mv == null || mv <= 0) continue;

    final comps = compositions[asset.id]?.where((c) => c.type == compositionType).toList();

    if (comps != null && comps.isNotEmpty) {
      for (final c in comps) {
        final contribution = mv * c.weight / 100;
        result.putIfAbsent(c.name, () => {});
        result[c.name]![asset.name] = (result[c.name]![asset.name] ?? 0) + contribution;
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
      : (count > 0 ? holdings.fold(0.0, (a, b) => a + b.value) / total * 100 : 0.0);
  final top5 = count >= 5
      ? holdings.take(5).fold(0.0, (a, b) => a + b.value) / total * 100
      : (count > 0 ? holdings.fold(0.0, (a, b) => a + b.value) / total * 100 : 0.0);

  final hhi = total > 0 ? holdings.fold(0.0, (sum, e) => sum + pow(e.value / total, 2)) * 10000 : 0.0;

  final classification = hhi < 1500
      ? 'diversified'
      : hhi < 2500
      ? 'moderate'
      : 'concentrated';

  return ConcentrationResult(
    top1: top1,
    top3: top3,
    top5: top5,
    hhi: hhi,
    classification: classification,
  );
}

/// Instruments that charge a TER. One of these without a TER on record has an
/// unknown cost, not a zero one. Stocks, bonds, cash, crypto, real estate, …
/// have no TER at all and weigh in at zero cost.
const _terChargingInstruments = {InstrumentType.etf, InstrumentType.etc, InstrumentType.fund, InstrumentType.pension};

/// Market-value-weighted TER of a set of holdings.
class WeightedTerResult {
  /// Weighted TER in percent; null when no holding could be weighed.
  final double? ter;

  /// Yearly cost of the covered holdings: value × TER.
  final double annualCost;

  /// Funds with a value but no TER on record, left out of both the value the
  /// TER is weighted over and [annualCost]: counted as free they would
  /// understate [ter].
  final int unknownTerFunds;

  const WeightedTerResult({required this.ter, required this.annualCost, required this.unknownTerFunds});
}

/// Weighted TER of the [assets] with a positive market value in [values]
/// (an asset without a value cannot be weighed and is skipped).
WeightedTerResult computeWeightedTer(List<Asset> assets, Map<int, double> values) {
  var covered = 0.0, cost = 0.0;
  var unknown = 0;
  for (final asset in assets) {
    final mv = values[asset.id];
    if (mv == null || mv <= 0) continue;
    final ter = asset.ter;
    if (ter == null && _terChargingInstruments.contains(asset.instrumentType)) {
      unknown++;
      continue;
    }
    covered += mv;
    if (ter != null && ter > 0) cost += mv * ter / 100;
  }
  return WeightedTerResult(ter: covered > 0 ? cost / covered * 100 : null, annualCost: cost, unknownTerFunds: unknown);
}
