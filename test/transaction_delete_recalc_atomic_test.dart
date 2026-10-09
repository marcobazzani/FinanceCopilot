// Deleting rows and re-running the running balance they moved are one DB
// transaction, as saving a row is: a failed recalculation used to leave the
// row(s) deleted with every later balance stale. Now nothing is deleted.
import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/domain/transaction_service.dart';

void main() {
  late AppDatabase db;
  late TransactionService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = TransactionService(db);
  });
  tearDown(() => db.close());

  Future<int> cumulativeAccount(String name) async {
    final id = await db.into(db.accounts).insert(AccountsCompanion.insert(name: name));
    await db
        .into(db.importConfigs)
        .insert(ImportConfigsCompanion.insert(accountId: Value(id), mappingsJson: Value(jsonEncode({'__balanceMode': 'cumulative'}))));
    return id;
  }

  Future<int> row(int accountId, int day, double amount) => db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          accountId: accountId,
          operationDate: DateTime(2025, 1, day),
          valueDate: DateTime(2025, 1, day),
          amount: amount,
          description: Value('Day $day'),
        ),
      );

  Future<List<(double, double?)>> rows(int accountId) async => [
    for (final t
        in await (db.select(db.transactions)
              ..where((t) => t.accountId.equals(accountId))
              ..orderBy([(t) => OrderingTerm.asc(t.valueDate), (t) => OrderingTerm.asc(t.id)]))
            .get())
      (t.amount, t.balanceAfter),
  ];

  /// The recalculation's balance write fails from now on; a delete does not.
  Future<void> failBalanceWrites() => db.customStatement(
    "CREATE TEMP TRIGGER fail_balance BEFORE UPDATE OF balance_after ON transactions BEGIN SELECT RAISE(ABORT, 'injected failure'); END",
  );

  test('delete: a failed recalculation leaves the row in place', () async {
    final acct = await cumulativeAccount('Main');
    await row(acct, 1, 100);
    final gone = await row(acct, 2, -30);
    await row(acct, 3, 10);
    await service.recalculateBalances(acct, balanceMode: 'cumulative');
    await failBalanceWrites();

    await expectLater(service.delete(gone), throwsA(anything));
    expect(await rows(acct), [(100, 100), (-30, 70), (10, 80)], reason: 'the delete is rolled back with its recalculation');
  });

  test('deleteMany: a failed recalculation of any account leaves every row in place', () async {
    final a = await cumulativeAccount('A');
    final b = await cumulativeAccount('B');
    final a1 = await row(a, 1, 100);
    await row(a, 2, 50);
    final b1 = await row(b, 1, 20);
    await row(b, 2, 5);
    await service.recalculateBalances(a, balanceMode: 'cumulative');
    await service.recalculateBalances(b, balanceMode: 'cumulative');
    await failBalanceWrites();

    await expectLater(service.deleteMany([a1, b1]), throwsA(anything));
    expect(await rows(a), [(100, 100), (50, 150)]);
    expect(await rows(b), [(20, 20), (5, 25)]);
  });

  test('baseline: without a failure the rows go and the balances follow', () async {
    final a = await cumulativeAccount('A');
    final gone = await row(a, 1, 100);
    final alsoGone = await row(a, 2, 50);
    await row(a, 3, 10);
    await service.recalculateBalances(a, balanceMode: 'cumulative');

    expect(await service.delete(gone), 1);
    expect(await rows(a), [(50, 50), (10, 60)]);
    expect(await service.deleteMany([alsoGone]), 1);
    expect(await rows(a), [(10, 10)]);
    expect(await service.delete(gone), 0, reason: 'already gone');
  });
}
