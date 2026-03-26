import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/asset_event_service.dart';

void main() {
  late AppDatabase db;
  late AssetEventService service;

  /// Helper: insert a parent asset and return its id.
  Future<int> createAsset(String name) async {
    return db.into(db.assets).insert(AssetsCompanion.insert(
          name: name,
          assetType: AssetType.stockEtf,
          valuationMethod: ValuationMethod.eventDriven,
        ));
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = AssetEventService(db);
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
      );
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 6, 1),
        type: EventType.buy,
        amount: 200.0,
      );
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 3, 1),
        type: EventType.dividend,
        amount: 50.0,
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
      );
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 2, 1),
        type: EventType.buy,
        amount: 200.0,
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
      );
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 2, 1),
        type: EventType.sell,
        amount: 50.0,
      );
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 3, 1),
        type: EventType.dividend,
        amount: 10.0,
      );

      final deleted = await service.deleteByAsset(assetId);
      expect(deleted, 3);

      final events = await service.getByAsset(assetId);
      expect(events, isEmpty);
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
      );
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 3, 1),
        type: EventType.sell,
        amount: 500.0,
        quantity: 5.0,
      );
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 6, 1),
        type: EventType.dividend,
        amount: 25.0,
      );

      final events = await service.getByAsset(assetId);
      final types = events.map((e) => e.type).toSet();
      expect(types, containsAll([EventType.buy, EventType.sell, EventType.dividend]));
    });
  });
}
