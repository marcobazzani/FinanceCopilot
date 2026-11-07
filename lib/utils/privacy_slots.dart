// The markers a localized sentence carries where its position-size figures
// go: plain strings, so a service can build such a sentence and the UI blur
// only the figures (see PrivacySentence).

const _slotStart = '\u{E000}';
const _slotEnd = '\u{E001}';

/// Marks where the [index]-th figure of a [PrivacySentence] goes. Pass it to a
/// localized string in place of the formatted amount, then hand the real
/// figures to [PrivacySentence.figures] (or to the `maskedFigures` of
/// `showConfirmDialog` / `showInfoSnack`).
String privacySlot(int index) => '$_slotStart$index$_slotEnd';

/// [template] cut at its [privacySlot] markers, in reading order: a run of
/// `words` between them (`slot` null), or the place of the figure the marker
/// `privacySlot(slot)` stands for (`words` empty). [PrivacySentence] puts its
/// figures in those places; a rich text can put spans of its own there.
List<({String words, int? slot})> splitPrivacySlots(String template) {
  final parts = <({String words, int? slot})>[];
  var rest = template;
  while (true) {
    final start = rest.indexOf(_slotStart);
    final end = start < 0 ? -1 : rest.indexOf(_slotEnd, start);
    if (end < 0) {
      if (rest.isNotEmpty) parts.add((words: rest, slot: null));
      return parts;
    }
    if (start > 0) parts.add((words: rest.substring(0, start), slot: null));
    parts.add((words: '', slot: int.parse(rest.substring(start + 1, end))));
    rest = rest.substring(end + 1);
  }
}
