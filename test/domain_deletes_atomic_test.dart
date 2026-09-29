// Deleting an account, an asset, an adjustment or a buffer removes its child
// rows first and the parent row last. A failure on the last write must leave
// NOTHING deleted: the children used to be gone already (each delete was its
// own write), leaving an account without its transactions, an asset without
// its events, an adjustment without its entries or buffer.
//
// The failure is injected with a trigger that aborts the parent row's delete.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/account_service.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';
import 'package:finance_copilot/services/domain/buffer_service.dart';
import 'package:finance_copilot/services/domain/extraordinary_event_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Every delete from [table] fails from now on.
  Future<void> failDeletesFrom(String table) =>
      db.customStatement("CREATE TEMP TRIGGER fail_delete_$table BEFORE DELETE ON $table BEGIN SELECT RAISE(ABORT, 'injected failure'); END");

  Future<int> count(String table) async => (await db.customSelect('SELECT COUNT(*) AS c FROM $table').getSingle()).read<int>('c');

  Future<List<int>> counts(List<String> tables) async => [for (final t in tables) await count(t)];

  group('AccountService', () {
    Future<int> accountWithHistory(String name) async {
      final id = await AccountService(db).create(name: name, currency: 'EUR');
      for (final day in [1, 2]) {
        await db
            .into(db.transactions)
            .insert(
              TransactionsCompanion.insert(
                accountId: id,
                operationDate: DateTime(2025, 1, day),
                valueDate: DateTime(2025, 1, day),
                amount: 100.0 * day,
              ),
            );
      }
      await db.into(db.importConfigs).insert(ImportConfigsCompanion.insert(accountId: Value(id)));
      return id;
    }

    const tables = ['transactions', 'import_configs', 'accounts'];

    test('delete: a failure on the account row keeps its transactions and import config', () async {
      final id = await accountWithHistory('Main');
      expect(await counts(tables), [2, 1, 1]);
      await failDeletesFrom('accounts');

      await expectLater(AccountService(db).delete(id), throwsA(anything));
      expect(await counts(tables), [2, 1, 1], reason: 'nothing deleted');
    });

    test('deleteMany: a failure on the account rows keeps every transaction and import config', () async {
      final a = await accountWithHistory('A');
      final b = await accountWithHistory('B');
      expect(await counts(tables), [4, 2, 2]);
      await failDeletesFrom('accounts');

      await expectLater(AccountService(db).deleteMany([a, b]), throwsA(anything));
      expect(await counts(tables), [4, 2, 2], reason: 'nothing deleted');
    });

    test('baseline: without a failure the account and its rows are deleted', () async {
      final a = await accountWithHistory('A');
      final b = await accountWithHistory('B');
      expect(await AccountService(db).delete(a), 1);
      expect(await counts(tables), [2, 1, 1]);
      expect(await AccountService(db).deleteMany([b]), 1);
      expect(await counts(tables), [0, 0, 0]);
    });
  });

  group('AssetService', () {
    late int broker;
    setUp(() async => broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker')));

    Future<int> assetWithHistory(String name) async {
      final id = await AssetService(db).create(name: name, intermediaryId: broker, currency: 'EUR');
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: id,
              date: DateTime(2025, 1, 1),
              valueDate: DateTime(2025, 1, 1),
              type: EventType.buy,
              amount: 1000,
              quantity: const Value(10),
              price: const Value(100),
            ),
          );
      await db
          .into(db.assetSnapshots)
          .insert(
            AssetSnapshotsCompanion.insert(
              assetId: id,
              date: DateTime(2025, 1, 31),
              value: 1100,
              invested: 1000,
              growth: 100,
              growthPercent: 10,
              afterTaxValue: 1074,
            ),
          );
      await db
          .into(db.marketPrices)
          .insert(MarketPricesCompanion.insert(assetId: id, date: DateTime(2025, 1, 31), closePrice: 110, currency: 'EUR'));
      return id;
    }

    const tables = ['asset_events', 'asset_snapshots', 'market_prices', 'assets'];

    test('delete: a failure on the asset row keeps its events, snapshots and prices', () async {
      final id = await assetWithHistory('Fund');
      await failDeletesFrom('assets');

      await expectLater(AssetService(db).delete(id), throwsA(anything));
      expect(await counts(tables), [1, 1, 1, 1], reason: 'nothing deleted');
    });

    test('deleteMany: a failure on the asset rows keeps every event, snapshot and price', () async {
      final a = await assetWithHistory('A');
      final b = await assetWithHistory('B');
      await failDeletesFrom('assets');

      await expectLater(AssetService(db).deleteMany([a, b]), throwsA(anything));
      expect(await counts(tables), [2, 2, 2, 2], reason: 'nothing deleted');
    });

    test('baseline: without a failure the asset and its rows are deleted', () async {
      final a = await assetWithHistory('A');
      final b = await assetWithHistory('B');
      expect(await AssetService(db).delete(a), 1);
      expect(await counts(tables), [1, 1, 1, 1]);
      expect(await AssetService(db).deleteMany([b]), 1);
      expect(await counts(tables), [0, 0, 0, 0]);
    });
  });

  group('ExtraordinaryEventService.delete', () {
    /// A spread adjustment with its scheduled entries and a linked buffer
    /// holding one reimbursement.
    Future<int> spreadWithBuffer() async {
      final events = ExtraordinaryEventService(db);
      final id = await events.create(
        name: 'Car',
        direction: EventDirection.outflow,
        treatment: EventTreatment.spread,
        totalAmount: 1200,
        currency: 'EUR',
        eventDate: DateTime(2025, 1, 1),
        stepFrequency: StepFrequency.monthly,
        spreadStart: DateTime(2025, 1, 1),
        spreadEnd: DateTime(2025, 3, 1),
      );
      final bufferId = await events.createLinkedBuffer(id);
      await BufferService(db).createTransaction(
        bufferId: bufferId,
        operationDate: DateTime(2025, 2, 1),
        amount: 100,
        currency: 'EUR',
        isReimbursement: true,
      );
      return id;
    }

    const tables = ['extraordinary_event_entries', 'buffer_transactions', 'buffers', 'extraordinary_events'];

    test('a failure on the event row keeps its entries, buffer and buffer transactions', () async {
      final id = await spreadWithBuffer();
      final before = await counts(tables);
      expect(before, [3, 1, 1, 1]);
      await failDeletesFrom('extraordinary_events');

      await expectLater(ExtraordinaryEventService(db).delete(id), throwsA(anything));
      expect(await counts(tables), before, reason: 'nothing deleted');
    });

    test('baseline: without a failure the event and everything linked to it are deleted', () async {
      final id = await spreadWithBuffer();
      expect(await ExtraordinaryEventService(db).delete(id), 1);
      expect(await counts(tables), [0, 0, 0, 0]);
    });
  });

  group('BufferService.delete', () {
    Future<int> bufferWithHistory() async {
      final buffers = BufferService(db);
      final id = await buffers.create(name: 'Holiday');
      for (final month in [1, 2]) {
        await buffers.createTransaction(bufferId: id, operationDate: DateTime(2025, month, 1), amount: 50, currency: 'EUR');
      }
      return id;
    }

    const tables = ['buffer_transactions', 'buffers'];

    test('a failure on the buffer row keeps its transactions', () async {
      final id = await bufferWithHistory();
      await failDeletesFrom('buffers');

      await expectLater(BufferService(db).delete(id), throwsA(anything));
      expect(await counts(tables), [2, 1], reason: 'nothing deleted');
    });

    test('baseline: without a failure the buffer and its transactions are deleted', () async {
      final id = await bufferWithHistory();
      expect(await BufferService(db).delete(id), 1);
      expect(await counts(tables), [0, 0]);
    });
  });
}
