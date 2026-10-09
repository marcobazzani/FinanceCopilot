import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/utils/formatters.dart';

// tryParseLocalized used to hand the text straight to NumberFormat.parse,
// which skips the grouping separator wherever it appears: under it_IT the
// dot-decimal '1500.0' read as 15000, '0.8' as 8 and a fetched FX rate
// '1.080000' as 1080000. A text that is not spelled with the locale's own
// separators is not a number in that locale: it must be rejected, never
// read as a figure a hundred or a million times off.
void main() {
  group('tryParseLocalized rejects numbers not spelled in the locale', () {
    const itMisparses = ['1500.0', '0.8', '1.080000', '12.5', '1,234.56', '1.5,0', ',5', '5,'];
    for (final text in itMisparses) {
      test('it_IT: "$text" is not a number', () {
        expect(tryParseLocalized(text, locale: 'it_IT'), isNull);
      });
    }

    const usMisparses = ['1,5', '0,8', '12,5', '1500,0', '1.234,56', '1,5.0'];
    for (final text in usMisparses) {
      test('en_US: "$text" is not a number', () {
        expect(tryParseLocalized(text, locale: 'en_US'), isNull);
      });
    }
  });

  group('tryParseLocalized still reads the locale spelling', () {
    test('it_IT: comma decimal, dot grouping between groups of three', () {
      expect(tryParseLocalized('1.500,5', locale: 'it_IT'), 1500.5);
      expect(tryParseLocalized('1500,5', locale: 'it_IT'), 1500.5);
      expect(tryParseLocalized('1,080000', locale: 'it_IT'), 1.08);
      expect(tryParseLocalized('0,8', locale: 'it_IT'), 0.8);
      expect(tryParseLocalized('1.080', locale: 'it_IT'), 1080);
      expect(tryParseLocalized('-1.234,56', locale: 'it_IT'), closeTo(-1234.56, 1e-9));
      expect(tryParseLocalized(' 42 ', locale: 'it_IT'), 42);
    });

    test('en_US: dot decimal, comma grouping between groups of three', () {
      expect(tryParseLocalized('1500.0', locale: 'en_US'), 1500);
      expect(tryParseLocalized('0.8', locale: 'en_US'), 0.8);
      expect(tryParseLocalized('1.080000', locale: 'en_US'), 1.08);
      expect(tryParseLocalized('1,234.56', locale: 'en_US'), closeTo(1234.56, 1e-9));
      expect(tryParseLocalized('-12.5', locale: 'en_US'), -12.5);
    });
  });
}
