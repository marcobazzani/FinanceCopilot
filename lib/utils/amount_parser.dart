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
String resolveImportLocale({String? saved, required String? appLocale}) =>
    saved ?? appLocale ?? 'en_US';
