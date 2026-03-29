import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/account_service.dart';

void main() {
  late AppDatabase db;
  late AccountService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = AccountService(db);
  });

  tearDown(() async => await db.close());

  group('create and retrieve', () {
    test('create returns an id and getById retrieves it', () async {
      final id = await service.create(name: 'Checking', currency: 'EUR');
      expect(id, greaterThan(0));

      final account = await service.getById(id);
      expect(account.name, 'Checking');
      expect(account.currency, 'EUR');
      expect(account.institution, '');
    });

    test('create with custom currency and institution', () async {
      final id = await service.create(
        name: 'USD Account',
        currency: 'USD',
        institution: 'Chase',
      );

      final account = await service.getById(id);
      expect(account.currency, 'USD');
      expect(account.institution, 'Chase');
    });

    test('getAll returns all created accounts', () async {
      await service.create(name: 'A', currency: 'EUR');
      await service.create(name: 'B', currency: 'EUR');

      final all = await service.getAll();
      expect(all.length, 2);
    });
  });

  group('sortOrder auto-increment', () {
    test('each new account gets incrementing sortOrder', () async {
      await service.create(name: 'First', currency: 'EUR');
      await service.create(name: 'Second', currency: 'EUR');
      await service.create(name: 'Third', currency: 'EUR');

      final all = await service.getAll();
      expect(all[0].name, 'First');
      expect(all[0].sortOrder, 1);
      expect(all[1].name, 'Second');
      expect(all[1].sortOrder, 2);
      expect(all[2].name, 'Third');
      expect(all[2].sortOrder, 3);
    });
  });

  group('update', () {
    test('update name', () async {
      final id = await service.create(name: 'Old Name', currency: 'EUR');
      final result = await service.update(
        id,
        const AccountsCompanion(name: Value('New Name')),
      );
      expect(result, isTrue);

      final updated = await service.getById(id);
      expect(updated.name, 'New Name');
    });

    test('update currency', () async {
      final id = await service.create(name: 'Test', currency: 'EUR');
      await service.update(id, const AccountsCompanion(currency: Value('GBP')));

      final updated = await service.getById(id);
      expect(updated.currency, 'GBP');
    });

    test('update non-existent id returns false', () async {
      final result = await service.update(
        999,
        const AccountsCompanion(name: Value('Nope')),
      );
      expect(result, isFalse);
    });
  });

  group('delete', () {
    test('delete removes the account', () async {
      final id = await service.create(name: 'ToDelete', currency: 'EUR');
      final deleted = await service.delete(id);
      expect(deleted, 1);

      final all = await service.getAll();
      expect(all, isEmpty);
    });

    test('delete cascades transactions', () async {
      final accountId = await service.create(name: 'WithTx', currency: 'EUR');

      // Insert transactions directly
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
            accountId: accountId,
            operationDate: DateTime(2024, 1, 1),
            valueDate: DateTime(2024, 1, 1),
            amount: 100.0,
          ));
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
            accountId: accountId,
            operationDate: DateTime(2024, 1, 2),
            valueDate: DateTime(2024, 1, 2),
            amount: 200.0,
          ));

      // Verify transactions exist
      final txBefore = await (db.select(db.transactions)
            ..where((t) => t.accountId.equals(accountId)))
          .get();
      expect(txBefore.length, 2);

      // Delete the account
      await service.delete(accountId);

      // Verify transactions are gone
      final txAfter = await (db.select(db.transactions)
            ..where((t) => t.accountId.equals(accountId)))
          .get();
      expect(txAfter, isEmpty);
    });
  });

  group('reorder', () {
    test('reorder updates sortOrder for all accounts', () async {
      final id1 = await service.create(name: 'A', currency: 'EUR');
      final id2 = await service.create(name: 'B', currency: 'EUR');
      final id3 = await service.create(name: 'C', currency: 'EUR');

      // Reverse the order
      await service.reorder([id3, id2, id1]);

      final all = await service.getAll();
      expect(all[0].name, 'C');
      expect(all[0].sortOrder, 0);
      expect(all[1].name, 'B');
      expect(all[1].sortOrder, 1);
      expect(all[2].name, 'A');
      expect(all[2].sortOrder, 2);
    });
  });

  group('getStatsForAll', () {
    test('returns empty map when no transactions', () async {
      await service.create(name: 'Empty', currency: 'EUR');
      final stats = await service.getStatsForAll();
      expect(stats, isEmpty);
    });

    test('returns correct stats with transactions', () async {
      final accountId = await service.create(name: 'Stats', currency: 'EUR');

      await db.into(db.transactions).insert(TransactionsCompanion.insert(
            accountId: accountId,
            operationDate: DateTime(2024, 1, 10),
            valueDate: DateTime(2024, 1, 10),
            amount: 100.0,
            balanceAfter: const Value(100.0),
          ));
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
            accountId: accountId,
            operationDate: DateTime(2024, 3, 15),
            valueDate: DateTime(2024, 3, 15),
            amount: -50.0,
            balanceAfter: const Value(50.0),
          ));

      final stats = await service.getStatsForAll();
      expect(stats.containsKey(accountId), isTrue);

      final s = stats[accountId]!;
      expect(s.count, 2);
      expect(s.firstDate, isNotNull);
      expect(s.lastDate, isNotNull);
      expect(s.balance, 50.0);
    });

    test('stats for multiple accounts', () async {
      final id1 = await service.create(name: 'Acc1', currency: 'EUR');
      final id2 = await service.create(name: 'Acc2', currency: 'EUR');

      await db.into(db.transactions).insert(TransactionsCompanion.insert(
            accountId: id1,
            operationDate: DateTime(2024, 1, 1),
            valueDate: DateTime(2024, 1, 1),
            amount: 500.0,
            balanceAfter: const Value(500.0),
          ));
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
            accountId: id2,
            operationDate: DateTime(2024, 2, 1),
            valueDate: DateTime(2024, 2, 1),
            amount: 200.0,
            balanceAfter: const Value(200.0),
          ));

      final stats = await service.getStatsForAll();
      expect(stats.length, 2);
      expect(stats[id1]!.count, 1);
      expect(stats[id1]!.balance, 500.0);
      expect(stats[id2]!.count, 1);
      expect(stats[id2]!.balance, 200.0);
    });
  });
}
