import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/utils/uuid_v7.dart';

void main() {
  test('ids minted within the same millisecond stay unique and well-formed', () {
    // Thousands of ids in a tight loop share milliseconds by pigeonhole, so
    // the per-millisecond sequence path always runs (it used to be reached
    // only when a fast machine happened to mint two ids in one tick).
    final ids = List.generate(5000, (_) => UuidV7.generate());
    final format = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

    expect(ids.toSet(), hasLength(ids.length));
    expect(ids.where((id) => !format.hasMatch(id)), isEmpty, reason: 'version 7, RFC 4122 variant');
    final msPrefixes = ids.map((id) => id.substring(0, 13)).toSet();
    expect(msPrefixes.length, lessThan(ids.length), reason: 'several ids shared a millisecond');
  });
}
