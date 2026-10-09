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

  /// Accounts whose balance is in a currency without any rate to
  /// [baseCurrency]: their series has no spots, so every total leaves them
  /// out — counted by [totalExclusions].
  final Set<int> excludedAccountIds;

  /// Adjustments (extraordinary events) whose amounts are in a currency
  /// without any rate to [baseCurrency]: their series are kept without spots,
  /// so every total leaves them out — counted by [totalExclusions].
  final Set<int> excludedAdjustmentIds;

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
    this.excludedAccountIds = const {},
    this.excludedAdjustmentIds = const {},
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

  /// Refund Income records of the year (not income, but inside [savings]).
  final double refunds;
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
    this.refunds = 0,
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

  /// Income records (salaries, refunds, pension contributions) whose currency
  /// had no rate to base on their value date: left out of [years] rather than
  /// converted 1:1, and counted here.
  final int rowsWithoutRate;
  const _IncomeExpenseData({
    required this.years,
    required this.baseCurrency,
    required this.firstDate,
    this.pensionContribCumulativeSpots = const [],
    required this.rowsWithoutRate,
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

/// The series of [visible] that make up a chart's total, so an asset is never
/// counted twice nor valued at cost:
/// - a visible `asset_net:<id>` supersedes `asset_invested:<id>` and
///   `asset_market:<id>`;
/// - otherwise a visible `asset_market:<id>` supersedes `asset_invested:<id>`;
/// - a superseding series without spots (no price or exchange rate) leaves
///   the asset out altogether — its invested line never stands in for the
///   missing value — and [totalExclusions] reports the asset as unpriced;
/// - right-axis series are on another scale and never count.
List<ChartSeries> smartTotalSeries(List<ChartSeries> visible) => _smartTotal(visible).series;

/// The series of [smartTotalSeries], and the assets it leaves out for want of
/// a value: the series standing for the asset (net if visible, else market)
/// has no spots.
({List<ChartSeries> series, Set<int> unpriced}) _smartTotal(List<ChartSeries> visible) {
  final visibleInvestedIds = <int>{};
  final visibleMarketIds = <int>{};
  final visibleNetIds = <int>{};
  for (final s in visible) {
    final key = parseSeriesKey(s.key);
    if (key == null) continue;
    if (key.type == 'asset_invested') visibleInvestedIds.add(key.id);
    if (key.type == 'asset_market') visibleMarketIds.add(key.id);
    if (key.type == 'asset_net') visibleNetIds.add(key.id);
  }
  final excludeFromTotal = <String>{};
  for (final id in visibleNetIds) {
    excludeFromTotal.add('asset_invested:$id');
    excludeFromTotal.add('asset_market:$id');
  }
  for (final id in visibleInvestedIds) {
    if (visibleMarketIds.contains(id)) {
      excludeFromTotal.add('asset_invested:$id');
    }
  }
  final series = <ChartSeries>[];
  final unpriced = <int>{};
  for (final s in visible) {
    if (excludeFromTotal.contains(s.key) || s.rightAxis) continue;
    final key = parseSeriesKey(s.key);
    if (key != null && s.spots.isEmpty && (key.type == 'asset_market' || key.type == 'asset_net')) {
      unpriced.add(key.id);
      continue;
    }
    series.add(s);
  }
  return (series: series, unpriced: unpriced);
}

/// Every contributor a total built from some visible series leaves out — or,
/// for an incomplete cost basis, holds only part of — for want of a price or
/// an exchange rate, each one once. Totals over several charts merge theirs
/// with [union]; the footnote under them shows [excludedFromTotalCount].
class TotalExclusions {
  /// Assets without a value in the series standing for them in the total
  /// (see [smartTotalSeries]), or without a market value to draw the gain the
  /// total adds up from.
  final Set<int> unpricedAssetIds;

  /// Assets standing in the total through their invested or gain series while
  /// a buy or sell amount has no rate to base: the amount is missing from
  /// them (see [costBasisIncompleteAssetIds]) — every amount when their
  /// invested series has no spots, whether they have a price or not.
  final Set<int> costBasisIncompleteAssetIds;

  /// Accounts without a rate to base (see [AllSeriesData.excludedAccountIds]).
  final Set<int> accountIds;

  /// Adjustments without a rate to base (see
  /// [AllSeriesData.excludedAdjustmentIds]).
  final Set<int> adjustmentIds;

  const TotalExclusions({
    this.unpricedAssetIds = const {},
    this.costBasisIncompleteAssetIds = const {},
    this.accountIds = const {},
    this.adjustmentIds = const {},
  });

  /// How many contributors are left out: an asset counts once, whatever the
  /// reason.
  int get excludedFromTotalCount => {...unpricedAssetIds, ...costBasisIncompleteAssetIds}.length + accountIds.length + adjustmentIds.length;

  /// The contributors left out of either.
  TotalExclusions union(TotalExclusions other) => TotalExclusions(
    unpricedAssetIds: {...unpricedAssetIds, ...other.unpricedAssetIds},
    costBasisIncompleteAssetIds: {...costBasisIncompleteAssetIds, ...other.costBasisIncompleteAssetIds},
    accountIds: {...accountIds, ...other.accountIds},
    adjustmentIds: {...adjustmentIds, ...other.adjustmentIds},
  );
}

/// What the smart total of [visible] ([buildSmartTotalSpots]) leaves out of
/// [data]: the assets whose series standing for their value has no spots
/// ([smartTotalSeries]), plus, among the series the total adds up, the
/// accounts and adjustments of [data] without a rate to base and the assets
/// whose cost basis is incomplete. An asset series the total adds up without
/// spots adds nothing to it, so its asset is counted whatever the reason: an
/// invested line none of whose amounts converts to base (an incomplete cost
/// basis, priced or not), a gain series against a whole cost basis (no market
/// value to draw it from: unpriced).
TotalExclusions totalExclusions(List<ChartSeries> visible, AllSeriesData data) {
  final total = _smartTotal(visible);
  late final incompleteCostBasis = costBasisIncompleteAssetIds(data);
  final unpriced = {...total.unpriced};
  final costBasis = <int>{};
  final accounts = <int>{};
  final adjustments = <int>{};
  for (final s in total.series) {
    final key = parseSeriesKey(s.key);
    if (key == null) continue;
    if (key.type == 'account') {
      if (data.excludedAccountIds.contains(key.id)) accounts.add(key.id);
    } else if (isAdjustmentSeriesKey(s.key)) {
      if (data.excludedAdjustmentIds.contains(key.id)) adjustments.add(key.id);
    } else if (key.type == 'asset_invested' || key.type == 'asset_gain') {
      if (incompleteCostBasis.contains(key.id) || (key.type == 'asset_invested' && s.spots.isEmpty)) {
        costBasis.add(key.id);
      } else if (s.spots.isEmpty) {
        unpriced.add(key.id);
      }
    }
  }
  return TotalExclusions(
    unpricedAssetIds: unpriced,
    costBasisIncompleteAssetIds: costBasis,
    accountIds: accounts,
    adjustmentIds: adjustments,
  );
}

/// Carry-forward total of the [smartTotalSeries] of [visible]: the total a
/// chart card plots and shows in its header, and what the role resolvers read.
List<FlSpot> buildSmartTotalSpots(List<ChartSeries> visible) => buildTotalSpots(smartTotalSeries(visible).map((s) => s.spots).toList());

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
///
/// Every step is in calendar days, never in multiples of 24 hours: on a
/// daylight-saving change a day is 23 or 25 hours long, and 7 × 24 hours
/// before a local midnight is 23:00 of the calendar day before the one meant.
DateTime priceChangeReferenceDate({
  required DateTime today,
  required String unit,
  required int number,
  required int firstDayOfWeekIndex,
}) {
  switch (unit) {
    case 'd':
      return _calendarDaysBefore(today, number);
    case 'w':
      return _calendarDaysBefore(today, number * 7);
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
      return DateTime(today.year, today.month, today.day - daysSinceWeekStart - 1);
    case 'MTD':
      // Day 0 of the month = last day of the previous month, so the base is the
      // previous month's close (anchoring to the 1st made day 1 of the month read 0).
      return DateTime(today.year, today.month, 0);
    case 'YTD':
      // Dec 31 of the previous year, so the base is the prior year's close
      // (anchoring to Jan 1 made the first trading day of the year read 0).
      return DateTime(today.year - 1, 12, 31);
    case 'All':
      return DateTime(2000, 1, 1);
    default:
      return _calendarDaysBefore(today, 1);
  }
}

/// [date] moved back [days] calendar days, at the same time of day.
DateTime _calendarDaysBefore(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day - days, date.hour, date.minute, date.second, date.millisecond, date.microsecond);
