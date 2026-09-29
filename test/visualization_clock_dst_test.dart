// Calendar-day helpers on the two daylight-saving change days.
//
// `Duration(days: 1)` is 24 hours of elapsed time, not one calendar day: in a
// zone with daylight saving the spring-forward day is 23 hours long and the
// fall-back day 25. "Next local midnight" computed as midnight + 24 h was an
// hour late in March and an hour early in October — after 23:00 on the
// October change day the day-rollover timer got a NEGATIVE delay, fired at
// once, re-armed itself with the same negative delay and kept re-firing until
// midnight.
//
// These cases only bite when the suite runs in a zone with daylight saving
// (e.g. Europe/Rome); in UTC they are ordinary days and must pass all the same.

import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/utils/visualization_clock.dart';

void main() {
  test('startOfNextDay is the next local midnight, also across a DST change and month/year ends', () {
    for (final (value, expected) in [
      (DateTime(2026, 6, 10), DateTime(2026, 6, 11)),
      (DateTime(2026, 6, 10, 23, 59, 59), DateTime(2026, 6, 11)),
      (DateTime(2026, 3, 29), DateTime(2026, 3, 30)), // 23 h long in Europe/Rome
      (DateTime(2026, 3, 29, 12), DateTime(2026, 3, 30)),
      (DateTime(2026, 10, 25), DateTime(2026, 10, 26)), // 25 h long in Europe/Rome
      (DateTime(2026, 10, 25, 23, 30), DateTime(2026, 10, 26)),
      (DateTime(2026, 2, 28), DateTime(2026, 3, 1)),
      (DateTime(2024, 2, 28), DateTime(2024, 2, 29)),
      (DateTime(2026, 12, 31, 18), DateTime(2027, 1, 1)),
    ]) {
      final next = startOfNextDay(value);
      expect(next, expected, reason: '$value');
      expect((next.hour, next.minute, next.second), (0, 0, 0), reason: 'a local midnight ($value)');
    }
  });

  test('throughEndExclusive bounds an as-of read at the next midnight; null means unbounded', () {
    expect(throughEndExclusive(null), isNull);
    expect(throughEndExclusive(DateTime(2026, 10, 25)), DateTime(2026, 10, 26));
    expect(throughEndExclusive(DateTime(2026, 3, 29, 15, 42)), DateTime(2026, 3, 30));
  });

  test('durationUntilNextDay lands just after the next local midnight on the DST change days', () {
    for (final (now, nextMidnight) in [
      (DateTime(2026, 3, 29, 0, 30), DateTime(2026, 3, 30)), // spring-forward day, 23 h in Europe/Rome
      (DateTime(2026, 3, 29, 23, 30), DateTime(2026, 3, 30)),
      (DateTime(2026, 3, 28, 12), DateTime(2026, 3, 29)), // the day before: midnight is still there
      (DateTime(2026, 10, 25, 0, 30), DateTime(2026, 10, 26)), // fall-back day, 25 h in Europe/Rome
      (DateTime(2026, 10, 25, 23, 30), DateTime(2026, 10, 26)), // after the old midnight + 24 h
      (DateTime(2026, 10, 24, 12), DateTime(2026, 10, 25)),
    ]) {
      final wait = durationUntilNextDay(now);
      expect(wait.isNegative, isFalse, reason: 'a negative delay re-fires the rollover timer at once ($now)');
      expect(now.add(wait), nextMidnight.add(const Duration(seconds: 1)), reason: 'fires one second after the next midnight ($now)');
    }
  });
}
