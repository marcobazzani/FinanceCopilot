import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/adjustment_items.dart';
import 'package:finance_copilot/utils/visualization_clock.dart';

/// Resolves the `currency → base` rate for a day key (unix seconds at local
/// midnight); null when no rate is known.
typedef RateLookup = Future<double?> Function(String currency, int dayKey);

/// What a spread saving plan set aside in a period, in base currency: the
/// ledger's "Saving for X" rows of event [eventId], summed.
typedef SavingPlanSpending = ({int eventId, String name, double amount});

/// What one period — a year, or one month of it — spent per category, got
/// back in refunds, moved between the user's own instruments and set aside in
/// spread saving plans, in base currency (positive numbers). Category `null`
/// = uncategorized.
class SpendingPeriod {
  /// (categoryId | null) → total spent.
  final Map<int?, double> byCategory;

  /// (categoryId | null) → ids of the transactions summed into that bucket.
  /// The drill-down lists exactly these rows, so it can never disagree with
  /// the figure it explains.
  final Map<int?, List<int>> idsByCategory;

  /// Refunds received, and the rows behind them.
  final double refunds;
  final List<int> refundIds;

  /// Outflows in transfer-type categories: not spending.
  final double transfersExcluded;

  /// What each spread saving plan set aside, biggest first.
  final List<SavingPlanSpending> savingPlans;

  const SpendingPeriod({
    this.byCategory = const {},
    this.idsByCategory = const {},
    this.refunds = 0,
    this.refundIds = const [],
    this.transfersExcluded = 0,
    this.savingPlans = const [],
  });

  /// A period without any row.
  static const none = SpendingPeriod();

  double get total => byCategory.values.fold(0.0, (a, b) => a + b);

  double amount(int? categoryId) => byCategory[categoryId] ?? 0.0;

  List<int> ids(int? categoryId) => idsByCategory[categoryId] ?? const [];

  double get savingPlansTotal => savingPlans.fold(0.0, (a, p) => a + p.amount);
}

/// Spending per category, per year and per month, in base currency (positive
/// numbers): a [SpendingPeriod] each, the months of a year adding up to it.
///
/// Every outflow is spending except money moved between the user's own
/// instruments: transfer-type categories (transfers, investments) are left
/// out but summed in [SpendingPeriod.transfersExcluded] so the chart can say
/// how much, and rows the ledger explains structurally ([excludedIds]:
/// transfer pairs, no-ops, adjustments, cancelled) are left out entirely.
/// An outflow in an income or reimbursement category is still money that
/// left: it counts, under its category. Rows whose FX rate is unavailable are
/// excluded and counted in [fxExcluded] so the chart can footnote them
/// instead of silently mis-summing.
///
/// Refunds received — inflows in a reimbursement or expense category (money
/// coming back for something spent) — are summed in
/// [SpendingPeriod.refunds]: spending is gross, so a chart that compares it
/// with net figures needs them as their own term, never folded in silently.
/// Uncategorized inflows are not refunds: what they are is unknown.
///
/// Spread saving plans — the ledger's synthetic "Saving for X" rows, the
/// scheduled steps of a spread no transaction accounts for — are spending
/// too, summed per plan in [SpendingPeriod.savingPlans]. They are no
/// transactions, so they have no category and are not in
/// [SpendingPeriod.byCategory].
class SpendingByCategoryData {
  /// Years with spending, ascending.
  final List<int> years;
  final int currentYear;
  final int fxExcluded;
  final String baseCurrency;

  /// year → what it spent.
  final Map<int, SpendingPeriod> yearly;

  /// (year, month) → what that month spent.
  final Map<(int, int), SpendingPeriod> monthly;

  const SpendingByCategoryData({
    required this.years,
    required this.currentYear,
    required this.fxExcluded,
    required this.baseCurrency,
    this.yearly = const {},
    this.monthly = const {},
  });

  /// What [year] spent — or its [month] (1–12), when given.
  SpendingPeriod period(int year, [int? month]) => (month == null ? yearly[year] : monthly[(year, month)]) ?? SpendingPeriod.none;

  double transfersExcluded(int year) => period(year).transfersExcluded;

  double refunds(int year) => period(year).refunds;
  List<int> refundIds(int year) => period(year).refundIds;

  List<SavingPlanSpending> savingPlans(int year) => period(year).savingPlans;
  double savingPlansTotal(int year) => period(year).savingPlansTotal;

  bool get isEmpty => yearly.values.every((p) => p.byCategory.isEmpty);

  double totalFor(int year) => period(year).total;

  double amount(int year, int? categoryId) => period(year).amount(categoryId);

  List<int> ids(int year, int? categoryId) => period(year).ids(categoryId);

  /// Share of the year's spending (0..1); 0 when the year has no spending.
  double share(int year, int? categoryId) {
    final t = totalFor(year);
    return t == 0 ? 0.0 : amount(year, categoryId) / t;
  }

  /// Category ids (null included) ordered by all-years total, descending.
  List<int?> categoriesByTotal() {
    final totals = <int?, double>{};
    for (final p in yearly.values) {
      for (final e in p.byCategory.entries) {
        totals[e.key] = (totals[e.key] ?? 0) + e.value;
      }
    }
    final keys = totals.keys.toList()
      ..sort((a, b) {
        final c = totals[b]!.compareTo(totals[a]!);
        if (c != 0) return c;
        // Stable: uncategorized last among ties, then by id.
        if (a == null) return 1;
        if (b == null) return -1;
        return a.compareTo(b);
      });
    return keys;
  }
}

/// True when an outflow in a category of [type] counts as spending: every
/// type except transfers (own-money moves).
bool isSpendingCategoryType(CategoryType? type) => type != CategoryType.transfer;

/// True when an inflow in a category of [type] is money coming back for
/// something spent.
bool isRefundCategoryType(CategoryType? type) => type == CategoryType.reimbursement || type == CategoryType.expense;

/// The running sums of one period while the rows are read.
class _PeriodSums {
  final byCategory = <int?, double>{};
  final ids = <int?, List<int>>{};
  var refunds = 0.0;
  final refundIds = <int>[];
  var transfers = 0.0;
  final plans = <int, SavingPlanSpending>{};

  SpendingPeriod build() => SpendingPeriod(
    byCategory: byCategory,
    idsByCategory: ids,
    refunds: refunds,
    refundIds: refundIds,
    transfersExcluded: transfers,
    savingPlans: plans.values.toList()
      ..sort((a, b) {
        final c = b.amount.compareTo(a.amount);
        return c != 0 ? c : a.eventId.compareTo(b.eventId);
      }),
  );
}

/// [savingItems] are the ledger's "Saving for X" rows (see
/// [SavingScheduleItem]): a negative one — a spread outflow setting money
/// aside — is spending, like any outflow; a positive one brings money in
/// and, like an uncategorized inflow, is not.
Future<SpendingByCategoryData> aggregateSpendingByCategory({
  required List<Transaction> transactions,
  required Map<int, Category> categories,
  required RateLookup rate,
  required String baseCurrency,
  required DateTime now,
  DateTime? through,
  Set<int> excludedIds = const {},
  List<SavingScheduleItem> savingItems = const [],
}) async {
  final years = <int, _PeriodSums>{};
  final months = <(int, int), _PeriodSums>{};
  // A row counts in its year and in its month (of its value date).
  List<_PeriodSums> periodsOf(DateTime d) => [
    years.putIfAbsent(d.year, _PeriodSums.new),
    months.putIfAbsent((d.year, d.month), _PeriodSums.new),
  ];
  var fxExcluded = 0;
  // Every row of the as-of day counts, whatever its clock time: the bound is
  // the next midnight, as for the ledger's own as-of reads.
  final endExclusive = throughEndExclusive(through);
  bool afterCutoff(DateTime d) => endExclusive != null && !d.isBefore(endExclusive);
  // The rate from [currency] to base on [d]'s calendar day; null when none.
  Future<double?> rateOn(String currency, DateTime d) async {
    if (currency == baseCurrency) return 1.0;
    return rate(currency, DateTime(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 1000);
  }

  for (final t in transactions) {
    if (t.amount == 0 || t.status == TransactionStatus.cancelled || excludedIds.contains(t.id)) continue;
    if (afterCutoff(t.valueDate)) continue;
    final cat = t.categoryId == null ? null : categories[t.categoryId];
    if (t.amount > 0 && !isRefundCategoryType(cat?.type)) continue;
    // A row pointing at a deleted category is treated as uncategorized.
    final catId = cat?.id;
    final r = await rateOn(t.currency, t.valueDate);
    if (r == null) {
      fxExcluded++;
      continue;
    }
    for (final p in periodsOf(t.valueDate)) {
      if (t.amount > 0) {
        p.refunds += t.amount * r;
        p.refundIds.add(t.id);
      } else if (!isSpendingCategoryType(cat?.type)) {
        p.transfers += t.amount.abs() * r;
      } else {
        p.byCategory[catId] = (p.byCategory[catId] ?? 0) + t.amount.abs() * r;
        (p.ids[catId] ??= []).add(t.id);
      }
    }
  }
  for (final item in savingItems) {
    if (item.amount >= 0 || afterCutoff(item.date)) continue;
    final r = await rateOn(item.currency, item.date);
    if (r == null) {
      fxExcluded++;
      continue;
    }
    for (final p in periodsOf(item.date)) {
      p.plans[item.eventId] = (
        eventId: item.eventId,
        name: item.eventName,
        amount: (p.plans[item.eventId]?.amount ?? 0) + item.amount.abs() * r,
      );
    }
  }
  return SpendingByCategoryData(
    years: [
      for (final e in years.entries)
        if (e.value.byCategory.isNotEmpty) e.key,
    ]..sort(),
    currentYear: now.year,
    yearly: {for (final e in years.entries) e.key: e.value.build()},
    monthly: {for (final e in months.entries) e.key: e.value.build()},
    fxExcluded: fxExcluded,
    baseCurrency: baseCurrency,
  );
}
