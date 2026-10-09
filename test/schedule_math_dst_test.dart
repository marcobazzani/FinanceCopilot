// Weekly steps are calendar days. `anchor.add(Duration(days: 7 * n))` adds
// 7 x 24 hours, and a week across a daylight-saving change is 167 or 169
// hours long: in Europe/Rome the 4 weekly steps before an event on
// 2026-04-15 landed on Mar 17/24/31/Apr 7 (and the autumn change produced
// 23:00 times) instead of Mar 18/25/Apr 1/8.
//
// Expected days are written as calendar dates, so the tests hold in any time
// zone; run with TZ=Europe/Rome to see the DST case.
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/utils/schedule_math.dart';

void main() {
  bool midnight(DateTime d) => d.hour == 0 && d.minute == 0 && d.second == 0 && d.millisecond == 0 && d.microsecond == 0;

  group('weekly steps across daylight saving', () {
    test('spring: the 4 weeks before 2026-04-15', () {
      final event = DateTime(2026, 4, 15);
      final start = stepBack(event, 4, StepFrequency.weekly);
      final end = stepBack(event, 1, StepFrequency.weekly);
      expect(start, DateTime(2026, 3, 18));
      expect(end, DateTime(2026, 4, 8));
      final dates = computeStepDates(start, end, StepFrequency.weekly);
      expect(dates, [DateTime(2026, 3, 18), DateTime(2026, 3, 25), DateTime(2026, 4, 1), DateTime(2026, 4, 8)]);
      expect(dates.every(midnight), isTrue);
    });

    test('autumn: the 4 weeks before 2026-11-04', () {
      final event = DateTime(2026, 11, 4);
      final start = stepBack(event, 4, StepFrequency.weekly);
      final end = stepBack(event, 1, StepFrequency.weekly);
      final dates = computeStepDates(start, end, StepFrequency.weekly);
      expect(dates, [DateTime(2026, 10, 7), DateTime(2026, 10, 14), DateTime(2026, 10, 21), DateTime(2026, 10, 28)]);
      expect(dates.every(midnight), isTrue, reason: 'no 23:00 step');
    });

    test('forward: a schedule across both changes keeps its weekday', () {
      final dates = computeStepDates(DateTime(2026, 3, 16), DateTime(2026, 11, 2), StepFrequency.weekly);
      expect(dates.first, DateTime(2026, 3, 16));
      expect(dates.last, DateTime(2026, 11, 2));
      expect(dates.length, 34);
      for (final (i, d) in dates.indexed) {
        expect(d, DateTime(2026, 3, 16 + 7 * i), reason: 'step $i');
        expect(d.weekday, DateTime.monday, reason: 'step $i');
        expect(midnight(d), isTrue, reason: 'step $i');
      }
    });

    test('computeEndDate and computeStartDate', () {
      expect(computeEndDate(DateTime(2026, 3, 18), 4, StepFrequency.weekly), DateTime(2026, 4, 8));
      expect(computeStartDate(DateTime(2026, 11, 4), 5, StepFrequency.weekly), DateTime(2026, 10, 7));
    });
  });

  test('monthly, quarterly and yearly steps are calendar days across daylight saving', () {
    for (final (freq, expected) in [
      (StepFrequency.monthly, [DateTime(2026, 2, 28), DateTime(2026, 3, 28), DateTime(2026, 4, 28)]),
      (StepFrequency.quarterly, [DateTime(2025, 10, 28), DateTime(2026, 1, 28), DateTime(2026, 4, 28)]),
      (StepFrequency.yearly, [DateTime(2024, 10, 28), DateTime(2025, 10, 28), DateTime(2026, 10, 28)]),
    ]) {
      final dates = computeStepDates(expected.first, expected.last, freq);
      expect(dates, expected, reason: freq.name);
      expect(dates.every(midnight), isTrue, reason: freq.name);
    }
  });
}
