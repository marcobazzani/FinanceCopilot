import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:finance_copilot/utils/date_parser.dart';

// Forms pre-fill dates with DateFormat.yMd(locale) but used to read them back
// with the day-first parser only: under en_US the pre-filled "3/7/2026"
// (March 7) was saved as 3 July and a typed "9/27/2026" was rejected.
// tryParseUserDate reads the locale's own short date first and only then
// falls back to the comprehensive day-first parser.
void main() {
  setUpAll(() async => initializeDateFormatting());

  group('tryParseUserDate — en_US (month first)', () {
    const locale = 'en_US';

    test('reads the locale short date month-first', () {
      expect(tryParseUserDate('3/7/2026', locale: locale), DateTime(2026, 3, 7));
      expect(tryParseUserDate('03/07/2026', locale: locale), DateTime(2026, 3, 7));
    });

    test('accepts a day above 12 in the day position', () {
      expect(tryParseUserDate('9/27/2026', locale: locale), DateTime(2026, 9, 27));
    });

    test('a two-digit year keeps the month-first order', () {
      expect(tryParseUserDate('3/7/26', locale: locale), DateTime(2026, 3, 7));
    });

    test('falls back to the comprehensive parser for other shapes', () {
      expect(tryParseUserDate('2026-03-07', locale: locale), DateTime(2026, 3, 7));
      expect(tryParseUserDate(' 7 Mar 2026 ', locale: locale), DateTime(2026, 3, 7));
    });

    test('rejects what neither parser reads', () {
      expect(tryParseUserDate('', locale: locale), isNull);
      expect(tryParseUserDate('not a date', locale: locale), isNull);
      expect(tryParseUserDate('2/30/2026', locale: locale), isNull);
      expect(tryParseUserDate('13/13/2026', locale: locale), isNull);
    });

    test('a one- or three-digit year is not read as a year of antiquity', () {
      expect(tryParseUserDate('3/7/5', locale: locale), isNull);
      expect(tryParseUserDate('3/7/126', locale: locale), isNull);
    });
  });

  group('tryParseUserDate — it_IT (day first)', () {
    const locale = 'it_IT';

    test('reads the locale short date day-first', () {
      expect(tryParseUserDate('07/03/2026', locale: locale), DateTime(2026, 3, 7));
      expect(tryParseUserDate('3/7/2026', locale: locale), DateTime(2026, 7, 3));
      expect(tryParseUserDate('27/09/2026', locale: locale), DateTime(2026, 9, 27));
    });

    test('a two-digit year keeps the day-first order', () {
      expect(tryParseUserDate('07/03/26', locale: locale), DateTime(2026, 3, 7));
    });

    test('falls back to the comprehensive parser for other shapes', () {
      expect(tryParseUserDate('2026-03-07', locale: locale), DateTime(2026, 3, 7));
      expect(tryParseUserDate('7 marzo 2026', locale: locale), DateTime(2026, 3, 7));
    });

    test('a month above 12 is rejected, not swapped', () {
      expect(tryParseUserDate('9/27/2026', locale: locale), isNull);
    });
  });

  test('every supported locale reads back its own pre-filled short date', () {
    final dates = [DateTime(2026, 1, 1), DateTime(2026, 3, 7), DateTime(2026, 9, 27), DateTime(2026, 12, 31)];
    for (final locale in ['en_US', 'en_GB', 'it_IT', 'de_DE', 'fr_FR', 'es_ES']) {
      for (final d in dates) {
        final text = DateFormat.yMd(locale).format(d);
        expect(tryParseUserDate(text, locale: locale), d, reason: '$locale "$text"');
      }
    }
  });

  // Pins the dd/MM/yy century rule the user-date parser shares.
  test('parseDate two-digit year century boundary: 50 → 2050, 51 → 1951', () {
    expect(parseDate('15/01/50'), DateTime(2050, 1, 15));
    expect(parseDate('15/01/51'), DateTime(1951, 1, 15));
    expect(parseDate('15/01/00'), DateTime(2000, 1, 15));
  });
}
