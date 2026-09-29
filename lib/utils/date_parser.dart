import 'package:intl/intl.dart' show DateFormat;

import 'formatters.dart' show monthMap;
import 'visualization_clock.dart' show dateOnly;

/// Why [parseDate] rejected a text. Still a [FormatException] whose message
/// is the English one the logs show, plus what was read, so a caller can
/// word the problem in the user's language.
class DateParseException extends FormatException {
  /// The text that was read.
  final String raw;

  /// There was nothing to read.
  final bool empty;

  const DateParseException(super.message, {required this.raw, this.empty = false});
}

/// Comprehensive date parser supporting many formats.
///
/// Handles: dd/MM/yyyy, yyyy-MM-dd, dd-MMM-yyyy, MMM dd yyyy,
/// 2-digit years, compact yyyyMMdd, epoch timestamps, ISO 8601, etc.
/// Multi-language month names via [monthMap].
///
/// Throws [DateParseException] if no format matches.
DateTime parseDate(String s) {
  s = s.trim();
  if (s.isEmpty) throw DateParseException('Empty date', raw: s, empty: true);

  // Strip surrounding quotes
  if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) {
    s = s.substring(1, s.length - 1).trim();
  }

  // ── Numeric formats ──
  //
  // Strict month/day ranges: we'd rather throw than let the DateTime
  // constructor silently normalize "99/99/2024" into a far-future date.
  // Anchoring ymd with `$` ensures ISO 8601 timestamps with a TZ offset
  // (e.g. "2024-01-15T10:00:00+02:00") fall through to DateTime.parse,
  // which preserves the offset.

  // dd/MM/yyyy or dd-MM-yyyy or dd.MM.yyyy (with optional HH:mm:ss)
  final dmy = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$').firstMatch(s);
  if (dmy != null) {
    final day = int.parse(dmy.group(1)!);
    final month = int.parse(dmy.group(2)!);
    if (!_validDayMonth(day, month)) {
      throw DateParseException('Invalid day/month in date: $s', raw: s);
    }
    return DateTime(
      int.parse(dmy.group(3)!),
      month,
      day,
      int.tryParse(dmy.group(4) ?? '') ?? 0,
      int.tryParse(dmy.group(5) ?? '') ?? 0,
      int.tryParse(dmy.group(6) ?? '') ?? 0,
    );
  }

  // yyyy-MM-dd or yyyy/MM/dd (with optional time T or space separated)
  final ymd = RegExp(r'^(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})(?:[T\s](\d{1,2}):(\d{2})(?::(\d{2}))?)?$').firstMatch(s);
  if (ymd != null) {
    final month = int.parse(ymd.group(2)!);
    final day = int.parse(ymd.group(3)!);
    if (!_validDayMonth(day, month)) {
      throw DateParseException('Invalid day/month in date: $s', raw: s);
    }
    return DateTime(
      int.parse(ymd.group(1)!),
      month,
      day,
      int.tryParse(ymd.group(4) ?? '') ?? 0,
      int.tryParse(ymd.group(5) ?? '') ?? 0,
      int.tryParse(ymd.group(6) ?? '') ?? 0,
    );
  }

  // MM/YYYY (period only — no day) → last day of that month.
  // Used by pension statements that report a "period" column like
  // "12/2024". Resolving to the last day puts revalue snapshots at the
  // end of the period so they sort AFTER that period's contributes,
  // which is what the resync's qty-at-value-date anchor expects.
  // Anchored before dmy2 so a 2-digit year like "12/24" is still
  // interpreted as dd/MM/yy, not MM/YYYY.
  final mYy = RegExp(r'^(\d{1,2})[/\-.](\d{4})$').firstMatch(s);
  if (mYy != null) {
    final month = int.parse(mYy.group(1)!);
    final year = int.parse(mYy.group(2)!);
    if (month < 1 || month > 12) {
      throw DateParseException('Invalid month in date: $s', raw: s);
    }
    // DateTime(y, m+1, 0) = last day of month m, robust across leap years.
    return DateTime(year, month + 1, 0);
  }

  // MMMM YYYY (month name + year, no day) → last day of that month.
  // E.g. "Gennaio 2026", "January 2026", "Févr 2026". Used by pension /
  // periodic statements where the period column is a localized month label.
  // Resolution mirrors the MM/YYYY case above so parser behavior is uniform.
  final monthYearNamed = RegExp(r'^(\w+)\s+(\d{4})$', caseSensitive: false).firstMatch(s);
  if (monthYearNamed != null) {
    final month = monthMap[monthYearNamed.group(1)!.toLowerCase()];
    if (month != null) {
      final year = int.parse(monthYearNamed.group(2)!);
      return DateTime(year, month + 1, 0);
    }
  }

  // dd/MM/yy (2-digit year)
  final dmy2 = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2})$').firstMatch(s);
  if (dmy2 != null) {
    final day = int.parse(dmy2.group(1)!);
    final month = int.parse(dmy2.group(2)!);
    if (!_validDayMonth(day, month)) {
      throw DateParseException('Invalid day/month in date: $s', raw: s);
    }
    return DateTime(_expandTwoDigitYear(int.parse(dmy2.group(3)!)), month, day);
  }

  // yyyyMMdd (compact, no separators)
  final compact = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(s);
  if (compact != null) {
    final month = int.parse(compact.group(2)!);
    final day = int.parse(compact.group(3)!);
    // Any 8 digits match the shape; only a real calendar date is one.
    // Without this, "86547083" silently becomes 8659-12-22 by rollover.
    if (!_validDayMonth(day, month)) {
      throw DateParseException('Invalid day/month in date: $s', raw: s);
    }
    return DateTime(int.parse(compact.group(1)!), month, day);
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
    return n > 9999999999 ? DateTime.fromMillisecondsSinceEpoch(n) : DateTime.fromMillisecondsSinceEpoch(n * 1000);
  }

  // ── Fallback: Dart's DateTime.parse (handles ISO 8601) ──
  try {
    return DateTime.parse(s);
  } catch (_) {
    throw DateParseException('Invalid date format: $s', raw: s);
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

/// A date the user typed in a form field under [locale]: a calendar day, at
/// local midnight.
///
/// The locale's own short date comes first — the `DateFormat.yMd` text the
/// forms pre-fill — so under en_US "3/7/2026" is March 7 and "9/27/2026" is
/// accepted. Any other shape goes to the day-first [tryParseDate] (ISO
/// "2026-03-07", named months, …); a clock time or zone in it only locates
/// the day: '2026-03-07T23:30:00Z' is the local day of that instant, never
/// the instant itself. Null when neither reads it.
DateTime? tryParseUserDate(String text, {required String locale}) {
  final s = text.trim();
  if (s.isEmpty) return null;
  final short = DateFormat.yMd(locale);
  try {
    final d = short.parseStrict(s);
    if (d.year >= 1000) return d;
    // `y` takes a short year literally ("26" is year 26). A two-digit year
    // keeps the locale's day/month order and gets the dd/MM/yy century.
    if ((short.pattern ?? '').endsWith('y') && _trailingTwoDigits.hasMatch(s)) {
      return DateTime(_expandTwoDigitYear(d.year), d.month, d.day);
    }
  } on FormatException {
    // Not the locale's short date: the comprehensive parser below decides.
  }
  final parsed = tryParseDate(s);
  return parsed == null ? null : dateOnly(parsed.toLocal());
}

final _trailingTwoDigits = RegExp(r'(^|\D)\d{2}$');

int _expandTwoDigitYear(int year) => year + (year > 50 ? 1900 : 2000);

bool _validDayMonth(int day, int month) => month >= 1 && month <= 12 && day >= 1 && day <= 31;
