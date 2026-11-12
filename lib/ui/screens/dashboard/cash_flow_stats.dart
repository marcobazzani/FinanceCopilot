part of 'dashboard_screen.dart';

// ════════════════════════════════════════════════════
// Cash Flow stats: one period's figures, day by day
// ════════════════════════════════════════════════════

/// A run of days, both ends included.
typedef _Days = DayRange;

/// One part of a period — a day, a week, a month or a year of it (see
/// [periodBuckets]) — with its income, expenses and savings so far, counted
/// as the period's are. [future]: it has not started yet.
typedef _Part = ({String label, DateTime start, DateTime end, double income, double expenses, double savings, bool future});

/// The period shown when none is picked: this month.
CashFlowPeriod _periodOrDefault(CashFlowPeriod? picked, DateTime today) => picked ?? CashFlowPeriod.thisMonth(today);

/// Months with something to show: income, a change of savings, or spending in
/// the ledger (year → its months).
Map<int, List<int>> _availableMonths(_IncomeExpenseData? ieData, SpendingByCategoryData? spending) {
  final available = <int, List<int>>{};
  for (final y in ieData?.years ?? const <_YearBucket>[]) {
    for (final m in y.months) {
      final spent = spending?.period(y.year, m.month).total ?? 0;
      if (m.income.abs() >= 0.005 || m.savings.abs() >= 0.005 || spent >= 0.005) {
        (available[y.year] ??= []).add(m.month);
      }
    }
  }
  return available;
}

/// The first month with data; the current month without any.
YearMonth _firstMonth(Map<int, List<int>> available, DateTime today) {
  if (available.isEmpty) return (today.year, today.month);
  final year = available.keys.reduce(min);
  return (year, available[year]!.reduce(min));
}

/// The periods the overview pages through: [period]'s own kind, from the
/// first with data to the one holding today, oldest first, and where [period]
/// is among them. Only [period] itself when it cannot step.
({List<CashFlowPeriod> periods, int index}) _pagesOf(CashFlowPeriod period, Map<int, List<int>> available, DateTime today) {
  final first = _firstMonth(available, today);
  var latest = period;
  while (latest.canStep(1, first, today)) {
    latest = latest.shifted(1);
  }
  final back = <CashFlowPeriod>[latest];
  while (back.last.canStep(-1, first, today)) {
    back.add(back.last.shifted(-1));
  }
  final periods = back.reversed.toList();
  final index = periods.indexOf(period);
  return index < 0 ? (periods: [period], index: 0) : (periods: periods, index: index);
}

/// The [records] dated [from] to [to], both included.
Iterable<ExplainRecord> _recordsBetween(List<ExplainRecord> records, DateTime from, DateTime to) => records.where((r) {
  final d = dayOf(r.date);
  return !d.isBefore(from) && !d.isAfter(to);
});

/// The income records dated [from] to [to], both included.
Iterable<ExplainRecord> _incomeRecordsBetween(_IncomeExpenseData data, DateTime from, DateTime to) =>
    _recordsBetween(data.incomeRecords, from, to);

double _sumOf(Iterable<ExplainRecord> records) => records.fold(0.0, (a, r) => a + r.amount);

/// The Saving total day by day, read as the yearly figures read it: on any day
/// the last value known by then; before its history starts, its first value.
class _SavingTotal {
  final DateTime firstDate;
  final List<FlSpot> spots;
  _SavingTotal(this.firstDate, this.spots);

  static final _cache = Expando<_SavingTotal>();

  static _SavingTotal of(_IncomeExpenseData data) => _cache[data] ??= _SavingTotal(
    data.firstDate,
    buildTotalSpots([for (final s in data.savingSeries) s.spots])..sort((a, b) => a.x.compareTo(b.x)),
  );

  double at(DateTime day) {
    if (spots.isEmpty) return 0;
    final x = chart_math.calendarDaysBetween(firstDate, day).toDouble();
    var lo = 0, hi = spots.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (spots[mid].x <= x) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo == 0 ? spots.first.y : spots[lo - 1].y;
  }
}

/// What the days [from] to [to] saved, as the yearly figures count it: the
/// Saving total's growth over them, less the pension contributions in them
/// (money the employer or the state put in, not saved from income).
double _savingsBetween(_IncomeExpenseData data, DateTime from, DateTime to) {
  final total = _SavingTotal.of(data);
  return total.at(to) - total.at(addDays(from, -1)) - _sumOf(_recordsBetween(data.pensionRecords, from, to));
}

/// Income, expenses and savings of the days [from] to [to] (income from the
/// days [from] to [incomeTo]), as Year by year counts them: expenses are
/// income less savings.
({double income, double savings, double expenses}) _figuresBetween(_IncomeExpenseData data, DateTime from, DateTime to, {DateTime? incomeTo}) {
  final income = _sumOf(_incomeRecordsBetween(data, from, incomeTo ?? to));
  final savings = _savingsBetween(data, from, to);
  return (income: income, savings: savings, expenses: income - savings);
}

/// Expenses as a running total, one figure a day from [from] to [to]: income
/// so far less the savings so far.
List<double> _expensesRunning(_IncomeExpenseData data, DateTime from, DateTime to) {
  final total = _SavingTotal.of(data);
  final opening = total.at(addDays(from, -1));
  double byDay(List<ExplainRecord> records, DateTime day) => _sumOf(records.where((r) => dayOf(r.date) == day));
  final incomeIn = _incomeRecordsBetween(data, from, to).toList();
  final pensionIn = _recordsBetween(data.pensionRecords, from, to).toList();
  final out = <double>[];
  var income = 0.0, pension = 0.0;
  for (var day = from; !day.isAfter(to); day = addDays(day, 1)) {
    income += byDay(incomeIn, day);
    pension += byDay(pensionIn, day);
    out.add(income - (total.at(day) - opening - pension));
  }
  return out;
}

/// The income records of [from] to [to] as a running total, one figure a day.
List<double> _incomeRunning(_IncomeExpenseData data, DateTime from, DateTime to) {
  final byDay = <DateTime, double>{};
  for (final r in _incomeRecordsBetween(data, from, to)) {
    byDay[dayOf(r.date)] = (byDay[dayOf(r.date)] ?? 0) + r.amount;
  }
  final out = <double>[];
  var sum = 0.0;
  for (var day = from; !day.isAfter(to); day = addDays(day, 1)) {
    sum += byDay[day] ?? 0;
    out.add(sum);
  }
  return out;
}

/// One period of the Cash Flow overview and its screens: what it earned,
/// spent and saved so far, against the same days of the period it is compared
/// with, day by day and bar by bar.
class _PeriodStats {
  final CashFlowPeriod period;
  final String label;

  /// The period's days; [until] is the last one counted (today, at most).
  final DateTime start;
  final DateTime end;
  final DateTime until;

  /// Income, expenses and savings, as Year by year and the Sankey count them.
  final double income;
  final double expenses;
  final double savings;

  /// What the ledger holds of the expenses: spending in its categories and
  /// saving plans; the refunds received back; and what no transaction shows
  /// (expenses − spending + refunds: positive, expenses the ledger lacks;
  /// negative, spending no income record accounts for).
  final double spent;
  final double refunds;
  double get untracked => expenses - spent + refunds;

  /// Against the same days of the other period; null without a comparison.
  final ComparedFigure? expensesVs;
  final ComparedFigure? incomeVs;
  final ComparedFigure? savingsVs;

  /// How the other period reads, and what the comparison was, in words.
  final String? vsLabel;
  final List<String> notes;

  /// The first and the last day of the period it is compared with; null
  /// without one.
  final DateTime? otherStart;
  final DateTime? otherEnd;

  /// The days of the other period each part was set against (the same days
  /// as the part's so far): what a narrowed figure or a list row is compared
  /// with. Empty without a comparison.
  final List<_Days> comparedDays;

  /// Running totals, one figure a day: the period's so far, the other
  /// period's whole.
  final List<double> expensesRun;
  final List<double> incomeRun;
  final List<double>? expensesRunBefore;
  final List<double>? incomeRunBefore;

  /// The period's parts: the bars of the Income card and of the screens, and
  /// the months its income list is made of.
  final List<_Part> parts;
  final List<ChartTick> ticks;

  /// The parts begun, today's included: what an average per part divides by.
  int get partsBegun => parts.where((p) => !p.future).length;

  /// What the period spent, per category, merchant and saving plan.
  final SpendingPeriod spending;

  /// The income records of the period so far.
  final List<ExplainRecord> incomeRecords;

  const _PeriodStats({
    required this.period,
    required this.label,
    required this.start,
    required this.end,
    required this.until,
    required this.income,
    required this.expenses,
    required this.savings,
    required this.spent,
    required this.refunds,
    required this.expensesVs,
    required this.incomeVs,
    required this.savingsVs,
    required this.vsLabel,
    required this.notes,
    required this.otherStart,
    required this.otherEnd,
    required this.comparedDays,
    required this.expensesRun,
    required this.incomeRun,
    required this.expensesRunBefore,
    required this.incomeRunBefore,
    required this.parts,
    required this.ticks,
    required this.spending,
    required this.incomeRecords,
  });

  /// Calendar days of the period, the x axis of its charts.
  int get dayCount => daysBetween(start, end) + 1;

  /// The period has not begun yet.
  bool get future => start.isAfter(until);

  static _PeriodStats of({
    required CashFlowPeriod period,
    required CashFlowCompare compare,
    required DateTime today,
    required Map<int, List<int>> available,
    required _IncomeExpenseData? ieData,
    required SpendingByCategoryData? spending,
    required AppStrings s,
    required String language,
  }) {
    final day = dayOf(today);
    final first = _firstMonth(available, today);
    final start = period.start ?? DateTime(first.$1, first.$2, 1);
    final end = period.end ?? day;
    final until = end.isAfter(day) ? day : end;
    final started = !start.isAfter(until);
    double spentIn(DateTime a, DateTime b) => spending?.spentBetween(a, b) ?? 0;
    List<ExplainRecord> incomeIn(DateTime a, DateTime b) => ieData == null ? const [] : _incomeRecordsBetween(ieData, a, b).toList();
    // A period's income counts to the end of today's month, as the yearly
    // figures do (a salary already recorded for the 27th is this month's),
    // never past the period's own end.
    DateTime incomeEnd(DateTime to, DateTime periodEnd) {
      final monthEnd = DateTime(to.year, to.month + 1, 0);
      final last = monthEnd.isAfter(periodEnd) ? periodEnd : monthEnd;
      return last.isBefore(to) ? to : last;
    }

    const nothing = (income: 0.0, savings: 0.0, expenses: 0.0);
    ({double income, double savings, double expenses}) figures(DateTime a, DateTime b, {DateTime? periodEnd}) =>
        ieData == null ? nothing : _figuresBetween(ieData, a, b, incomeTo: periodEnd == null ? null : incomeEnd(b, periodEnd));
    final incomeTo = incomeEnd(until, end);

    // Unit by unit, each against the same days of its counterpart.
    final other = comparisonOf(period, compare);
    ComparedFigure? expensesVs, incomeVs, savingsVs;
    String? vsLabel;
    final notes = <String>[];
    final comparedDays = <_Days>[];
    if (other != null && started && spending != null && ieData != null) {
      final units = period.units, baseUnits = other.units;
      final expenseUnits = <ComparedUnit>[], incomeUnits = <ComparedUnit>[], savingUnits = <ComparedUnit>[];
      _Days? firstBase, lastBase;
      ({_Days unit, _Days same, DateTime to})? partial;
      for (var i = 0; i < units.length && i < baseUnits.length; i++) {
        final same = sameDays(units[i], baseUnits[i], today);
        if (same == null) continue;
        comparedDays.add(same);
        final to = units[i].end.isAfter(day) ? day : units[i].end;
        firstBase ??= baseUnits[i];
        lastBase = baseUnits[i];
        if (to.isBefore(units[i].end)) partial = (unit: units[i], same: same, to: to);
        final (now, before) = (figures(units[i].start, to), figures(same.start, same.end));
        expenseUnits.add((current: now.expenses, base: before.expenses, comparable: true));
        savingUnits.add((current: now.savings, base: before.savings, comparable: true));
        final (ci, bi) = (incomeIn(units[i].start, to), incomeIn(same.start, same.end));
        incomeUnits.add((current: _sumOf(ci), base: _sumOf(bi), comparable: ci.isNotEmpty && bi.isNotEmpty));
      }
      expensesVs = compareUnits(expenseUnits);
      incomeVs = compareUnits(incomeUnits);
      savingsVs = compareUnits(savingUnits);
      if (firstBase != null && lastBase != null) {
        final compared = other.byDays
            ? other
            : CashFlowPeriod.range((firstBase.start.year, firstBase.start.month), (lastBase.start.year, lastBase.start.month));
        vsLabel = compared.label(s, language, today);
        notes.add(s.cfComparedWith(vsLabel));
        if (partial != null) {
          final unitLabel = period.byDays
              ? period.label(s, language, today)
              : CashFlowPeriod.month(partial.unit.start.year, partial.unit.start.month).label(s, language, today);
          notes.add(
            s.cfSoFarAgainst(
              unitLabel,
              daysBetween(partial.unit.start, partial.to) + 1,
              daysBetween(partial.unit.start, partial.unit.end) + 1,
              CashFlowPeriod.days(partial.same.start, partial.same.end).label(s, language, today),
            ),
          );
        }
        final withIncome = incomeUnits.where((u) => u.comparable).length;
        if (withIncome == 0) {
          notes.add(s.cfNoIncomeToCompare);
        } else if (withIncome < incomeUnits.length) {
          notes.add(s.cfIncomeOver(withIncome, incomeUnits.length));
        }
      }
    }
    final otherDays = other == null || other.start == null ? null : (start: other.start!, end: other.end!);
    final parts = <_Part>[
      for (final b in periodBuckets(period, start, end))
        () {
          final future = b.start.isAfter(day);
          final to = b.end.isAfter(day) ? day : b.end;
          final f = future || ieData == null
              ? nothing
              : _figuresBetween(ieData, b.start, to, incomeTo: b.end.isAfter(incomeTo) ? incomeTo : b.end);
          return (
            label: bucketLabel(period, b, language),
            start: b.start,
            end: b.end,
            income: f.income,
            expenses: f.expenses,
            savings: f.savings,
            future: future,
          );
        }(),
    ];
    final ticks = chartTicks(period, start, end, language);
    final totals = started ? figures(start, until, periodEnd: end) : nothing;
    return _PeriodStats(
      period: period,
      label: period.label(s, language, today),
      start: start,
      end: end,
      until: until,
      income: totals.income,
      expenses: totals.expenses,
      savings: totals.savings,
      spent: started ? spentIn(start, until) : 0,
      refunds: !started
          ? 0
          : (spending?.refundsBetween(start, until) ?? 0) + (ieData == null ? 0 : _sumOf(_recordsBetween(ieData.refundRecords, start, until))),
      expensesVs: expensesVs,
      incomeVs: incomeVs,
      savingsVs: savingsVs,
      vsLabel: vsLabel,
      notes: notes,
      otherStart: vsLabel == null ? null : otherDays?.start,
      otherEnd: vsLabel == null ? null : otherDays?.end,
      comparedDays: vsLabel == null ? const [] : comparedDays,
      expensesRun: started && ieData != null ? _expensesRunning(ieData, start, until) : const [],
      incomeRun: started && ieData != null ? _incomeRunning(ieData, start, until) : const [],
      expensesRunBefore: vsLabel == null || otherDays == null || ieData == null
          ? null
          : _expensesRunning(ieData, otherDays.start, otherDays.end),
      incomeRunBefore: vsLabel == null || otherDays == null || ieData == null ? null : _incomeRunning(ieData, otherDays.start, otherDays.end),
      parts: parts,
      ticks: ticks,
      spending: started && spending != null ? spending.sumOfDays(start, until) : SpendingPeriod.none,
      incomeRecords: started ? incomeIn(start, incomeTo) : const [],
    );
  }
}
