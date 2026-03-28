import 'formatters.dart' show monthMap;

/// Comprehensive date parser supporting many formats.
///
/// Handles: dd/MM/yyyy, yyyy-MM-dd, dd-MMM-yyyy, MMM dd yyyy,
/// 2-digit years, compact yyyyMMdd, epoch timestamps, ISO 8601, etc.
/// Multi-language month names via [monthMap].
///
/// Throws [FormatException] if no format matches.
DateTime parseDate(String s) {
  s = s.trim();
  if (s.isEmpty) throw const FormatException('Empty date');

  // Strip surrounding quotes
  if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) {
    s = s.substring(1, s.length - 1).trim();
  }

  // ── Numeric formats ──

  // dd/MM/yyyy or dd-MM-yyyy or dd.MM.yyyy (with optional HH:mm:ss)
  final dmy = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$').firstMatch(s);
  if (dmy != null) {
    return DateTime(
      int.parse(dmy.group(3)!),
      int.parse(dmy.group(2)!),
      int.parse(dmy.group(1)!),
      int.tryParse(dmy.group(4) ?? '') ?? 0,
      int.tryParse(dmy.group(5) ?? '') ?? 0,
      int.tryParse(dmy.group(6) ?? '') ?? 0,
    );
  }

  // yyyy-MM-dd or yyyy/MM/dd (with optional time T or space separated)
  final ymd = RegExp(r'^(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})(?:[T\s](\d{1,2}):(\d{2})(?::(\d{2}))?)?').firstMatch(s);
  if (ymd != null) {
    return DateTime(
      int.parse(ymd.group(1)!),
      int.parse(ymd.group(2)!),
      int.parse(ymd.group(3)!),
      int.tryParse(ymd.group(4) ?? '') ?? 0,
      int.tryParse(ymd.group(5) ?? '') ?? 0,
      int.tryParse(ymd.group(6) ?? '') ?? 0,
    );
  }

  // dd/MM/yy (2-digit year)
  final dmy2 = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2})$').firstMatch(s);
  if (dmy2 != null) {
    var year = int.parse(dmy2.group(3)!);
    year += year > 50 ? 1900 : 2000;
    return DateTime(year, int.parse(dmy2.group(2)!), int.parse(dmy2.group(1)!));
  }

  // yyyyMMdd (compact, no separators)
  final compact = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(s);
  if (compact != null) {
    return DateTime(
      int.parse(compact.group(1)!),
      int.parse(compact.group(2)!),
      int.parse(compact.group(3)!),
    );
  }

  // ── Named month formats ──

  // dd MMM yyyy or dd-MMM-yyyy (e.g. "20 Feb 2017", "20-Feb-2017")
  final namedDmy = RegExp(r'^(\d{1,2})[\s\-.](\w+)[\s\-.](\d{4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$', caseSensitive: false).firstMatch(s);
  if (namedDmy != null) {
    final month = monthMap[namedDmy.group(2)!.toLowerCase()];
    if (month != null) {
      return DateTime(
        int.parse(namedDmy.group(3)!),
        month,
        int.parse(namedDmy.group(1)!),
        int.tryParse(namedDmy.group(4) ?? '') ?? 0,
        int.tryParse(namedDmy.group(5) ?? '') ?? 0,
        int.tryParse(namedDmy.group(6) ?? '') ?? 0,
      );
    }
  }

  // MMM dd, yyyy (e.g. "Feb 20, 2017", "February 20, 2017")
  final namedMdy = RegExp(r'^(\w+)\s+(\d{1,2}),?\s+(\d{4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$', caseSensitive: false).firstMatch(s);
  if (namedMdy != null) {
    final month = monthMap[namedMdy.group(1)!.toLowerCase()];
    if (month != null) {
      return DateTime(
        int.parse(namedMdy.group(3)!),
        month,
        int.parse(namedMdy.group(2)!),
        int.tryParse(namedMdy.group(4) ?? '') ?? 0,
        int.tryParse(namedMdy.group(5) ?? '') ?? 0,
        int.tryParse(namedMdy.group(6) ?? '') ?? 0,
      );
    }
  }

  // yyyy MMM dd (e.g. "2017 Feb 20")
  final namedYmd = RegExp(r'^(\d{4})[\s\-.](\w+)[\s\-.](\d{1,2})$', caseSensitive: false).firstMatch(s);
  if (namedYmd != null) {
    final month = monthMap[namedYmd.group(2)!.toLowerCase()];
    if (month != null) {
      return DateTime(
        int.parse(namedYmd.group(1)!),
        month,
        int.parse(namedYmd.group(3)!),
      );
    }
  }

  // ── Epoch timestamps ──

  // Unix seconds (10 digits) or milliseconds (13 digits)
  final epoch = RegExp(r'^(\d{10,13})$').firstMatch(s);
  if (epoch != null) {
    final n = int.parse(epoch.group(1)!);
    return n > 9999999999
        ? DateTime.fromMillisecondsSinceEpoch(n)
        : DateTime.fromMillisecondsSinceEpoch(n * 1000);
  }

  // ── Fallback: Dart's DateTime.parse (handles ISO 8601) ──
  try {
    return DateTime.parse(s);
  } catch (_) {
    throw FormatException('Invalid date format: $s');
  }
}

/// Non-throwing version of [parseDate]. Returns null on failure.
DateTime? tryParseDate(String text) {
  try {
    return parseDate(text);
  } catch (_) {
    return null;
  }
}
