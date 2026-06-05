import 'dart:math';

import 'package:fl_chart/fl_chart.dart';

import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show AllSeriesData, buildTotalSpots;

class PillarScopedHistory {
  final DateTime? inceptionDate;
  final List<FlSpot> investedTotal;
  final List<FlSpot> marketTotal;

  const PillarScopedHistory({
    required this.inceptionDate,
    required this.investedTotal,
    required this.marketTotal,
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

  const PillarPerformanceSnapshot({
    required this.asOfDate,
    required this.marketValue,
    required this.netInvested,
    required this.absoluteReturnAmount,
    required this.absoluteReturnPct,
    required this.twrr,
    required this.cagr,
    required this.hasSufficientHistory,
  });

  factory PillarPerformanceSnapshot.empty(DateTime asOfDate) => PillarPerformanceSnapshot(
    asOfDate: DateTime(asOfDate.year, asOfDate.month, asOfDate.day),
    marketValue: 0,
    netInvested: 0,
    absoluteReturnAmount: 0,
    absoluteReturnPct: null,
    twrr: null,
    cagr: null,
    hasSufficientHistory: false,
  );
}

PillarScopedHistory buildPillarScopedHistory({
  required AllSeriesData allData,
  required Map<int, double> fractions,
}) {
  final scaledInvested = <List<FlSpot>>[];
  final scaledMarket = <List<FlSpot>>[];
  double? minX;

  void seenX(double x) {
    if (minX == null || x < minX!) minX = x;
  }

  for (final entry in fractions.entries) {
    final fraction = entry.value;
    if (fraction <= 0) continue;
    final invested = allData.assetInvested.where((x) => x.key == 'asset_invested:${entry.key}').firstOrNull;
    final market = allData.assetMarket.where((x) => x.key == 'asset_market:${entry.key}').firstOrNull;
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
  final inceptionDate = (investedTotal.isEmpty && marketTotal.isEmpty) ? null : allData.firstDate.add(Duration(days: shift.toInt()));

  return PillarScopedHistory(
    inceptionDate: inceptionDate,
    investedTotal: investedTotal,
    marketTotal: marketTotal,
  );
}

PillarPerformanceSnapshot computePillarPerformanceSnapshot({
  required DateTime asOfDate,
  required AllSeriesData allData,
  required Map<int, double> fractions,
}) {
  final normalizedAsOf = DateTime(asOfDate.year, asOfDate.month, asOfDate.day);
  if (fractions.isEmpty) return PillarPerformanceSnapshot.empty(normalizedAsOf);

  final history = buildPillarScopedHistory(allData: allData, fractions: fractions);
  if (!history.hasData) return PillarPerformanceSnapshot.empty(normalizedAsOf);

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
    final days = normalizedAsOf.difference(history.inceptionDate!).inDays;
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
