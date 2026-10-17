import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/utils/chart_math.dart' as chart_math;
import 'package:finance_copilot/utils/logger.dart';

final _log = getLogger('CashFlowExplanation');

/// The Cash Flow figure being explained.
enum CashFlowField { income, savings, expenses }

/// What a series of the Saving total stands for.
enum ExplainSeriesKind { account, investment, adjustment }

/// One series of the Saving total, as the dashboard drew it: [spots] are
/// (day offset from the first date of the data, value in base currency). The
/// value is carried forward from the last point, and is 0 before the first.
class ExplainSeries {
  final ExplainSeriesKind kind;

  /// The account id for an account; the asset or adjustment id otherwise.
  final int id;
  final String name;

  /// The account's currency (accounts only).
  final String? currency;
  final List<(double, double)> spots;
  const ExplainSeries({required this.kind, required this.id, required this.name, this.currency, required this.spots});
}

/// An income or pension-contribution record ([id] = its `incomes` row), its
/// amount already in base currency.
typedef ExplainRecord = ({int id, DateTime date, double amount});

enum ExplainSectionKind {
  /// The income records of the period.
  incomeRecords,

  /// The transactions that moved the saving accounts' balances, by category.
  accountTransactions,

  /// The balance an account already had when it entered the total.
  accountOpening,

  /// The change in what was invested.
  investments,

  /// Extraordinary events (adjustments).
  adjustments,

  /// Pension contributions: they raise a fund, never the user's bank balance.
  pensionContributions,

  /// What the rows above do not explain (exchange rates, a row that cannot be
  /// converted): shown, never absorbed into another row.
  unexplained,
}

enum ExplainLineKind { record, typeGroup, category, uncategorized, account, series, pension, unexplained }

class ExplainLine {
  final ExplainLineKind kind;

  /// A record's date.
  final DateTime? date;

  /// The name of an account or series.
  final String label;
  final CategoryType? categoryType;
  final int? categoryId;
  final int count;
  final double amount;

  /// The categories of a type row; they add up to its [amount].
  final List<ExplainLine> children;

  /// What the row is made of, for the drill-down: the transactions summed
  /// into it (a type row: those of its categories; an account row: its first
  /// row, whose balance shows what was already there), the income records
  /// (an income or pension row), or the series it was read from (an
  /// investment, adjustment, account-opening or unexplained row) with its
  /// value at the start and at the end of the period.
  final List<int> transactionIds;
  final List<int> recordIds;
  final ExplainSeriesKind? seriesKind;
  final int? seriesId;
  final double? valueFrom, valueTo;
  const ExplainLine({
    required this.kind,
    this.date,
    this.label = '',
    this.categoryType,
    this.categoryId,
    this.count = 0,
    required this.amount,
    this.children = const [],
    this.transactionIds = const [],
    this.recordIds = const [],
    this.seriesKind,
    this.seriesId,
    this.valueFrom,
    this.valueTo,
  });
}

class ExplainSection {
  final ExplainSectionKind kind;
  final List<ExplainLine> lines;
  const ExplainSection(this.kind, this.lines);
  double get amount => lines.fold(0.0, (s, l) => s + l.amount);
}

/// The rows that add up to one Cash Flow figure.
class CashFlowExplanation {
  final CashFlowField field;
  final int year;

  /// Null for a year.
  final int? month;
  final List<ExplainSection> sections;
  const CashFlowExplanation({required this.field, required this.year, this.month, required this.sections});

  double get total => sections.fold(0.0, (s, sec) => s + sec.amount);
}

// Below half a cent a difference is rounding, not something to show.
const _eps = 0.005;

double _carried(List<(double, double)> spots, double x) {
  var v = 0.0;
  for (final s in spots) {
    if (s.$1 <= x) {
      v = s.$2;
    } else {
      break;
    }
  }
  return v;
}

/// The rows that add up to one Cash Flow figure of [year] (and [month], a
/// whole year when null), from the same inputs the figure is made of.
///
/// - Income: the income records dated in the period.
/// - Savings: how much the Saving total ([series]) grew from [periodFrom]
///   (exclusive) to [periodTo], minus the pension contributions. Each series
///   is carried forward from its last point and is 0 before its first, and
///   the total is measured from its first point: a period that starts before
///   anything is tracked starts there. An account's growth is split into the
///   transactions that moved its balance (by category type, then category);
///   an investment's or adjustment's is its own row.
/// - Expenses: Income − Savings, so every savings row appears with its sign
///   turned round.
///
/// [rate] converts an account's currency to [baseCurrency] on a day (epoch
/// seconds at local midnight); a transaction it cannot convert is left out of
/// the rows and ends up in the unexplained row, never converted 1:1.
Future<CashFlowExplanation> explainCashFlowCell({
  required CashFlowField field,
  required int year,
  int? month,
  required DateTime firstDate,
  required DateTime periodFrom,
  required DateTime periodTo,
  required String baseCurrency,
  required List<ExplainSeries> series,
  required List<Transaction> transactions,
  required Map<int, Category> categories,
  required List<ExplainRecord> income,
  required List<ExplainRecord> pension,
  required Future<double?> Function(String currency, int dayKey) rate,
}) async {
  bool inPeriod(DateTime d) => d.year == year && (month == null || d.month == month);

  final sections = <ExplainSection>[];

  ExplainSection incomeSection() {
    final records = income.where((r) => inPeriod(r.date)).toList()..sort((a, b) => a.date.compareTo(b.date));
    return ExplainSection(ExplainSectionKind.incomeRecords, [
      for (final r in records) ExplainLine(kind: ExplainLineKind.record, date: r.date, count: 1, amount: r.amount, recordIds: [r.id]),
    ]);
  }

  if (field == CashFlowField.income) {
    return CashFlowExplanation(field: field, year: year, month: month, sections: [incomeSection()]);
  }

  final savings = await _savingsSections(
    year: year,
    firstDate: firstDate,
    periodFrom: periodFrom,
    periodTo: periodTo,
    series: series,
    transactions: transactions,
    categories: categories,
    pension: pension.where((r) => inPeriod(r.date)).toList(),
    rate: rate,
  );

  if (field == CashFlowField.savings) {
    sections.addAll(savings);
  } else {
    sections.add(incomeSection());
    for (final s in savings) {
      sections.add(_negated(s));
    }
  }
  return CashFlowExplanation(field: field, year: year, month: month, sections: sections);
}

ExplainSection _negated(ExplainSection s) => ExplainSection(s.kind, [for (final l in s.lines) _negatedLine(l)]);

ExplainLine _negatedLine(ExplainLine l) => ExplainLine(
  kind: l.kind,
  date: l.date,
  label: l.label,
  categoryType: l.categoryType,
  categoryId: l.categoryId,
  count: l.count,
  amount: -l.amount,
  children: [for (final c in l.children) _negatedLine(c)],
  transactionIds: l.transactionIds,
  recordIds: l.recordIds,
  seriesKind: l.seriesKind,
  seriesId: l.seriesId,
  valueFrom: l.valueFrom,
  valueTo: l.valueTo,
);

Future<List<ExplainSection>> _savingsSections({
  required int year,
  required DateTime firstDate,
  required DateTime periodFrom,
  required DateTime periodTo,
  required List<ExplainSeries> series,
  required List<Transaction> transactions,
  required Map<int, Category> categories,
  required List<ExplainRecord> pension,
  required Future<double?> Function(String currency, int dayKey) rate,
}) async {
  // The total starts at its first point: before it, nothing is measured.
  double? x0;
  for (final s in series) {
    for (final p in s.spots) {
      if (x0 == null || p.$1 < x0) x0 = p.$1;
    }
  }

  final byAccount = <int, List<Transaction>>{};
  for (final t in transactions) {
    if (t.balanceAfter != null) (byAccount[t.accountId] ??= []).add(t);
  }
  for (final rows in byAccount.values) {
    rows.sort((a, b) {
      final c = a.valueDate.compareTo(b.valueDate);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  }

  double dayX(DateTime d) => chart_math.calendarDaysBetween(firstDate, d).toDouble();
  int dayKey(DateTime d) => DateTime(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 1000;

  // type → category → (ids, amount); null type = uncategorized.
  final groups = <CategoryType?, Map<int?, (List<int>, double)>>{};
  final opening = <ExplainLine>[];
  final investments = <ExplainLine>[];
  final adjustments = <ExplainLine>[];
  final unexplained = <ExplainLine>[];

  if (x0 != null) {
    final w0 = dayX(periodFrom) < x0 ? x0 : dayX(periodFrom);
    final w1 = dayX(periodTo) < x0 ? x0 : dayX(periodTo);

    for (final s in series) {
      final v0 = _carried(s.spots, w0);
      final v1 = _carried(s.spots, w1);
      final delta = v1 - v0;
      if (s.kind != ExplainSeriesKind.account) {
        if (delta.abs() >= _eps) {
          final line = ExplainLine(
            kind: ExplainLineKind.series,
            label: s.name,
            count: 1,
            amount: delta,
            seriesKind: s.kind,
            seriesId: s.id,
            valueFrom: v0,
            valueTo: v1,
          );
          (s.kind == ExplainSeriesKind.investment ? investments : adjustments).add(line);
        }
        continue;
      }

      var explained = 0.0;
      var enteringTotal = 0.0;
      final enteringIds = <int>[];
      double? prev;
      for (final t in byAccount[s.id] ?? const <Transaction>[]) {
        final x = dayX(t.valueDate);
        final balance = t.balanceAfter!;
        if (x <= w0) {
          prev = balance;
          continue;
        }
        if (x > w1) break;

        final r = await rate(s.currency ?? t.currency, dayKey(t.valueDate));
        // The part of the balance's move that is this transaction, and the
        // part that was already in the account before its first row.
        final entering = prev == null ? balance - t.amount : 0.0;
        final move = prev == null ? t.amount : balance - prev;
        prev = balance;
        if (r == null) continue;
        if (entering.abs() >= _eps) {
          enteringTotal += entering * r;
          explained += entering * r;
          enteringIds.add(t.id);
        }
        if (move.abs() < _eps) continue;
        final cat = t.categoryId == null ? null : categories[t.categoryId];
        final type = cat?.type;
        final catId = cat?.id;
        final inType = groups.putIfAbsent(type, () => {});
        final entry = inType.putIfAbsent(catId, () => (<int>[], 0.0));
        entry.$1.add(t.id);
        inType[catId] = (entry.$1, entry.$2 + move * r);
        explained += move * r;
      }
      if (enteringTotal.abs() >= _eps) {
        opening.add(
          ExplainLine(
            kind: ExplainLineKind.account,
            label: s.name,
            count: 1,
            amount: enteringTotal,
            transactionIds: enteringIds,
            seriesKind: s.kind,
            seriesId: s.id,
          ),
        );
      }
      final left = delta - explained;
      if (left.abs() >= _eps) {
        unexplained.add(
          ExplainLine(
            kind: ExplainLineKind.unexplained,
            label: s.name,
            amount: left,
            seriesKind: s.kind,
            seriesId: s.id,
            valueFrom: v0,
            valueTo: v1,
          ),
        );
      }
    }
  }

  const typeOrder = [CategoryType.income, CategoryType.expense, CategoryType.transfer, CategoryType.reimbursement, null];
  final transactionLines = <ExplainLine>[];
  for (final type in typeOrder) {
    final cats = groups[type];
    if (cats == null) continue;
    final children = [
      for (final e in cats.entries)
        ExplainLine(
          kind: type == null ? ExplainLineKind.uncategorized : ExplainLineKind.category,
          categoryType: type,
          categoryId: e.key,
          count: e.value.$1.length,
          amount: e.value.$2,
          transactionIds: List.unmodifiable(e.value.$1),
        ),
    ]..sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));
    if (children.isEmpty) continue;
    transactionLines.add(
      ExplainLine(
        kind: type == null ? ExplainLineKind.uncategorized : ExplainLineKind.typeGroup,
        categoryType: type,
        count: children.fold(0, (s, c) => s + c.count),
        amount: children.fold(0.0, (s, c) => s + c.amount),
        // An uncategorized row has no categories to list.
        children: type == null ? const [] : children,
        transactionIds: [for (final c in children) ...c.transactionIds],
      ),
    );
  }

  final pensionTotal = pension.fold(0.0, (s, r) => s + r.amount);
  final result = <ExplainSection>[
    ExplainSection(ExplainSectionKind.accountTransactions, transactionLines),
    ExplainSection(ExplainSectionKind.accountOpening, opening),
    ExplainSection(ExplainSectionKind.investments, investments),
    ExplainSection(ExplainSectionKind.adjustments, adjustments),
    ExplainSection(ExplainSectionKind.pensionContributions, [
      if (pensionTotal.abs() >= _eps)
        ExplainLine(kind: ExplainLineKind.pension, count: pension.length, amount: -pensionTotal, recordIds: [for (final r in pension) r.id]),
    ]),
    ExplainSection(ExplainSectionKind.unexplained, unexplained),
  ].where((s) => s.lines.isNotEmpty).toList();
  if (unexplained.isNotEmpty) {
    _log.warning('savings $year: ${unexplained.length} account(s) with a balance change the transactions do not explain');
  }
  return result;
}
