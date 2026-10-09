// parseStoredTaxRate lives with kDefaultTaxRate in asset_value_math.dart: the
// one reading of the TAX_RATE setting (its two readers are pinned in
// stored_tax_rate_readers_test.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

import 'package:finance_copilot/utils/asset_value_math.dart';

void main() {
  late List<LogRecord> warnings;

  setUp(() {
    warnings = [];
    final sub = Logger.root.onRecord.where((r) => r.level == Level.WARNING).listen(warnings.add);
    addTearDown(sub.cancel);
  });

  test('nothing stored: the default rate, silently', () async {
    expect(parseStoredTaxRate(null), kDefaultTaxRate);
    await pumpEventQueue();
    expect(warnings, isEmpty);
  });

  test('a number: clamped to [0, 1], silently', () async {
    expect(parseStoredTaxRate('0.3'), 0.3);
    expect(parseStoredTaxRate('0'), 0.0);
    expect(parseStoredTaxRate('1'), 1.0);
    expect(parseStoredTaxRate('1.5'), 1.0);
    expect(parseStoredTaxRate('-0.2'), 0.0);
    await pumpEventQueue();
    expect(warnings, isEmpty);
  });

  test('a value that is not a number: the default rate, and a warning naming it', () async {
    for (final stored in ['26%', '', 'abc', '0,3']) {
      expect(parseStoredTaxRate(stored), kDefaultTaxRate, reason: '"$stored"');
    }
    await pumpEventQueue();
    expect(warnings.map((r) => r.message), [
      for (final stored in ['26%', '', 'abc', '0,3']) 'TAX_RATE "$stored" is not a number: the default 0.26 applies',
    ]);
  });
}
