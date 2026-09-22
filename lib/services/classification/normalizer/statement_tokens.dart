/// Tokenization of a bank statement line and removal of "bank noise" —
/// dates, times, card masks, reference numbers, month names, trailing
/// reference sections and trailing country codes.
///
/// Everything here is a plain character/word scanner: each rule is a named
/// function you can read, unit-test and step through, and the result carries
/// which rules fired.
library;

/// A maximal run of word characters (letters, digits, `*`) or a maximal run
/// of everything else (spaces, punctuation). A line is a strict alternation
/// of the two, so re-joining segments reproduces the original text.
class Segment {
  final String text;
  final bool isWord;
  const Segment(this.text, {required this.isWord});

  bool get isDigits => isWord && text.isNotEmpty && text.codeUnits.every(_isDigit);
  int get digitCount => text.codeUnits.where(_isDigit).length;
  bool get hasMask => text.contains('*');

  /// A separator that is exactly [s] (whitespace ignored).
  bool isSeparator(String s) => !isWord && text.trim() == s;
  bool get isWhitespaceOnly => !isWord && text.trim().isEmpty;

  @override
  String toString() => isWord ? 'W($text)' : 'S(${text.replaceAll(' ', '␣')})';
}

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;
bool _isLetter(int c) => (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || c > 0x7F;
bool _isWordChar(int c) => _isDigit(c) || _isLetter(c) || c == 0x2A /* * */;

List<Segment> segmentLine(String s) {
  final out = <Segment>[];
  var start = 0;
  bool? inWord;
  for (var i = 0; i < s.length; i++) {
    final w = _isWordChar(s.codeUnitAt(i));
    if (inWord == null) {
      inWord = w;
    } else if (w != inWord) {
      out.add(Segment(s.substring(start, i), isWord: inWord));
      start = i;
      inWord = w;
    }
  }
  if (start < s.length) out.add(Segment(s.substring(start), isWord: inWord ?? false));
  return out;
}

/// Lower-case words (alnum runs) of [s] — the unit the kind lexicon matches on.
List<String> wordsOf(String s) =>
    segmentLine(s.toLowerCase()).where((seg) => seg.isWord).map((seg) => seg.text.replaceAll('*', '')).where((w) => w.isNotEmpty).toList();

String collapseWhitespace(String s) {
  final b = StringBuffer();
  var pendingSpace = false;
  for (final r in s.runes) {
    final ws = r == 0x20 || r == 0x09 || r == 0x0A || r == 0x0D || r == 0xA0;
    if (ws) {
      pendingSpace = b.isNotEmpty;
    } else {
      if (pendingSpace) b.write(' ');
      pendingSpace = false;
      b.writeCharCode(r);
    }
  }
  return b.toString();
}

/// Case-insensitive `indexOf` of [phrase] in [text] starting at a word
/// boundary (start of string or after a non-word character). Returns -1 when
/// absent.
int indexOfPhrase(String text, String phrase, {int from = 0, bool caseSensitive = false}) {
  final hay = caseSensitive ? text : text.toLowerCase();
  final needle = caseSensitive ? phrase : phrase.toLowerCase();
  var i = hay.indexOf(needle, from);
  while (i >= 0) {
    if (i == 0 || !_isWordChar(hay.codeUnitAt(i - 1))) return i;
    i = hay.indexOf(needle, i + 1);
  }
  return -1;
}

// ── Noise rules (data) ──

/// Once one of these appears, the rest of the line is references only.
const trailingSectionMarkers = [
  'Data operazione',
  'Dt-ord:',
  'Banca Ord', // "Banca Ord:" and "Banca Ordinante:"
  'Info-Cli:',
  'Data accredito',
  'IDENTIFICATIVO SCT',
  'RIFERIMENTO SCT',
  'DESCR.OPERAZIONE',
  'Qta/Val.nom.',
  'Carta N.',
];

const _monthNames = {
  'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno', 'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre', //
  'january', 'february', 'march', 'april', 'may', 'june', 'july', 'august', 'september', 'october', 'november', 'december',
};

/// Upper-case country codes as printed on card slips (`Dublin IE`).
const _countryCodes = {
  'IE', 'IRL', 'IT', 'ITA', 'LT', 'LTU', 'GB', 'GBR', 'UK', 'US', 'USA', 'DE', 'DEU', 'FR', 'FRA', 'ES', 'ESP', //
  'NL', 'NLD', 'LU', 'LUX', 'BE', 'BEL', 'CH', 'CHE', 'AT', 'AUT', 'PT', 'PRT',
};

/// Tokens carrying this many digits or more are references, not names.
const _referenceDigits = 3;

// ── Noise removal ──

/// Remove everything that is not part of a counterparty name. Pure.
String stripStatementNoise(String text) {
  var t = cutTrailingSections(text).replaceAll('<*>', ' ');
  var segs = segmentLine(t);
  segs = _dropDateAndTimeSequences(segs);
  segs = _dropNoiseWords(segs);
  t = collapseWhitespace(segs.map((s) => s.text).join());
  t = _dropTrailingCountryCode(t);
  return trimDanglingPunctuation(t);
}

/// Truncate at the first trailing reference section.
String cutTrailingSections(String text) {
  var cut = text.length;
  for (final m in trailingSectionMarkers) {
    final i = text.toLowerCase().indexOf(m.toLowerCase());
    if (i >= 0 && i < cut) cut = i;
  }
  return text.substring(0, cut);
}

/// Dates (`24/03/22`, `2024-03-24`) and times (`19:29`, `19.29`) span several
/// segments, so they are matched as sequences. A leading `DEL`/`ORE` word that
/// introduces them is dropped too.
List<Segment> _dropDateAndTimeSequences(List<Segment> segs) {
  final drop = <int>{};
  bool digits(int i, int min, int max) => i < segs.length && segs[i].isDigits && segs[i].text.length >= min && segs[i].text.length <= max;
  bool sep(int i, String s) => i < segs.length && segs[i].isSeparator(s);
  bool introducer(int i, String word) => i >= 2 && segs[i - 1].isWhitespaceOnly && segs[i - 2].isWord && segs[i - 2].text.toLowerCase() == word;

  for (var i = 0; i < segs.length; i++) {
    if (!segs[i].isWord) continue;
    // dd/mm/yy[yy]
    if (digits(i, 1, 2) && sep(i + 1, '/') && digits(i + 2, 1, 2) && sep(i + 3, '/') && digits(i + 4, 2, 4)) {
      drop.addAll([i, i + 1, i + 2, i + 3, i + 4]);
      if (introducer(i, 'del')) drop.addAll([i - 2, i - 1]);
      continue;
    }
    // yyyy-mm-dd
    if (digits(i, 4, 4) && sep(i + 1, '-') && digits(i + 2, 2, 2) && sep(i + 3, '-') && digits(i + 4, 2, 2)) {
      drop.addAll([i, i + 1, i + 2, i + 3, i + 4]);
      continue;
    }
    // hh:mm[:ss] / hh.mm
    if (digits(i, 1, 2) && (sep(i + 1, ':') || sep(i + 1, '.')) && digits(i + 2, 2, 2)) {
      drop.addAll([i, i + 1, i + 2]);
      if (sep(i + 3, ':') && digits(i + 4, 2, 2)) drop.addAll([i + 3, i + 4]);
      if (introducer(i, 'ore')) drop.addAll([i - 2, i - 1]);
    }
  }
  return _without(segs, drop);
}

/// Word-level noise: month names, `NOT PROVIDED`, card masks, store numbers
/// glued to names (`Acme1946` → `Acme`), reference tokens (≥3 digits), and
/// the `N.` that introduces a card number.
List<Segment> _dropNoiseWords(List<Segment> segs) {
  final out = <Segment>[];
  final words = [
    for (var i = 0; i < segs.length; i++)
      if (segs[i].isWord) i,
  ];
  final drop = <int>{};
  final replace = <int, String>{};

  int? nextWord(int i) => words.where((w) => w > i).firstOrNull;

  for (final i in words) {
    final w = segs[i];
    final lower = w.text.toLowerCase();
    if (_monthNames.contains(lower)) {
      drop.add(i);
      continue;
    }
    if (lower == 'not') {
      final n = nextWord(i);
      if (n != null && segs[n].text.toLowerCase() == 'provided') drop.addAll([i, n]);
      continue;
    }
    if (lower == 'n') {
      final n = nextWord(i);
      if (n != null && segs[n].hasMask) drop.add(i);
      continue;
    }
    var text = w.hasMask ? stripCardMask(w.text) : w.text;
    text = trimGluedStoreNumber(text);
    if (text.isEmpty || text.codeUnits.where(_isDigit).length >= _referenceDigits) {
      drop.add(i);
    } else if (text != w.text) {
      replace[i] = text;
    }
  }
  for (var i = 0; i < segs.length; i++) {
    if (drop.contains(i)) continue;
    out.add(replace.containsKey(i) ? Segment(replace[i]!, isWord: true) : segs[i]);
  }
  return out;
}

/// `Revolut**5591*` → `Revolut`; `****2569` → ``; `Amz*wp` → `Amz wp`.
/// Each run of `*` together with the digits (and optional closing `*`) that
/// follow it is replaced by a single space, so the halves of a masked name
/// stay readable as two words.
String stripCardMask(String word) {
  final b = StringBuffer();
  var i = 0;
  while (i < word.length) {
    if (word[i] == '*') {
      while (i < word.length && word[i] == '*') {
        i++;
      }
      while (i < word.length && _isDigit(word.codeUnitAt(i))) {
        i++;
      }
      if (i < word.length && word[i] == '*') i++;
      b.write(' ');
    } else {
      b.write(word[i]);
      i++;
    }
  }
  return b.toString().trim();
}

/// `Acme1946` → `Acme`: a run of ≥3 digits at the end of a word that follows a
/// letter is a store/terminal number, not part of the name.
String trimGluedStoreNumber(String word) {
  var end = word.length;
  while (end > 0 && _isDigit(word.codeUnitAt(end - 1))) {
    end--;
  }
  final digits = word.length - end;
  if (digits >= _referenceDigits && end > 0 && _isLetter(word.codeUnitAt(end - 1))) return word.substring(0, end);
  return word;
}

String _dropTrailingCountryCode(String t) {
  final sp = t.lastIndexOf(' ');
  if (sp < 0) return t;
  final last = t.substring(sp + 1);
  return _countryCodes.contains(last) ? t.substring(0, sp) : t;
}

/// Leading `- : , . ; /` and trailing `- : , ; /` are separators left behind
/// by removed tokens. A trailing dot is kept (`S.p.A.`).
String trimDanglingPunctuation(String t) {
  const lead = ' -:,.;/';
  const trail = ' -:,;/';
  var s = 0, e = t.length;
  while (s < e && lead.contains(t[s])) {
    s++;
  }
  while (e > s && trail.contains(t[e - 1])) {
    e--;
  }
  return collapseWhitespace(t.substring(s, e));
}

List<Segment> _without(List<Segment> segs, Set<int> drop) => drop.isEmpty
    ? segs
    : [
        for (var i = 0; i < segs.length; i++)
          if (!drop.contains(i)) segs[i],
      ];
