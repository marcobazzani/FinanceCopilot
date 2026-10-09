import 'package:flutter_test/flutter_test.dart';
import 'package:finance_copilot/utils/chart_math.dart';

void main() {
  group('calendarDaysBetween / dateAddDays — DST-safe chart day math', () {
    // Regression pin for the "chart shows yesterday's date" bug: a naive
    // `to.difference(from).inDays` between two LOCAL midnights that straddle a
    // DST change (winter firstDate → summer point) truncates by one, so every
    // summer date was labelled a day early. UTC-normalized math is exact.
    test('winter → summer counts exact calendar days (Jan 2 → Sep 4, 2026 = 245)', () {
      final from = DateTime(2026, 1, 2); // winter (CET / UTC+1 in Europe)
      final to = DateTime(2026, 9, 4); // summer (CEST / UTC+2 in Europe)
      expect(calendarDaysBetween(from, to), 245);
    });

    test('reverse map lands on the correct calendar date (no off-by-one)', () {
      final from = DateTime(2026, 1, 2);
      final d = dateAddDays(from, 245);
      expect([d.year, d.month, d.day], [2026, 9, 4]);
    });

    test('forward/reverse round-trip across a range of offsets', () {
      final from = DateTime(2026, 1, 2);
      for (final off in [0, 1, 30, 58, 120, 245, 365]) {
        expect(calendarDaysBetween(from, dateAddDays(from, off)), off);
      }
    });

    test('time-of-day is ignored; same day is 0', () {
      final d = DateTime(2026, 6, 15, 13, 45);
      expect(calendarDaysBetween(d, DateTime(2026, 6, 15)), 0);
      expect(calendarDaysBetween(DateTime(2026, 6, 15), d), 0);
    });
  });
}
