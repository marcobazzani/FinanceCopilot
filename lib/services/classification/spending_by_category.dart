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

/// What one merchant took in a period: the spending rows with its merchant
/// key, in base currency (positive).
class MerchantSpending {
  /// The stable merchant key its rows share.
  final String key;

  /// The merchant as the statement names it.
  final String name;
  final double amount;

  /// The rows summed into [amount].
  final List<int> ids;

  /// What its rows are categorized as: category → amount (null =
  /// uncategorized).
  final Map<int?, double> byCategory;

  const MerchantSpending({required this.key, required this.name, required this.amount, required this.ids, required this.byCategory});

  /// The category holding most of its spending; null when that is
  /// uncategorized.
  int? get mainCategory {
    int? best;
    var most = double.negativeInfinity;
    for (final MapEntry(:key, :value) in byCategory.entries) {
      if (value > most) {
        best = key;
        most = value;
      }
    }
    return best;
  }
}

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

  /// Merchant key → what was spent with that merchant: the rows of
  /// [byCategory] that carry a merchant key, cash withdrawals left out (the
  /// ledger cannot say where cash was spent).
  final Map<String, MerchantSpending> merchants;

  const SpendingPeriod({
    this.byCategory = const {},
    this.idsByCategory = const {},
    this.refunds = 0,
    this.refundIds = const [],
    this.transfersExcluded = 0,
    this.savingPlans = const [],
    this.merchants = const {},
  });

  /// A period without any row.
  static const none = SpendingPeriod();

  double get total => byCategory.values.fold(0.0, (a, b) => a + b);

  double amount(int? categoryId) => byCategory[categoryId] ?? 0.0;

  List<int> ids(int? categoryId) => idsByCategory[categoryId] ?? const [];

  double get savingPlansTotal => savingPlans.fold(0.0, (a, p) => a + p.amount);

  /// The [limit] merchants paid most, biggest first.
  List<MerchantSpending> topMerchants(int limit) {
    final all = merchants.values.toList()
      ..sort((a, b) {
        final c = b.amount.compareTo(a.amount);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    return all.take(limit).toList();
  }
}

/// One row counted as spending, in base currency (positive): a transaction
/// ([id]) of an account ([accountId]), or a step of a spread saving plan
/// ([plan], no transaction, no account). [currency] is the one the row was
/// spent in: the transaction's, or the plan's. Rows without a merchant key,
/// and cash withdrawals, have no merchant.
typedef SpendingEntry = ({
  DateTime day,
  double amount,
  int? id,
  int? categoryId,
  String? merchantKey,
  String? merchantName,
  ({int eventId, String name})? plan,
  int? accountId,
  String currency,
});

/// Spending per category, per year and per month, in base currency (positive
/// numbers): a [SpendingPeriod] each, the months of a year adding up to it;
/// and every spending row on its day ([entries]), so any run of days adds up
/// the same way.
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

  /// The spending rows, by day.
  final List<SpendingEntry> entries;

  /// The refunds received (inflows in a reimbursement or expense category),
  /// by day, in base currency (positive).
  final List<({DateTime day, double amount, int id})> refundEntries;

  const SpendingByCategoryData({
    required this.years,
    required this.currentYear,
    required this.fxExcluded,
    required this.baseCurrency,
    this.yearly = const {},
    this.monthly = const {},
    this.entries = const [],
    this.refundEntries = const [],
  });

  /// The refunds received from [from] to [to], both included.
  double refundsBetween(DateTime from, DateTime to) =>
      refundEntries.where((e) => !e.day.isBefore(from) && !e.day.isAfter(to)).fold(0.0, (a, e) => a + e.amount);

  /// Where the entries of [day] start.
  int _firstOn(DateTime day) {
    var lo = 0, hi = entries.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (entries[mid].day.isBefore(day)) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// The entries of the days [from] to [to], both included.
  Iterable<SpendingEntry> entriesBetween(DateTime from, DateTime to) sync* {
    for (var i = _firstOn(from); i < entries.length && !entries[i].day.isAfter(to); i++) {
      yield entries[i];
    }
  }

  /// What the days [from] to [to] spent, in all, or on the rows [where] picks.
  double spentBetween(DateTime from, DateTime to, {bool Function(SpendingEntry)? where}) =>
      entriesBetween(from, to).where(where ?? (_) => true).fold(0.0, (a, e) => a + e.amount);

  /// What the days [from] to [to] spent, per category, merchant and saving
  /// plan: the same sums as a month's, over any run of days.
  SpendingPeriod sumOfDays(DateTime from, DateTime to) {
    final sums = _PeriodSums();
    for (final e in entriesBetween(from, to)) {
      if (e.plan case final plan?) {
        sums.plans[plan.eventId] = (eventId: plan.eventId, name: plan.name, amount: (sums.plans[plan.eventId]?.amount ?? 0) + e.amount);
        continue;
      }
      sums.byCategory[e.categoryId] = (sums.byCategory[e.categoryId] ?? 0) + e.amount;
      (sums.ids[e.categoryId] ??= []).add(e.id!);
      if (e.merchantKey case final key?) {
        sums.merchants.putIfAbsent(key, () => _MerchantSums(key, e.merchantName ?? key)).add(e.amount, e.categoryId, e.id!, e.merchantName);
      }
    }
    return sums.build();
  }

  /// What the days [from] to [to] spent as a running total — the total at
  /// the end of each day, one figure a day — of all rows, or of those [where]
  /// picks.
  List<double> runningBetween(DateTime from, DateTime to, {bool Function(SpendingEntry)? where}) {
    final out = <double>[];
    var sum = 0.0;
    var i = _firstOn(from);
    for (var day = from; !day.isAfter(to); day = DateTime(day.year, day.month, day.day + 1)) {
      while (i < entries.length && !entries[i].day.isAfter(day)) {
        final e = entries[i++];
        if (where == null || where(e)) sum += e.amount;
      }
      out.add(sum);
    }
    return out;
  }

  /// What [year] spent — or its [month] (1–12), when given.
  SpendingPeriod period(int year, [int? month]) => (month == null ? yearly[year] : monthly[(year, month)]) ?? SpendingPeriod.none;

  /// What the [months] ((year, month) pairs) spent, summed into one period.
  /// A month in [shares] counts for that share of it (5/30 of it when set
  /// against a month still in progress); every other month counts whole.
  SpendingPeriod sumOfMonths(Iterable<(int, int)> months, {Map<(int, int), double> shares = const {}}) {
    final byCategory = <int?, double>{};
    final ids = <int?, List<int>>{};
    var refunds = 0.0;
    final refundIds = <int>[];
    var transfers = 0.0;
    final plans = <int, SavingPlanSpending>{};
    final merchants = <String, _MerchantSums>{};
    for (final (y, m) in months) {
      final p = period(y, m);
      final share = shares[(y, m)] ?? 1;
      p.byCategory.forEach((k, v) => byCategory[k] = (byCategory[k] ?? 0) + v * share);
      p.idsByCategory.forEach((k, v) => (ids[k] ??= []).addAll(v));
      refunds += p.refunds * share;
      refundIds.addAll(p.refundIds);
      transfers += p.transfersExcluded * share;
      for (final plan in p.savingPlans) {
        final sum = plans[plan.eventId]?.amount ?? 0;
        plans[plan.eventId] = (eventId: plan.eventId, name: plan.name, amount: sum + plan.amount * share);
      }
      for (final merchant in p.merchants.values) {
        merchants.putIfAbsent(merchant.key, () => _MerchantSums(merchant.key, merchant.name)).merge(merchant, share);
      }
    }
    return SpendingPeriod(
      byCategory: byCategory,
      idsByCategory: ids,
      refunds: refunds,
      refundIds: refundIds,
      transfersExcluded: transfers,
      savingPlans: plans.values.toList()..sort((a, b) => b.amount.compareTo(a.amount)),
      merchants: {for (final e in merchants.entries) e.key: e.value.build()},
    );
  }

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

/// The running sums of one merchant while the rows are read.
class _MerchantSums {
  final String key;
  String name;
  var amount = 0.0;
  final ids = <int>[];
  final byCategory = <int?, double>{};
  _MerchantSums(this.key, this.name);

  void add(double value, int? categoryId, int id, String? counterparty) {
    amount += value;
    ids.add(id);
    byCategory[categoryId] = (byCategory[categoryId] ?? 0) + value;
    // The key stands in for the name only until a row names the merchant.
    if (name == key && counterparty != null && counterparty.isNotEmpty) name = counterparty;
  }

  void merge(MerchantSpending m, double share) {
    amount += m.amount * share;
    ids.addAll(m.ids);
    m.byCategory.forEach((k, v) => byCategory[k] = (byCategory[k] ?? 0) + v * share);
  }

  MerchantSpending build() => MerchantSpending(key: key, name: name, amount: amount, ids: ids, byCategory: byCategory);
}

/// The running sums of one period while the rows are read.
class _PeriodSums {
  final byCategory = <int?, double>{};
  final ids = <int?, List<int>>{};
  var refunds = 0.0;
  final refundIds = <int>[];
  var transfers = 0.0;
  final plans = <int, SavingPlanSpending>{};
  final merchants = <String, _MerchantSums>{};

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
    merchants: {for (final e in merchants.entries) e.key: e.value.build()},
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
  final entries = <SpendingEntry>[];
  final refundEntries = <({DateTime day, double amount, int id})>[];
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
        final value = t.amount.abs() * r;
        p.byCategory[catId] = (p.byCategory[catId] ?? 0) + value;
        (p.ids[catId] ??= []).add(t.id);
        final key = t.merchantKey;
        if (key != null && key.isNotEmpty && t.entryKind != BankEntryKind.atmWithdrawal) {
          p.merchants.putIfAbsent(key, () => _MerchantSums(key, t.counterparty ?? key)).add(value, catId, t.id, t.counterparty);
        }
      }
    }
    if (t.amount > 0) {
      refundEntries.add((day: DateTime(t.valueDate.year, t.valueDate.month, t.valueDate.day), amount: t.amount * r, id: t.id));
    }
    if (t.amount < 0 && isSpendingCategoryType(cat?.type)) {
      final key = t.merchantKey;
      final merchant = key != null && key.isNotEmpty && t.entryKind != BankEntryKind.atmWithdrawal;
      entries.add((
        day: DateTime(t.valueDate.year, t.valueDate.month, t.valueDate.day),
        amount: t.amount.abs() * r,
        id: t.id,
        categoryId: catId,
        merchantKey: merchant ? key : null,
        merchantName: merchant ? t.counterparty : null,
        plan: null,
        accountId: t.accountId,
        currency: t.currency,
      ));
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
    entries.add((
      day: DateTime(item.date.year, item.date.month, item.date.day),
      amount: item.amount.abs() * r,
      id: null,
      categoryId: null,
      merchantKey: null,
      merchantName: null,
      plan: (eventId: item.eventId, name: item.eventName),
      accountId: null,
      currency: item.currency,
    ));
  }
  entries.sort((a, b) => a.day.compareTo(b.day));
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
    entries: entries,
    refundEntries: refundEntries..sort((a, b) => a.day.compareTo(b.day)),
  );
}
