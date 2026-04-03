import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/utils/formatters.dart';

void main() {
  group('homeDir', () {
    test('returns non-empty string', () {
      expect(homeDir, isNotEmpty);
    });
  });

  group('tryParseLocalized', () {
    test('parses Italian format "1.234,56"', () {
      final result = tryParseLocalized('1.234,56', locale: 'it_IT');
      expect(result, closeTo(1234.56, 0.001));
    });

    test('parses English format "1,234.56"', () {
      final result = tryParseLocalized('1,234.56', locale: 'en_US');
      expect(result, closeTo(1234.56, 0.001));
    });

    test('returns null for empty string', () {
      expect(tryParseLocalized('', locale: 'en_US'), isNull);
    });

    test('returns null for whitespace-only string', () {
      expect(tryParseLocalized('   ', locale: 'en_US'), isNull);
    });

    test('returns null for non-numeric garbage', () {
      expect(tryParseLocalized('abc', locale: 'en_US'), isNull);
    });

    test('parses simple integer', () {
      final result = tryParseLocalized('42', locale: 'en_US');
      expect(result, 42.0);
    });
  });

  group('formatYmd', () {
    test('formats date as YYYY-MM-DD', () {
      expect(formatYmd(DateTime(2024, 1, 15)), '2024-01-15');
    });

    test('pads single-digit month and day', () {
      expect(formatYmd(DateTime(2024, 3, 5)), '2024-03-05');
    });

    test('handles double-digit month and day', () {
      expect(formatYmd(DateTime(2024, 12, 31)), '2024-12-31');
    });
  });

  group('currencyFormat', () {
    test('formats with EUR symbol', () {
      final fmt = currencyFormat('en_US', 'EUR');
      final result = fmt.format(1234.56);
      expect(result, contains('EUR'));
      expect(result, contains('1,234.56'));
    });

    test('formats with dollar symbol', () {
      final fmt = currencyFormat('en_US', '\$');
      final result = fmt.format(99.99);
      expect(result, contains('\$'));
      expect(result, contains('99.99'));
    });

    test('respects custom decimalDigits', () {
      final fmt = currencyFormat('en_US', 'USD', decimalDigits: 0);
      final result = fmt.format(1234.56);
      expect(result, contains('1,235'));
      expect(result, isNot(contains('.')));
    });
  });

  group('amountFormat', () {
    test('formats number with US locale', () {
      final fmt = amountFormat('en_US');
      expect(fmt.format(1234.56), '1,234.56');
    });

    test('formats number with Italian locale', () {
      final fmt = amountFormat('it_IT');
      final result = fmt.format(1234.56);
      // Italian uses dot as grouping and comma as decimal
      expect(result, '1.234,56');
    });

    test('formats zero', () {
      final fmt = amountFormat('en_US');
      expect(fmt.format(0), '0.00');
    });
  });

  group('parseFlexibleNumber', () {
    test('parses EU format "1.234,56"', () {
      expect(parseFlexibleNumber('1.234,56'), closeTo(1234.56, 0.001));
    });

    test('parses US format "1,234.56"', () {
      expect(parseFlexibleNumber('1,234.56'), closeTo(1234.56, 0.001));
    });

    test('parses number with comma as decimal (no thousands)', () {
      expect(parseFlexibleNumber('42,50'), closeTo(42.50, 0.001));
    });

    test('strips currency symbols', () {
      expect(parseFlexibleNumber('\$1,234.56'), closeTo(1234.56, 0.001));
    });

    test('returns null for empty string', () {
      expect(parseFlexibleNumber(''), isNull);
    });
  });

  group('parseFlexibleDate', () {
    test('delegates to date parser for ISO format', () {
      final result = parseFlexibleDate('2024-01-15');
      expect(result, isNotNull);
      expect(result!.year, 2024);
      expect(result.month, 1);
      expect(result.day, 15);
    });

    test('delegates to date parser for European format', () {
      final result = parseFlexibleDate('15/01/2024');
      expect(result, isNotNull);
      expect(result!.day, 15);
      expect(result.month, 1);
    });

    test('returns null for garbage input', () {
      expect(parseFlexibleDate('not-a-date'), isNull);
    });
  });

  group('qtyFormat', () {
    test('formats with up to 4 decimal places', () {
      final fmt = qtyFormat('en_US');
      expect(fmt.format(1.2345), '1.2345');
    });

    test('trims trailing zeros', () {
      final fmt = qtyFormat('en_US');
      expect(fmt.format(10.0), '10');
    });
  });

  group('monthMap', () {
    test('contains English month abbreviations', () {
      expect(monthMap['jan'], 1);
      expect(monthMap['dec'], 12);
    });

    test('contains Italian month names', () {
      expect(monthMap['gennaio'], 1);
      expect(monthMap['dicembre'], 12);
    });

    test('contains German abbreviations', () {
      expect(monthMap['mär'], 3);
      expect(monthMap['okt'], 10);
    });
  });
}
