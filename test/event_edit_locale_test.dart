import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/utils/formatters.dart' as fmt;

// Pins the format/parse contract the event edit screen relies on:
// formatting a value with amountFormat(locale) and then parsing it back
// with tryParseLocalized(locale) must be lossless for the same locale.
//
// Prior bug: event_edit_screen.dart:73 formatted initial amounts with
// Platform.localeName while _save parsed with appLocaleProvider. When
// the two locales disagreed on decimal/thousands separators, round-trips
// drifted by 10x/100x (231 -> 231000).
void main() {
  group('amountFormat <-> tryParseLocalized round-trip', () {
    const values = [231.0, 250000.0, 0.01, 1234567.89];
    const locales = ['en_US', 'it_IT', 'de_DE', 'fr_FR'];

    for (final locale in locales) {
      for (final value in values) {
        test('$locale: $value round-trips losslessly', () {
          final text = fmt.amountFormat(locale).format(value);
          final parsed = fmt.tryParseLocalized(text, locale: locale);
          expect(parsed, isNotNull, reason: 'failed to parse "$text" in $locale');
          expect(parsed, closeTo(value, 1e-9),
              reason: '$locale round-trip of $value via "$text" returned $parsed');
        });
      }
    }

    test('it_IT formats with comma decimal and dot thousands', () {
      expect(fmt.amountFormat('it_IT').format(250000.0), '250.000,00');
      expect(fmt.amountFormat('it_IT').format(231.0), '231,00');
    });

    test('en_US formats with dot decimal and comma thousands', () {
      expect(fmt.amountFormat('en_US').format(250000.0), '250,000.00');
      expect(fmt.amountFormat('en_US').format(231.0), '231.00');
    });
  });
}
