import 'package:intl/intl.dart';

/// Why [parseAmount] rejected a text. Still a [FormatException] whose message
/// is the English one the logs show, plus what was read and in which number
/// format, so a caller can word the problem in the user's language.
class AmountParseException extends FormatException {
  /// The text that was read.
  final String raw;

  /// The number format it was read with.
  final String locale;

  /// There was nothing to read (only blanks or a currency symbol).
  final bool empty;

  const AmountParseException(super.message, {required this.raw, required this.locale, this.empty = false});
}

/// Parses an amount/balance string under the given locale.
///
/// Locale must be an ICU locale tag the app uses (e.g. `it_IT`, `en_US`,
/// `de_DE`, `fr_FR`, `es_ES`, `en_GB`). The decimal/thousands separators
/// come from the locale — no heuristic guessing. Throws
/// [AmountParseException] when [s] is not a number in [locale].
double parseAmount(String s, {required String locale}) {
  final cleaned = asciiMinus(s.replaceAll(RegExp(r'[€$£¥]'), '')).trim();
  if (cleaned.isEmpty) throw AmountParseException('Empty amount', raw: s, locale: locale, empty: true);
  final symbols = NumberFormat.decimalPattern(locale).symbols;
  if (!isWellFormedNumber(cleaned, decimalSeparator: symbols.DECIMAL_SEP, groupSeparator: symbols.GROUP_SEP)) {
    throw AmountParseException('"$s" is not a number in $locale', raw: s, locale: locale);
  }
  return NumberFormat.decimalPattern(locale).parse(cleaned).toDouble();
}

/// [text] with the minus sign U+2212 some locales format negative numbers
/// with (sv_SE: "−1 234,50") replaced by '-', which every locale's parser
/// reads.
String asciiMinus(String text) => text.replaceAll('\u2212', '-');

/// Whether [text] is a number spelled with exactly this locale's separators:
/// an optional sign, digits, the group separator only between groups of
/// three digits, the decimal separator at most once, nothing else. The sign
/// may be the Unicode minus the locale formats it with ([asciiMinus]).
///
/// `NumberFormat.parse` is lenient: under `it_IT` it reads `-258.35` as
/// −25835 because it treats the dot as grouping regardless of what follows.
/// A dot-decimal export loaded under a comma-decimal locale then imports
/// every amount a hundred times too big and nothing flags it. A string that
/// does not fit the locale's shape is not a number in that locale and must
/// fail, so the row shows up as an error instead of a wrong figure.
bool isWellFormedNumber(String text, {required String decimalSeparator, required String groupSeparator}) {
  var t = asciiMinus(text).replaceAll('\u00A0', ' ').replaceAll('\u202F', ' ').trim();
  if (t.startsWith('+') || t.startsWith('-')) t = t.substring(1);
  if (t.isEmpty) return false;
  final g = RegExp.escape(groupSeparator == '\u00A0' || groupSeparator == '\u202F' ? ' ' : groupSeparator);
  final d = RegExp.escape(decimalSeparator);
  // digits with optional 3-digit groups, then an optional fraction.
  final re = RegExp('^(\\d{1,3}($g\\d{3})*|\\d+)($d\\d+)?\$');
  return re.hasMatch(t);
}

/// Like [parseAmount] but returns null on null/empty/parse-failure.
double? tryParseAmount(String? s, {required String locale}) {
  if (s == null || s.trim().isEmpty) return null;
  try {
    return parseAmount(s, locale: locale);
  } catch (_) {
    return null;
  }
}

/// [v] without the noise binary arithmetic leaves on a decimal figure
/// (`1100.15 − 1000.10` is 100.05000000000007): rounded to 15 significant
/// digits, which a real 2–6-decimal figure fits in, so such a figure comes
/// back exactly.
///
/// A sum or difference carries the noise of its largest term, not its own:
/// `12345.62 − 12345.67` is −0.049999999999272404, whose first 15 digits are
/// still noise. Pass that term's size as [magnitude] and the 15 digits are
/// counted from it instead (here −0.05). A [magnitude] no larger than [v]
/// changes nothing.
double stripFloatNoise(double v, {double magnitude = 0}) {
  if (!v.isFinite) return v;
  final scale = magnitude.abs();
  if (scale <= v.abs()) return double.parse(v.toStringAsPrecision(15));
  // The decimals 15 significant digits of [scale] reach, from its decimal
  // exponent ("1.23456700000000e+4" → 4 → 10 decimals).
  final exponent = int.parse(scale.toStringAsExponential(14).split('e').last);
  return double.parse(v.toStringAsFixed((14 - exponent).clamp(0, 20)));
}

/// Pick the effective locale to parse an import file under.
///
/// Priority:
///  1. The user's per-source override (`saved`), if any.
///  2. The app's configured locale (`appLocale`).
///  3. `en_US` as a final safety net.
String resolveImportLocale({String? saved, required String? appLocale}) => saved ?? appLocale ?? 'en_US';

/// Format [value] for locale-aware round-tripping back through
/// [parseAmount]/[tryParseAmount], preserving FULL precision.
///
/// `NumberFormat.decimalPattern` defaults to 3 fraction digits — rounding
/// e.g. a small quantity or a high-precision FX rate to fewer significant
/// digits than the source data had (0.00012345 → "0" for a `en_US`
/// locale). Raising `maximumFractionDigits` instead surfaces
/// binary/decimal floating-point noise that the default's rounding
/// normally hides (7707.97 formats as "7707.970000000000255").
///
/// Only the DECIMAL SEPARATOR needs to match the active locale for
/// [parseAmount] to round-trip correctly — thousands grouping is cosmetic
/// and unneeded for this internal transport format. This builds on Dart's
/// canonical shortest round-trip digits (`double.toString()`, exact by
/// construction) and swaps in the target locale's decimal separator instead
/// of re-deriving decimal digits through `NumberFormat`.
///
/// `double.toString()` switches to scientific notation for magnitudes
/// outside roughly 1e-6..1e21 (`0.0000001` → `1e-7`), and
/// [parseAmount] cannot read that back — `NumberFormat` expects the
/// locale's own exponent symbol, so `1e-7` returns null and the value is
/// lost. Any exponent is therefore expanded to plain decimal digits here.
String formatAmountLossless(double value, {required String locale}) {
  // Whole numbers: avoid `double.toString()`'s trailing ".0" for a cleaner
  // round-trip string (parses identically either way, but matches the
  // un-suffixed shape a user would expect to see in a preview).
  if (value == value.truncateToDouble() && value.abs() < 1e15) {
    return value.toInt().toString();
  }
  final canonical = _withoutExponent(value.toString());
  final sep = _decimalSeparatorFor(locale);
  return sep == '.' ? canonical : canonical.replaceFirst('.', sep);
}

/// Rewrite a Dart `double.toString()` result that uses scientific notation
/// (`1e-7`, `1.5e+21`) as plain decimal digits, preserving every digit.
/// Inputs without an exponent are returned unchanged.
String _withoutExponent(String s) {
  final eIndex = s.indexOf('e');
  if (eIndex < 0) return s;

  final exponent = int.parse(s.substring(eIndex + 1));
  var mantissa = s.substring(0, eIndex);
  final negative = mantissa.startsWith('-');
  if (negative) mantissa = mantissa.substring(1);

  final dotIndex = mantissa.indexOf('.');
  var digits = mantissa;
  var pointPosition = mantissa.length;
  if (dotIndex >= 0) {
    digits = mantissa.substring(0, dotIndex) + mantissa.substring(dotIndex + 1);
    pointPosition = dotIndex;
  }
  // Shift the decimal point by the exponent, padding with zeros on whichever
  // side the point runs off the digit string.
  pointPosition += exponent;

  final String plain;
  if (pointPosition <= 0) {
    plain = '0.${'0' * -pointPosition}$digits';
  } else if (pointPosition >= digits.length) {
    plain = digits + '0' * (pointPosition - digits.length);
  } else {
    plain = '${digits.substring(0, pointPosition)}.${digits.substring(pointPosition)}';
  }
  return negative ? '-$plain' : plain;
}

/// The single character [locale]'s `NumberFormat` uses as a decimal
/// separator — derived by formatting a fixed probe value rather than
/// reaching into intl's internal symbol tables.
String _decimalSeparatorFor(String locale) {
  final probe = NumberFormat.decimalPattern(locale).format(1.5);
  return probe.replaceAll(RegExp(r'[0-9]'), '');
}
