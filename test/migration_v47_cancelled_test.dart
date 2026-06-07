// Migration v47 — mark cancelled transactions from filtered import configs.
//
// When a transaction was imported under a 'filtered' balance config and its
// filter-column value is NOT in the config's include set, it never moved the
// balance but was stored status=settled. Migration v47 flips those rows to
// cancelled (status-only; balance_after untouched), using exact set
// membership against the saved __balanceFilterInclude — no phrase matching.
//
// This test exercises the REAL migration method via the @visibleForTesting
// hook, so it catches divergence if the migration logic changes.

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';

void main() {
  late AppDatabase db;
  late int accountId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Revolut'));
  });

  tearDown(() async => db.close());

  Future<void> insertTx({
    required double amount,
    required String desc,
    required String state,
    required double balanceAfter,
    String status = 'settled',
  }) async {
    await db.customStatement(
      'INSERT INTO transactions (account_id, operation_date, value_date, amount, description, balance_after, status, currency, tags, raw_metadata) '
      "VALUES (?, strftime('%s','2025-01-01'), strftime('%s','2025-01-01'), ?, ?, ?, ?, 'EUR', '[]', ?)",
      [
        accountId,
        amount,
        desc,
        balanceAfter,
        status,
        jsonEncode({'State': state, 'Descrizione': desc}),
      ],
    );
  }

  Future<void> insertFilteredConfig() async {
    await db.customStatement(
      "INSERT INTO import_configs (account_id, scope, mappings_json, formula_json, hash_columns_json) "
      "VALUES (?, 'transaction', ?, '[]', '[]')",
      [
        accountId,
        jsonEncode({
          'date': 'Data di inizio',
          'amount': 'Importo',
          'description': 'Descrizione',
          '__balanceMode': 'filtered',
          '__balanceFilterColumn': 'State',
          // stored as a JSON-encoded string list, mirroring production
          '__balanceFilterInclude': jsonEncode(['COMPLETATO', 'In sospeso']),
        }),
      ],
    );
  }

  test('flips excluded (ANNULLATA) rows to cancelled, leaves included settled', () async {
    await insertFilteredConfig();
    await insertTx(amount: -100.0, desc: 'Coffee', state: 'COMPLETATO', balanceAfter: -100.0);
    await insertTx(amount: -507.68, desc: 'Tires', state: 'OPERAZIONE ANNULLATA', balanceAfter: -100.0);
    await insertTx(amount: -50.0, desc: 'Lunch', state: 'COMPLETATO', balanceAfter: -150.0);

    await db.runMigrateCancelledFromFilteredConfigs();

    final txs = await db.select(db.transactions).get();
    final byDesc = {for (final t in txs) t.description: t};
    expect(byDesc['Tires']!.status, TransactionStatus.cancelled);
    expect(byDesc['Coffee']!.status, TransactionStatus.settled);
    expect(byDesc['Lunch']!.status, TransactionStatus.settled);
  });

  test('does NOT touch balance_after', () async {
    await insertFilteredConfig();
    await insertTx(amount: -507.68, desc: 'Tires', state: 'OPERAZIONE ANNULLATA', balanceAfter: -100.0);

    await db.runMigrateCancelledFromFilteredConfigs();

    final t = (await db.select(db.transactions).get()).single;
    expect(t.status, TransactionStatus.cancelled);
    expect(t.balanceAfter, -100.0, reason: 'balance_after must be untouched');
  });

  test('is idempotent — second run changes nothing', () async {
    await insertFilteredConfig();
    await insertTx(amount: -507.68, desc: 'Tires', state: 'OPERAZIONE ANNULLATA', balanceAfter: -100.0);

    await db.runMigrateCancelledFromFilteredConfigs();
    await db.runMigrateCancelledFromFilteredConfigs();

    final cancelled = (await db.select(db.transactions).get()).where((t) => t.status == TransactionStatus.cancelled);
    expect(cancelled, hasLength(1));
  });

  test('no-op for accounts without a filtered config', () async {
    // No import config inserted at all.
    await insertTx(amount: -507.68, desc: 'Tires', state: 'OPERAZIONE ANNULLATA', balanceAfter: -100.0);

    await db.runMigrateCancelledFromFilteredConfigs();

    final t = (await db.select(db.transactions).get()).single;
    expect(t.status, TransactionStatus.settled, reason: 'without a filtered config, status is left as-is');
  });

  test('rows with no parseable filter value are left untouched (no guessing)', () async {
    await insertFilteredConfig();
    // raw_metadata without the State key at all.
    await db.customStatement(
      'INSERT INTO transactions (account_id, operation_date, value_date, amount, description, balance_after, status, currency, tags, raw_metadata) '
      "VALUES (?, strftime('%s','2025-01-01'), strftime('%s','2025-01-01'), -10.0, 'NoState', -10.0, 'settled', 'EUR', '[]', ?)",
      [
        accountId,
        jsonEncode({'Other': 'x'}),
      ],
    );

    await db.runMigrateCancelledFromFilteredConfigs();

    final t = (await db.select(db.transactions).get()).single;
    expect(t.status, TransactionStatus.settled);
  });
}
