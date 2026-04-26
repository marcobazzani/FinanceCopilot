import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/utils/date_parser.dart';

void main() {
  group('tryParseDate', () {
    test('parses ISO format "2024-01-15"', () {
      final result = tryParseDate('2024-01-15');
      expect(result, isNotNull);
      expect(result!.year, 2024);
      expect(result.month, 1);
      expect(result.day, 15);
    });

    test('parses European format "15/01/2024"', () {
      final result = tryParseDate('15/01/2024');
      expect(result, isNotNull);
      expect(result!.year, 2024);
      expect(result.month, 1);
      expect(result.day, 15);
    });

    test('rejects ambiguous "01/15/2024" with month > 12', () {
      // Old behavior silently produced March 1, 2025 by overflowing the
      // DateTime constructor. That hides bad import data — we'd rather the
      // user see a parse failure than book a transaction in the wrong year.
      expect(tryParseDate('01/15/2024'), isNull);
    });

    test('parses "15-Jan-2024"', () {
      final result = tryParseDate('15-Jan-2024');
      expect(result, isNotNull);
      expect(result!.year, 2024);
      expect(result.month, 1);
      expect(result.day, 15);
    });

    test('parses "January 15, 2024"', () {
      final result = tryParseDate('January 15, 2024');
      expect(result, isNotNull);
      expect(result!.year, 2024);
      expect(result.month, 1);
      expect(result.day, 15);
    });

    test('returns null for garbage input', () {
      expect(tryParseDate('not-a-date'), isNull);
      expect(tryParseDate('hello world'), isNull);
      expect(tryParseDate('abc/def/ghi'), isNull);
    });

    test('returns null for empty string', () {
      expect(tryParseDate(''), isNull);
    });

    test('returns null for whitespace-only string', () {
      expect(tryParseDate('   '), isNull);
    });
  });

  group('parseDate', () {
    test('parses date with time "15/01/2024 14:30:00"', () {
      final result = parseDate('15/01/2024 14:30:00');
      expect(result.year, 2024);
      expect(result.month, 1);
      expect(result.day, 15);
      expect(result.hour, 14);
      expect(result.minute, 30);
    });

    test('parses ISO with T separator "2024-01-15T10:30:00"', () {
      final result = parseDate('2024-01-15T10:30:00');
      expect(result.year, 2024);
      expect(result.month, 1);
      expect(result.day, 15);
      expect(result.hour, 10);
      expect(result.minute, 30);
    });

    test('parses compact yyyyMMdd format "20240115"', () {
      final result = parseDate('20240115');
      expect(result.year, 2024);
      expect(result.month, 1);
      expect(result.day, 15);
    });

    test('parses 2-digit year "15/01/24"', () {
      final result = parseDate('15/01/24');
      expect(result.year, 2024);
      expect(result.month, 1);
      expect(result.day, 15);
    });

    test('parses 2-digit year in 1900s "15/01/99"', () {
      final result = parseDate('15/01/99');
      expect(result.year, 1999);
    });

    test('strips surrounding quotes', () {
      final result = parseDate('"2024-01-15"');
      expect(result.year, 2024);
      expect(result.month, 1);
      expect(result.day, 15);
    });

    test('parses Italian month name "15 Gennaio 2024"', () {
      final result = parseDate('15 Gennaio 2024');
      expect(result.year, 2024);
      expect(result.month, 1);
      expect(result.day, 15);
    });

    test('parses "Feb 20, 2017" (MMM dd, yyyy)', () {
      final result = parseDate('Feb 20, 2017');
      expect(result.year, 2017);
      expect(result.month, 2);
      expect(result.day, 20);
    });

    test('parses dot-separated "15.01.2024"', () {
      final result = parseDate('15.01.2024');
      expect(result.year, 2024);
      expect(result.month, 1);
      expect(result.day, 15);
    });

    test('throws FormatException for invalid input', () {
      expect(() => parseDate('not-a-date'), throwsFormatException);
    });

    test('throws FormatException for empty string', () {
      expect(() => parseDate(''), throwsFormatException);
    });
  });

  group('ISO 8601 with timezone offset', () {
    test('"2024-01-15T10:00:00+02:00" preserves the UTC instant', () {
      // The literal numbers describe 10:00 in UTC+2, i.e. 08:00 UTC. The
      // parser must agree with Dart's DateTime.parse, not strip the offset
      // and treat 10:00 as local time.
      final parsed = parseDate('2024-01-15T10:00:00+02:00');
      final reference = DateTime.parse('2024-01-15T10:00:00+02:00');
      expect(parsed.toUtc(), reference.toUtc());
    });

    test('"2024-01-15T10:00:00Z" preserves the UTC instant', () {
      final parsed = parseDate('2024-01-15T10:00:00Z');
      final reference = DateTime.parse('2024-01-15T10:00:00Z');
      expect(parsed.toUtc(), reference.toUtc());
    });

    test('"2024-01-15T10:00:00-05:00" preserves the UTC instant', () {
      final parsed = parseDate('2024-01-15T10:00:00-05:00');
      final reference = DateTime.parse('2024-01-15T10:00:00-05:00');
      expect(parsed.toUtc(), reference.toUtc());
    });
  });

  group('Range validation', () {
    test('rejects month > 12 in dd/MM/yyyy', () {
      // Old behavior: DateTime(2024, 99, 99) silently normalized to a far
      // future date. Must throw instead.
      expect(() => parseDate('99/99/2024'), throwsFormatException);
    });

    test('rejects day > 31 in dd/MM/yyyy', () {
      expect(() => parseDate('32/01/2024'), throwsFormatException);
    });

    test('rejects month 0 and day 0', () {
      expect(() => parseDate('0/1/2024'), throwsFormatException);
      expect(() => parseDate('1/0/2024'), throwsFormatException);
    });

    test('rejects month > 12 in yyyy-MM-dd', () {
      expect(() => parseDate('2024-13-01'), throwsFormatException);
    });

    test('rejects day > 31 in yyyy-MM-dd', () {
      expect(() => parseDate('2024-01-32'), throwsFormatException);
    });

    test('still accepts valid edge values', () {
      // Boundaries that should remain valid
      expect(parseDate('31/12/2024').day, 31);
      expect(parseDate('01/01/2024').day, 1);
      expect(parseDate('2024-12-31').month, 12);
    });
  });

  group('Trailing junk', () {
    test('rejects extra characters after yyyy-MM-dd', () {
      // Without anchoring, the regex consumed the prefix and silently
      // ignored "extra", which then caused dates with TZ offsets to lose
      // their offset.
      expect(tryParseDate('2024-01-15extra'), isNull);
    });
  });
}
