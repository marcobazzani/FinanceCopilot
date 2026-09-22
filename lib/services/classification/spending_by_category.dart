import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';

/// Resolves the `currency → base` rate for a day key (unix seconds at local
/// midnight); null when no rate is known.
typedef RateLookup = Future<double?> Function(String currency, int dayKey);

/// Spending per year per category, in base currency (positive numbers).
///
/// Category `null` = uncategorized. Transfer-type categories (transfers,
/// investments) and income/reimbursement-type categories are excluded —
/// they are not spending — and so are rows the ledger explains structurally
/// ([excludedIds]: transfer pairs, no-ops, adjustments, cancelled). Rows whose
/// FX rate is unavailable are excluded and counted in [fxExcluded] so the
/// chart can footnote them instead of silently mis-summing.
class SpendingByCategoryData {
  /// Years ascending.
  final List<int> years;
  final int currentYear;

  /// year → (categoryId | null) → total.
  final Map<int, Map<int?, double>> byYear;
  final int fxExcluded;
  final String baseCurrency;

  const SpendingByCategoryData({
    required this.years,
    required this.currentYear,
    required this.byYear,
    required this.fxExcluded,
    required this.baseCurrency,
  });

  bool get isEmpty => byYear.values.every((m) => m.isEmpty);

  double totalFor(int year) => (byYear[year] ?? const {}).values.fold(0.0, (a, b) => a + b);

  double amount(int year, int? categoryId) => byYear[year]?[categoryId] ?? 0.0;

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

/// True when [type] counts as spending for the chart.
bool isSpendingCategoryType(CategoryType? type) => type == null || type == CategoryType.expense;

Future<SpendingByCategoryData> aggregateSpendingByCategory({
  required List<Transaction> transactions,
  required Map<int, Category> categories,
  required RateLookup rate,
  required String baseCurrency,
  required DateTime now,
  DateTime? through,
  Set<int> excludedIds = const {},
}) async {
  final byYear = <int, Map<int?, double>>{};
  var fxExcluded = 0;
  for (final t in transactions) {
    if (t.amount >= 0 || t.status == TransactionStatus.cancelled || excludedIds.contains(t.id)) continue;
    if (through != null && t.valueDate.isAfter(through)) continue;
    final cat = t.categoryId == null ? null : categories[t.categoryId];
    // A row pointing at a deleted category is treated as uncategorized.
    final catId = cat?.id;
    if (!isSpendingCategoryType(cat?.type)) continue;

    final d = t.valueDate;
    final dayKey = DateTime(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 1000;
    final r = t.currency == baseCurrency ? 1.0 : await rate(t.currency, dayKey);
    if (r == null) {
      fxExcluded++;
      continue;
    }
    final m = byYear.putIfAbsent(d.year, () => <int?, double>{});
    m[catId] = (m[catId] ?? 0) + t.amount.abs() * r;
  }
  final years = byYear.keys.toList()..sort();
  return SpendingByCategoryData(
    years: years,
    currentYear: now.year,
    byYear: byYear,
    fxExcluded: fxExcluded,
    baseCurrency: baseCurrency,
  );
}
