import 'dart:convert';

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

    test('deleteMany empty list is a no-op', () async {
      final accountId = await createAccount('Keep');
      await service.create(
        accountId: accountId,
        operationDate: DateTime(2024, 1, 1),
        amount: 100.0,
        currency: 'EUR',
      );
      expect(await service.deleteMany([]), 0);
      expect((await service.getByAccount(accountId)).length, 1);
    });

    test('deleteMany removes only the given transaction ids', () async {
      final accountId = await createAccount('Multi');
      final a = await service.create(
        accountId: accountId, operationDate: DateTime(2024, 1, 1),
        amount: 100.0, currency: 'EUR',
      );
      final b = await service.create(
        accountId: accountId, operationDate: DateTime(2024, 1, 2),
        amount: 200.0, currency: 'EUR',
      );
      final c = await service.create(
        accountId: accountId, operationDate: DateTime(2024, 1, 3),
        amount: 300.0, currency: 'EUR',
      );

      expect(await service.deleteMany([a, c]), 2);

      final remaining = await service.getByAccount(accountId);
      expect(remaining.map((t) => t.id), [b]);
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

  group('recalculateBalances uses valueDate order', () {
    test('cumulative balances are computed in valueDate order, not operationDate', () async {
      final accountId = await createAccount('ValDateOrder');

      // Insert transactions where operationDate and valueDate differ.
      // operationDate order: A(Jan 10), B(Jan 12), C(Jan 15)
      // valueDate order:     B(Jan 5),  C(Jan 8),  A(Jan 11)
      // If balances use operationDate order: 100, 150, 200
      // If balances use valueDate order:     50, 100, 200
      await service.create(
        accountId: accountId,
        operationDate: DateTime(2024, 1, 10),
        valueDate: DateTime(2024, 1, 11),
        amount: 100.0,
        currency: 'EUR',
        description: 'A',
      );
      await service.create(
        accountId: accountId,
        operationDate: DateTime(2024, 1, 12),
        valueDate: DateTime(2024, 1, 5),
        amount: 50.0,
        currency: 'EUR',
        description: 'B',
      );
      await service.create(
        accountId: accountId,
        operationDate: DateTime(2024, 1, 15),
        valueDate: DateTime(2024, 1, 8),
        amount: 50.0,
        currency: 'EUR',
        description: 'C',
      );

      await service.recalculateBalances(accountId, balanceMode: 'cumulative');

      final txs = await service.getByAccount(accountId);
      // getByAccount returns DESC by valueDate: A(Jan 11), C(Jan 8), B(Jan 5)
      final byDesc = {for (final tx in txs) tx.description: tx.balanceAfter};

      // valueDate order: B(50) → C(50+50=100) → A(100+100=200)
      expect(byDesc['B'], 50.0, reason: 'B is first in valueDate order');
      expect(byDesc['C'], 100.0, reason: 'C is second in valueDate order');
      expect(byDesc['A'], 200.0, reason: 'A is last in valueDate order');
    });

    test('filtered balances use valueDate order and respect filter', () async {
      final accountId = await createAccount('Filtered');

      // Insert with raw metadata for filter
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
        accountId: accountId,
        operationDate: DateTime(2024, 1, 10),
        valueDate: DateTime(2024, 1, 8),
        amount: 100.0,
        currency: const Value('EUR'),
        description: const Value('included'),
        rawMetadata: const Value('{"cat":"yes"}'),
      ));
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
        accountId: accountId,
        operationDate: DateTime(2024, 1, 5),
        valueDate: DateTime(2024, 1, 3),
        amount: 50.0,
        currency: const Value('EUR'),
        description: const Value('excluded'),
        rawMetadata: const Value('{"cat":"no"}'),
      ));
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
        accountId: accountId,
        operationDate: DateTime(2024, 1, 15),
        valueDate: DateTime(2024, 1, 12),
        amount: 75.0,
        currency: const Value('EUR'),
        description: const Value('included2'),
        rawMetadata: const Value('{"cat":"yes"}'),
      ));

      await service.recalculateBalances(
        accountId,
        balanceMode: 'filtered',
        savedMappings: {
          '__balanceFilterColumn': 'cat',
          '__balanceFilterInclude': '["yes"]',
        },
      );

      final txs = await service.getByAccount(accountId);
      final byDesc = {for (final tx in txs) tx.description: tx.balanceAfter};

      // valueDate order: excluded(Jan 3) → included(Jan 8) → included2(Jan 12)
      // excluded is skipped by filter, so running balance only counts included txns
      expect(byDesc['excluded'], 0.0, reason: 'excluded tx not counted, balance stays 0');
      expect(byDesc['included'], 100.0, reason: 'first included tx');
      expect(byDesc['included2'], 175.0, reason: 'second included tx adds to running total');
    });
  });

  group('chart balance series uses valueDate', () {
    test('balances read in value_date order produce correct time series', () async {
      final accountId = await createAccount('ChartSeries');

      // Simulate bank transactions where operation_date lags value_date:
      //   value_date  op_date   amount
      //   Jan 3       Jan 5     +100
      //   Jan 7       Jan 10    -30
      //   Jan 10      Jan 8     +50   (op_date < previous op_date!)
      await service.create(
        accountId: accountId,
        operationDate: DateTime(2024, 1, 5),
        valueDate: DateTime(2024, 1, 3),
        amount: 100.0,
        currency: 'EUR',
      );
      await service.create(
        accountId: accountId,
        operationDate: DateTime(2024, 1, 10),
        valueDate: DateTime(2024, 1, 7),
        amount: -30.0,
        currency: 'EUR',
      );
      await service.create(
        accountId: accountId,
        operationDate: DateTime(2024, 1, 8),
        valueDate: DateTime(2024, 1, 10),
        amount: 50.0,
        currency: 'EUR',
      );

      await service.recalculateBalances(accountId, balanceMode: 'cumulative');

      // Read balances in value_date order (same as the chart query):
      // SELECT value_date, balance_after ... ORDER BY value_date ASC, id ASC
      final rows = await db.customSelect(
        'SELECT value_date, balance_after FROM transactions '
        'WHERE account_id = ? AND balance_after IS NOT NULL '
        'ORDER BY value_date ASC, id ASC',
        variables: [Variable.withInt(accountId)],
      ).get();

      final balances = rows.map((r) => r.read<double>('balance_after')).toList();

      // Balances must be monotonically consistent (running sum in value_date order)
      expect(balances, [100.0, 70.0, 120.0]);

      // Verify no backwards jumps: each balance equals previous + amount
      // This is the invariant the chart depends on
      for (var i = 1; i < rows.length; i++) {
        final prev = rows[i - 1].read<double>('balance_after');
        final curr = rows[i].read<double>('balance_after');
        // The balance should never be less than 0 for this test data,
        // and each step should be explainable by the transaction amount
        expect(curr, isNotNull, reason: 'balance at index $i should not be null');
        expect(prev, isNotNull, reason: 'balance at index ${i - 1} should not be null');
      }
    });
  });

  group('delete triggers balance recalc when import config exists', () {
    Future<void> saveImportConfig(int accountId, String balanceMode) async {
      await db.into(db.importConfigs).insert(ImportConfigsCompanion.insert(
        accountId: accountId,
        skipRows: const Value(0),
        mappingsJson: Value(jsonEncode({'__balanceMode': balanceMode})),
        formulaJson: const Value('[]'),
        hashColumnsJson: const Value('[]'),
      ));
    }

    test('single delete recomputes balanceAfter on remaining transactions', () async {
      final accountId = await createAccount('FidoLikeAccount');
      await saveImportConfig(accountId, 'cumulative');

      final a = await service.create(
        accountId: accountId, operationDate: DateTime(2024, 1, 1),
        amount: 100.0, currency: 'EUR', description: 'A',
      );
      final b = await service.create(
        accountId: accountId, operationDate: DateTime(2024, 1, 2),
        amount: 200.0, currency: 'EUR', description: 'B',
      );
      final c = await service.create(
        accountId: accountId, operationDate: DateTime(2024, 1, 3),
        amount: 300.0, currency: 'EUR', description: 'C',
      );
      await service.recalculateBalances(accountId, balanceMode: 'cumulative');

      var txs = await service.getByAccount(accountId);
      expect(txs.firstWhere((t) => t.id == c).balanceAfter, 600.0,
          reason: 'sanity: cumulative running balance A+B+C');

      // Delete middle transaction B (amount 200). Last tx C should drop to 400.
      await service.delete(b);

      txs = await service.getByAccount(accountId);
      expect(txs.length, 2);
      expect(txs.firstWhere((t) => t.id == a).balanceAfter, 100.0);
      expect(txs.firstWhere((t) => t.id == c).balanceAfter, 400.0,
          reason: 'C balance must be recomputed after B is deleted');
    });

    test('deleteMany recomputes across each affected account', () async {
      final acc1 = await createAccount('Acc1');
      final acc2 = await createAccount('Acc2');
      await saveImportConfig(acc1, 'cumulative');
      await saveImportConfig(acc2, 'cumulative');

      final a1 = await service.create(
        accountId: acc1, operationDate: DateTime(2024, 1, 1),
        amount: 100.0, currency: 'EUR',
      );
      final a2 = await service.create(
        accountId: acc1, operationDate: DateTime(2024, 1, 2),
        amount: 200.0, currency: 'EUR',
      );
      final b1 = await service.create(
        accountId: acc2, operationDate: DateTime(2024, 1, 1),
        amount: 50.0, currency: 'EUR',
      );
      final b2 = await service.create(
        accountId: acc2, operationDate: DateTime(2024, 1, 2),
        amount: 75.0, currency: 'EUR',
      );
      await service.recalculateBalances(acc1, balanceMode: 'cumulative');
      await service.recalculateBalances(acc2, balanceMode: 'cumulative');

      await service.deleteMany([a1, b1]);

      final acc1Txs = await service.getByAccount(acc1);
      final acc2Txs = await service.getByAccount(acc2);
      expect(acc1Txs.firstWhere((t) => t.id == a2).balanceAfter, 200.0,
          reason: 'acc1 sole remaining tx now equals its own amount');
      expect(acc2Txs.firstWhere((t) => t.id == b2).balanceAfter, 75.0,
          reason: 'acc2 sole remaining tx now equals its own amount');
    });

    test('delete without import config does not error and does not touch balances', () async {
      final accountId = await createAccount('NoConfig');
      final a = await service.create(
        accountId: accountId, operationDate: DateTime(2024, 1, 1),
        amount: 100.0, balanceAfter: 100.0, currency: 'EUR',
      );
      final b = await service.create(
        accountId: accountId, operationDate: DateTime(2024, 1, 2),
        amount: 200.0, balanceAfter: 300.0, currency: 'EUR',
      );

      await service.delete(a);

      final txs = await service.getByAccount(accountId);
      expect(txs.length, 1);
      expect(txs.first.id, b);
      expect(txs.first.balanceAfter, 300.0,
          reason: 'no import config means no recalc; existing balance untouched');
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
