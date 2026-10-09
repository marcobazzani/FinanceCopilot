import '../../database/tables.dart';
import 'normalizer/entry_kind_lexicon.dart';
import 'normalizer/line_formats.dart';
import 'normalizer/statement_tokens.dart';

export 'normalizer/entry_kind_lexicon.dart' show detectEntryKind, kindOf, typeHintOf;
export 'normalizer/line_formats.dart' show Direction, extractCounterparty, statementLineFormats;
export 'normalizer/statement_tokens.dart' show stripStatementNoise;

/// Bump whenever the extraction logic changes so stored
/// `merchant_key` / `counterparty` / `entry_kind` columns are recomputed on
/// next startup (see `TransactionClassifierService.recomputeKeysIfStale`).
const int normalizerVersion = 2;

/// Longest merchant key stored; longer names are truncated after squashing.
const int maxMerchantKeyLength = 32;
const int maxCounterpartyLength = 60;

/// Result of [normalizeDescription].
class NormalizedEntry {
  final BankEntryKind entryKind;

  /// Human-readable counterparty (merchant / payee / payer). When the line
  /// carries nothing but a card mask this is the mask itself (`*1172`); null
  /// when nothing at all survives noise stripping.
  final String? counterparty;

  /// Stable grouping key: uppercase alphanumerics only, bank noise stripped.
  /// Never empty — falls back to a kind-based key so every row groups.
  final String merchantKey;

  /// Name of the line format that extracted the counterparty (trace).
  final String format;

  const NormalizedEntry({required this.entryKind, required this.counterparty, required this.merchantKey, required this.format});

  @override
  String toString() => 'NormalizedEntry($entryKind, $counterparty, $merchantKey, via $format)';
}

/// Extract entry kind, counterparty and merchant key from a bank statement
/// line. Pure function: no I/O, deterministic, safe to run in a batch over
/// the whole ledger.
///
/// Pipeline:
///   1. kind        — bank type label or description head vs. the kind lexicon;
///   2. format      — the first statement line format that recognizes the
///                    line yields the raw counterparty span;
///   3. noise       — dates, times, masks, references, months, country codes
///                    and trailing reference sections are removed;
///   4. key         — upper-case alphanumerics of what is left (this is what
///                    makes `M ARCO BAZZAN I` and `MARCO BAZZANI` one merchant).
///
/// [inflow] decides which side of a payer/payee pair is the counterparty.
NormalizedEntry normalizeDescription({
  required String description,
  String? descriptionFull,
  Map<String, dynamic>? rawMetadata,
  required bool inflow,
}) {
  final desc = collapseWhitespace(description);
  final full = collapseWhitespace(descriptionFull ?? '');
  final text = (full.isNotEmpty && !desc.contains(full)) ? '$desc $full' : desc;

  final kind = detectEntryKind(typeHint: typeHintOf(rawMetadata), description: desc);
  final (span, format) = extractCounterparty(text, inflow ? Direction.inflow : Direction.outflow);
  final cleaned = stripStatementNoise(span);
  final key = squashToKey(cleaned);

  if (key.isEmpty) {
    // Nothing but bank noise: group by kind, keeping the card mask when
    // present so different cards stay separate groups.
    final mask = cardMaskDigits(text);
    return NormalizedEntry(
      entryKind: kind,
      counterparty: mask != null ? '*$mask' : null,
      merchantKey: mask != null ? '${kindKey(kind)}*$mask' : kindKey(kind),
      format: format,
    );
  }

  return NormalizedEntry(
    entryKind: kind,
    counterparty: cleaned.length > maxCounterpartyLength ? cleaned.substring(0, maxCounterpartyLength).trim() : cleaned,
    merchantKey: key.length > maxMerchantKeyLength ? key.substring(0, maxMerchantKeyLength) : key,
    format: format,
  );
}

/// Upper-case ASCII letters and digits only.
String squashToKey(String s) {
  final b = StringBuffer();
  for (final c in s.toUpperCase().codeUnits) {
    if ((c >= 0x30 && c <= 0x39) || (c >= 0x41 && c <= 0x5A)) b.writeCharCode(c);
  }
  return b.toString();
}

/// Digits of the first card mask in [text] (`**5591*` → `5591`), if any with
/// at least three digits.
String? cardMaskDigits(String text) {
  var i = text.indexOf('*');
  while (i >= 0) {
    var j = i;
    while (j < text.length && text[j] == '*') {
      j++;
    }
    while (j < text.length && text[j] == ' ') {
      j++;
    }
    final start = j;
    while (j < text.length && text.codeUnitAt(j) >= 0x30 && text.codeUnitAt(j) <= 0x39) {
      j++;
    }
    if (j - start >= 3) return text.substring(start, j);
    i = text.indexOf('*', j > i ? j : i + 1);
  }
  return null;
}

/// Fallback grouping key for lines that carry no name at all.
String kindKey(BankEntryKind k) => switch (k) {
  BankEntryKind.cardTopUp => 'TOPUP',
  BankEntryKind.atmWithdrawal => 'ATM',
  _ => k.name.toUpperCase(),
};
