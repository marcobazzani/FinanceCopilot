import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/utils/visualization_clock.dart';

void main() {
  test('dateOnly strips the time component', () {
    expect(dateOnly(DateTime(2026, 5, 30, 14, 15)), DateTime(2026, 5, 30));
  });

  test('lastCompletedMonthEnd returns the prior month end', () {
    expect(lastCompletedMonthEnd(DateTime(2026, 5, 30)), DateTime(2026, 4, 30));
    expect(lastCompletedMonthEnd(DateTime(2026, 3, 1)), DateTime(2026, 2, 28));
    expect(lastCompletedMonthEnd(DateTime(2024, 3, 1)), DateTime(2024, 2, 29));
    expect(
      lastCompletedMonthEnd(DateTime(2026, 1, 15)),
      DateTime(2025, 12, 31),
    );
  });

  test('lastCompletedYearEnd returns the prior year end', () {
    expect(lastCompletedYearEnd(DateTime(2026, 5, 30)), DateTime(2025, 12, 31));
    expect(lastCompletedYearEnd(DateTime(2026, 1, 1)), DateTime(2025, 12, 31));
  });

  test('nextMonthEnd returns the current month end (wayforward)', () {
    expect(nextMonthEnd(DateTime(2026, 5, 15)), DateTime(2026, 5, 31));
    expect(nextMonthEnd(DateTime(2026, 2, 1)), DateTime(2026, 2, 28));
    expect(nextMonthEnd(DateTime(2024, 2, 1)), DateTime(2024, 2, 29)); // leap
    expect(nextMonthEnd(DateTime(2026, 12, 10)), DateTime(2026, 12, 31)); // year wrap
    // On a month-end the result is that same day.
    expect(nextMonthEnd(DateTime(2026, 4, 30)), DateTime(2026, 4, 30));
  });

  test('nextYearEnd returns the current year end (wayforward)', () {
    expect(nextYearEnd(DateTime(2026, 5, 30)), DateTime(2026, 12, 31));
    expect(nextYearEnd(DateTime(2026, 1, 1)), DateTime(2026, 12, 31));
    expect(nextYearEnd(DateTime(2026, 12, 31)), DateTime(2026, 12, 31));
  });

  test('durationUntilNextDay counts down to just after the next midnight', () {
    // 00:43 -> 23h17m until midnight, +1s guard.
    expect(
      durationUntilNextDay(DateTime(2026, 7, 2, 0, 43)),
      const Duration(hours: 23, minutes: 17, seconds: 1),
    );
    // Just before midnight.
    expect(
      durationUntilNextDay(DateTime(2026, 7, 2, 23, 59, 30)),
      const Duration(seconds: 31),
    );
    // Exactly at midnight -> a full day (+1s) to the next one.
    expect(
      durationUntilNextDay(DateTime(2026, 7, 2, 0, 0, 0)),
      const Duration(days: 1, seconds: 1),
    );
    // Always strictly positive and within a day (+ the 1s guard).
    for (final now in [
      DateTime(2026, 1, 1, 0, 0, 1),
      DateTime(2026, 6, 15, 12, 34, 56),
      DateTime(2024, 2, 29, 18, 0),
    ]) {
      final d = durationUntilNextDay(now);
      expect(d.inMilliseconds, greaterThan(0));
      expect(d, lessThanOrEqualTo(const Duration(days: 1, seconds: 1)));
    }
  });
}
