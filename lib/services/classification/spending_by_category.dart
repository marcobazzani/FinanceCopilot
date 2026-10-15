import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/adjustment_items.dart';
import 'package:finance_copilot/utils/visualization_clock.dart';

/// Resolves the `currency → base` rate for a day key (unix seconds at local
/// midnight); null when no rate is known.
typedef RateLookup = Future<double?> Function(String currency, int dayKey);

/// What a spread saving plan set aside in a year, in base currency: the
/// ledger's "Saving for X" rows of event [eventId], summed.
typedef SavingPlanSpending = ({int eventId, String name, double amount});

/// Spending per year per category, in base currency (positive numbers).
///
/// Every outflow is spending except money moved between the user's own
/// instruments: transfer-type categories (transfers, investments) are left
/// out but summed per year in [transfersExcludedByYear] so the chart can say
/// how much, and rows the ledger explains structurally ([excludedIds]:
/// transfer pairs, no-ops, adjustments, cancelled) are left out entirely.
/// An outflow in an income or reimbursement category is still money that
/// left: it counts, under its category. Category `null` = uncategorized.
/// Rows whose FX rate is unavailable are excluded and counted in
/// [fxExcluded] so the chart can footnote them instead of silently
/// mis-summing.
///
/// Refunds received — inflows in a reimbursement or expense category (money
/// coming back for something spent) — are summed per year in
/// [refundsByYear]: spending above is gross, so a chart that compares it
/// with net figures needs them as their own term, never folded in silently.
/// Uncategorized inflows are not refunds: what they are is unknown.
///
/// Spread saving plans — the ledger's synthetic "Saving for X" rows, the
/// scheduled steps of a spread no transaction accounts for — are spending
/// too, summed per year and plan in [savingPlansByYear]. They are no
/// transactions, so they have no category and are not in [byYear].
class SpendingByCategoryData {
  /// Years ascending.
  final List<int> years;
  final int currentYear;

  /// year → (categoryId | null) → total.
  final Map<int, Map<int?, double>> byYear;

  /// year → (categoryId | null) → ids of the transactions summed into that
  /// bucket. The drill-down lists exactly these rows, so it can never
  /// disagree with the figure it explains.
  final Map<int, Map<int?, List<int>>> idsByYear;
  final int fxExcluded;
  final String baseCurrency;

  /// year → outflows in transfer-type categories (not spending), base currency.
  final Map<int, double> transfersExcludedByYear;

  const SpendingByCategoryData({
    required this.years,
    required this.currentYear,
    required this.byYear,
    required this.fxExcluded,
    required this.baseCurrency,
    this.idsByYear = const {},
    this.transfersExcludedByYear = const {},
    this.refundsByYear = const {},
    this.refundIdsByYear = const {},
    this.savingPlansByYear = const {},
  });

  double transfersExcluded(int year) => transfersExcludedByYear[year] ?? 0.0;

  /// year → refunds received (base currency) and the rows behind them.
  final Map<int, double> refundsByYear;
  final Map<int, List<int>> refundIdsByYear;

  double refunds(int year) => refundsByYear[year] ?? 0.0;
  List<int> refundIds(int year) => refundIdsByYear[year] ?? const [];

  /// year → what each spread saving plan set aside in it (positive, base
  /// currency), biggest first.
  final Map<int, List<SavingPlanSpending>> savingPlansByYear;

  List<SavingPlanSpending> savingPlans(int year) => savingPlansByYear[year] ?? const [];
  double savingPlansTotal(int year) => savingPlans(year).fold(0.0, (a, p) => a + p.amount);

  bool get isEmpty => byYear.values.every((m) => m.isEmpty);

  double totalFor(int year) => (byYear[year] ?? const {}).values.fold(0.0, (a, b) => a + b);

  double amount(int year, int? categoryId) => byYear[year]?[categoryId] ?? 0.0;

  List<int> ids(int year, int? categoryId) => idsByYear[year]?[categoryId] ?? const [];

  /// Share of the year's spending (0..1); 0 when the year has no spending.
  double share(int year, int? categoryId) {
    final t = totalFor(year);
    return t == 0 ? 0.0 : amount(year, categoryId) / t;
  }

  /// Category ids (null included) ordered by all-years total, descending.
  List<int?> categoriesByTotal() {
    final totals = <int?, double>{};
    for (final m in byYear.values) {
      for (final e in m.entries) {
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
  final byYear = <int, Map<int?, double>>{};
  final idsByYear = <int, Map<int?, List<int>>>{};
  var fxExcluded = 0;
  final transfers = <int, double>{};
  final refunds = <int, double>{};
  final refundIds = <int, List<int>>{};
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
    final d = t.valueDate;
    final r = await rateOn(t.currency, d);
    if (r == null) {
      fxExcluded++;
      continue;
    }
    if (t.amount > 0) {
      refunds[d.year] = (refunds[d.year] ?? 0) + t.amount * r;
      (refundIds[d.year] ??= []).add(t.id);
      continue;
    }
    if (!isSpendingCategoryType(cat?.type)) {
      transfers[d.year] = (transfers[d.year] ?? 0) + t.amount.abs() * r;
      continue;
    }
    final m = byYear.putIfAbsent(d.year, () => <int?, double>{});
    m[catId] = (m[catId] ?? 0) + t.amount.abs() * r;
    (idsByYear.putIfAbsent(d.year, () => <int?, List<int>>{})[catId] ??= []).add(t.id);
  }
  // year → event id → what the plan set aside.
  final plans = <int, Map<int, SavingPlanSpending>>{};
  for (final item in savingItems) {
    if (item.amount >= 0 || afterCutoff(item.date)) continue;
    final r = await rateOn(item.currency, item.date);
    if (r == null) {
      fxExcluded++;
      continue;
    }
    final m = plans.putIfAbsent(item.date.year, () => {});
    m[item.eventId] = (eventId: item.eventId, name: item.eventName, amount: (m[item.eventId]?.amount ?? 0) + item.amount.abs() * r);
  }
  final years = byYear.keys.toList()..sort();
  return SpendingByCategoryData(
    years: years,
    currentYear: now.year,
    byYear: byYear,
    idsByYear: idsByYear,
    transfersExcludedByYear: transfers,
    refundsByYear: refunds,
    refundIdsByYear: refundIds,
    savingPlansByYear: {
      for (final e in plans.entries)
        e.key: e.value.values.toList()
          ..sort((a, b) {
            final c = b.amount.compareTo(a.amount);
            return c != 0 ? c : a.eventId.compareTo(b.eventId);
          }),
    },
    fxExcluded: fxExcluded,
    baseCurrency: baseCurrency,
  );
}
