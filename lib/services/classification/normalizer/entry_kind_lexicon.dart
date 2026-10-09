/// The bank-declared entry kind, recognized from the bank's own type label
/// (a `Tipo`/`Causale` column) or from the short causale at the head of the
/// description. This is vocabulary, not categorization: it never decides a
/// category, it only becomes a rule dimension and a hint in the UI.
library;

import '../../../database/tables.dart';
import 'statement_tokens.dart';

/// A phrase to look for in a line, expressed as words.
///
/// Mini-syntax used by the table below (kept trivially readable):
///   * `^word …`  — the phrase must start the line;
///   * `word$`    — the line must END with this word (with `^`: exact line);
///   * `stem*`    — the last word only needs to START with `stem`
///                  (`accredit*` matches accredita / accredito).
class KindPhrase {
  final List<String> words;
  final bool anchoredStart;
  final bool anchoredEnd;
  final bool prefixLast;

  const KindPhrase._(this.words, {required this.anchoredStart, required this.anchoredEnd, required this.prefixLast});

  factory KindPhrase(String spec) {
    var s = spec;
    final start = s.startsWith('^');
    if (start) s = s.substring(1);
    final end = s.endsWith('\$');
    if (end) s = s.substring(0, s.length - 1);
    final prefix = s.endsWith('*');
    if (prefix) s = s.substring(0, s.length - 1);
    return KindPhrase._(wordsOf(s), anchoredStart: start, anchoredEnd: end, prefixLast: prefix);
  }

  bool matches(List<String> lineWords) {
    if (words.isEmpty || lineWords.length < words.length) return false;
    final positions = anchoredStart ? [0] : List.generate(lineWords.length - words.length + 1, (i) => i);
    for (final p in positions) {
      if (anchoredEnd && p + words.length != lineWords.length) continue;
      var ok = true;
      for (var i = 0; i < words.length && ok; i++) {
        final w = lineWords[p + i];
        final last = i == words.length - 1;
        ok = (last && prefixLast) ? w.startsWith(words[i]) : w == words[i];
      }
      if (ok) return true;
    }
    return false;
  }
}

/// Ordered vocabulary. The FIRST kind whose phrase matches wins, so the more
/// specific meanings come first (a stamp duty on a securities account is a
/// tax, not a trade; a phone top-up is a purchase, not a card top-up).
final List<(BankEntryKind, List<KindPhrase>)> entryKindLexicon = [
  (BankEntryKind.tax, _phrases(['impost*', 'bollo', 'f24', 'tasse', 'tax', 'taxes', 'government'])),
  (BankEntryKind.securitiesTrade, _phrases(['titoli', 'securities'])),
  (BankEntryKind.salary, _phrases(['stipendio', 'emolumenti', 'salary', 'payroll', 'wages'])),
  (BankEntryKind.interest, _phrases(['interessi', 'interest*', 'competenze'])),
  (
    BankEntryKind.refund,
    _phrases(['rimborso', 'refund*', 'chargeback*', 'storno', 'ricompensa', 'reward*', 'cashback', 'sconto canone']),
  ),
  (BankEntryKind.fxExchange, _phrases(['cambio valuta', 'cambia valuta', 'exchange*', 'fx'])),
  (BankEntryKind.cardPayment, _phrases(['ricarica telefonica', 'phone top-up', 'phone topup'])),
  // Anchored: a top-up is the bank's own label ("Ricarica", "Top-Up"), while
  // a purchase whose merchant name contains "top up" (a phone credit at a
  // POS) is still a card payment.
  (BankEntryKind.cardTopUp, _phrases(['^ricaric*', '^top-up', '^topup'])),
  (BankEntryKind.transfer, _phrases(['pocket*', 'vault*', 'salvadanaio'])),
  (BankEntryKind.cashDeposit, _phrases(['versamento contanti', 'cash deposit', 'versament*'])),
  (BankEntryKind.atmWithdrawal, _phrases(['preliev*', 'maxipreliev*', '^atm', 'cash withdrawal', 'withdrawal*'])),
  (BankEntryKind.directDebit, _phrases(['sdd', 'direct debit', 'addebito diretto', 'addebito sepa', 'addebit*'])),
  (BankEntryKind.standingOrder, _phrases(['^sto', 'standing order', 'ordine permanente'])),
  (BankEntryKind.fee, _phrases(['canon*', 'commission*', 'fee', 'fees', 'spese', 'recupero spese'])),
  (
    BankEntryKind.cardPayment,
    _phrases([
      'pagamento con carta', 'card payment*', 'visa debit', 'pagamento bancomat', 'pagamento tramite pos', //
      '^c-pos', '^pos', '^online', 'point of sale*', 'carta',
    ]),
  ),
  (
    BankEntryKind.transfer,
    _phrases([
      'bonifico', 'giroconto', 'disposizione di pagamento', '^sct', '^mobile sct', 'transfer*', 'accredit*', //
      'pagamento da parte di', 'pagamento a favore di', '^to', '^pagamento\$', '^payment\$',
    ]),
  ),
];

List<KindPhrase> _phrases(List<String> specs) => specs.map(KindPhrase.new).toList();

/// Statement-metadata column names that carry the bank's own type label.
const typeHintColumns = {'tipo', 'type', 'causale', 'tipo operazione', 'transaction type', 'tipo transazione', 'kind'};

/// The bank's type label from the raw import row, if the export had one.
String? typeHintOf(Map<String, dynamic>? rawMetadata) {
  if (rawMetadata == null) return null;
  for (final e in rawMetadata.entries) {
    if (!typeHintColumns.contains(e.key.toLowerCase().trim())) continue;
    final v = e.value;
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

/// First lexicon entry matching [text], or null.
BankEntryKind? kindOf(String text) {
  final words = wordsOf(text);
  if (words.isEmpty) return null;
  for (final (kind, phrases) in entryKindLexicon) {
    if (phrases.any((p) => p.matches(words))) return kind;
  }
  return null;
}

/// Kind from the bank's label when present, else from the description head
/// (the short causale before ` - `, or the first [headLength] characters).
BankEntryKind detectEntryKind({required String? typeHint, required String description, int headLength = 48}) {
  if (typeHint != null) {
    final k = kindOf(typeHint);
    if (k != null) return k;
  }
  final head = description.contains(' - ')
      ? description.substring(0, description.indexOf(' - '))
      : (description.length > headLength ? description.substring(0, headLength) : description);
  return kindOf(head) ?? BankEntryKind.unknown;
}
