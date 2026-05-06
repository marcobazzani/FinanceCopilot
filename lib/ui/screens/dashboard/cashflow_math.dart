part of 'dashboard_screen.dart';

// ════════════════════════════════════════════════════
// Cash Flow math utilities — thin wrappers around lib/utils/chart_math.dart
// ════════════════════════════════════════════════════

List<FlSpot> _computeMA(List<FlSpot> spots, int windowDays) => chart_math.computeMA(spots, windowDays);

List<FlSpot> _computeVelocity(List<FlSpot> dense) => chart_math.computeVelocity(dense);

List<FlSpot> _buildSpendingFromSaving(List<FlSpot> savingSpots) => chart_math.buildSpendingFromSaving(savingSpots);

List<FlSpot> _computeDiff(List<FlSpot> a, List<FlSpot> b) => chart_math.computeDiff(a, b);

/// Subtract a sparse cumulative series [step] from a dense base series
/// [base], aligned by x. For each base.x, find the latest step.x <= base.x
/// and subtract that step.y. Used to remove cumulative pension
/// contributions from a saving-NAV series so velocity reflects personal
/// cashflow only. O(N+M) — both inputs must be sorted by x.
List<FlSpot> _subtractCumulativeSeries(List<FlSpot> base, List<FlSpot> step) {
  if (step.isEmpty) return base;
  final result = <FlSpot>[];
  var stepIdx = 0;
  double currentStep = 0;
  for (final p in base) {
    while (stepIdx < step.length && step[stepIdx].x <= p.x) {
      currentStep = step[stepIdx].y;
      stepIdx++;
    }
    result.add(FlSpot(p.x, p.y - currentStep));
  }
  return result;
}
