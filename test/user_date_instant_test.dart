// A date the user types in a form is a calendar day. tryParseUserDate handed
// an ISO instant back as it was parsed — '2026-03-07T23:30:00Z' as a UTC
// DateTime with a clock time — so a form saved an instant, and the day shown
// and stored depended on the zone. It is now the local calendar day of what
// was typed, at local midnight. Expected days are derived from the zone the
// test runs in; run with TZ=Europe/Rome and TZ=UTC.
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/utils/date_parser.dart';

void main() {
  setUpAll(() async => initializeDateFormatting());

  DateTime localDayOf(DateTime instant) {
    final local = instant.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  void expectLocalDay(DateTime? parsed, DateTime expected, String what) {
    expect(parsed, expected, reason: what);
    expect(parsed!.isUtc, isFalse, reason: '$what: a local day, not an instant');
    expect([parsed.hour, parsed.minute, parsed.second, parsed.millisecond], [0, 0, 0, 0], reason: '$what: midnight');
  }

  for (final locale in ['it_IT', 'en_US']) {
    group(locale, () {
      test('an ISO instant in UTC is the local calendar day of that instant', () {
        expectLocalDay(tryParseUserDate('2026-03-07T23:30:00Z', locale: locale), localDayOf(DateTime.utc(2026, 3, 7, 23, 30)), 'Z');
        expectLocalDay(tryParseUserDate('2026-03-07T00:30:00Z', locale: locale), localDayOf(DateTime.utc(2026, 3, 7, 0, 30)), 'Z, early');
      });

      test('an ISO instant with an offset is the local calendar day of that instant', () {
        expectLocalDay(
          tryParseUserDate('2026-03-07T23:30:00+02:00', locale: locale),
          localDayOf(DateTime.utc(2026, 3, 7, 21, 30)),
          '+02:00',
        );
      });

      test('a date with a clock time is its day', () {
        expectLocalDay(tryParseUserDate('2026-03-07 14:45', locale: locale), DateTime(2026, 3, 7), 'ymd time');
        expectLocalDay(tryParseUserDate('2026-03-07T14:45:10', locale: locale), DateTime(2026, 3, 7), 'ISO local time');
      });
    });
  }

  test('plain dates are unchanged', () {
    expectLocalDay(tryParseUserDate('07/03/2026', locale: 'it_IT'), DateTime(2026, 3, 7), 'it short');
    expectLocalDay(tryParseUserDate('3/7/2026', locale: 'en_US'), DateTime(2026, 3, 7), 'en short');
    expectLocalDay(tryParseUserDate('2026-03-07', locale: 'it_IT'), DateTime(2026, 3, 7), 'ISO date');
    expect(tryParseUserDate('not a date', locale: 'it_IT'), isNull);
  });
}
