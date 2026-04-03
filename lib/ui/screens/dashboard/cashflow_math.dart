part of 'dashboard_screen.dart';

// ════════════════════════════════════════════════════
// Cash Flow math utilities — thin wrappers around lib/utils/chart_math.dart
// ════════════════════════════════════════════════════

List<FlSpot> _computeMA(List<FlSpot> spots, int windowDays) => chart_math.computeMA(spots, windowDays);

List<FlSpot> _computeVelocity(List<FlSpot> dense) => chart_math.computeVelocity(dense);

List<FlSpot> _buildSpendingFromSaving(List<FlSpot> savingSpots) => chart_math.buildSpendingFromSaving(savingSpots);

List<FlSpot> _computeDiff(List<FlSpot> a, List<FlSpot> b) => chart_math.computeDiff(a, b);
