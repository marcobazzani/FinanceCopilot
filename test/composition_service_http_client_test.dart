// Pinned bug: the composition sync talked to the network through a bare
// `Dio()` — no connect, send or receive timeout. Assets are synced one after
// another, so a single stalled request hung the whole sync forever and the
// global refresh never finished.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/market/composition_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('the default client gives up on a stalled request instead of hanging the sync', () {
    final service = CompositionService(db);
    addTearDown(service.dispose);
    final options = service.httpClientForTest.options;

    for (final (name, timeout) in [
      ('connect', options.connectTimeout),
      ('send', options.sendTimeout),
      ('receive', options.receiveTimeout),
    ]) {
      expect(timeout, isNotNull, reason: '$name timeout');
      expect(timeout, lessThanOrEqualTo(const Duration(seconds: 30)), reason: '$name timeout');
      expect(timeout, greaterThan(Duration.zero), reason: '$name timeout');
    }
  });
}
