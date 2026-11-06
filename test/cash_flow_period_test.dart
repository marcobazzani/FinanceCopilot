// The Cash Flow period: the selector's spans (week, month, half year, year),
// custom days, labels, stepping within the data, the parts it compares by, its
// bars and chart labels, and the same days of the period it is set against.
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/ui/screens/dashboard/cash_flow_period.dart';

void main() {
  setUpAll(() async => initializeDateFormatting());

  // A Friday.
  final today = DateTime(2026, 11, 6);
  const en = AppStrings.en;
  String label(CashFlowPeriod p, {AppStrings s = en, String language = 'en'}) => p.label(s, language, today);

  group('the selector\'s spans', () {
    test('this week runs Monday to Sunday', () {
      final w = CashFlowPeriod.current(CashFlowSpan.week, today);
      expect((w.start, w.end), (DateTime(2026, 11, 2), DateTime(2026, 11, 8)));
      expect(w.span, CashFlowSpan.week);
      expect(CashFlowPeriod.week(DateTime(2026, 11, 8)), w, reason: 'Sunday is the end of the same week');
      expect(CashFlowPeriod.week(DateTime(2026, 11, 9)).start, DateTime(2026, 11, 9), reason: 'Monday starts the next');
    });

    test('this month, this half year, this year', () {
      expect(CashFlowPeriod.current(CashFlowSpan.month, today), CashFlowPeriod.month(2026, 11));
      final half = CashFlowPeriod.current(CashFlowSpan.half, today);
      expect((half.from, half.to, half.span), ((2026, 7), (2026, 12), CashFlowSpan.half));
      expect(CashFlowPeriod.thisHalf(DateTime(2026, 3, 1)).to, (2026, 6));
      expect(CashFlowPeriod.current(CashFlowSpan.year, today), CashFlowPeriod.year(2026));
    });

    test('a custom period is none of the spans', () {
      expect(CashFlowPeriod.range((2026, 3), (2026, 5)).span, isNull);
      expect(CashFlowPeriod.days(DateTime(2026, 10, 3), DateTime(2026, 10, 17)).span, isNull);
      expect(CashFlowPeriod.range((2026, 2), (2026, 7)).span, isNull, reason: 'six months, but not a half year');
    });

    test('custom days that are whole months read as months', () {
      expect(CashFlowPeriod.fromDays(DateTime(2026, 3, 1), DateTime(2026, 5, 31)), CashFlowPeriod.range((2026, 3), (2026, 5)));
      expect(CashFlowPeriod.fromDays(DateTime(2026, 10, 1), DateTime(2026, 10, 31)), CashFlowPeriod.month(2026, 10));
      expect(CashFlowPeriod.fromDays(DateTime(2026, 10, 17), DateTime(2026, 10, 3)).kind, CashFlowPeriodKind.days, reason: 'either order');
    });
  });

  group('labels', () {
    test('English', () {
      expect(label(CashFlowPeriod.month(2026, 10)), 'Oct 2026');
      expect(label(CashFlowPeriod.year(2026)), '2026 YTD');
      expect(label(CashFlowPeriod.year(2025)), '2025');
      expect(label(CashFlowPeriod.thisHalf(today)), 'Jul–Dec 2026');
      expect(label(CashFlowPeriod.range((2025, 11), (2026, 2))), 'Nov 2025 – Feb 2026');
      expect(label(CashFlowPeriod.thisWeek(today)), 'Nov 2 – Nov 8 2026');
      expect(label(CashFlowPeriod.week(DateTime(2026, 1, 1))), 'Dec 29 2025 – Jan 4 2026');
      expect(label(CashFlowPeriod.all), 'All years');
    });

    test('Italian', () {
      String it(CashFlowPeriod p) => label(p, s: AppStrings.it, language: 'it');
      expect(it(CashFlowPeriod.month(2026, 10)), 'ott 2026');
      expect(it(CashFlowPeriod.year(2026)), '2026 in corso');
      expect(it(CashFlowPeriod.thisWeek(today)), '2 nov – 8 nov 2026');
    });
  });

  group('stepping', () {
    test('a week by a week, a month by a month, a half year by six months, days by their length', () {
      expect(CashFlowPeriod.thisWeek(today).shifted(-1).start, DateTime(2026, 10, 26));
      expect(CashFlowPeriod.month(2026, 1).shifted(-1), CashFlowPeriod.month(2025, 12));
      expect(CashFlowPeriod.thisHalf(today).shifted(-1), CashFlowPeriod.range((2026, 1), (2026, 6)));
      final days = CashFlowPeriod.days(DateTime(2026, 10, 3), DateTime(2026, 10, 9));
      expect((days.shifted(-1).start, days.shifted(-1).end), (DateTime(2026, 9, 26), DateTime(2026, 10, 2)));
      expect(CashFlowPeriod.all.shifted(-1), CashFlowPeriod.all);
    });

    test('a year earlier: the same weekdays for a week, the months a year back', () {
      final w = CashFlowPeriod.thisWeek(today).yearEarlier();
      expect((w.start, w.start!.weekday), (DateTime(2025, 11, 3), DateTime.monday));
      expect(CashFlowPeriod.month(2026, 11).yearEarlier(), CashFlowPeriod.month(2025, 11));
    });

    test('the steps stop where the data starts, and after today', () {
      const first = (2016, 12);
      expect(CashFlowPeriod.month(2026, 11).canStep(1, first, today), isFalse);
      expect(CashFlowPeriod.month(2026, 11).canStep(-1, first, today), isTrue);
      expect(CashFlowPeriod.month(2016, 12).canStep(-1, first, today), isFalse);
      expect(CashFlowPeriod.thisWeek(today).canStep(1, first, today), isFalse);
      expect(CashFlowPeriod.thisHalf(today).canStep(1, first, today), isFalse);
      expect(CashFlowPeriod.all.canStep(-1, first, today), isFalse);
    });
  });

  group('the parts a period is compared by', () {
    test('its months, or the whole of a week', () {
      expect(CashFlowPeriod.thisHalf(today).units.length, 6);
      expect(CashFlowPeriod.thisHalf(today).units.last, (start: DateTime(2026, 12, 1), end: DateTime(2026, 12, 31)));
      expect(CashFlowPeriod.thisWeek(today).units, [(start: DateTime(2026, 11, 2), end: DateTime(2026, 11, 8))]);
      expect(CashFlowPeriod.all.units, isEmpty);
    });

    test('the month in progress against the same days of the other: 1–6 October', () {
      final nov = CashFlowPeriod.month(2026, 11).units.single, oct = CashFlowPeriod.month(2026, 10).units.single;
      expect(sameDays(nov, oct, today), (start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 6)));
    });

    test('a week in progress: Monday to Friday against Monday to Friday', () {
      final week = CashFlowPeriod.thisWeek(today);
      expect(sameDays(week.units.single, week.shifted(-1).units.single, today), (start: DateTime(2026, 10, 26), end: DateTime(2026, 10, 30)));
    });

    test('a past unit against all of the other; one not begun against nothing', () {
      final oct = CashFlowPeriod.month(2026, 10).units.single, sep = CashFlowPeriod.month(2026, 9).units.single;
      expect(sameDays(oct, sep, today), sep);
      final dec = CashFlowPeriod.month(2026, 12).units.single;
      expect(sameDays(dec, CashFlowPeriod.month(2025, 12).units.single, today), isNull);
    });

    test('30 March against February stops at its last day', () {
      final mar = CashFlowPeriod.month(2026, 3).units.single, feb = CashFlowPeriod.month(2026, 2).units.single;
      expect(sameDays(mar, feb, DateTime(2026, 3, 30))!.end, DateTime(2026, 2, 28));
    });

    test('units that do not compare count on neither side', () {
      expect(
        compareUnits([(current: 100, base: 80, comparable: true), (current: 50, base: 0, comparable: false)]),
        (current: 100.0, base: 80.0),
      );
      expect(compareUnits([(current: 1, base: 1, comparable: false)]), isNull);
    });

    test('the period it is compared with', () {
      expect(comparisonOf(CashFlowPeriod.month(2026, 11), CashFlowCompare.previous), CashFlowPeriod.month(2026, 10));
      expect(comparisonOf(CashFlowPeriod.year(2026), CashFlowCompare.yearEarlier), CashFlowPeriod.year(2025));
      expect(comparisonOf(CashFlowPeriod.year(2026), CashFlowCompare.none), isNull);
      expect(comparisonOf(CashFlowPeriod.all, CashFlowCompare.previous), isNull);
    });
  });

  group('bars and chart labels', () {
    test('a week has seven day bars, labelled by weekday', () {
      final w = CashFlowPeriod.thisWeek(today);
      expect(periodBuckets(w, w.start!, w.end!).length, 7);
      expect([for (final t in chartTicks(w, w.start!, w.end!, 'en')) t.label], ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']);
    });

    test('a month: a bar a day; labels every fifth day and the last, never crowded', () {
      final m = CashFlowPeriod.month(2026, 11);
      expect(periodBuckets(m, m.start!, m.end!).length, 30);
      expect([for (final t in chartTicks(m, m.start!, m.end!, 'en')) t.x], [1, 6, 11, 16, 21, 26, 30]);
    });

    test('a year: twelve month bars, twelve month labels (not a label every fifth day)', () {
      final y = CashFlowPeriod.year(2026);
      expect(periodBuckets(y, y.start!, y.end!).length, 12);
      final ticks = chartTicks(y, y.start!, y.end!, 'en');
      expect(ticks.length, 12);
      expect((ticks.first, ticks[1]), ((x: 1, label: 'Jan'), (x: 32, label: 'Feb')));
    });

    test('the bars read as days, months or years', () {
      expect(bucketLabel(CashFlowPeriod.month(2026, 11), DateTime(2026, 11, 6), 'en'), '6');
      expect(bucketLabel(CashFlowPeriod.year(2026), DateTime(2026, 3, 1), 'en'), 'Mar');
      expect(bucketLabel(CashFlowPeriod.all, DateTime(2019, 1, 1), 'en'), '2019');
    });
  });

  group('custom days and everything', () {
    final feb = CashFlowPeriod.days(DateTime(2026, 2, 1), DateTime(2026, 2, 20));

    test('a year earlier: the same dates a year back; everything stays everything', () {
      expect(feb.yearEarlier(), CashFlowPeriod.days(DateTime(2025, 2, 1), DateTime(2025, 2, 20)));
      expect(CashFlowPeriod.all.yearEarlier(), CashFlowPeriod.all);
    });

    test('custom days: a bar a day, a label every few days by day and month', () {
      expect(periodBuckets(feb, feb.start!, feb.end!).length, 20);
      expect(
        [for (final t in chartTicks(feb, feb.start!, feb.end!, 'en')) t],
        [
          (x: 1, label: 'Feb 1'),
          (x: 5, label: 'Feb 5'),
          (x: 9, label: 'Feb 9'),
          (x: 13, label: 'Feb 13'),
          (x: 17, label: 'Feb 17'),
        ],
      );
      expect(shortLabel(feb, 'en'), 'Feb 1');
    });

    test('everything: a bar a year, clipped to the history, a label a year', () {
      final (from, to) = (DateTime(2024, 12, 1), DateTime(2026, 3, 10));
      expect(periodBuckets(CashFlowPeriod.all, from, to), [
        (start: from, end: DateTime(2024, 12, 31)),
        (start: DateTime(2025, 1, 1), end: DateTime(2025, 12, 31)),
        (start: DateTime(2026, 1, 1), end: to),
      ]);
      expect([for (final t in chartTicks(CashFlowPeriod.all, from, to, 'en')) t.label], ['2024', '2025', '2026']);
      expect(shortLabel(CashFlowPeriod.all, 'en'), '');
    });

    test('months of two years read by their first month; equal periods are one', () {
      expect(shortLabel(CashFlowPeriod.range((2025, 7), (2025, 12)), 'en'), 'Jul 25');
      final again = CashFlowPeriod.days(DateTime(2026, 2, 1), DateTime(2026, 2, 20));
      expect(again, feb);
      expect(again.hashCode, feb.hashCode);
      expect({feb, again, CashFlowPeriod.month(2026, 2)}.length, 2);
    });
  });

  group('the five before', () {
    test('a period and the four before it, oldest first', () {
      expect([for (final p in trailOf(CashFlowPeriod.month(2026, 2))) shortLabel(p, 'en')], ['Oct', 'Nov', 'Dec', 'Jan', 'Feb']);
      expect([for (final p in trailOf(CashFlowPeriod.year(2026))) shortLabel(p, 'en')], ['2022', '2023', '2024', '2025', '2026']);
      expect([for (final p in trailOf(CashFlowPeriod.thisHalf(today))) shortLabel(p, 'en')], ['Jul 24', 'Jan 25', 'Jul 25', 'Jan 26', 'Jul 26']);
      expect([for (final p in trailOf(CashFlowPeriod.thisWeek(today))) shortLabel(p, 'en')], ['Oct 5', 'Oct 12', 'Oct 19', 'Oct 26', 'Nov 2']);
      expect(trailOf(CashFlowPeriod.all), [CashFlowPeriod.all]);
    });

    test('short labels in Italian', () {
      expect(shortLabel(CashFlowPeriod.month(2026, 10), 'it'), 'ott');
      expect(shortLabel(CashFlowPeriod.thisWeek(today), 'it'), '2 nov');
    });
  });

  test('calendar days, not hours: the last Sunday of March is one day', () {
    expect(daysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 30)), 2);
    expect(addDays(DateTime(2026, 3, 28), 2), DateTime(2026, 3, 30));
  });
}
