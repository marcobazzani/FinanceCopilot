import 'dart:io' show Platform;
import 'package:intl/intl.dart';

import 'amount_parser.dart' show asciiMinus, formatAmountLossless, isWellFormedNumber, stripFloatNoise;
import 'date_parser.dart' as date_parse;

/// Locale-aware number/date formatters.
/// All functions accept a locale string (e.g. 'it_IT', 'en_US').

/// Parse a number string using the configured locale's conventions.
/// Uses NumberFormat from intl to correctly handle the locale's
/// decimal/grouping separators (e.g. "1.234,56" in it_IT, "1,234.56" in en_US).
///
/// Strict: a text not spelled with exactly the locale's separators is not a
/// number in that locale and returns null. `NumberFormat.parse` alone skips
/// the grouping separator anywhere, so under it_IT "1500.0" read as 15000.
/// The Unicode minus some locales format with is a sign ([asciiMinus]).
double? tryParseLocalized(String text, {required String locale}) {
  final trimmed = asciiMinus(text).trim();
  if (trimmed.isEmpty) return null;
  try {
    final format = NumberFormat.decimalPattern(locale);
    final symbols = format.symbols;
    if (!isWellFormedNumber(trimmed, decimalSeparator: symbols.DECIMAL_SEP, groupSeparator: symbols.GROUP_SEP)) return null;
    return format.parse(trimmed).toDouble();
  } catch (_) {
    return null;
  }
}

/// [value] as an edit form pre-fills it: [display]'s spelling (the locale's
/// usual one, "1.500,00" in it_IT) when that reads back as exactly [value],
/// else every digit ([formatAmountLossless]). A stored figure the user
/// leaves alone then saves unchanged instead of rounded to the display
/// precision. The noise of the arithmetic that computed a stored figure is
/// not a digit of it ([stripFloatNoise]): 100.05000000000007 pre-fills as
/// "100,05".
String editableFigure(double value, NumberFormat display, {required String locale}) {
  final figure = stripFloatNoise(value);
  final shown = display.format(figure);
  return tryParseLocalized(shown, locale: locale) == figure ? shown : formatAmountLossless(figure, locale: locale);
}

/// An optional number field read in [locale]: `value` is null for an empty
/// field, and `invalid` marks text the locale cannot read — to be flagged on
/// the field, never saved or applied as "no value".
({double? value, bool invalid}) readOptionalNumber(String text, {required String locale}) {
  if (text.trim().isEmpty) return (value: null, invalid: false);
  final value = tryParseLocalized(text, locale: locale);
  return (value: value, invalid: value == null);
}

NumberFormat amountFormat(String locale) => NumberFormat('#,##0.00', locale);

NumberFormat qtyFormat(String locale) => NumberFormat('#,##0.####', locale);

NumberFormat currencyFormat(String locale, String symbol, {int? decimalDigits}) =>
    NumberFormat.currency(locale: locale, symbol: symbol, decimalDigits: decimalDigits);

/// Format a date as yyyy-MM-dd without DateFormat overhead.
String formatYmd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateFormat shortDateFormat(String locale) => DateFormat.yMd(locale);
DateFormat monthYearFormat(String locale) => DateFormat.yMMM(locale);
DateFormat fullDateFormat(String locale) => DateFormat.yMMMd(locale);

/// Multi-language month name → month number map.
/// Used for flexible date parsing in import and paste operations.
const monthMap = {
  // English
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  'january': 1, 'february': 2, 'march': 3, 'april': 4, 'june': 6,
  'july': 7, 'august': 8, 'september': 9, 'october': 10,
  'november': 11, 'december': 12,
  // Italian
  'gen': 1, 'mag': 5, 'giu': 6,
  'lug': 7, 'ago': 8, 'set': 9, 'ott': 10, 'dic': 12,
  'gennaio': 1, 'febbraio': 2, 'marzo': 3, 'aprile': 4, 'maggio': 5,
  'giugno': 6, 'luglio': 7, 'agosto': 8, 'settembre': 9, 'ottobre': 10,
  'novembre': 11, 'dicembre': 12,
  // German
  'jän': 1, 'mär': 3, 'mai': 5, 'okt': 10, 'dez': 12,
  // French
  'janv': 1, 'févr': 2, 'avr': 4, 'juin': 6,
  'juil': 7, 'août': 8, 'sept': 9, 'déc': 12,
  // Spanish
  'ene': 1, 'abr': 4,
};

/// Smart number parser detecting `1.234,56` (EU) vs `1,234.56` (US) formats.
double? parseFlexibleNumber(String text) {
  var s = text.replaceAll(RegExp(r'[€$£¥\s\u00A0]'), '').trim();
  if (s.isEmpty) return null;
  // EU format: dots as thousands, comma as decimal
  if (s.contains('.') && s.contains(',')) {
    // Check which comes last → that's the decimal separator
    final lastDot = s.lastIndexOf('.');
    final lastComma = s.lastIndexOf(',');
    if (lastComma > lastDot) {
      // EU: 1.234,56
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      // US: 1,234.56
      s = s.replaceAll(',', '');
    }
  } else if (s.contains(',')) {
    s = s.replaceAll(',', '.');
  }
  return double.tryParse(s);
}

/// Flexible date parser: delegates to comprehensive [date_parse.tryParseDate].
DateTime? parseFlexibleDate(String text) => date_parse.tryParseDate(text);

/// Cross-platform home directory (macOS/Linux HOME, Windows USERPROFILE).
String get homeDir => Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
