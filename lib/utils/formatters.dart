import 'package:intl/intl.dart';

/// Locale-aware number/date formatters.
/// All functions accept a locale string (e.g. 'it_IT', 'en_US').

NumberFormat amountFormat(String locale) =>
    NumberFormat('#,##0.00', locale);

NumberFormat qtyFormat(String locale) =>
    NumberFormat('#,##0.####', locale);

NumberFormat currencyFormat(String locale, String symbol, {int? decimalDigits}) =>
    NumberFormat.currency(locale: locale, symbol: symbol, decimalDigits: decimalDigits);

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
  var s = text.replaceAll('€', '').replaceAll('\$', '').replaceAll('\u00A0', '').trim();
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

/// Flexible date parser: tries multiple formats + multi-language month names.
DateTime? parseFlexibleDate(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;

  // Try common numeric formats
  for (final fmt in [DateFormat('dd/MM/yyyy'), DateFormat('yyyy-MM-dd'), DateFormat('MM/dd/yyyy')]) {
    try {
      return fmt.parseStrict(t);
    } catch (_) {}
  }

  // Named month: "1 luglio 2013", "20 Feb 2017", etc.
  final namedMatch = RegExp(r'(\d{1,2})\s+(\w+)\s+(\d{4})').firstMatch(t);
  if (namedMatch != null) {
    final day = int.tryParse(namedMatch.group(1)!);
    final monthName = namedMatch.group(2)!.toLowerCase();
    final year = int.tryParse(namedMatch.group(3)!);
    final month = monthMap[monthName];
    if (day != null && month != null && year != null) {
      return DateTime(year, month, day);
    }
  }

  return null;
}
