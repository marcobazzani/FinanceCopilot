import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/asset_event_service.dart';

void main() {
  late AppDatabase db;
  late AssetEventService service;
  late int iid;

  /// Helper: insert a parent asset and return its id.
  Future<int> createAsset(String name) async {
    return db.into(db.assets).insert(AssetsCompanion.insert(
          name: name,
          assetType: AssetType.stockEtf,
          instrumentType: const Value(InstrumentType.etf),
          assetClass: const Value(AssetClass.equity),
          valuationMethod: ValuationMethod.eventDriven,
          intermediaryId: iid,
        ));
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = AssetEventService(db);
    iid = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Default'));
  });

  tearDown(() async => await db.close());

  group('create and retrieve', () {
    test('create buy event and retrieve by asset', () async {
      final assetId = await createAsset('VWCE');

      final id = await service.create(
        assetId: assetId,
        date: DateTime(2024, 3, 15),
        type: EventType.buy,
        amount: 1000.0,
        quantity: 10.0,
        price: 100.0,
        currency: 'EUR',
      );
      expect(id, greaterThan(0));

      final events = await service.getByAsset(assetId);
      expect(events.length, 1);
      expect(events.first.type, EventType.buy);
      expect(events.first.amount, 1000.0);
      expect(events.first.quantity, 10.0);
      expect(events.first.price, 100.0);
      expect(events.first.currency, 'EUR');
    });

    test('create with all optional fields', () async {
      final assetId = await createAsset('Test');

      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 500.0,
        quantity: 5.0,
        price: 100.0,
        currency: 'USD',
        exchangeRate: 1.1,
        commission: 2.5,
        notes: 'First purchase',
      );

      final events = await service.getByAsset(assetId);
      final e = events.first;
      expect(e.currency, 'USD');
      expect(e.exchangeRate, 1.1);
      expect(e.commission, 2.5);
      expect(e.notes, 'First purchase');
    });
  });

  group('ordering', () {
    test('getByAsset returns events ordered desc by date', () async {
      final assetId = await createAsset('Ordered');

      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 100.0,
        currency: 'EUR',
      );
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 6, 1),
        type: EventType.buy,
        amount: 200.0,
        currency: 'EUR',
      );
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 3, 1),
        type: EventType.buy,
        amount: 50.0,
        currency: 'EUR',
      );

      final events = await service.getByAsset(assetId);
      expect(events.length, 3);
      // Most recent first
      expect(events[0].date, DateTime(2024, 6, 1));
      expect(events[1].date, DateTime(2024, 3, 1));
      expect(events[2].date, DateTime(2024, 1, 1));
    });
  });

  group('update', () {
    test('update amount', () async {
      final assetId = await createAsset('Upd');
      final id = await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 100.0,
        currency: 'EUR',
      );

      final result = await service.update(
        id,
        const AssetEventsCompanion(amount: Value(999.0)),
      );
      expect(result, isTrue);

      final events = await service.getByAsset(assetId);
      expect(events.first.amount, 999.0);
    });

    test('update non-existent id returns false', () async {
      final result = await service.update(
        999,
        const AssetEventsCompanion(amount: Value(1.0)),
      );
      expect(result, isFalse);
    });
  });

  group('delete', () {
    test('delete single event', () async {
      final assetId = await createAsset('Del');
      final id1 = await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 100.0,
        currency: 'EUR',
      );
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 2, 1),
        type: EventType.buy,
        amount: 200.0,
        currency: 'EUR',
      );

      final deleted = await service.delete(id1);
      expect(deleted, 1);

      final events = await service.getByAsset(assetId);
      expect(events.length, 1);
      expect(events.first.amount, 200.0);
    });

    test('deleteByAsset removes all events for asset', () async {
      final assetId = await createAsset('DelAll');
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 100.0,
        currency: 'EUR',
      );
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 2, 1),
        type: EventType.sell,
        amount: 50.0,
        currency: 'EUR',
      );
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 3, 1),
        type: EventType.buy,
        amount: 10.0,
        currency: 'EUR',
      );

      final deleted = await service.deleteByAsset(assetId);
      expect(deleted, 3);

      final events = await service.getByAsset(assetId);
      expect(events, isEmpty);
    });

    test('deleteMany empty list is a no-op', () async {
      final assetId = await createAsset('Keep');
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 100.0,
        currency: 'EUR',
      );
      expect(await service.deleteMany([]), 0);
      expect((await service.getByAsset(assetId)).length, 1);
    });

    test('deleteMany removes only the given event ids', () async {
      final assetId = await createAsset('Multi');
      final a = await service.create(
        assetId: assetId, date: DateTime(2024, 1, 1),
        type: EventType.buy, amount: 100.0, currency: 'EUR',
      );
      final b = await service.create(
        assetId: assetId, date: DateTime(2024, 2, 1),
        type: EventType.buy, amount: 200.0, currency: 'EUR',
      );
      final c = await service.create(
        assetId: assetId, date: DateTime(2024, 3, 1),
        type: EventType.buy, amount: 300.0, currency: 'EUR',
      );

      expect(await service.deleteMany([a, c]), 2);

      final remaining = await service.getByAsset(assetId);
      expect(remaining.map((e) => e.id), [b]);
    });
  });

  group('event types', () {
    test('different event types are stored correctly', () async {
      final assetId = await createAsset('Types');

      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 1000.0,
        quantity: 10.0,
        currency: 'EUR',
      );
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 3, 1),
        type: EventType.sell,
        amount: 500.0,
        quantity: 5.0,
        currency: 'EUR',
      );
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 6, 1),
        type: EventType.buy,
        amount: 25.0,
        currency: 'EUR',
      );

      final events = await service.getByAsset(assetId);
      final types = events.map((e) => e.type).toSet();
      expect(types, containsAll([EventType.buy, EventType.sell]));
    });
  });

  group('getLatestRevalueAmount', () {
    test('returns null when no revalue events exist', () async {
      final assetId = await createAsset('NoRevalue');
      await service.create(
        assetId: assetId, date: DateTime(2024, 1, 1),
        type: EventType.buy, amount: 1000, currency: 'EUR',
      );
      final result = await service.getLatestRevalueAmount(assetId);
      expect(result, isNull);
    });

    test('returns latest revalue amount', () async {
      final assetId = await createAsset('BFP');
      await service.create(
        assetId: assetId, date: DateTime(2024, 1, 1),
        type: EventType.revalue, amount: 5000, currency: 'EUR',
      );
      await service.create(
        assetId: assetId, date: DateTime(2024, 6, 1),
        type: EventType.revalue, amount: 5200, currency: 'EUR',
      );
      final result = await service.getLatestRevalueAmount(assetId);
      expect(result, 5200);
    });

    test('ignores non-revalue events', () async {
      final assetId = await createAsset('Mixed');
      await service.create(
        assetId: assetId, date: DateTime(2024, 1, 1),
        type: EventType.revalue, amount: 3000, currency: 'EUR',
      );
      await service.create(
        assetId: assetId, date: DateTime(2024, 6, 1),
        type: EventType.buy, amount: 9999, currency: 'EUR',
      );
      final result = await service.getLatestRevalueAmount(assetId);
      expect(result, 3000);
    });

    test('returns null for non-existent asset', () async {
      final result = await service.getLatestRevalueAmount(99999);
      expect(result, isNull);
    });
  });

  group('getByAssets', () {
    test('returns events grouped by asset ID', () async {
      final asset1 = await createAsset('Asset1');
      final asset2 = await createAsset('Asset2');

      // 3 events for asset1
      await service.create(
        assetId: asset1, date: DateTime(2024, 1, 1),
        type: EventType.buy, amount: 100, currency: 'EUR',
      );
      await service.create(
        assetId: asset1, date: DateTime(2024, 2, 1),
        type: EventType.buy, amount: 200, currency: 'EUR',
      );
      await service.create(
        assetId: asset1, date: DateTime(2024, 3, 1),
        type: EventType.sell, amount: 50, currency: 'EUR',
      );

      // 2 events for asset2
      await service.create(
        assetId: asset2, date: DateTime(2024, 1, 15),
        type: EventType.buy, amount: 500, currency: 'USD',
      );
      await service.create(
        assetId: asset2, date: DateTime(2024, 4, 1),
        type: EventType.buy, amount: 300, currency: 'USD',
      );

      final result = await service.getByAssets([asset1, asset2]);
      expect(result.length, 2);
      expect(result[asset1]!.length, 3);
      expect(result[asset2]!.length, 2);
    });

    test('returns empty map for empty input', () async {
      final result = await service.getByAssets([]);
      expect(result, isEmpty);
    });

    test('excludes assets not in the list', () async {
      final asset1 = await createAsset('A1');
      final asset2 = await createAsset('A2');
      final asset3 = await createAsset('A3');

      await service.create(
        assetId: asset1, date: DateTime(2024, 1, 1),
        type: EventType.buy, amount: 100, currency: 'EUR',
      );
      await service.create(
        assetId: asset2, date: DateTime(2024, 1, 1),
        type: EventType.buy, amount: 200, currency: 'EUR',
      );
      await service.create(
        assetId: asset3, date: DateTime(2024, 1, 1),
        type: EventType.buy, amount: 300, currency: 'EUR',
      );

      final result = await service.getByAssets([asset1, asset3]);
      expect(result.length, 2);
      expect(result.containsKey(asset1), isTrue);
      expect(result.containsKey(asset2), isFalse);
      expect(result.containsKey(asset3), isTrue);
    });
  });

  group('getAverageBuyPrice', () {
    test('returns weighted average of buy events', () async {
      final assetId = await createAsset('Bond');
      await service.create(
        assetId: assetId, date: DateTime(2024, 1, 1),
        type: EventType.buy, amount: 9800, quantity: 100, price: 98.0,
        currency: 'EUR',
      );
      await service.create(
        assetId: assetId, date: DateTime(2024, 6, 1),
        type: EventType.buy, amount: 4900, quantity: 50, price: 98.0,
        currency: 'EUR',
      );
      final result = await service.getAverageBuyPrice(assetId);
      expect(result, closeTo(98.0, 0.01));
    });

    test('returns null when no buy events exist', () async {
      final assetId = await createAsset('Empty');
      final result = await service.getAverageBuyPrice(assetId);
      expect(result, isNull);
    });

    test('returns null for non-existent asset', () async {
      final result = await service.getAverageBuyPrice(99999);
      expect(result, isNull);
    });
  });
}
