// The one splitter behind every sentence that quotes figures: a template built
// with privacySlot markers cut into its words and the places of its figures,
// in reading order. PrivacySentence fills the places with its figures; the
// end-of-year explanation with the spans of its amounts.
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/ui/widgets/privacy_text.dart';

void main() {
  test('words and figure places in reading order, with the index each marker was made with', () {
    expect(splitPrivacySlots('Opening ${privacySlot(0)} implied by the closing (${privacySlot(1)}) on 3 rows.'), [
      (words: 'Opening ', slot: null),
      (words: '', slot: 0),
      (words: ' implied by the closing (', slot: null),
      (words: '', slot: 1),
      (words: ') on 3 rows.', slot: null),
    ]);
  });

  test('a figure at either end, or next to another, leaves no empty words', () {
    expect(splitPrivacySlots('${privacySlot(1)}${privacySlot(0)} left'), [
      (words: '', slot: 1),
      (words: '', slot: 0),
      (words: ' left', slot: null),
    ]);
    expect(splitPrivacySlots('Total: ${privacySlot(0)}'), [(words: 'Total: ', slot: null), (words: '', slot: 0)]);
  });

  test('no marker: the words alone; nothing: nothing', () {
    expect(splitPrivacySlots('No figure here.'), [(words: 'No figure here.', slot: null)]);
    expect(splitPrivacySlots(''), isEmpty);
  });
}
