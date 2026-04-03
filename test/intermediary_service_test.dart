import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/intermediary_service.dart';

void main() {
  late AppDatabase db;
  late IntermediaryService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = IntermediaryService(db);
  });

  tearDown(() async => await db.close());

  group('create', () {
    test('creates and returns an intermediary id', () async {
      final id = await service.create(name: 'Bank A');
      expect(id, greaterThan(0));
    });

    test('created intermediary is retrievable via getAll', () async {
      await service.create(name: 'Bank A');
      final all = await service.getAll();
      expect(all.length, 1);
      expect(all.first.name, 'Bank A');
    });

    test('multiple creates return distinct ids', () async {
      final id1 = await service.create(name: 'Bank A');
      final id2 = await service.create(name: 'Bank B');
      expect(id1, isNot(equals(id2)));

      final all = await service.getAll();
      expect(all.length, 2);
    });
  });

  group('watchAll', () {
    test('emits current intermediaries', () async {
      await service.create(name: 'Bank A');
      await service.create(name: 'Bank B');

      final result = await service.watchAll().first;
      expect(result.length, 2);
      expect(result[0].name, 'Bank A');
      expect(result[1].name, 'Bank B');
    });

    test('emits updates when intermediary is added', () async {
      await service.create(name: 'Bank A');

      final stream = service.watchAll();

      // First emission: one intermediary
      final first = await stream.first;
      expect(first.length, 1);

      // Add another
      await service.create(name: 'Bank B');

      // Next emission should have two
      final second = await stream.first;
      expect(second.length, 2);
    });
  });

  group('update', () {
    test('updates name of an existing intermediary', () async {
      final id = await service.create(name: 'Old Name');
      await service.update(id, const IntermediariesCompanion(name: Value('New Name')));

      final all = await service.getAll();
      expect(all.first.name, 'New Name');
    });

    test('updates sortOrder', () async {
      final id = await service.create(name: 'Bank A');
      await service.update(id, const IntermediariesCompanion(sortOrder: Value(42)));

      final all = await service.getAll();
      expect(all.first.sortOrder, 42);
    });
  });

  group('delete', () {
    test('removes the intermediary', () async {
      final id = await service.create(name: 'ToDelete');
      await service.delete(id);

      final all = await service.getAll();
      expect(all, isEmpty);
    });

    test('unlinks accounts when intermediary is deleted', () async {
      final intId = await service.create(name: 'Bank A');

      // Create an account linked to the intermediary
      final accountId = await db.into(db.accounts).insert(
        AccountsCompanion.insert(
          name: 'Checking',
          intermediaryId: Value(intId),
        ),
      );

      // Delete the intermediary
      await service.delete(intId);

      // Account should still exist but with null intermediaryId
      final account = await (db.select(db.accounts)
            ..where((a) => a.id.equals(accountId)))
          .getSingle();
      expect(account.intermediaryId, isNull);
    });

    test('unlinks assets when intermediary is deleted', () async {
      final intId = await service.create(name: 'Broker A');

      // Create an asset linked to the intermediary
      final assetId = await db.into(db.assets).insert(
        AssetsCompanion.insert(
          name: 'ETF World',
          assetType: AssetType.stockEtf,
          valuationMethod: ValuationMethod.marketPrice,
          intermediaryId: Value(intId),
        ),
      );

      // Delete the intermediary
      await service.delete(intId);

      // Asset should still exist but with null intermediaryId
      final asset = await (db.select(db.assets)
            ..where((a) => a.id.equals(assetId)))
          .getSingle();
      expect(asset.intermediaryId, isNull);
    });
  });

  group('reorder', () {
    test('changes sort order of intermediaries', () async {
      final id1 = await service.create(name: 'A');
      final id2 = await service.create(name: 'B');
      final id3 = await service.create(name: 'C');

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

  group('moveAccount', () {
    test('assigns an account to an intermediary', () async {
      final intId = await service.create(name: 'Bank A');
      final accountId = await db.into(db.accounts).insert(
        AccountsCompanion.insert(name: 'Checking'),
      );

      await service.moveAccount(accountId, intId);

      final account = await (db.select(db.accounts)
            ..where((a) => a.id.equals(accountId)))
          .getSingle();
      expect(account.intermediaryId, intId);
    });

    test('unassigns an account from an intermediary', () async {
      final intId = await service.create(name: 'Bank A');
      final accountId = await db.into(db.accounts).insert(
        AccountsCompanion.insert(
          name: 'Checking',
          intermediaryId: Value(intId),
        ),
      );

      await service.moveAccount(accountId, null);

      final account = await (db.select(db.accounts)
            ..where((a) => a.id.equals(accountId)))
          .getSingle();
      expect(account.intermediaryId, isNull);
    });

    test('moves account from one intermediary to another', () async {
      final intId1 = await service.create(name: 'Bank A');
      final intId2 = await service.create(name: 'Bank B');
      final accountId = await db.into(db.accounts).insert(
        AccountsCompanion.insert(
          name: 'Checking',
          intermediaryId: Value(intId1),
        ),
      );

      await service.moveAccount(accountId, intId2);

      final account = await (db.select(db.accounts)
            ..where((a) => a.id.equals(accountId)))
          .getSingle();
      expect(account.intermediaryId, intId2);
    });
  });

  group('moveAsset', () {
    test('assigns an asset to an intermediary', () async {
      final intId = await service.create(name: 'Broker A');
      final assetId = await db.into(db.assets).insert(
        AssetsCompanion.insert(
          name: 'ETF World',
          assetType: AssetType.stockEtf,
          valuationMethod: ValuationMethod.marketPrice,
        ),
      );

      await service.moveAsset(assetId, intId);

      final asset = await (db.select(db.assets)
            ..where((a) => a.id.equals(assetId)))
          .getSingle();
      expect(asset.intermediaryId, intId);
    });

    test('unassigns an asset from an intermediary', () async {
      final intId = await service.create(name: 'Broker A');
      final assetId = await db.into(db.assets).insert(
        AssetsCompanion.insert(
          name: 'ETF World',
          assetType: AssetType.stockEtf,
          valuationMethod: ValuationMethod.marketPrice,
          intermediaryId: Value(intId),
        ),
      );

      await service.moveAsset(assetId, null);

      final asset = await (db.select(db.assets)
            ..where((a) => a.id.equals(assetId)))
          .getSingle();
      expect(asset.intermediaryId, isNull);
    });

    test('moves asset from one intermediary to another', () async {
      final intId1 = await service.create(name: 'Broker A');
      final intId2 = await service.create(name: 'Broker B');
      final assetId = await db.into(db.assets).insert(
        AssetsCompanion.insert(
          name: 'ETF World',
          assetType: AssetType.stockEtf,
          valuationMethod: ValuationMethod.marketPrice,
          intermediaryId: Value(intId1),
        ),
      );

      await service.moveAsset(assetId, intId2);

      final asset = await (db.select(db.assets)
            ..where((a) => a.id.equals(assetId)))
          .getSingle();
      expect(asset.intermediaryId, intId2);
    });
  });
}
