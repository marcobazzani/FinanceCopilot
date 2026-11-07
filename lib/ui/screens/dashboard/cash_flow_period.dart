import 'dart:math';

import 'package:intl/intl.dart';

import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/utils/formatters.dart' show dayMonthFormat;

import 'eoy_projection.dart' show monthAbbr, monthYearLabel;

/// A month as (year, month 1-12).
typedef YearMonth = (int, int);

int _index(YearMonth m) => m.$1 * 12 + (m.$2 - 1);
YearMonth _fromIndex(int i) => (i ~/ 12, i % 12 + 1);

/// [m] moved by [months] (negative: earlier).
YearMonth addMonths(YearMonth m, int months) => _fromIndex(_index(m) + months);

/// A run of days, both ends included.
typedef DayRange = ({DateTime start, DateTime end});

/// A label under a chart, at day [x] (1 = the period's first day).
typedef ChartTick = ({int x, String label});

/// [day] at local midnight.
DateTime dayOf(DateTime day) => DateTime(day.year, day.month, day.day);

/// [day] moved by [days] calendar days: by date, never by hours, so summer
/// time cannot shift it.
DateTime addDays(DateTime day, int days) => DateTime(day.year, day.month, day.day + days);

/// Calendar days from [a] to [b].
int daysBetween(DateTime a, DateTime b) => DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// What a Cash Flow period is: how it reads and how it steps (a week by a
/// week, a month by a month, a run of months or of days by its length).
enum CashFlowPeriodKind { week, month, year, range, days, all }

/// The spans of the period selector: the current week, month, half year or
/// year.
enum CashFlowSpan { week, month, half, year }

/// What the Cash Flow overview sets the period against.
enum CashFlowCompare { none, previous, yearEarlier }

/// The one period the Cash Flow tab shows: a week (Monday to Sunday), a
/// month, a year, a run of months, a run of days, or every year. Both ends
/// included; the part after today has not happened yet.
class CashFlowPeriod {
  final CashFlowPeriodKind kind;

  /// First and last month it touches, both included; null for every year.
  final YearMonth? from;
  final YearMonth? to;

  /// First and last day of a week or of a run of days.
  final DateTime? firstDay;
  final DateTime? lastDay;

  const CashFlowPeriod._(this.kind, this.from, this.to, [this.firstDay, this.lastDay]);

  factory CashFlowPeriod.month(int year, int month) => CashFlowPeriod._(CashFlowPeriodKind.month, (year, month), (year, month));

  factory CashFlowPeriod.year(int year) => CashFlowPeriod._(CashFlowPeriodKind.year, (year, 1), (year, 12));

  /// The months from [a] to [b], in either order. One month is a month;
  /// January to December of one year is that year.
  factory CashFlowPeriod.range(YearMonth a, YearMonth b) {
    final (lo, hi) = _index(a) <= _index(b) ? (a, b) : (b, a);
    if (lo == hi) return CashFlowPeriod.month(lo.$1, lo.$2);
    if (lo.$1 == hi.$1 && lo.$2 == 1 && hi.$2 == 12) return CashFlowPeriod.year(lo.$1);
    return CashFlowPeriod._(CashFlowPeriodKind.range, lo, hi);
  }

  /// The week, Monday to Sunday, holding [day].
  factory CashFlowPeriod.week(DateTime day) {
    final monday = addDays(dayOf(day), DateTime.monday - day.weekday);
    final sunday = addDays(monday, 6);
    return CashFlowPeriod._(CashFlowPeriodKind.week, (monday.year, monday.month), (sunday.year, sunday.month), monday, sunday);
  }

  /// The days from [a] to [b], in either order.
  factory CashFlowPeriod.days(DateTime a, DateTime b) {
    final (lo, hi) = dayOf(a).isAfter(dayOf(b)) ? (dayOf(b), dayOf(a)) : (dayOf(a), dayOf(b));
    return CashFlowPeriod._(CashFlowPeriodKind.days, (lo.year, lo.month), (hi.year, hi.month), lo, hi);
  }

  static const all = CashFlowPeriod._(CashFlowPeriodKind.all, null, null);

  /// The days [a] to [b], as a custom period reads them: whole months as
  /// months (a month, a year, a run of months), any other days as days.
  factory CashFlowPeriod.fromDays(DateTime a, DateTime b) {
    final (lo, hi) = dayOf(a).isAfter(dayOf(b)) ? (dayOf(b), dayOf(a)) : (dayOf(a), dayOf(b));
    final wholeMonths = lo.day == 1 && addDays(hi, 1).day == 1;
    return wholeMonths ? CashFlowPeriod.range((lo.year, lo.month), (hi.year, hi.month)) : CashFlowPeriod.days(lo, hi);
  }

  static CashFlowPeriod thisWeek(DateTime today) => CashFlowPeriod.week(today);

  static CashFlowPeriod thisMonth(DateTime today) => CashFlowPeriod.month(today.year, today.month);

  /// January to June, or July to December, as [today] falls.
  static CashFlowPeriod thisHalf(DateTime today) =>
      today.month <= 6 ? CashFlowPeriod.range((today.year, 1), (today.year, 6)) : CashFlowPeriod.range((today.year, 7), (today.year, 12));

  static CashFlowPeriod thisYear(DateTime today) => CashFlowPeriod.year(today.year);

  /// The current period of [span].
  static CashFlowPeriod current(CashFlowSpan span, DateTime today) => switch (span) {
    CashFlowSpan.week => thisWeek(today),
    CashFlowSpan.month => thisMonth(today),
    CashFlowSpan.half => thisHalf(today),
    CashFlowSpan.year => thisYear(today),
  };

  /// The selector's span this period is one of; null for a custom period.
  CashFlowSpan? get span => switch (kind) {
    CashFlowPeriodKind.week => CashFlowSpan.week,
    CashFlowPeriodKind.month => CashFlowSpan.month,
    CashFlowPeriodKind.year => CashFlowSpan.year,
    CashFlowPeriodKind.range when length == 6 && (from!.$2 == 1 || from!.$2 == 7) => CashFlowSpan.half,
    _ => null,
  };

  /// A week or a run of days: periods that need not start on the 1st.
  bool get byDays => kind == CashFlowPeriodKind.week || kind == CashFlowPeriodKind.days;

  /// First and last day, both included; null for every year.
  DateTime? get start => byDays ? firstDay : (from == null ? null : DateTime(from!.$1, from!.$2, 1));
  DateTime? get end => byDays ? lastDay : (to == null ? null : DateTime(to!.$1, to!.$2 + 1, 0));

  /// Calendar days it spans; 0 for every year.
  int get dayCount => start == null ? 0 : daysBetween(start!, end!) + 1;

  /// How many months it touches; 0 for every year.
  int get length => from == null ? 0 : _index(to!) - _index(from!) + 1;

  bool contains(int year, int month) {
    if (kind == CashFlowPeriodKind.all) return true;
    final i = _index((year, month));
    return i >= _index(from!) && i <= _index(to!);
  }

  /// The months of [available] (year → its months with data) the period
  /// touches.
  Set<YearMonth> monthsIn(Map<int, List<int>> available) => {
    for (final MapEntry(key: year, value: months) in available.entries)
      for (final month in months)
        if (contains(year, month)) (year, month),
  };

  CashFlowPeriod _moved(int months) {
    final a = _fromIndex(_index(from!) + months), b = _fromIndex(_index(to!) + months);
    return switch (kind) {
      CashFlowPeriodKind.month => CashFlowPeriod.month(a.$1, a.$2),
      CashFlowPeriodKind.year => CashFlowPeriod.year(a.$1),
      _ => CashFlowPeriod._(kind, a, b),
    };
  }

  /// The period [steps] periods away (negative: earlier). Every year stays.
  CashFlowPeriod shifted(int steps) => switch (kind) {
    CashFlowPeriodKind.all => this,
    CashFlowPeriodKind.week => CashFlowPeriod.week(addDays(firstDay!, 7 * steps)),
    CashFlowPeriodKind.days => CashFlowPeriod.days(addDays(firstDay!, dayCount * steps), addDays(lastDay!, dayCount * steps)),
    _ => _moved(steps * length),
  };

  /// The same period a year earlier: the same week of the year (52 weeks
  /// back, so the weekdays match), the same days, or the months a year back.
  CashFlowPeriod yearEarlier() => switch (kind) {
    CashFlowPeriodKind.all => this,
    CashFlowPeriodKind.week => CashFlowPeriod.week(addDays(firstDay!, -364)),
    CashFlowPeriodKind.days => CashFlowPeriod.days(
      DateTime(firstDay!.year - 1, firstDay!.month, firstDay!.day),
      DateTime(lastDay!.year - 1, lastDay!.month, lastDay!.day),
    ),
    _ => _moved(-12),
  };

  /// Whether stepping back ([direction] −1) or ahead (+1) leads to a period
  /// with some day between the first month with data, [first], and [today].
  bool canStep(int direction, YearMonth first, DateTime today) {
    if (kind == CashFlowPeriodKind.all) return false;
    final next = shifted(direction);
    return !next.end!.isBefore(DateTime(first.$1, first.$2, 1)) && !next.start!.isAfter(dayOf(today));
  }

  /// The first and last day the period covers, the last one never after
  /// [today]. Not for every year.
  ({DateTime start, DateTime end}) daysUntil(DateTime today) {
    final day = dayOf(today);
    return (start: start!, end: end!.isAfter(day) ? day : end!);
  }

  /// The parts it is compared by: its months, or the whole of a week or of a
  /// run of days. None for every year.
  List<DayRange> get units {
    if (kind == CashFlowPeriodKind.all) return const [];
    if (byDays) return [(start: start!, end: end!)];
    return [
      for (var i = 0; i < length; i++)
        () {
          final (y, m) = addMonths(from!, i);
          return (start: DateTime(y, m, 1), end: DateTime(y, m + 1, 0));
        }(),
    ];
  }

  /// The period as it reads: "Oct 2026", "2025", "Jul–Dec 2026", "Nov 2025 –
  /// Feb 2026", "Oct 26 – Nov 1 2026", "All years"; the week, month or year
  /// [today] is in by what it is to you: "This week", "This month", "This
  /// year". Month and day names are spelled in [language], as the Cash Flow
  /// tables spell them.
  String label(AppStrings s, String language, DateTime today) {
    String monthYear(YearMonth m) => monthYearLabel(m.$1, m.$2, language);
    switch (kind) {
      case CashFlowPeriodKind.all:
        return s.cfAllYears;
      case CashFlowPeriodKind.month:
        // The one in progress by what it is to you: this month.
        return from == (today.year, today.month) ? s.cfThisMonth : monthYear(from!);
      case CashFlowPeriodKind.year:
        final year = from!.$1;
        return year == today.year ? s.cfThisYear : '$year';
      case CashFlowPeriodKind.range:
        final (a, b) = (from!, to!);
        return a.$1 == b.$1 ? '${monthAbbr(a.$2, language)}–${monthAbbr(b.$2, language)} ${a.$1}' : '${monthYear(a)} – ${monthYear(b)}';
      case CashFlowPeriodKind.week when !dayOf(today).isBefore(firstDay!) && !dayOf(today).isAfter(lastDay!):
        return s.cfThisWeek;
      case CashFlowPeriodKind.week:
      case CashFlowPeriodKind.days:
        final (a, b) = (firstDay!, lastDay!);
        final dm = dayMonthFormat(language);
        if (a == b) return '${dm.format(a)} ${a.year}';
        if (a.year != b.year) return '${dm.format(a)} ${a.year} – ${dm.format(b)} ${b.year}';
        return '${dm.format(a)} – ${dm.format(b)} ${a.year}';
    }
  }

  @override
  bool operator ==(Object other) =>
      other is CashFlowPeriod &&
      other.kind == kind &&
      other.from == from &&
      other.to == to &&
      other.firstDay == firstDay &&
      other.lastDay == lastDay;

  @override
  int get hashCode => Object.hash(kind, from, to, firstDay, lastDay);

  @override
  String toString() => 'CashFlowPeriod($kind, ${firstDay ?? from}, ${lastDay ?? to})';
}

/// The period [compare] sets [period] against: the one before it, or the same
/// period a year earlier. Unit by unit ([CashFlowPeriod.units]), the two line
/// up. Null with nothing to compare: [CashFlowCompare.none], or every year.
CashFlowPeriod? comparisonOf(CashFlowPeriod period, CashFlowCompare compare) {
  if (compare == CashFlowCompare.none || period.kind == CashFlowPeriodKind.all) return null;
  return compare == CashFlowCompare.previous ? period.shifted(-1) : period.yearEarlier();
}

/// The days of [base] to set against [unit] on [today], like for like: all of
/// [base] once [unit] is over; while [unit] runs, as many of [base]'s days as
/// it has had (1–6 October against 1–6 November, Monday–Wednesday against
/// Monday–Wednesday); null before [unit] starts.
({DateTime start, DateTime end})? sameDays(({DateTime start, DateTime end}) unit, ({DateTime start, DateTime end}) base, DateTime today) {
  final day = dayOf(today);
  if (day.isBefore(unit.start)) return null;
  if (!day.isBefore(unit.end)) return base;
  final end = addDays(base.start, daysBetween(unit.start, day));
  return (start: base.start, end: end.isAfter(base.end) ? base.end : end);
}

/// One figure on both sides of a comparison.
typedef ComparedFigure = ({double current, double base});

/// One unit of a comparison: the figure over the period's unit so far, the
/// figure over the same days of the unit it is set against ([sameDays]), and
/// whether the two compare at all (income needs income on both sides).
typedef ComparedUnit = ({double current, double base, bool comparable});

/// [units] added up on both sides; units that do not compare count on
/// neither. Null when none compares.
ComparedFigure? compareUnits(Iterable<ComparedUnit> units) {
  var current = 0.0, base = 0.0, any = false;
  for (final u in units) {
    if (!u.comparable) continue;
    any = true;
    current += u.current;
    base += u.base;
  }
  return any ? (current: current, base: base) : null;
}

/// The parts of a period, its bars: the days of a week or of a short run of
/// days; the weeks of a month (1–7, 8–14, 15–21, 22–28, then the rest); the
/// months of a half year, a year or a longer run; the years of every year.
List<DayRange> periodBuckets(CashFlowPeriod period, DateTime start, DateTime end) {
  if (period.kind == CashFlowPeriodKind.month) {
    return [
      for (var d = 1; d <= end.day; d += 7)
        (start: DateTime(start.year, start.month, d), end: DateTime(start.year, start.month, min(d + 6, end.day))),
    ];
  }
  final byDay = period.kind == CashFlowPeriodKind.week || (period.kind == CashFlowPeriodKind.days && period.dayCount <= 31);
  if (byDay) {
    return [for (var d = start; !d.isAfter(end); d = addDays(d, 1)) (start: d, end: d)];
  }
  DayRange clip(DateTime a, DateTime b) => (start: a.isBefore(start) ? start : a, end: b.isAfter(end) ? end : b);
  if (period.kind == CashFlowPeriodKind.all) {
    return [for (var y = start.year; y <= end.year; y++) clip(DateTime(y, 1, 1), DateTime(y, 12, 31))];
  }
  return [
    for (var m = (start.year, start.month); !DateTime(m.$1, m.$2, 1).isAfter(end); m = addMonths(m, 1))
      clip(DateTime(m.$1, m.$2, 1), DateTime(m.$1, m.$2 + 1, 0)),
  ];
}

/// The labels under a chart of [period] that runs [start] to [end]: the
/// weekdays of a week, every fifth day of a month (and its last), the months
/// of a longer run, the years of every year.
List<ChartTick> chartTicks(CashFlowPeriod period, DateTime start, DateTime end, String language) {
  final days = daysBetween(start, end) + 1;
  int xOf(DateTime d) => daysBetween(start, d) + 1;
  switch (period.kind) {
    case CashFlowPeriodKind.week:
      final weekday = DateFormat.E(language);
      return [for (var i = 0; i < 7; i++) (x: i + 1, label: weekday.format(addDays(start, i)))];
    case CashFlowPeriodKind.month:
      return [
        for (var d = 1; d <= days; d += 5)
          if (days - d >= 3 || d == 1) (x: d, label: '$d'),
        (x: days, label: '$days'),
      ];
    case CashFlowPeriodKind.days when days <= 31:
      final dm = dayMonthFormat(language);
      final step = max(1, (days / 5).ceil());
      return [for (var i = 0; i < days; i += step) (x: i + 1, label: dm.format(addDays(start, i)))];
    case CashFlowPeriodKind.all:
      return [
        for (var y = start.year; y <= end.year; y++)
          if (!DateTime(y, 1, 1).isBefore(start) || y == start.year)
            (x: xOf(DateTime(y, 1, 1).isBefore(start) ? start : DateTime(y, 1, 1)), label: '$y'),
      ];
    default:
      final months = [for (var m = (start.year, start.month); !DateTime(m.$1, m.$2, 1).isAfter(end); m = addMonths(m, 1)) m];
      // A label a month, fewer when there are many.
      final step = max(1, (months.length / 12).ceil());
      return [
        for (var i = 0; i < months.length; i += step)
          (
            x: xOf(DateTime(months[i].$1, months[i].$2, 1).isBefore(start) ? start : DateTime(months[i].$1, months[i].$2, 1)),
            label: monthAbbr(months[i].$2, language),
          ),
      ];
  }
}

/// How [part], one of the [periodBuckets] of [period], reads under its bar.
String bucketLabel(CashFlowPeriod period, DayRange part, String language) => switch (period.kind) {
  CashFlowPeriodKind.week => DateFormat.E(language).format(part.start),
  CashFlowPeriodKind.month => '${part.start.day}–${part.end.day}',
  CashFlowPeriodKind.days when period.dayCount <= 31 => '${part.start.day}',
  CashFlowPeriodKind.all => '${part.start.year}',
  _ => monthAbbr(part.start.month, language),
};

/// How long each of the [periodBuckets] of [period] is.
enum CashFlowPartSpan { day, week, month, year }

CashFlowPartSpan partSpanOf(CashFlowPeriod period) => switch (period.kind) {
  CashFlowPeriodKind.week => CashFlowPartSpan.day,
  CashFlowPeriodKind.month => CashFlowPartSpan.week,
  CashFlowPeriodKind.days when period.dayCount <= 31 => CashFlowPartSpan.day,
  CashFlowPeriodKind.all => CashFlowPartSpan.year,
  _ => CashFlowPartSpan.month,
};

/// [period] in a few characters, under a bar or a dot: "Nov" for a month,
/// "2025" for a year, "Jul 26" for a half year or a run of months, "Nov 2"
/// for a week or a run of days.
String shortLabel(CashFlowPeriod period, String language) => switch (period.kind) {
  CashFlowPeriodKind.month => monthAbbr(period.from!.$2, language),
  CashFlowPeriodKind.year => '${period.from!.$1}',
  CashFlowPeriodKind.range => '${monthAbbr(period.from!.$2, language)} ${(period.from!.$1 % 100).toString().padLeft(2, '0')}',
  CashFlowPeriodKind.week || CashFlowPeriodKind.days => dayMonthFormat(language).format(period.firstDay!),
  CashFlowPeriodKind.all => '',
};
