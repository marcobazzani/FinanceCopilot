import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/transaction_service.dart';

void main() {
  late AppDatabase db;
  late TransactionService service;

  /// Helper: insert a parent account and return its id.
  Future<int> createAccount(String name) async {
    return db.into(db.accounts).insert(AccountsCompanion.insert(
          name: name,
        ));
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = TransactionService(db);
  });

  tearDown(() async => await db.close());

  group('create and retrieve', () {
    test('create returns an id and getByAccount retrieves it', () async {
      final accountId = await createAccount('Checking');

      final id = await service.create(
        accountId: accountId,
        operationDate: DateTime(2024, 3, 15),
        amount: 100.0,
        description: 'Salary',
        currency: 'EUR',
      );
      expect(id, greaterThan(0));

      final txs = await service.getByAccount(accountId);
      expect(txs.length, 1);
      expect(txs.first.amount, 100.0);
      expect(txs.first.description, 'Salary');
      expect(txs.first.currency, 'EUR');
      expect(txs.first.status, TransactionStatus.settled);
    });

    test('create with all optional fields', () async {
      final accountId = await createAccount('Full');

      await service.create(
        accountId: accountId,
        operationDate: DateTime(2024, 1, 1),
        amount: -50.0,
        description: 'Coffee',
        descriptionFull: 'Starbucks coffee purchase',
        balanceAfter: 950.0,
        currency: 'USD',
        status: TransactionStatus.pending,
      );

      final txs = await service.getByAccount(accountId);
      final tx = txs.first;
      expect(tx.descriptionFull, 'Starbucks coffee purchase');
      expect(tx.balanceAfter, 950.0);
      expect(tx.currency, 'USD');
      expect(tx.status, TransactionStatus.pending);
    });
  });

  group('ordering', () {
    test('getByAccount returns transactions ordered desc by date, then desc by id', () async {
      final accountId = await createAccount('Ordered');

      await service.create(
        accountId: accountId,
        operationDate: DateTime(2024, 1, 1),
        amount: 100.0,
        description: 'Jan',
        currency: 'EUR',
      );
      await service.create(
        accountId: accountId,
        operationDate: DateTime(2024, 6, 1),
        amount: 200.0,
        description: 'Jun',
        currency: 'EUR',
      );
      await service.create(
        accountId: accountId,
        operationDate: DateTime(2024, 3, 1),
        amount: 150.0,
        description: 'Mar',
        currency: 'EUR',
      );
      // Same date as Jun, should be ordered by id desc (this one has higher id)
      await service.create(
        accountId: accountId,
        operationDate: DateTime(2024, 6, 1),
        amount: 250.0,
        description: 'Jun2',
        currency: 'EUR',
      );

      final txs = await service.getByAccount(accountId);
      expect(txs.length, 4);
      // Jun2 (highest id on same date) comes first
      expect(txs[0].description, 'Jun2');
      expect(txs[1].description, 'Jun');
      expect(txs[2].description, 'Mar');
      expect(txs[3].description, 'Jan');
    });
  });

  group('update', () {
    test('update description', () async {
      final accountId = await createAccount('Upd');
      final id = await service.create(
        accountId: accountId,
        operationDate: DateTime(2024, 1, 1),
        amount: 100.0,
        description: 'Old',
        currency: 'EUR',
      );

      final result = await service.update(
        id,
        const TransactionsCompanion(description: Value('New')),
      );
      expect(result, isTrue);

      final txs = await service.getByAccount(accountId);
      expect(txs.first.description, 'New');
    });

    test('update non-existent id returns false', () async {
      final result = await service.update(
        999,
        const TransactionsCompanion(description: Value('Nope')),
      );
      expect(result, isFalse);
    });
  });

  group('delete', () {
    test('delete single transaction', () async {
      final accountId = await createAccount('Del');
      final id = await service.create(
        accountId: accountId,
        operationDate: DateTime(2024, 1, 1),
        amount: 100.0,
        currency: 'EUR',
      );

      final deleted = await service.delete(id);
      expect(deleted, 1);

      final txs = await service.getByAccount(accountId);
      expect(txs, isEmpty);
    });
  });

  group('batchUpdateBalances', () {
    test('updates balanceAfter for multiple transactions', () async {
      final accountId = await createAccount('Batch');
      final id1 = await service.create(
        accountId: accountId,
        operationDate: DateTime(2024, 1, 1),
        amount: 100.0,
        currency: 'EUR',
      );
      final id2 = await service.create(
        accountId: accountId,
        operationDate: DateTime(2024, 1, 2),
        amount: 200.0,
        currency: 'EUR',
      );

      await service.batchUpdateBalances({id1: 100.0, id2: 300.0});

      final txs = await service.getByAccount(accountId);
      // Ordered desc by date: id2 first, id1 second
      expect(txs[0].balanceAfter, 300.0);
      expect(txs[1].balanceAfter, 100.0);
    });

    test('can set balanceAfter to null', () async {
      final accountId = await createAccount('NullBal');
      final id = await service.create(
        accountId: accountId,
        operationDate: DateTime(2024, 1, 1),
        amount: 100.0,
        balanceAfter: 100.0,
        currency: 'EUR',
      );

      await service.batchUpdateBalances({id: null});

      final txs = await service.getByAccount(accountId);
      expect(txs.first.balanceAfter, isNull);
    });
  });

  group('deleteByAccount', () {
    test('removes all transactions for an account', () async {
      final accountId = await createAccount('DelAll');
      await service.create(
        accountId: accountId,
        operationDate: DateTime(2024, 1, 1),
        amount: 100.0,
        currency: 'EUR',
      );
      await service.create(
        accountId: accountId,
        operationDate: DateTime(2024, 2, 1),
        amount: 200.0,
        currency: 'EUR',
      );
      await service.create(
        accountId: accountId,
        operationDate: DateTime(2024, 3, 1),
        amount: 300.0,
        currency: 'EUR',
      );

      final deleted = await service.deleteByAccount(accountId);
      expect(deleted, 3);

      final txs = await service.getByAccount(accountId);
      expect(txs, isEmpty);
    });

    test('does not affect other accounts', () async {
      final acc1 = await createAccount('Acc1');
      final acc2 = await createAccount('Acc2');

      await service.create(
        accountId: acc1,
        operationDate: DateTime(2024, 1, 1),
        amount: 100.0,
        currency: 'EUR',
      );
      await service.create(
        accountId: acc2,
        operationDate: DateTime(2024, 1, 1),
        amount: 200.0,
        currency: 'EUR',
      );

      await service.deleteByAccount(acc1);

      final txs1 = await service.getByAccount(acc1);
      final txs2 = await service.getByAccount(acc2);
      expect(txs1, isEmpty);
      expect(txs2.length, 1);
    });
  });

}
