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
  final List<ChartSeries> accounts;      // key: "account:<id>"
  final List<ChartSeries> assetInvested; // key: "asset_invested:<id>"
  final List<ChartSeries> assetMarket;   // key: "asset_market:<id>"
  final List<ChartSeries> assetGain;     // key: "asset_gain:<id>"  (market - invested)
  final List<ChartSeries> adjustments;      // key: "adjustment:<id>"
  final List<ChartSeries> incomeAdjustments; // key: "income_adj:<id>"
  final String baseCurrency;

  const AllSeriesData({
    required this.firstDate,
    required this.accounts,
    required this.assetInvested,
    required this.assetMarket,
    required this.assetGain,
    required this.adjustments,
    required this.incomeAdjustments,
    required this.baseCurrency,
  });

  List<ChartSeries> get allSeries => [...accounts, ...assetInvested, ...assetMarket, ...assetGain, ...adjustments, ...incomeAdjustments];
}

// ════════════════════════════════════════════════════
// Income/Expense data models
// ════════════════════════════════════════════════════

class _MonthBucket {
  final int year, month;
  final double income, navChange;
  double get expenses    => income - navChange;
  double get savings     => navChange;
  double get savingsRate => income > 0 ? navChange / income : 0;
  const _MonthBucket({required this.year, required this.month,
                      required this.income, required this.navChange});
}

class _YearBucket {
  final int year, days;
  final double income, navChange;
  final List<_MonthBucket> months;

  double get expenses        => income - navChange;
  double get savings         => navChange;
  double get savingsRate     => income > 0 ? navChange / income : 0;
  double get dailyIncome     => days > 0 ? income / days : 0;
  double get dailyExpenses   => days > 0 ? expenses / days : 0;
  double get monthlyIncome   => days > 0 ? income / days * 30.4 : 0;
  double get monthlyExpenses => days > 0 ? expenses / days * 30.4 : 0;

  const _YearBucket({required this.year, required this.days,
                     required this.income, required this.navChange,
                     required this.months});
}

class _IncomeExpenseData {
  final List<_YearBucket> years;
  final String baseCurrency;
  final DateTime firstDate;
  const _IncomeExpenseData({required this.years, required this.baseCurrency,
                            required this.firstDate});
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
int toDayKey(DateTime dt) =>
    DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch ~/ 1000;

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
