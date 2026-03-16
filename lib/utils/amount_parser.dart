/// Parses amount/balance strings, handling both European (1.234,56) and
/// standard (1,234.56) number formats.
double parseAmount(String s) {
  s = s.trim();
  if (s.isEmpty) throw const FormatException('Empty amount');

  // Remove currency symbols
  s = s.replaceAll(RegExp(r'[€$£¥]'), '').trim();

  // European format: 1.234,56 → 1234.56
  if (s.contains(',') && s.contains('.')) {
    final lastComma = s.lastIndexOf(',');
    final lastDot = s.lastIndexOf('.');
    if (lastComma > lastDot) {
      // European: dots are thousands, comma is decimal
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      // Standard: commas are thousands, dot is decimal
      s = s.replaceAll(',', '');
    }
  } else if (s.contains(',')) {
    // Could be European decimal or thousands separator
    // If comma has exactly 2 digits after it, treat as decimal
    final parts = s.split(',');
    if (parts.last.length <= 2) {
      s = s.replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
  }

  return double.parse(s);
}

/// Like [parseAmount] but returns null on failure instead of throwing.
double? tryParseAmount(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  try {
    return parseAmount(s);
  } catch (_) {
    return null;
  }
}
