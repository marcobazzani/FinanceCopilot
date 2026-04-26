import 'package:flutter_test/flutter_test.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/utils/schedule_math.dart';

void main() {
  group('addMonthsClamped — forward', () {
    test('adds months within the same year', () {
      expect(addMonthsClamped(DateTime(2024, 3, 15), 2), DateTime(2024, 5, 15));
    });

    test('rolls into next year', () {
      expect(addMonthsClamped(DateTime(2024, 11, 10), 3), DateTime(2025, 2, 10));
    });

    test('clamps day to last day of target month', () {
      expect(addMonthsClamped(DateTime(2024, 1, 31), 1), DateTime(2024, 2, 29));
      expect(addMonthsClamped(DateTime(2023, 1, 31), 1), DateTime(2023, 2, 28));
      expect(addMonthsClamped(DateTime(2024, 3, 31), 1), DateTime(2024, 4, 30));
    });

    test('crosses December into January correctly', () {
      expect(addMonthsClamped(DateTime(2024, 12, 31), 1), DateTime(2025, 1, 31));
    });
  });

  group('addMonthsClamped — backward', () {
    test('subtracts months within the same year', () {
      expect(addMonthsClamped(DateTime(2024, 5, 15), -2), DateTime(2024, 3, 15));
    });

    test('subtracting one month from January goes to previous year December', () {
      // This case fails with truncating division; floor division is required.
      expect(addMonthsClamped(DateTime(2024, 1, 15), -1), DateTime(2023, 12, 15));
    });

    test('subtracting two months from January goes to previous year November', () {
      expect(addMonthsClamped(DateTime(2024, 1, 15), -2), DateTime(2023, 11, 15));
    });

    test('subtracting three months from February crosses year boundary', () {
      expect(addMonthsClamped(DateTime(2024, 2, 15), -3), DateTime(2023, 11, 15));
    });

    test('subtracting twelve months goes back exactly one year', () {
      expect(addMonthsClamped(DateTime(2024, 6, 15), -12), DateTime(2023, 6, 15));
    });

    test('subtracting thirteen months goes back one year and one month', () {
      expect(addMonthsClamped(DateTime(2024, 6, 15), -13), DateTime(2023, 5, 15));
    });

    test('clamps day when retreating into a shorter month', () {
      // Mar 31 - 1 month -> Feb 29 (2024 is a leap year)
      expect(addMonthsClamped(DateTime(2024, 3, 31), -1), DateTime(2024, 2, 29));
      // Mar 31 - 1 month -> Feb 28 (2023 non-leap)
      expect(addMonthsClamped(DateTime(2023, 3, 31), -1), DateTime(2023, 2, 28));
    });
  });

  group('computeStartDate', () {
    test('5 monthly steps back from Mar 2025 yields Nov 2024', () {
      // stepCount=5, stepping back 4 times: Mar25 -> Feb25 -> Jan25 -> Dec24 -> Nov24
      final start = computeStartDate(DateTime(2025, 3, 15), 5, StepFrequency.monthly);
      expect(start, DateTime(2024, 11, 15));
    });

    test('quarterly steps back across year boundary', () {
      // 3 quarterly steps back from Apr 2025 -> Jan 2025 -> Oct 2024
      final start = computeStartDate(DateTime(2025, 4, 1), 3, StepFrequency.quarterly);
      expect(start, DateTime(2024, 10, 1));
    });

    test('yearly steps subtract one year per step', () {
      final start = computeStartDate(DateTime(2025, 6, 15), 4, StepFrequency.yearly);
      expect(start, DateTime(2022, 6, 15));
    });
  });

  group('month-end anchor preservation (no drift)', () {
    // Iterating addMonthsClamped step-by-step would drift Jan 31 ->
    // Feb 29 -> Mar 29 -> Apr 29 ... once Feb shrinks the day, every later
    // month inherits the shrunken day. A correct schedule should re-anchor
    // to the original start day so March goes back to 31, etc.

    test('monthly schedule from Jan 31 stays anchored at end-of-month', () {
      final dates = computeStepDates(
        DateTime(2024, 1, 31),
        DateTime(2024, 7, 31),
        StepFrequency.monthly,
      );
      expect(dates, [
        DateTime(2024, 1, 31),
        DateTime(2024, 2, 29),
        DateTime(2024, 3, 31),
        DateTime(2024, 4, 30),
        DateTime(2024, 5, 31),
        DateTime(2024, 6, 30),
        DateTime(2024, 7, 31),
      ]);
    });

    test('quarterly schedule from Nov 30 anchors to original day', () {
      // Nov 30 + 3 months -> Feb 28 (or 29). Without re-anchoring, the next
      // quarter would be May 28 instead of May 30.
      final dates = computeStepDates(
        DateTime(2024, 11, 30),
        DateTime(2025, 8, 30),
        StepFrequency.quarterly,
      );
      expect(dates, [
        DateTime(2024, 11, 30),
        DateTime(2025, 2, 28),
        DateTime(2025, 5, 30),
        DateTime(2025, 8, 30),
      ]);
    });

    test('computeEndDate does not drift across short months', () {
      // 7 monthly steps from Jan 31 -> July 31, not Jul 29.
      final end = computeEndDate(
        DateTime(2024, 1, 31), 7, StepFrequency.monthly);
      expect(end, DateTime(2024, 7, 31));
    });

    test('computeStartDate does not drift across short months', () {
      // 7 monthly steps back from Jul 31 should land on Jan 31, not Jan 29.
      final start = computeStartDate(
        DateTime(2024, 7, 31), 7, StepFrequency.monthly);
      expect(start, DateTime(2024, 1, 31));
    });

    test('yearly schedule from Feb 29 of a leap year', () {
      // Feb 29 2024 + 1 year -> Feb 28 2025 (no Feb 29). Then +1 year ->
      // Feb 28 2026 if we drift, but Feb 29 isn't valid; expected: Feb 28.
      // The +4 step IS Feb 29 2028 (leap year again) — original day must
      // be re-tried.
      final dates = computeStepDates(
        DateTime(2024, 2, 29),
        DateTime(2028, 2, 29),
        StepFrequency.yearly,
      );
      expect(dates, [
        DateTime(2024, 2, 29),
        DateTime(2025, 2, 28),
        DateTime(2026, 2, 28),
        DateTime(2027, 2, 28),
        DateTime(2028, 2, 29),
      ]);
    });
  });
}
