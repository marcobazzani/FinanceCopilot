import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/utils/amount_parser.dart';

void main() {
  group('parseAmount with locale', () {
    test('it_IT: comma is decimal, dot is thousands', () {
      expect(parseAmount('80,000', locale: 'it_IT'), 80.0);
      expect(parseAmount('81,050', locale: 'it_IT'), closeTo(81.05, 1e-9));
      expect(parseAmount('5.975,00', locale: 'it_IT'), 5975.0);
      expect(parseAmount('1.234.567', locale: 'it_IT'), 1234567.0);
      expect(parseAmount('10.000,000', locale: 'it_IT'), 10000.0);
      expect(parseAmount('-384,60', locale: 'it_IT'), closeTo(-384.6, 1e-9));
    });

    test('en_US: comma is thousands, dot is decimal', () {
      expect(parseAmount('80,000', locale: 'en_US'), 80000.0);
      expect(parseAmount('1,234.56', locale: 'en_US'), closeTo(1234.56, 1e-9));
      expect(parseAmount('5,975.00', locale: 'en_US'), 5975.0);
      expect(parseAmount('1,234,567', locale: 'en_US'), 1234567.0);
    });

    test('de_DE: comma decimal, dot thousands', () {
      expect(parseAmount('1.234.567', locale: 'de_DE'), 1234567.0);
      expect(parseAmount('1.234,56', locale: 'de_DE'), closeTo(1234.56, 1e-9));
    });

    test('strips currency symbols and whitespace', () {
      expect(parseAmount('€ 1.234,56', locale: 'it_IT'), closeTo(1234.56, 1e-9));
      expect(parseAmount('\$1,234.56', locale: 'en_US'), closeTo(1234.56, 1e-9));
      expect(parseAmount(' 80,000 ', locale: 'it_IT'), 80.0);
    });

    test('throws on empty', () {
      expect(() => parseAmount('', locale: 'it_IT'), throwsFormatException);
    });

    test('throws on garbage', () {
      expect(() => parseAmount('abc', locale: 'it_IT'), throwsFormatException);
    });
  });

  group('a number spelled in the other locale is rejected, never silently rescaled', () {
    // Regression: a dot-decimal export ("-258.35") loaded under it_IT used to
    // parse as -25835 — every amount x100, balance off by thousands.
    test('it_IT rejects dot-decimal and US grouping', () {
      for (final bad in ['-258.35', '697.71', '600.00', '2,000.00', '1,003.98', '0.5']) {
        expect(() => parseAmount(bad, locale: 'it_IT'), throwsFormatException, reason: bad);
        expect(tryParseAmount(bad, locale: 'it_IT'), isNull, reason: bad);
      }
    });
    test('en_US rejects comma-decimal and EU grouping', () {
      for (final bad in ['-90,5', '1.003,98', '5.975,00', '0,5']) {
        expect(() => parseAmount(bad, locale: 'en_US'), throwsFormatException, reason: bad);
      }
    });
    test('well-formed numbers of each locale still parse, including grouping and no fraction', () {
      expect(parseAmount('1.003,98', locale: 'it_IT'), 1003.98);
      expect(parseAmount('-90,5', locale: 'it_IT'), -90.5);
      expect(parseAmount('5000', locale: 'it_IT'), 5000);
      expect(parseAmount('1.234.567', locale: 'it_IT'), 1234567);
      expect(parseAmount('2,000.00', locale: 'en_US'), 2000);
      expect(parseAmount('-258.35', locale: 'en_US'), -258.35);
      expect(parseAmount('€ 1,003.98', locale: 'en_US'), 1003.98);
      expect(parseAmount('+12', locale: 'en_US'), 12);
    });
    test('malformed grouping is rejected in both', () {
      expect(tryParseAmount('12.34.56', locale: 'it_IT'), isNull);
      expect(tryParseAmount('1.23,45', locale: 'it_IT'), isNull, reason: 'group of two digits');
      expect(tryParseAmount('1,23.45', locale: 'en_US'), isNull);
      expect(tryParseAmount('12abc', locale: 'en_US'), isNull);
    });
    test('isWellFormedNumber with a space group separator (fr_FR style)', () {
      expect(isWellFormedNumber('1\u202F234,56', decimalSeparator: ',', groupSeparator: '\u202F'), isTrue);
      expect(isWellFormedNumber('1 234,56', decimalSeparator: ',', groupSeparator: '\u00A0'), isTrue);
      expect(isWellFormedNumber('1234.56', decimalSeparator: ',', groupSeparator: '\u00A0'), isFalse);
    });
  });

  group('tryParseAmount', () {
    test('returns null on empty/null', () {
      expect(tryParseAmount(null, locale: 'it_IT'), isNull);
      expect(tryParseAmount('', locale: 'it_IT'), isNull);
      expect(tryParseAmount('   ', locale: 'it_IT'), isNull);
    });

    test('returns null on garbage', () {
      expect(tryParseAmount('abc', locale: 'it_IT'), isNull);
    });

    test('parses valid input', () {
      expect(tryParseAmount('80,000', locale: 'it_IT'), 80.0);
    });
  });

  group('resolveImportLocale', () {
    test('saved wins over appLocale', () {
      expect(
        resolveImportLocale(saved: 'en_US', appLocale: 'it_IT'),
        'en_US',
      );
    });

    test('falls back to appLocale when saved is null', () {
      expect(
        resolveImportLocale(saved: null, appLocale: 'it_IT'),
        'it_IT',
      );
    });

    test('falls back to en_US when both null', () {
      expect(
        resolveImportLocale(saved: null, appLocale: null),
        'en_US',
      );
    });
  });
}
