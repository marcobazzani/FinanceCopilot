// A row with no raw statement data stores null — or, from older versions, an
// empty text. decodeRawMetadata reads both as "no statement data" without a
// word: the classifier decodes every row on each key recompute, and a warning
// per blank row buried the log. Text that is there but is not a JSON object
// is still logged.
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

import 'package:finance_copilot/services/classification/transaction_classifier_service.dart';
import 'package:finance_copilot/services/import/stored_import_data.dart';

void main() {
  late List<LogRecord> warnings;

  setUp(() {
    warnings = [];
    final sub = Logger.root.onRecord.where((r) => r.level >= Level.WARNING).listen(warnings.add);
    addTearDown(sub.cancel);
  });

  for (final (what, raw) in [('null', null), ('an empty text', ''), ('blanks', '  \n\t ')]) {
    test('$what: no statement data, no warning', () async {
      expect(decodeRawMetadata(raw), isNull);
      TransactionClassifierService.normalize(description: 'Trenitalia', rawMetadataJson: raw, amount: -10);
      await pumpEventQueue();
      expect(warnings, isEmpty);
    });
  }

  for (final (what, raw) in [('broken text', '{"Bank": '), ('a JSON list', '["1070"]'), ('JSON null', 'null')]) {
    test('$what: no statement data, one warning', () async {
      expect(decodeRawMetadata(raw), isNull);
      await pumpEventQueue();
      expect(warnings.map((r) => r.message), [contains('raw statement data is not a JSON object')]);
    });
  }

  test('a JSON object is the statement data', () {
    expect(decodeRawMetadata(' {"Bank":"1070"} '), {'Bank': '1070'});
  });
}
