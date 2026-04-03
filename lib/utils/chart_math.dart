import 'dart:math';

import 'package:fl_chart/fl_chart.dart';

/// Forward-fill spots to one point per integer day (gap-free).
List<FlSpot> densifySpots(List<FlSpot> spots) {
  if (spots.isEmpty) return [];
  final sorted = List<FlSpot>.from(spots)..sort((a, b) => a.x.compareTo(b.x));
  final result = <FlSpot>[];
  int ix = sorted.first.x.round();
  final ixMax = sorted.last.x.ceil();
  double lastY = sorted.first.y;
  int si = 0;
  while (ix <= ixMax) {
    while (si < sorted.length && sorted[si].x <= ix + 0.5) {
      lastY = sorted[si].y;
      si++;
    }
    result.add(FlSpot(ix.toDouble(), lastY));
    ix++;
  }
  return result;
}

/// Trailing SMA of [windowDays] on spots -- O(n) sliding window.
List<FlSpot> computeMA(List<FlSpot> spots, int windowDays) {
  final dense = densifySpots(spots);
  if (dense.isEmpty) return [];
  final result = <FlSpot>[];
  double sum = 0;
  for (int i = 0; i < dense.length; i++) {
    sum += dense[i].y;
    if (i >= windowDays) sum -= dense[i - windowDays].y;
    result.add(FlSpot(dense[i].x, sum / min(i + 1, windowDays)));
  }
  return result;
}

/// Day-over-day first difference (velocity = derivative of MA).
List<FlSpot> computeVelocity(List<FlSpot> dense) {
  final result = <FlSpot>[];
  for (int i = 1; i < dense.length; i++) {
    result.add(FlSpot(dense[i].x, dense[i].y - dense[i - 1].y));
  }
  return result;
}

/// Build spending spots: cumulative sum of negative daily deltas of the saving
/// series (mirrors Excel's "Uscite cumulate" = cumsum of MIN(0, daily_P&L)).
/// Output spots share the same X axis (days from firstDate) as saving spots.
List<FlSpot> buildSpendingFromSaving(List<FlSpot> savingSpots) {
  final dense = densifySpots(savingSpots);
  if (dense.length < 2) return [];
  final result = <FlSpot>[];
  double cumul = 0;
  result.add(FlSpot(dense.first.x, 0));
  for (int i = 1; i < dense.length; i++) {
    final delta = dense[i].y - dense[i - 1].y;
    if (delta < 0) cumul += delta; // accumulate only negative (outflow) days
    result.add(FlSpot(dense[i].x, cumul));
  }
  return result;
}

/// Element-wise difference of two spot lists (a - b), aligned by densified X.
List<FlSpot> computeDiff(List<FlSpot> a, List<FlSpot> b) {
  if (a.isEmpty || b.isEmpty) return [];
  final da = densifySpots(a);
  final db = densifySpots(b);
  final bMap = <double, double>{for (final s in db) s.x: s.y};
  return [
    for (final sa in da)
      if (bMap.containsKey(sa.x)) FlSpot(sa.x, sa.y - bMap[sa.x]!),
  ];
}
