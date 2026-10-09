// A hand-entered row, or an edit that moves a value date or an amount, moves
// the running balance of every later row. Only the delete paths used to re-run
// it, so creating or editing a row left `balance_after` stale — and the
// account balance read from it wrong.
//
// The account balance is the latest STORED balance: a row with no balance
// (hand-entered in an account whose balances come from nowhere) on the latest
// day used to make the account balance disappear.
import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/domain/account_service.dart';
import 'package:finance_copilot/services/domain/transaction_service.dart';

void main() {
  late AppDatabase db;
  late TransactionService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = TransactionService(db);
  });
  tearDown(() => db.close());

  Future<int> account(String name) => db.into(db.accounts).insert(AccountsCompanion.insert(name: name));

  Future<void> cumulativeConfig(int accountId) => db
      .into(db.importConfigs)
      .insert(ImportConfigsCompanion.insert(accountId: Value(accountId), mappingsJson: Value(jsonEncode({'__balanceMode': 'cumulative'}))));

  Future<int> row(int accountId, DateTime day, double amount, String description) => service.create(
    accountId: accountId,
    operationDate: day,
    valueDate: day,
    amount: amount,
    currency: 'EUR',
    description: description,
  );

  Future<Map<String, double?>> balances(int accountId) async => {
    for (final t in await service.getByAccount(accountId)) t.description: t.balanceAfter,
  };

  group('create re-runs the running balance', () {
    test('each new row gets its balance; one dated earlier moves the later ones', () async {
      final acct = await account('Main');
      await cumulativeConfig(acct);

      await row(acct, DateTime(2025, 1, 10), 100, 'salary');
      await row(acct, DateTime(2025, 1, 20), -30, 'groceries');
      expect(await balances(acct), {'salary': 100.0, 'groceries': 70.0});

      await row(acct, DateTime(2025, 1, 5), -10, 'coffee');
      expect(await balances(acct), {'coffee': -10.0, 'salary': 90.0, 'groceries': 60.0});
    });

    test('an account without an import config keeps the balance given', () async {
      final acct = await account('Manual');
      await service.create(
        accountId: acct,
        operationDate: DateTime(2025, 1, 10),
        amount: 100,
        balanceAfter: 950,
        currency: 'EUR',
        description: 'given',
      );
      expect(await balances(acct), {'given': 950.0});
    });
  });

  group('update re-runs the running balance', () {
    /// Balances brought up to date explicitly, so each test sees only what
    /// the update itself does.
    Future<void> settled(int accountId) => service.recalculateBalances(accountId, balanceMode: 'cumulative');

    test('moving a value date before an earlier row', () async {
      final acct = await account('Main');
      await cumulativeConfig(acct);
      await row(acct, DateTime(2025, 1, 10), 100, 'salary');
      final groceries = await row(acct, DateTime(2025, 1, 20), -30, 'groceries');
      await settled(acct);

      await service.update(groceries, TransactionsCompanion(valueDate: Value(DateTime(2025, 1, 5))));
      expect(await balances(acct), {'groceries': -30.0, 'salary': 70.0});
    });

    test('changing an amount', () async {
      final acct = await account('Main');
      await cumulativeConfig(acct);
      final salary = await row(acct, DateTime(2025, 1, 10), 100, 'salary');
      await row(acct, DateTime(2025, 1, 20), -30, 'groceries');
      await settled(acct);

      await service.update(salary, const TransactionsCompanion(amount: Value(120)));
      expect(await balances(acct), {'salary': 120.0, 'groceries': 90.0});
    });

    test('moving a row to another account re-runs both accounts', () async {
      final from = await account('From');
      final to = await account('To');
      await cumulativeConfig(from);
      await cumulativeConfig(to);
      await row(from, DateTime(2025, 1, 10), 100, 'salary');
      final moved = await row(from, DateTime(2025, 1, 20), -30, 'groceries');
      await row(to, DateTime(2025, 1, 15), 500, 'opening');
      await settled(from);
      await settled(to);

      await service.update(moved, TransactionsCompanion(accountId: Value(to)));
      expect(await balances(from), {'salary': 100.0});
      expect(await balances(to), {'groceries': 470.0, 'opening': 500.0});
    });

    test('a category-only edit leaves the balances alone', () async {
      final acct = await account('Main');
      await cumulativeConfig(acct);
      final salary = await row(acct, DateTime(2025, 1, 10), 100, 'salary');
      // Balances deliberately out of line: only a recalculation would fix them.
      await service.batchUpdateBalances({salary: 42});

      await service.update(salary, const TransactionsCompanion(description: Value('pay')));
      expect(await balances(acct), {'pay': 42.0});
    });

    test('an unknown row is reported as not updated', () async {
      expect(await service.update(999, TransactionsCompanion(valueDate: Value(DateTime(2025, 1, 1)))), isFalse);
    });
  });

  group('account balance = latest row that has a balance', () {
    Future<void> insert(int accountId, DateTime day, double amount, {double? balance}) => db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: accountId,
            operationDate: day,
            valueDate: day,
            amount: amount,
            balanceAfter: Value(balance),
          ),
        );

    test('a later hand-entered row without a balance', () async {
      final acct = await account('Main');
      await insert(acct, DateTime(2025, 1, 10), 100, balance: 100);
      await insert(acct, DateTime(2025, 1, 20), -30);

      final stats = (await AccountService(db).getStatsForAll())[acct]!;
      expect(stats.balance, 100.0, reason: 'the latest known balance, not no balance at all');
      expect(stats.count, 2);
      expect(stats.lastDate, DateTime(2025, 1, 20));
    });

    test('a row without a balance on the same latest day, inserted last', () async {
      final acct = await account('Main');
      await insert(acct, DateTime(2025, 1, 10), 100, balance: 100);
      await insert(acct, DateTime(2025, 1, 20), -30, balance: 70);
      await insert(acct, DateTime(2025, 1, 20), -5);

      expect((await AccountService(db).getStatsForAll())[acct]!.balance, 70.0);
      expect((await AccountService(db).watchStatsForAll().first)[acct]!.balance, 70.0);
    });

    test('the as-of bound still applies', () async {
      final acct = await account('Main');
      await insert(acct, DateTime(2025, 1, 10), 100, balance: 100);
      await insert(acct, DateTime(2025, 1, 12), 5);
      await insert(acct, DateTime(2025, 1, 20), -30, balance: 70);

      expect((await AccountService(db).getStatsForAll(through: DateTime(2025, 1, 15)))[acct]!.balance, 100.0);
    });

    test('an account whose rows carry no balance at all has none', () async {
      final acct = await account('Main');
      await insert(acct, DateTime(2025, 1, 10), 100);

      final stats = (await AccountService(db).getStatsForAll())[acct]!;
      expect(stats.balance, isNull);
      expect(stats.count, 1);
    });
  });
}
