import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_strings.dart';
import '../../widgets/privacy_text.dart' show privacySlot, splitPrivacySlots;

/// Per-month income/expense data used by the EoY projection.
class EoyMonth {
  final int month; // 1-12
  final double income;
  final double expenses;

  /// The days a month still in progress has had and the days it has (5 of 30
  /// on 5 November); null once it is over.
  final ({int days, int of})? soFar;
  const EoyMonth({required this.month, required this.income, required this.expenses, this.soFar});

  /// How much of the month has gone by: 1 once it is over.
  double get share => switch (soFar) {
    (:final days, :final of) => days / of,
    null => 1,
  };
}

/// Year-level totals + per-month breakdown used by the EoY projection.
class EoyYear {
  final int year;
  final double income;
  final double expenses;
  final List<EoyMonth> months;
  const EoyYear({
    required this.year,
    required this.income,
    required this.expenses,
    required this.months,
  });
}

/// Components of an EoY projection for a single metric (income or expenses).
///
/// `value`        — projected full-year total
/// `prevTotal`    — previous year's full-year total
/// `prevSame`     — previous year's value over the same Jan..[months] window
/// `currentTotal` — current year's value over the same Jan..[months] window
/// `months`       — last month index that actually has data for this metric
/// `partial`      — that month, when it is still in progress: the previous
///                  year's month is counted for the same share of it
class EoyDetails {
  final double value;
  final double prevTotal;
  final double prevSame;
  final double currentTotal;
  final int months;
  final ({int month, int days, int of})? partial;
  const EoyDetails({
    required this.value,
    required this.prevTotal,
    required this.prevSame,
    required this.currentTotal,
    required this.months,
    this.partial,
  });
}

/// Project the current year's full-year value for `income` (default) or
/// `expenses` based on the same period of the previous year.
///
/// The "current period" is intentionally per-metric: it ends at the last
/// month that actually has non-zero data for that metric. Salaries post at
/// month-end, so summing through the calendar-current month would compare an
/// empty current month against a fully-paid previous-year month and skew the
/// projection low.
///
/// A month still in progress counts for the share of it gone by: the previous
/// year's month is taken for the same share (5/30 of it on 5 November), so a
/// few days are never set against a whole month.
EoyDetails? computeEoyDetails(EoyYear current, EoyYear prev, {bool expenses = false}) {
  if (current.months.isEmpty) return null;

  int? lastMonth;
  double currentTotal = 0;
  for (final m in current.months) {
    final v = expenses ? m.expenses : m.income;
    if (v != 0) {
      lastMonth = m.month;
      currentTotal += v;
    }
  }
  if (lastMonth == null || currentTotal == 0) return null;
  final n = lastMonth;

  final shares = {for (final m in current.months) m.month: m.share};
  final prevSame = prev.months.where((m) => m.month <= n).fold(0.0, (s, m) => s + (expenses ? m.expenses : m.income) * (shares[m.month] ?? 1));
  if (prevSame == 0) return null;

  final prevTotal = expenses ? prev.expenses : prev.income;
  final last = current.months.where((m) => m.month == n).firstOrNull;
  return EoyDetails(
    value: prevTotal * currentTotal / prevSame,
    prevTotal: prevTotal,
    prevSame: prevSame,
    currentTotal: currentTotal,
    months: n,
    partial: switch (last?.soFar) {
      (:final days, :final of) => (month: n, days: days, of: of),
      null => null,
    },
  );
}

/// Abbreviated name of [month] (1-12) in [locale], e.g. "Apr" / "apr".
String monthAbbr(int month, String locale) => DateFormat.MMM(locale).format(DateTime(2000, month.clamp(1, 12)));

/// A month by its name and year: "Mar 2026" ("mar 2026" in Italian).
String monthYearLabel(int year, int month, String locale) => '${monthAbbr(month, locale)} $year';

/// A position-size figure inside a rich formula or explanation: an amount of
/// income, expenses, savings or a projection of them. Privacy mode masks these
/// spans alone; the labels, months and percentages around them stay readable.
class PositionFigureSpan extends TextSpan {
  const PositionFigureSpan({super.text, super.style});
}

/// The expenses of the last 12 months: the yearly figure behind the Health
/// tab's monthly expenses and FIRE number. It is real spending over a whole
/// seasonal cycle, so it neither depends on the current year being
/// consolidated nor jumps with the calendar.
///
/// The window is the same one [incomeOverLastYear] uses: after the same day a
/// year ago, up to and including [today]. Months inside it count whole; the
/// month in progress counts as far as it has gone, and the month a year ago
/// counts for the days after [today]'s day only.
///
/// Null when [years] does not reach back to that month a year ago (less than
/// 12 months of history) or the window has no expenses: a shorter span would
/// be passed off as a year.
double? expensesOverLastYear(Iterable<EoyYear> years, DateTime today) {
  EoyMonth? monthOf(int year, int month) =>
      years.where((y) => y.year == year).expand((y) => y.months).where((m) => m.month == month).firstOrNull;

  final oldest = monthOf(today.year - 1, today.month);
  if (oldest == null) return null;

  final daysInOldest = DateTime(today.year - 1, today.month + 1, 0).day;
  final daysAfterToday = daysInOldest - (today.day < daysInOldest ? today.day : daysInOldest);
  var total = oldest.expenses * daysAfterToday / daysInOldest;
  // The 11 whole months after it, up to and including this month so far.
  for (var i = 1; i <= 12; i++) {
    final d = DateTime(today.year - 1, today.month + i);
    total += monthOf(d.year, d.month)?.expenses ?? 0;
  }
  return total > 0 ? total : null;
}

/// Build the multi-line EoY explanation rendered in the Savings Rate KPI
/// info dialog. Returns `null` when neither income nor expenses can be
/// projected.
///
/// Worded by [s]; month names are spelled in [locale], the display locale
/// (English without one).
///
/// Layout:
///   1. Title + seasonal-reference subtitle
///   2. Bold "Predictions" block: Income / Expenses / Savings / Rate
///   3. "How it's calculated" details: per-metric breakdown + savings/rate
///      math + formula footer
///
/// Every amount is its own [PositionFigureSpan]; the rest (labels, years,
/// month ranges, percentages) are plain spans.
TextSpan? buildEoyExplanationSpan({
  required EoyYear current,
  required EoyYear prev,
  required NumberFormat amtFmt,
  required NumberFormat pctFmt,
  required String sym,
  required AppStrings s,
  String locale = 'en_US',
}) {
  if (current.months.isEmpty) return null;
  final incD = computeEoyDetails(current, prev);
  final expD = computeEoyDetails(current, prev, expenses: true);
  if (incD == null && expD == null) return null;

  final eoyInc = incD?.value;
  final eoyExp = expD?.value;
  final eoySav = (eoyInc != null && eoyExp != null) ? eoyInc - eoyExp : null;
  final eoyRate = (eoyInc != null && eoyInc > 0 && eoySav != null) ? eoySav / eoyInc : null;

  final boldStyle = const TextStyle(fontWeight: FontWeight.w700);

  String monthRangeOf(EoyDetails d) => d.months == 1 ? monthAbbr(1, locale) : '${monthAbbr(1, locale)}–${monthAbbr(d.months, locale)}';

  /// [v] as a marked amount, followed by the currency symbol unless [bare].
  PositionFigureSpan amount(double v, {bool bare = false, TextStyle? style}) =>
      PositionFigureSpan(text: bare ? amtFmt.format(v) : '${amtFmt.format(v)} $sym', style: style);

  // Stands for the amount in a localized sentence; [sentence] puts the
  // amount's spans in its place, the words on either side stay plain spans.
  final amountMark = privacySlot(0);
  List<InlineSpan> sentence(String template, List<InlineSpan> filling) {
    final parts = splitPrivacySlots(template);
    assert(parts.where((part) => part.slot != null).length == 1, 'one amount per sentence: $template');
    return [
      for (final (:words, :slot) in parts)
        if (slot == null) TextSpan(text: words) else ...filling,
    ];
  }

  final children = <InlineSpan>[];

  // ── Header ─────────────────────────────────────────────
  children.add(
    TextSpan(
      text: '${s.eoyTitle(current.year)}\n',
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
  );
  children.add(TextSpan(text: '${s.eoyBasis(prev.year)}\n\n'));

  // ── Predictions (bold values) ─────────────────────────
  void addPrediction(String label, double? value, {bool isPct = false}) {
    if (value == null) return;
    children.add(TextSpan(text: '  $label: '));
    if (isPct) {
      children.add(TextSpan(text: '~${pctFmt.format(value)}\n', style: boldStyle));
    } else {
      children.addAll([TextSpan(text: '~', style: boldStyle), amount(value, style: boldStyle), const TextSpan(text: '\n')]);
    }
  }

  addPrediction(s.colIncome, eoyInc);
  addPrediction(s.colExpenses, eoyExp);
  addPrediction(s.colSavings, eoySav);
  addPrediction(s.colRate, eoyRate, isPct: true);

  // ── Details ───────────────────────────────────────────
  children.add(
    TextSpan(
      text: '\n${s.eoyHowCalculated}\n',
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
  );

  void addMetricDetail(String label, EoyDetails? d, double? result) {
    if (d == null || result == null) return;
    final monthRange = monthRangeOf(d);
    final prevPct = d.prevSame != 0 ? pctFmt.format(d.currentTotal / d.prevSame) : '?';
    children.addAll([
      TextSpan(text: '━ $label\n  '),
      ...sentence(s.eoyPrevFullYear(prev.year, amountMark), [amount(d.prevTotal)]),
      const TextSpan(text: '\n  '),
      ...sentence(s.eoyPrevSamePeriod(monthRange, prev.year, amountMark), [amount(d.prevSame)]),
      const TextSpan(text: '\n  '),
      ...sentence(s.eoyCurrentSoFar(current.year, monthRange, amountMark, prevPct, prev.year), [amount(d.currentTotal)]),
      const TextSpan(text: '\n  '),
      if (d.partial case (:final month, :final days, :final of))
        TextSpan(
          text: '${s.cfPartialMonth(monthYearLabel(current.year, month, locale), days, of, monthYearLabel(prev.year, month, locale))}\n  ',
        ),
      ...sentence(s.eoyProjection(amountMark), [
        amount(d.prevTotal, bare: true),
        const TextSpan(text: ' × '),
        amount(d.currentTotal, bare: true),
        const TextSpan(text: ' ÷ '),
        amount(d.prevSame, bare: true),
        const TextSpan(text: ' = ~'),
        amount(result),
      ]),
      const TextSpan(text: '\n'),
    ]);
  }

  addMetricDetail(s.colIncome, incD, eoyInc);
  addMetricDetail(s.colExpenses, expD, eoyExp);

  if (eoySav != null) {
    children.addAll([
      TextSpan(text: '━ ${s.colSavings}\n  ~'),
      amount(eoyInc!),
      const TextSpan(text: ' − ~'),
      amount(eoyExp!),
      const TextSpan(text: ' = ~'),
      amount(eoySav),
      const TextSpan(text: '\n'),
    ]);
  }
  if (eoyRate != null) {
    children.addAll([
      TextSpan(text: '━ ${s.colRate}\n  ~'),
      amount(eoySav!, bare: true),
      const TextSpan(text: ' ÷ ~'),
      amount(eoyInc!, bare: true),
      TextSpan(text: ' = ~${pctFmt.format(eoyRate)}\n'),
    ]);
  }

  children.add(TextSpan(text: '\n${s.eoyFormula}\n'));

  return TextSpan(children: children);
}
