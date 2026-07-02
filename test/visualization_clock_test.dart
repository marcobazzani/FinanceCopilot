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
}
