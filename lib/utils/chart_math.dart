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

/// Projects a trailing-rate series (e.g. velocity) past real "today" by holding
/// the value at [x] constant for all later points.
///
/// A trailing 365-day velocity computed over a flat, carried-forward future
/// replays the historical curve from a year earlier (`S(t−365)`), producing a
/// misleading rise/sawtooth for a *projected* rate. Holding the last real value
/// flat instead means "current rate carried forward" — the line still extends
/// to the future date (not truncated), just without the trailing-window replay.
/// Points at/before [x] are unchanged; if nothing is at/before [x] (e.g. a past
/// wayback date), the series is returned unchanged.
List<FlSpot> holdFlatAfter(List<FlSpot> spots, double x) {
  double? holdY;
  for (final s in spots) {
    if (s.x <= x) {
      holdY = s.y;
    } else {
      break;
    }
  }
  if (holdY == null) return spots;
  return [
    for (final s in spots)
      if (s.x <= x) s else FlSpot(s.x, holdY),
  ];
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
