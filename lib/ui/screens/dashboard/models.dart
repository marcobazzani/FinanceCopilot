part of 'dashboard_screen.dart';

// ════════════════════════════════════════════════════
// Data models
// ════════════════════════════════════════════════════

/// Unified series for accounts, assets, and CAPEX.
class ChartSeries {
  final String key; // unique id for toggling: "a:3" (account), "s:7" (asset), "c:1" (capex)
  final String name;
  final Color color;
  final List<FlSpot> spots;
  final bool isDashed;
  final bool rightAxis; // true → scale into left pixel space, show on right Y-axis
  const ChartSeries({
    required this.key,
    required this.name,
    required this.color,
    required this.spots,
    this.isDashed = false,
    this.rightAxis = false,
  });
}

/// All chart data: account series, asset series, CAPEX series, market value series.
class AllSeriesData {
  final DateTime firstDate;
  final List<ChartSeries> accounts; // key: "account:<id>"
  final List<ChartSeries> assetInvested; // key: "asset_invested:<id>"
  final List<ChartSeries> assetMarket; // key: "asset_market:<id>"
  final List<ChartSeries> assetGain; // key: "asset_gain:<id>"  (market - invested)
  final List<ChartSeries> assetNet; // key: "asset_net:<id>"   (invested + max(0,gain)*(1-tax))
  final List<ChartSeries> adjustments; // key: "adjustment_value/events:<id>"  — outflow events
  final List<ChartSeries> incomeAdjustments; // key: "income_adj_value/events:<id>"  — non-ephemeral inflow events
  final List<ChartSeries> ephemeralInflows; // key: "ephemeral_inflow_value/events:<id>" — line-of-credit inflows
  final String baseCurrency;

  const AllSeriesData({
    required this.firstDate,
    required this.accounts,
    required this.assetInvested,
    required this.assetMarket,
    required this.assetGain,
    required this.assetNet,
    required this.adjustments,
    required this.incomeAdjustments,
    required this.ephemeralInflows,
    required this.baseCurrency,
  });

  List<ChartSeries> get allSeries => [
    ...accounts,
    ...assetInvested,
    ...assetMarket,
    ...assetGain,
    ...assetNet,
    ...adjustments,
    ...incomeAdjustments,
    ...ephemeralInflows,
  ];

  /// Series composing the Cash chart: accounts + adjustments + ephemeral
  /// inflows negated (line-of-credit money raises Cash in absolute value).
  /// Used as the resolver fallback when no `cash` role chart exists.
  List<ChartSeries> get cashSeries => [
    ...accounts,
    ...adjustments,
    ...ephemeralInflows.map(_negate),
  ];

  /// Series composing the Saving chart: accounts + invested + adjustments
  /// + non-ephemeral inflow adjustments. Ephemeral inflows are excluded.
  List<ChartSeries> get savingSeries => [...accounts, ...assetInvested, ...adjustments, ...incomeAdjustments];

  static ChartSeries _negate(ChartSeries s) => ChartSeries(
    key: s.key,
    name: s.name,
    color: s.color,
    spots: s.spots.map((p) => FlSpot(p.x, -p.y)).toList(),
    isDashed: s.isDashed,
    rightAxis: s.rightAxis,
  );

  /// Carry-forward total Cash spots — what the Cash chart plots.
  List<FlSpot> get cashSpots => buildTotalSpots(cashSeries.map((s) => s.spots).toList());

  /// Carry-forward total Saving spots — what the Saving chart plots.
  List<FlSpot> get savingSpots => buildTotalSpots(savingSeries.map((s) => s.spots).toList());
}

// ════════════════════════════════════════════════════
// Income/Expense data models
// ════════════════════════════════════════════════════

class _MonthBucket {
  final int year, month;
  final double income, navChange, pensionContrib;
  final bool hasIncomeData;
  // Pension contributions inflate navChange without ever touching the
  // user's wallet (employer/state/severance redirect). Subtract them
  // so savings/expenses reflect personal cashflow only. Refunds are
  // intentionally NOT subtracted: they DO land in the user's bank, so
  // their NAV impact is real personal savings — only the income-side
  // classification is excluded.
  double get personalNavChange => navChange - pensionContrib;
  double get expenses => income - personalNavChange;
  double get savings => personalNavChange;
  double get savingsRate => income > 0 ? personalNavChange / income : 0;
  const _MonthBucket({
    required this.year,
    required this.month,
    required this.income,
    required this.navChange,
    this.pensionContrib = 0,
    this.hasIncomeData = false,
  });
}

class _YearBucket {
  final int year, days;
  final double income, navChange, pensionContrib;
  final List<_MonthBucket> months;

  double get personalNavChange => navChange - pensionContrib;
  double get expenses => income - personalNavChange;
  double get savings => personalNavChange;
  double get savingsRate => income > 0 ? personalNavChange / income : 0;
  double get dailyIncome => days > 0 ? income / days : 0;
  double get dailyExpenses => days > 0 ? expenses / days : 0;
  double get monthlyIncome => days > 0 ? income / days * 30.4 : 0;
  double get monthlyExpenses => days > 0 ? expenses / days * 30.4 : 0;
  double get monthlySavings => days > 0 ? savings / days * 30.4 : 0;

  const _YearBucket({
    required this.year,
    required this.days,
    required this.income,
    required this.navChange,
    required this.months,
    this.pensionContrib = 0,
  });
}

class _IncomeExpenseData {
  final List<_YearBucket> years;
  final String baseCurrency;
  final DateTime firstDate;

  /// Cumulative pension contributions in base currency, as a series of
  /// (dayOffsetFromFirstDate, cumulativeAmount) spots. Empty when the
  /// user has no pension imports. Cashflow_tab subtracts this from
  /// savingSpots to compute "personal saving" velocity — pension money
  /// inflates fund NAV but never lands in the user's bank account, so
  /// it shouldn't drive saving/expense velocity metrics.
  final List<FlSpot> pensionContribCumulativeSpots;
  const _IncomeExpenseData({
    required this.years,
    required this.baseCurrency,
    required this.firstDate,
    this.pensionContribCumulativeSpots = const [],
  });
}

final _chartColors = [
  Colors.blue,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.teal,
  Colors.red,
  Colors.amber,
  Colors.cyan,
  Colors.indigo,
  Colors.pink,
  Colors.lime,
  Colors.deepOrange,
];

/// Convert a DateTime to a day-key (epoch seconds at midnight).
int toDayKey(DateTime dt) => DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch ~/ 1000;

/// Build a carry-forward total line from multiple spot lists.
List<FlSpot> buildTotalSpots(List<List<FlSpot>> allSpots) {
  if (allSpots.isEmpty) return [];
  final allX = <double>{};
  final lookups = <Map<double, double>>[];
  for (final spots in allSpots) {
    final m = <double, double>{};
    for (final s in spots) {
      m[s.x] = s.y;
      allX.add(s.x);
    }
    lookups.add(m);
  }
  final sorted = allX.toList()..sort();
  final running = List<double>.filled(lookups.length, 0.0);
  return sorted.map((x) {
    var total = 0.0;
    for (var i = 0; i < lookups.length; i++) {
      if (lookups[i].containsKey(x)) running[i] = lookups[i][x]!;
      total += running[i];
    }
    return FlSpot(x, total);
  }).toList();
}

List<FlSpot> extendSingleSpotCarryForward(
  List<FlSpot> spots, {
  required DateTime firstDate,
  required int endDayKey,
}) {
  if (spots.length != 1) return spots;
  final endDate = DateTime.fromMillisecondsSinceEpoch(endDayKey * 1000);
  final endX = chart_math.calendarDaysBetween(firstDate, endDate).toDouble();
  if (endX <= spots.single.x) return spots;
  return [spots.single, FlSpot(endX, spots.single.y)];
}

bool isOutflowAdjustmentSeriesKey(String key) =>
    key.startsWith('adjustment:') || key.startsWith('adjustment_value:') || key.startsWith('adjustment_events:');

bool isIncomeAdjustmentSeriesKey(String key) =>
    key.startsWith('income_adj:') || key.startsWith('income_adj_value:') || key.startsWith('income_adj_events:');

bool isEphemeralInflowSeriesKey(String key) => key.startsWith('ephemeral_inflow_value:') || key.startsWith('ephemeral_inflow_events:');

bool isAdjustmentSeriesKey(String key) =>
    isOutflowAdjustmentSeriesKey(key) || isIncomeAdjustmentSeriesKey(key) || isEphemeralInflowSeriesKey(key);

/// Reference ("compare-against") date for the price-change period selector.
///
/// Mirrors the chip semantics: the relative units (`d`, `w`, `m`, `y`) step
/// back by [number]; the "to-date" units anchor to the last close BEFORE the
/// start of the current week (`WTD`), month (`MTD`), or year (`YTD`) — the
/// prior period's close — so the first day of a period compares against the
/// previous period's end rather than itself; `All` reaches back to a fixed
/// epoch. [firstDayOfWeekIndex] follows `MaterialLocalizations` (0 = Sunday …
/// 6 = Saturday) so `WTD` honours the active locale's first day of week
/// (Monday for it/de/fr/es/en_GB, Sunday for en_US).
DateTime priceChangeReferenceDate({
  required DateTime today,
  required String unit,
  required int number,
  required int firstDayOfWeekIndex,
}) {
  switch (unit) {
    case 'd':
      return today.subtract(Duration(days: number));
    case 'w':
      return today.subtract(Duration(days: number * 7));
    case 'm':
      return DateTime(today.year, today.month - number, today.day);
    case 'y':
      return DateTime(today.year - number, today.month, today.day);
    case 'WTD':
      // Days elapsed since the locale's first day of week. DateTime.weekday is
      // Mon=1..Sun=7; `% 7` maps it onto the Sun=0..Sat=6 scale used by
      // MaterialLocalizations.firstDayOfWeekIndex.
      final daysSinceWeekStart = (today.weekday % 7 - firstDayOfWeekIndex + 7) % 7;
      // Anchor to the day BEFORE the week start so getPrice("on or before")
      // resolves to the previous week's close (the week-start day itself read 0).
      return DateTime(today.year, today.month, today.day).subtract(Duration(days: daysSinceWeekStart + 1));
    case 'MTD':
      // Day before the 1st = last day of the previous month, so the base is the
      // previous month's close (anchoring to the 1st made day 1 of the month read 0).
      return DateTime(today.year, today.month, 1).subtract(const Duration(days: 1));
    case 'YTD':
      // Dec 31 of the previous year, so the base is the prior year's close
      // (anchoring to Jan 1 made the first trading day of the year read 0).
      return DateTime(today.year, 1, 1).subtract(const Duration(days: 1));
    case 'All':
      return DateTime(2000, 1, 1);
    default:
      return today.subtract(const Duration(days: 1));
  }
}
