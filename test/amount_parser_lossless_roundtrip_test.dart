// Regression: `formatAmountLossless` is the transport format between XLSX/
// formula parsing and the locale-aware `parseAmount`, so everything it emits
// MUST parse back to the same value.
//
// `double.toString()` switches to scientific notation outside roughly
// 1e-6..1e21 (0.0000001 → "1e-7"), and `NumberFormat` cannot read that back:
// `tryParseAmount` returns null and the value silently disappears from the
// import. Small share quantities and high-precision FX rates land exactly in
// that range.

import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/utils/amount_parser.dart';

void main() {
  // Locales with '.' and ',' decimal separators — the swap must not disturb
  // the digits themselves.
  const locales = ['en_US', 'it_IT', 'de_DE', 'fr_FR'];

  void expectRoundTrip(double value, {String? reason}) {
    for (final locale in locales) {
      final text = formatAmountLossless(value, locale: locale);
      expect(
        text.toLowerCase(),
        isNot(contains('e')),
        reason: '$locale: "$text" uses scientific notation, which parseAmount cannot read',
      );
      expect(
        tryParseAmount(text, locale: locale),
        value,
        reason: reason == null ? '$locale: "$text"' : '$locale: "$text" — $reason',
      );
    }
  }

  test('sub-1e-6 magnitudes round-trip instead of vanishing', () {
    expectRoundTrip(0.0000001, reason: 'double.toString() gives 1e-7');
    expectRoundTrip(1e-7);
    expectRoundTrip(2.5e-8);
    expectRoundTrip(1.234567e-9);
    expectRoundTrip(-0.0000001, reason: 'sign must survive the exponent expansion');
    expectRoundTrip(-3.75e-8);
  });

  test('very large magnitudes round-trip', () {
    expectRoundTrip(1e21);
    expectRoundTrip(1.5e22);
    expectRoundTrip(-1e21);
  });

  test('ordinary amounts keep full precision and no float noise', () {
    for (final locale in locales) {
      expect(formatAmountLossless(7707.97, locale: locale), anyOf('7707.97', '7707,97'));
      expect(tryParseAmount(formatAmountLossless(7707.97, locale: locale), locale: locale), 7707.97);
    }
    expectRoundTrip(0.00012345);
    expectRoundTrip(1.0000000001);
    expectRoundTrip(-42.5);
  });

  test('whole numbers stay un-suffixed', () {
    for (final locale in locales) {
      expect(formatAmountLossless(1234, locale: locale), '1234');
      expect(formatAmountLossless(0, locale: locale), '0');
      expect(formatAmountLossless(-7, locale: locale), '-7');
    }
  });

  test('a quantity too small for the old 3-digit rounding survives', () {
    // NumberFormat.decimalPattern would have rendered this as "0".
    const tinyQuantity = 0.00012345;
    for (final locale in locales) {
      final text = formatAmountLossless(tinyQuantity, locale: locale);
      expect(tryParseAmount(text, locale: locale), tinyQuantity);
      expect(text, isNot('0'));
    }
  });
}
