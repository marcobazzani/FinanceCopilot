import 'package:intl/intl.dart';

/// Parses an amount/balance string under the given locale.
///
/// Locale must be an ICU locale tag the app uses (e.g. `it_IT`, `en_US`,
/// `de_DE`, `fr_FR`, `es_ES`, `en_GB`). The decimal/thousands separators
/// come from the locale — no heuristic guessing.
double parseAmount(String s, {required String locale}) {
  final cleaned = s.replaceAll(RegExp(r'[€$£¥]'), '').trim();
  if (cleaned.isEmpty) throw const FormatException('Empty amount');
  return NumberFormat.decimalPattern(locale).parse(cleaned).toDouble();
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
