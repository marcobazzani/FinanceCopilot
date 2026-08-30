import 'package:flutter_test/flutter_test.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show priceChangeReferenceDate;

void main() {
  // 2024-03-13 is a Wednesday; carries a time-of-day so we can assert which
  // units preserve it (relative) vs. normalise to midnight (to-date anchors).
  final wed = DateTime(2024, 3, 13, 10, 30);

  group('priceChangeReferenceDate — existing units (pinning)', () {
    test('d steps back by number of days, preserving time-of-day', () {
      expect(
        priceChangeReferenceDate(today: wed, unit: 'd', number: 1, firstDayOfWeekIndex: 1),
        DateTime(2024, 3, 12, 10, 30),
      );
      expect(
        priceChangeReferenceDate(today: wed, unit: 'd', number: 5, firstDayOfWeekIndex: 1),
        DateTime(2024, 3, 8, 10, 30),
      );
    });

    test('w steps back by number*7 days', () {
      expect(
        priceChangeReferenceDate(today: wed, unit: 'w', number: 2, firstDayOfWeekIndex: 1),
        DateTime(2024, 2, 28, 10, 30),
      );
    });

    test('m steps back by number of months (same day-of-month, normalised to midnight)', () {
      expect(
        priceChangeReferenceDate(today: wed, unit: 'm', number: 1, firstDayOfWeekIndex: 1),
        DateTime(2024, 2, 13),
      );
      expect(
        priceChangeReferenceDate(today: wed, unit: 'm', number: 3, firstDayOfWeekIndex: 1),
        DateTime(2023, 12, 13),
      );
    });

    test('y steps back by number of years (normalised to midnight)', () {
      expect(
        priceChangeReferenceDate(today: wed, unit: 'y', number: 1, firstDayOfWeekIndex: 1),
        DateTime(2023, 3, 13),
      );
    });

    test('YTD anchors to Jan 1 (midnight)', () {
      expect(
        priceChangeReferenceDate(today: wed, unit: 'YTD', number: 1, firstDayOfWeekIndex: 1),
        DateTime(2024, 1, 1),
      );
    });

    test('All anchors to the fixed epoch', () {
      expect(
        priceChangeReferenceDate(today: wed, unit: 'All', number: 1, firstDayOfWeekIndex: 1),
        DateTime(2000, 1, 1),
      );
    });

    test('unknown unit falls back to yesterday', () {
      expect(
        priceChangeReferenceDate(today: wed, unit: '?', number: 1, firstDayOfWeekIndex: 1),
        DateTime(2024, 3, 12, 10, 30),
      );
    });
  });

  group('priceChangeReferenceDate — MTD', () {
    test('anchors to the first of the current month (midnight)', () {
      expect(
        priceChangeReferenceDate(today: wed, unit: 'MTD', number: 1, firstDayOfWeekIndex: 1),
        DateTime(2024, 3, 1),
      );
    });

    test('on the 1st, anchors to that same day (independent of week start)', () {
      final first = DateTime(2024, 3, 1, 9);
      expect(
        priceChangeReferenceDate(today: first, unit: 'MTD', number: 1, firstDayOfWeekIndex: 0),
        DateTime(2024, 3, 1),
      );
    });
  });

  group('priceChangeReferenceDate — WTD honours the locale first day of week', () {
    test('Monday-start locale (index 1): Wednesday → that Monday', () {
      expect(
        priceChangeReferenceDate(today: wed, unit: 'WTD', number: 1, firstDayOfWeekIndex: 1),
        DateTime(2024, 3, 11), // Monday
      );
    });

    test('Sunday-start locale (index 0): Wednesday → the preceding Sunday', () {
      expect(
        priceChangeReferenceDate(today: wed, unit: 'WTD', number: 1, firstDayOfWeekIndex: 0),
        DateTime(2024, 3, 10), // Sunday
      );
    });

    test('on a Sunday, Monday-start reaches back 6 days to that Monday', () {
      final sun = DateTime(2024, 3, 17, 8); // Sunday
      expect(
        priceChangeReferenceDate(today: sun, unit: 'WTD', number: 1, firstDayOfWeekIndex: 1),
        DateTime(2024, 3, 11), // previous Monday
      );
    });

    test('on a Sunday, Sunday-start anchors to that same day (midnight)', () {
      final sun = DateTime(2024, 3, 17, 8);
      expect(
        priceChangeReferenceDate(today: sun, unit: 'WTD', number: 1, firstDayOfWeekIndex: 0),
        DateTime(2024, 3, 17),
      );
    });

    test('on the week-start day itself, returns that day at midnight', () {
      final mon = DateTime(2024, 3, 11, 15); // Monday
      expect(
        priceChangeReferenceDate(today: mon, unit: 'WTD', number: 1, firstDayOfWeekIndex: 1),
        DateTime(2024, 3, 11),
      );
    });
  });
}
