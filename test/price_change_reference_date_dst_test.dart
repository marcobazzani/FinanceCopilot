// The price-change reference date across a daylight-saving change (Europe/Rome
// dates). A day there is 23 or 25 hours long on a change, so stepping back
// N × 24 hours from local midnight lands at 23:00 of the calendar day before
// the one meant: '1w' on 2026-04-02 compared with 25 March instead of 26
// March. Every period steps back in calendar days. The expectations hold in
// any time zone; run under TZ=Europe/Rome to exercise the change itself.
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show priceChangeReferenceDate;

void main() {
  DateTime reference(DateTime today, String unit, {int number = 1, int firstDayOfWeekIndex = 1}) =>
      priceChangeReferenceDate(today: today, unit: unit, number: number, firstDayOfWeekIndex: firstDayOfWeekIndex);

  group('after the spring-forward of 29 March 2026', () {
    test('1w on 2 April compares with 26 March', () {
      expect(reference(DateTime(2026, 4, 2), 'w'), DateTime(2026, 3, 26));
    });

    test('1d on 30 March compares with 29 March', () {
      expect(reference(DateTime(2026, 3, 30), 'd'), DateTime(2026, 3, 29));
    });

    test('a relative step keeps the time of day', () {
      expect(reference(DateTime(2026, 3, 30, 1, 30), 'd'), DateTime(2026, 3, 29, 1, 30));
      expect(reference(DateTime(2026, 4, 5, 0, 15), 'w', number: 2), DateTime(2026, 3, 22, 0, 15));
    });

    test('WTD on Thursday 2 April anchors to Sunday 29 March, the day before the week start', () {
      expect(reference(DateTime(2026, 4, 2), 'WTD'), DateTime(2026, 3, 29));
    });

    test('an unknown unit falls back to the calendar day before', () {
      expect(reference(DateTime(2026, 3, 30), '?'), DateTime(2026, 3, 29));
    });
  });

  test('MTD in a year whose DST starts on 31 March anchors to 31 March', () {
    expect(reference(DateTime(2024, 4, 10), 'MTD'), DateTime(2024, 3, 31));
    expect(reference(DateTime(2024, 4, 1, 9), 'MTD'), DateTime(2024, 3, 31));
  });

  test('YTD anchors to 31 December of the previous year', () {
    expect(reference(DateTime(2026, 7, 1), 'YTD'), DateTime(2025, 12, 31));
    expect(reference(DateTime(2026, 1, 1), 'YTD'), DateTime(2025, 12, 31));
  });

  group('after the fall-back of 25 October 2026', () {
    test('1w and 1d land on midnight of the calendar day', () {
      expect(reference(DateTime(2026, 10, 26), 'w'), DateTime(2026, 10, 19));
      expect(reference(DateTime(2026, 10, 26), 'd'), DateTime(2026, 10, 25));
    });

    test('WTD on Wednesday 28 October anchors to Sunday 25 October', () {
      expect(reference(DateTime(2026, 10, 28), 'WTD'), DateTime(2026, 10, 25));
    });
  });
}
