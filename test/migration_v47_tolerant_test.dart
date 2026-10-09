// Migration v47 reads the filtered balance settings of every transaction
// import config with the shared tolerant reader: the include set as a
// JSON-encoded list or a list (pinned), a config it cannot read skipped rather
// than guessed (pinned) — and a filter column of an unexpected shape no longer
// aborts the migration (and with it the database upgrade).
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> account(String name) => db.into(db.accounts).insert(AccountsCompanion.insert(name: name));

  Future<void> config(int accountId, Map<String, Object?> mappings) => db.customStatement(
    "INSERT INTO import_configs (account_id, scope, mappings_json, formula_json, hash_columns_json) VALUES (?, 'transaction', ?, '[]', '[]')",
    [accountId, jsonEncode(mappings)],
  );

  Future<void> tx(int accountId, String state) => db.customStatement(
    'INSERT INTO transactions (account_id, operation_date, value_date, amount, description, status, currency, tags, raw_metadata) '
    "VALUES (?, strftime('%s','2025-01-01'), strftime('%s','2025-01-01'), -1.0, ?, 'settled', 'EUR', '[]', ?)",
    [
      accountId,
      state,
      jsonEncode({'State': state}),
    ],
  );

  Future<Map<String, TransactionStatus>> statuses() async => {for (final t in await db.select(db.transactions).get()) t.description: t.status};

  test('pin: an include set stored as a JSON list', () async {
    final a = await account('A');
    await config(a, {
      '__balanceMode': 'filtered',
      '__balanceFilterColumn': 'State',
      '__balanceFilterInclude': ['DONE'],
    });
    await tx(a, 'DONE');
    await tx(a, 'FAILED');
    await db.runMigrateCancelledFromFilteredConfigs();
    expect(await statuses(), {'DONE': TransactionStatus.settled, 'FAILED': TransactionStatus.cancelled});
  });

  test('pin: an include set that is not JSON skips the config', () async {
    final a = await account('A');
    await config(a, {'__balanceMode': 'filtered', '__balanceFilterColumn': 'State', '__balanceFilterInclude': 'DONE'});
    await tx(a, 'FAILED');
    await db.runMigrateCancelledFromFilteredConfigs();
    expect(await statuses(), {'FAILED': TransactionStatus.settled});
  });

  test('a filter column that is not text skips that config; the others are migrated', () async {
    final bad = await account('Bad');
    final good = await account('Good');
    await config(bad, {'__balanceMode': 'filtered', '__balanceFilterColumn': 7, '__balanceFilterInclude': '["DONE"]'});
    await config(good, {'__balanceMode': 'filtered', '__balanceFilterColumn': 'State', '__balanceFilterInclude': '["DONE"]'});
    await tx(bad, 'SKIPPED');
    await tx(good, 'FAILED');
    await db.runMigrateCancelledFromFilteredConfigs();
    expect(await statuses(), {'SKIPPED': TransactionStatus.settled, 'FAILED': TransactionStatus.cancelled});
  });
}
