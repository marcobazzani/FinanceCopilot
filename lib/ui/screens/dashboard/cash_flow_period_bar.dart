part of 'dashboard_screen.dart';

// ════════════════════════════════════════════════════
// Cash Flow tab: the period every section follows
// ════════════════════════════════════════════════════

/// The period the Cash Flow tab shows; null = this month. Kept for the
/// session, so switching tabs does not lose it.
final _cashFlowPeriodProvider = StateProvider<CashFlowPeriod?>((ref) => null);

/// What the Cash Flow overview and its screens compare the period with: the
/// previous period (this month against last month) unless picked otherwise.
final _cashFlowCompareProvider = StateProvider<CashFlowCompare>((ref) => CashFlowCompare.previous);
