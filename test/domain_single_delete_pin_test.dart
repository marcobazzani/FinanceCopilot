// Pins a single delete of an account or an asset as exactly a one-id bulk
// delete: the same rows removed (its own children only, in one transaction —
// see domain_deletes_atomic_test.dart), the same count returned, and nothing
// for an id that does not exist.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/account_service.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  for (final single in [true, false]) {
    Future<int> deleteAccount(int id) => single ? AccountService(db).delete(id) : AccountService(db).deleteMany([id]);
    Future<int> deleteAsset(int id) => single ? AssetService(db).delete(id) : AssetService(db).deleteMany([id]);
    final how = single ? 'delete(id)' : 'deleteMany([id])';

    test('$how: the account, its transactions and import configs; nothing of another account', () async {
      final service = AccountService(db);
      Future<int> account(String name) async {
        final id = await service.create(name: name, currency: 'EUR');
        for (final day in [1, 2]) {
          await db
              .into(db.transactions)
              .insert(
                TransactionsCompanion.insert(
                  accountId: id,
                  operationDate: DateTime(2025, 1, day),
                  valueDate: DateTime(2025, 1, day),
                  amount: 10,
                ),
              );
        }
        await db.into(db.importConfigs).insert(ImportConfigsCompanion.insert(accountId: Value(id)));
        return id;
      }

      final gone = await account('Gone');
      final kept = await account('Kept');
      await db.into(db.importConfigs).insert(ImportConfigsCompanion.insert()); // not tied to any account

      expect(await deleteAccount(gone), 1);
      expect((await service.getAll()).map((a) => a.id), [kept]);
      expect((await db.select(db.transactions).get()).map((t) => t.accountId), [kept, kept]);
      expect((await db.select(db.importConfigs).get()).map((c) => c.accountId), [kept, null]);

      expect(await deleteAccount(gone), 0, reason: 'already deleted');
      expect(await db.select(db.transactions).get(), hasLength(2));
    });

    test('$how: the asset, its events, snapshots and prices; nothing of another asset', () async {
      final service = AssetService(db);
      final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
      Future<int> asset(String name) async {
        final id = await service.create(name: name, intermediaryId: broker, currency: 'EUR');
        await db
            .into(db.assetEvents)
            .insert(
              AssetEventsCompanion.insert(
                assetId: id,
                date: DateTime(2025, 1, 1),
                valueDate: DateTime(2025, 1, 1),
                type: EventType.buy,
                amount: 100,
                quantity: const Value(1),
                price: const Value(100),
              ),
            );
        await db
            .into(db.assetSnapshots)
            .insert(
              AssetSnapshotsCompanion.insert(
                assetId: id,
                date: DateTime(2025, 1, 31),
                value: 110,
                invested: 100,
                growth: 10,
                growthPercent: 10,
                afterTaxValue: 107.4,
              ),
            );
        await db
            .into(db.marketPrices)
            .insert(MarketPricesCompanion.insert(assetId: id, date: DateTime(2025, 1, 31), closePrice: 110, currency: 'EUR'));
        return id;
      }

      final gone = await asset('Gone');
      final kept = await asset('Kept');

      expect(await deleteAsset(gone), 1);
      expect((await service.getAll()).map((a) => a.id), [kept]);
      expect((await db.select(db.assetEvents).get()).map((e) => e.assetId), [kept]);
      expect((await db.select(db.assetSnapshots).get()).map((s) => s.assetId), [kept]);
      expect((await db.select(db.marketPrices).get()).map((p) => p.assetId), [kept]);

      expect(await deleteAsset(gone), 0, reason: 'already deleted');
      expect(await db.select(db.assetEvents).get(), hasLength(1));
    });
  }
}
