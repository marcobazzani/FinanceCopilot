import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_strings.dart';

/// Per-month income/expense data used by the EoY projection.
class EoyMonth {
  final int month; // 1-12
  final double income;
  final double expenses;
  const EoyMonth({required this.month, required this.income, required this.expenses});
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
class EoyDetails {
  final double value;
  final double prevTotal;
  final double prevSame;
  final double currentTotal;
  final int months;
  const EoyDetails({
    required this.value,
    required this.prevTotal,
    required this.prevSame,
    required this.currentTotal,
    required this.months,
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

  final prevSame = prev.months
      .where((m) => m.month <= n)
      .fold(0.0, (s, m) => s + (expenses ? m.expenses : m.income));
  if (prevSame == 0) return null;

  final prevTotal = expenses ? prev.expenses : prev.income;
  return EoyDetails(
    value: prevTotal * currentTotal / prevSame,
    prevTotal: prevTotal,
    prevSame: prevSame,
    currentTotal: currentTotal,
    months: n,
  );
}

const _monthAbbrs = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
String monthAbbr(int month) => _monthAbbrs[(month - 1).clamp(0, 11)];

/// Build the multi-line EoY explanation rendered in the Savings Rate KPI
/// info dialog. Returns `null` when neither income nor expenses can be
/// projected.
///
/// Layout:
///   1. Title + seasonal-reference subtitle
///   2. Bold "Predictions" block: Income / Expenses / Savings / Rate
///   3. "How it's calculated" details: per-metric breakdown + savings/rate
///      math + formula footer
TextSpan? buildEoyExplanationSpan({
  required EoyYear current,
  required EoyYear prev,
  required NumberFormat amtFmt,
  required NumberFormat pctFmt,
  required String sym,
  required AppStrings s,
}) {
  if (current.months.isEmpty) return null;
  final incD = computeEoyDetails(current, prev);
  final expD = computeEoyDetails(current, prev, expenses: true);
  if (incD == null && expD == null) return null;

  final eoyInc = incD?.value;
  final eoyExp = expD?.value;
  final eoySav = (eoyInc != null && eoyExp != null) ? eoyInc - eoyExp : null;
  final eoyRate = (eoyInc != null && eoyInc > 0 && eoySav != null) ? eoySav / eoyInc : null;

  final isIt = s.eoyFormula.contains('anno'); // detect language
  final boldStyle = const TextStyle(fontWeight: FontWeight.w700);

  String monthRangeOf(EoyDetails d) =>
      d.months == 1 ? 'Jan' : 'Jan–${monthAbbr(d.months)}';

  String fmtAmt(double v) => '${amtFmt.format(v)} $sym';

  final children = <InlineSpan>[];

  // ── Header ─────────────────────────────────────────────
  children.add(TextSpan(
    text: isIt
        ? 'Previsione fine anno ${current.year}\n'
        : 'End-of-year ${current.year} prediction\n',
    style: const TextStyle(fontWeight: FontWeight.w700),
  ));
  children.add(TextSpan(
    text: isIt
        ? 'Basata sull\'andamento del ${prev.year} come riferimento stagionale.\n\n'
        : 'Based on ${prev.year} as the seasonal reference.\n\n',
  ));

  // ── Predictions (bold values) ─────────────────────────
  void addPrediction(String label, double? value, {bool isPct = false}) {
    if (value == null) return;
    children.add(TextSpan(text: '  $label: '));
    children.add(TextSpan(
      text: isPct ? '~${pctFmt.format(value)}\n' : '~${fmtAmt(value)}\n',
      style: boldStyle,
    ));
  }

  addPrediction(s.colIncome, eoyInc);
  addPrediction(s.colExpenses, eoyExp);
  addPrediction(s.colSavings, eoySav);
  addPrediction(s.colRate, eoyRate, isPct: true);

  // ── Details ───────────────────────────────────────────
  children.add(TextSpan(
    text: isIt ? '\nDettagli del calcolo:\n' : '\nHow it\'s calculated:\n',
    style: const TextStyle(fontWeight: FontWeight.w600),
  ));

  void addMetricDetail(String label, EoyDetails? d, double? result) {
    if (d == null || result == null) return;
    final monthRange = monthRangeOf(d);
    final prevPct = d.prevSame != 0
        ? (d.currentTotal / d.prevSame * 100).toStringAsFixed(1)
        : '?';
    final body = isIt
        ? '━ $label\n'
            '  Nel ${prev.year}, il totale annuo è stato ${fmtAmt(d.prevTotal)}.\n'
            '  Nello stesso periodo ($monthRange) del ${prev.year}: ${fmtAmt(d.prevSame)}.\n'
            '  Nel ${current.year} ($monthRange) finora: ${fmtAmt(d.currentTotal)} ($prevPct% rispetto al ${prev.year}).\n'
            '  Proiezione: ${amtFmt.format(d.prevTotal)} × ${amtFmt.format(d.currentTotal)} ÷ ${amtFmt.format(d.prevSame)} = ~${fmtAmt(result)}\n'
        : '━ $label\n'
            '  In ${prev.year}, the full-year total was ${fmtAmt(d.prevTotal)}.\n'
            '  Over the same period ($monthRange) in ${prev.year}: ${fmtAmt(d.prevSame)}.\n'
            '  In ${current.year} ($monthRange) so far: ${fmtAmt(d.currentTotal)} ($prevPct% vs ${prev.year}).\n'
            '  Projection: ${amtFmt.format(d.prevTotal)} × ${amtFmt.format(d.currentTotal)} ÷ ${amtFmt.format(d.prevSame)} = ~${fmtAmt(result)}\n';
    children.add(TextSpan(text: body));
  }

  addMetricDetail(s.colIncome, incD, eoyInc);
  addMetricDetail(s.colExpenses, expD, eoyExp);

  if (eoySav != null) {
    children.add(TextSpan(
      text: '━ ${s.colSavings}\n'
          '  ~${fmtAmt(eoyInc!)} − ~${fmtAmt(eoyExp!)} = ~${fmtAmt(eoySav)}\n',
    ));
  }
  if (eoyRate != null) {
    children.add(TextSpan(
      text: '━ ${s.colRate}\n'
          '  ~${amtFmt.format(eoySav!)} ÷ ~${amtFmt.format(eoyInc!)} = ~${pctFmt.format(eoyRate)}\n',
    ));
  }

  children.add(TextSpan(text: '\n${s.eoyFormula}\n'));

  return TextSpan(children: children);
}
