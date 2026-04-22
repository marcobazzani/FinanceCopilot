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
