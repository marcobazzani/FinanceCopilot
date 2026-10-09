// Some locales spell a negative number with the Unicode minus sign U+2212
// (sv_SE formats -1234.5 as "−1 234,50"), and the strict number check only
// knew the ASCII hyphen: the app could not read back a figure it had itself
// formatted in such a locale. The Unicode minus is read as '-'.
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:finance_copilot/utils/amount_parser.dart';
import 'package:finance_copilot/utils/formatters.dart' as fmt;

void main() {
  const minus = '\u2212';

  test('the formatted figure of a Unicode-minus locale reads back', () {
    for (final locale in ['sv_SE', 'nb_NO', 'fi_FI']) {
      for (final v in [-1234.5, -0.05, -1000000.0]) {
        final text = fmt.amountFormat(locale).format(v);
        expect(text, startsWith(minus), reason: '$locale spells "$text" with U+2212');
        expect(parseAmount(text, locale: locale), v, reason: '$locale "$text"');
        expect(tryParseAmount(text, locale: locale), v, reason: '$locale "$text"');
        expect(fmt.tryParseLocalized(text, locale: locale), v, reason: '$locale "$text"');
      }
    }
  });

  test('isWellFormedNumber accepts the Unicode minus as a sign', () {
    expect(isWellFormedNumber('${minus}1\u00A0234,50', decimalSeparator: ',', groupSeparator: '\u00A0'), isTrue);
    expect(isWellFormedNumber('${minus}258.35', decimalSeparator: '.', groupSeparator: ','), isTrue);
  });

  test('it is still only a sign', () {
    for (final text in [minus, '$minus$minus 5', '5$minus', '1${minus}2', '$minus-5']) {
      expect(
        isWellFormedNumber(text, decimalSeparator: '.', groupSeparator: ','),
        isFalse,
        reason: '"$text"',
      );
      expect(tryParseAmount(text, locale: 'en_US'), isNull, reason: '"$text"');
    }
  });

  test('a locale with an ASCII minus is unchanged', () {
    expect(parseAmount('-1.234,50', locale: 'it_IT'), -1234.5);
    expect(parseAmount(NumberFormat('#,##0.00', 'en_US').format(-1234.5), locale: 'en_US'), -1234.5);
    expect(fmt.tryParseLocalized('-258.35', locale: 'it_IT'), isNull, reason: 'still strict about the separators');
  });
}
