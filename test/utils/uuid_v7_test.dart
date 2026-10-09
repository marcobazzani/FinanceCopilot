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

  // The timestamp is the leading 48 bits: `tttttttt-tttt-7sss-…`.
  int timestampOf(String id) => int.parse(id.substring(0, 8) + id.substring(9, 13), radix: 16);

  void expectCreationOrder(List<String> ids) {
    for (var i = 1; i < ids.length; i++) {
      expect(ids[i].compareTo(ids[i - 1]), greaterThan(0), reason: 'id #$i sorts before id #${i - 1}');
    }
  }

  test('a millisecond that runs out of sequence numbers moves on to the next one, in order', () {
    // 12-bit sequence: at most 4096 ids per millisecond on a frozen clock.
    final t = DateTime(2100).millisecondsSinceEpoch;
    final ids = List.generate(10000, (_) => UuidV7.generateAt(t));

    expectCreationOrder(ids);
    final stamps = ids.map(timestampOf).toList();
    expect(stamps.toSet().length, greaterThanOrEqualTo(3));
    expect(stamps.first, t);
  });

  test('a wall clock that steps back never makes an id sort before the previous one', () {
    final t = DateTime(2101).millisecondsSinceEpoch;
    final ids = [UuidV7.generateAt(t), UuidV7.generateAt(t - 60000), UuidV7.generateAt(t - 1)];

    expectCreationOrder(ids);
    expect(ids.map(timestampOf), everyElement(t), reason: 'stays on the last timestamp until the clock catches up');
    expect(timestampOf(UuidV7.generateAt(t + 5)), t + 5);
  });
}
