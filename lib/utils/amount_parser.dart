/// Parses amount/balance strings, handling both European (1.234,56) and
/// standard (1,234.56) number formats.
double parseAmount(String s) {
  s = s.trim();
  if (s.isEmpty) throw const FormatException('Empty amount');

  // Remove currency symbols and whitespace used as thousands separator
  s = s.replaceAll(RegExp(r'[€$£¥\s]'), '').trim();

  // Both dot and comma present → disambiguate by position
  if (s.contains(',') && s.contains('.')) {
    final lastComma = s.lastIndexOf(',');
    final lastDot = s.lastIndexOf('.');
    if (lastComma > lastDot) {
      // European: dots are thousands, comma is decimal (1.234,56)
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      // Standard: commas are thousands, dot is decimal (1,234.56)
      s = s.replaceAll(',', '');
    }
  } else if (s.contains(',')) {
    // Comma only: ≤2 digits after → decimal, 3 digits → thousands
    final parts = s.split(',');
    if (parts.length > 2) {
      // Multiple commas: definitely thousands (1,234,567)
      s = s.replaceAll(',', '');
    } else if (parts.last.length == 3) {
      // Exactly 3 digits after comma: thousands separator (1,234)
      s = s.replaceAll(',', '');
    } else {
      // 1-2 digits after comma: decimal separator (1,5 or 1,50)
      s = s.replaceAll(',', '.');
    }
  } else if (s.contains('.')) {
    // Dot only: ≤2 digits after → decimal, 3 digits → thousands
    final parts = s.split('.');
    if (parts.length > 2) {
      // Multiple dots: definitely thousands (1.234.567)
      s = s.replaceAll('.', '');
    } else if (parts.last.length == 3 && parts.first.isNotEmpty) {
      // Exactly 3 digits after dot: thousands separator (1.234)
      s = s.replaceAll('.', '');
    }
    // Otherwise: decimal point (1.5, 12.34, etc.) — keep as is
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
