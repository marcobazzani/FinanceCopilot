import 'dart:math';

import 'package:fl_chart/fl_chart.dart';

import 'package:finance_copilot/utils/chart_math.dart' as chart_math;
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show AllSeriesData, buildTotalSpots, costBasisIncompleteAssetIds;

class PillarScopedHistory {
  final DateTime? inceptionDate;
  final List<FlSpot> investedTotal;
  final List<FlSpot> marketTotal;

  /// Held assets left out of BOTH totals because they have no market value
  /// at the end of their history (no price, or no exchange rate to base), or
  /// because their cost basis is incomplete (a buy or sell amount without an
  /// exchange rate to base, see [costBasisIncompleteAssetIds]).
  final int excludedAssetCount;

  const PillarScopedHistory({
    required this.inceptionDate,
    required this.investedTotal,
    required this.marketTotal,
    this.excludedAssetCount = 0,
  });

  bool get hasData => investedTotal.isNotEmpty || marketTotal.isNotEmpty;
}

class PillarPerformanceSnapshot {
  final DateTime asOfDate;
  final double marketValue;
  final double netInvested;
  final double absoluteReturnAmount;
  final double? absoluteReturnPct;
  final double? twrr;
  final double? cagr;
  final bool hasSufficientHistory;

  /// Held assets left out of every figure (market value AND money put in)
  /// because they have no market value or an incomplete cost basis — see
  /// [PillarScopedHistory.excludedAssetCount].
  final int excludedAssetCount;

  const PillarPerformanceSnapshot({
    required this.asOfDate,
    required this.marketValue,
    required this.netInvested,
    required this.absoluteReturnAmount,
    required this.absoluteReturnPct,
    required this.twrr,
    required this.cagr,
    required this.hasSufficientHistory,
    this.excludedAssetCount = 0,
  });

  factory PillarPerformanceSnapshot.empty(DateTime asOfDate, {int excludedAssetCount = 0}) => PillarPerformanceSnapshot(
    asOfDate: DateTime(asOfDate.year, asOfDate.month, asOfDate.day),
    marketValue: 0,
    netInvested: 0,
    absoluteReturnAmount: 0,
    absoluteReturnPct: null,
    twrr: null,
    cagr: null,
    hasSufficientHistory: false,
    excludedAssetCount: excludedAssetCount,
  );
}

PillarScopedHistory buildPillarScopedHistory({
  required AllSeriesData allData,
  required Map<int, double> fractions,
}) {
  final scaledInvested = <List<FlSpot>>[];
  final scaledMarket = <List<FlSpot>>[];
  final costBasisIncomplete = costBasisIncompleteAssetIds(allData);
  double? minX;
  var excluded = 0;

  void seenX(double x) {
    if (minX == null || x < minX!) minX = x;
  }

  for (final entry in fractions.entries) {
    final fraction = entry.value;
    if (fraction <= 0) continue;
    final invested = allData.assetInvested.where((x) => x.key == 'asset_invested:${entry.key}').firstOrNull;
    final market = allData.assetMarket.where((x) => x.key == 'asset_market:${entry.key}').firstOrNull;
    if (invested == null && market == null) continue;
    // Held but without a market value where its history ends (no price, or
    // no rate to base): the money put in would stand against a missing value
    // and read as a loss in every return figure. With an incomplete cost
    // basis the money put in misses part of what the value holds, which reads
    // as a gain (or, for a sell, a loss). Left out of both sides.
    if (!_valuedToTheEnd(market?.spots ?? const [], invested?.spots ?? const []) || costBasisIncomplete.contains(entry.key)) {
      excluded++;
      continue;
    }
    if (invested != null) {
      if (invested.spots.isNotEmpty) seenX(invested.spots.first.x);
      scaledInvested.add(
        invested.spots.map((p) => FlSpot(p.x, p.y * fraction)).toList(),
      );
    }
    if (market != null) {
      if (market.spots.isNotEmpty) seenX(market.spots.first.x);
      scaledMarket.add(
        market.spots.map((p) => FlSpot(p.x, p.y * fraction)).toList(),
      );
    }
  }

  final shift = minX ?? 0;
  List<FlSpot> trim(List<FlSpot> spots) => spots.where((p) => p.x >= shift).map((p) => FlSpot(p.x - shift, p.y)).toList();

  final investedTotal = buildTotalSpots(scaledInvested.map(trim).toList());
  final marketTotal = buildTotalSpots(scaledMarket.map(trim).toList());
  final inceptionDate = (investedTotal.isEmpty && marketTotal.isEmpty) ? null : chart_math.dateAddDays(allData.firstDate, shift.toInt());

  return PillarScopedHistory(
    inceptionDate: inceptionDate,
    investedTotal: investedTotal,
    marketTotal: marketTotal,
    excludedAssetCount: excluded,
  );
}

/// Whether an asset's [market] series has a value on the last day of its
/// history — the last day of its [invested] series, which runs to the end of
/// the chart once the asset is bought. A closed position's exact zeros count
/// as a value.
bool _valuedToTheEnd(List<FlSpot> market, List<FlSpot> invested) {
  if (market.isEmpty) return false;
  return invested.isEmpty || market.last.x >= invested.last.x;
}

PillarPerformanceSnapshot computePillarPerformanceSnapshot({
  required DateTime asOfDate,
  required AllSeriesData allData,
  required Map<int, double> fractions,
}) {
  final normalizedAsOf = DateTime(asOfDate.year, asOfDate.month, asOfDate.day);
  if (fractions.isEmpty) return PillarPerformanceSnapshot.empty(normalizedAsOf);

  final history = buildPillarScopedHistory(allData: allData, fractions: fractions);
  if (!history.hasData) return PillarPerformanceSnapshot.empty(normalizedAsOf, excludedAssetCount: history.excludedAssetCount);

  final endingMarketValue = history.marketTotal.isEmpty ? 0.0 : history.marketTotal.last.y;
  final endingNetInvested = history.investedTotal.isEmpty ? 0.0 : history.investedTotal.last.y;
  final absoluteReturnAmount = endingMarketValue - endingNetInvested;
  final absoluteReturnPct = endingNetInvested > 0 ? (endingMarketValue / endingNetInvested) - 1 : null;

  final hasSufficientHistory =
      history.inceptionDate != null && history.marketTotal.length >= 2 && history.marketTotal.last.x > history.marketTotal.first.x;

  double? twrr;
  double? cagr;
  if (endingNetInvested > 0 && hasSufficientHistory) {
    twrr = _computeTwrr(
      marketTotal: history.marketTotal,
      investedTotal: history.investedTotal,
    );
    final days = chart_math.calendarDaysBetween(history.inceptionDate!, normalizedAsOf);
    if (twrr != null && days > 0 && (1 + twrr) > 0) {
      cagr = pow(1 + twrr, 365 / days).toDouble() - 1;
    }
  }

  return PillarPerformanceSnapshot(
    asOfDate: normalizedAsOf,
    marketValue: endingMarketValue,
    netInvested: endingNetInvested,
    absoluteReturnAmount: absoluteReturnAmount,
    absoluteReturnPct: absoluteReturnPct,
    twrr: twrr,
    cagr: cagr,
    hasSufficientHistory: hasSufficientHistory,
    excludedAssetCount: history.excludedAssetCount,
  );
}

double? _computeTwrr({
  required List<FlSpot> marketTotal,
  required List<FlSpot> investedTotal,
}) {
  if (marketTotal.length < 2) return null;

  final allX = <double>{
    ...marketTotal.map((spot) => spot.x),
    ...investedTotal.map((spot) => spot.x),
  }.toList()..sort();
  if (allX.length < 2) return null;

  final marketByX = {for (final spot in marketTotal) spot.x: spot.y};
  final investedByX = {for (final spot in investedTotal) spot.x: spot.y};

  double runningMarket = 0;
  double runningInvested = 0;
  double? previousMarket;
  double? previousInvested;
  var growth = 1.0;
  var hasReturnWindow = false;

  for (final x in allX) {
    if (marketByX.containsKey(x)) runningMarket = marketByX[x]!;
    if (investedByX.containsKey(x)) runningInvested = investedByX[x]!;

    if (previousMarket == null) {
      previousMarket = runningMarket;
      previousInvested = runningInvested;
      continue;
    }

    if (previousMarket <= 0) {
      previousMarket = runningMarket;
      previousInvested = runningInvested;
      continue;
    }

    final cashFlow = runningInvested - (previousInvested ?? 0);
    final gross = (runningMarket - cashFlow) / previousMarket;
    if (!gross.isFinite || gross <= 0) return null;

    growth *= gross;
    hasReturnWindow = true;
    previousMarket = runningMarket;
    previousInvested = runningInvested;
  }

  return hasReturnWindow ? growth - 1 : null;
}
