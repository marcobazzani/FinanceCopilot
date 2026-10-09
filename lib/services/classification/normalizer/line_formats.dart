/// Statement line formats: each parser recognizes one way banks lay out a
/// line and extracts the raw counterparty span from it. Parsers are tried in
/// order; the first that recognizes the line wins. The parser name is kept
/// on the result so a bad extraction can be traced to its rule.
library;

import 'statement_tokens.dart';

/// Which side of a payer/payee pair is "the other party".
enum Direction { inflow, outflow }

abstract class LineFormat {
  const LineFormat();

  /// Stable, human-readable name used in traces and tests.
  String get name;

  /// The raw counterparty text (still containing noise), or null when this
  /// format does not apply to [text].
  String? extract(String text, Direction direction);
}

/// `... Ord: <payer> Ben: <payee> Dt-ord: ...` — the counterparty is the
/// payer for inflows and the payee for outflows.
class PayerPayeeFormat extends LineFormat {
  @override
  final String name;
  final String payerMarker;
  final String payeeMarker;
  final List<String> stops;
  const PayerPayeeFormat(this.name, {required this.payerMarker, required this.payeeMarker, required this.stops});

  @override
  String? extract(String text, Direction direction) {
    final payerAt = indexOfPhrase(text, payerMarker);
    if (payerAt < 0) return null;
    final payeeAt = indexOfPhrase(text, payeeMarker, from: payerAt + payerMarker.length);
    if (payeeAt < 0) return null;
    final payer = text.substring(payerAt + payerMarker.length, payeeAt);
    final payee = _cutAt(text.substring(payeeAt + payeeMarker.length), stops);
    return direction == Direction.inflow ? payer : payee;
  }
}

/// `... ORD:<payer> DT.ORD:...` — a credit transfer that only names the payer.
class PayerOnlyFormat extends LineFormat {
  @override
  final String name;
  final String marker;
  final List<String> stops;
  final bool caseSensitive;
  const PayerOnlyFormat(this.name, {required this.marker, required this.stops, this.caseSensitive = true});

  @override
  String? extract(String text, Direction direction) {
    final at = indexOfPhrase(text, marker, caseSensitive: caseSensitive);
    if (at < 0) return null;
    return _cutAt(text.substring(at + marker.length), stops, caseSensitive: caseSensitive);
  }
}

/// `DISPOSIZIONE DI PAGAMENTO <branch> <payer…> <account ≥9 digits> <payee…> V/ORDINE …`
class OutgoingOrderFormat extends LineFormat {
  @override
  String get name => 'outgoingOrder';
  const OutgoingOrderFormat();

  @override
  String? extract(String text, Direction direction) {
    const head = 'DISPOSIZIONE DI PAGAMENTO';
    final at = indexOfPhrase(text, head);
    if (at < 0) return null;
    final words = text.substring(at + head.length).trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty || !_allDigits(words.first)) return null;
    final account = words.indexWhere((w) => _allDigits(w) && w.length >= 9, 1);
    if (account < 0) return null;
    final end = words.indexWhere((w) => w.toUpperCase() == 'V/ORDINE', account + 1);
    if (end < 0) return null;
    return words.sublist(account + 1, end).join(' ');
  }
}

/// Everything after a marker to the end of the line (`C/O <merchant>`,
/// `Prelievo di contanti presso <bank>`).
class AfterMarkerFormat extends LineFormat {
  @override
  final String name;
  final List<String> markers;
  const AfterMarkerFormat(this.name, this.markers);

  @override
  String? extract(String text, Direction direction) {
    for (final m in markers) {
      final at = indexOfPhrase(text, m);
      if (at >= 0) return text.substring(at + m.length);
    }
    return null;
  }
}

/// `<Causale> - <merchant> Carta N. …` — card slips whose causale is one of
/// [causali]; the merchant runs from the dash to the card-number section.
class CardSlipFormat extends LineFormat {
  @override
  String get name => 'cardSlip';
  final List<String> causali;
  final List<String> stops;
  const CardSlipFormat({required this.causali, required this.stops});

  @override
  String? extract(String text, Direction direction) {
    for (final c in causali) {
      final at = indexOfPhrase(text, c);
      if (at < 0) continue;
      final rest = text.substring(at + c.length).trimLeft();
      if (!rest.startsWith('-')) continue;
      return _cutAt(rest.substring(1), stops);
    }
    return null;
  }
}

/// Lines that start with a type prefix followed by the counterparty:
/// `POS <merchant> yyyymmdd`, `SDD <creditor>`, `To <payee>`…
class PrefixedFormat extends LineFormat {
  @override
  String get name => 'prefixed';
  final List<String> prefixes;
  const PrefixedFormat(this.prefixes);

  @override
  String? extract(String text, Direction direction) {
    final lower = text.toLowerCase();
    for (final p in prefixes) {
      final pl = p.toLowerCase();
      if (lower.startsWith(pl) && text.length > p.length && text[p.length].trim().isEmpty) {
        return text.substring(p.length);
      }
    }
    return null;
  }
}

/// `Ricarica di *1234` / `Ricarica di Google Pay con *3710` — a card top-up.
/// A bare mask yields an empty span so the kind-based fallback key applies.
class TopUpFormat extends LineFormat {
  @override
  String get name => 'topUp';
  const TopUpFormat();

  @override
  String? extract(String text, Direction direction) {
    const marker = 'Ricarica di';
    if (!text.toLowerCase().startsWith(marker.toLowerCase())) return null;
    final rest = text.substring(marker.length).trim();
    return rest.startsWith('*') ? '' : rest;
  }
}

/// `<short causale> - <detail>` — generic two-part lines: the detail is the
/// interesting half. Only when the causale is short enough to be a label.
class CausaleDetailFormat extends LineFormat {
  @override
  String get name => 'causaleDetail';
  final int maxCausaleLength;
  const CausaleDetailFormat({this.maxCausaleLength = 40});

  @override
  String? extract(String text, Direction direction) {
    final dash = text.indexOf(' - ');
    return (dash > 0 && dash < maxCausaleLength) ? text.substring(dash + 3) : null;
  }
}

/// Last resort: the whole line is the counterparty.
class PlainFormat extends LineFormat {
  @override
  String get name => 'plain';
  const PlainFormat();

  @override
  String? extract(String text, Direction direction) => text;
}

/// The formats, in evaluation order. Specific layouts first, generic last.
const List<LineFormat> statementLineFormats = [
  PayerPayeeFormat('payerPayee', payerMarker: 'Ord:', payeeMarker: 'Ben:', stops: ['Dt-ord', 'Banca Ord', 'Info-Cli']),
  PayerPayeeFormat(
    'payerPayeeLong',
    payerMarker: 'Ordinante:',
    payeeMarker: 'Beneficiario:',
    stops: ['Banca Ordinante', 'Data accredito', 'Causale'],
  ),
  // Outgoing transfers that only name the payee (`Ben: X Ins: <date> Da: INTERNET Iban: …`).
  PayerOnlyFormat('payeeOnly', marker: 'Ben:', stops: ['Ins:', 'Da:', 'Iban:', 'TransID', 'Cau'], caseSensitive: false),
  PayerOnlyFormat(
    'payeeOnlyLong',
    marker: 'Beneficiario:',
    // `IBA N` = "IBAN" split by a PDF column wrap.
    stops: ['IBAN', 'IBA N', 'Data Inserimento', 'Canale', 'Causale'],
    caseSensitive: false,
  ),
  PayerOnlyFormat('creditOrd', marker: 'ORD:', stops: ['DT.ORD', 'DESCR', 'RIFERIMENTO', 'IDENTIFICATIVO']),
  OutgoingOrderFormat(),
  AfterMarkerFormat('careOf', ['C/O']),
  CardSlipFormat(causali: ['Pagamento Visa Debit', 'Pagamento Bancomat', 'VISA DEBIT'], stops: ['Carta N.']),
  AfterMarkerFormat('atmAt', ['Prelievo di contanti presso', 'Prelievo Bancomat']),
  PrefixedFormat([
    'C-POS', 'POS', 'SDD', 'MOBILE SCT', 'SCT', 'STO', 'ATM', 'ONLINE', 'To', 'From', //
    'Pagamento da parte di', 'Pagamento a favore di', 'Payment from', 'Transfer to', 'Transfer from',
  ]),
  TopUpFormat(),
  CausaleDetailFormat(),
  PlainFormat(),
];

/// Run the formats in order; returns the raw span and the format that produced it.
(String span, String format) extractCounterparty(String text, Direction direction) {
  for (final f in statementLineFormats) {
    final span = f.extract(text, direction);
    if (span != null) return (span, f.name);
  }
  return (text, 'plain');
}

String _cutAt(String text, List<String> stops, {bool caseSensitive = false}) {
  var cut = text.length;
  for (final s in stops) {
    final i = indexOfPhrase(text, s, caseSensitive: caseSensitive);
    if (i >= 0 && i < cut) cut = i;
  }
  return text.substring(0, cut);
}

bool _allDigits(String w) => w.isNotEmpty && w.codeUnits.every((c) => c >= 0x30 && c <= 0x39);
