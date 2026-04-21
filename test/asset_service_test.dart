import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/asset_service.dart';

void main() {
  late AppDatabase db;
  late AssetService service;
  late int iid;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = AssetService(db);
    iid = await db.into(db.intermediaries).insert(
      IntermediariesCompanion.insert(name: 'Default'),
    );
  });

  tearDown(() async => await db.close());

  group('create and retrieve', () {
    test('create returns an id and getById retrieves it', () async {
      final id = await service.create(name: 'VWCE', currency: 'EUR', intermediaryId: iid);
      expect(id, greaterThan(0));

      final asset = await service.getById(id);
      expect(asset.name, 'VWCE');
      expect(asset.currency, 'EUR');
    });

    test('create with all optional fields', () async {
      final id = await service.create(
        name: 'Apple Inc',
        ticker: 'AAPL',
        isin: 'US0378331005',
        exchange: 'NASDAQ',
        currency: 'USD',
        taxRate: 0.26,
        intermediaryId: iid,
      );

      final asset = await service.getById(id);
      expect(asset.ticker, 'AAPL');
      expect(asset.isin, 'US0378331005');
      expect(asset.exchange, 'NASDAQ');
      expect(asset.currency, 'USD');
      expect(asset.taxRate, 0.26);
    });

    test('getAll returns all assets', () async {
      await service.create(name: 'A', currency: 'EUR', intermediaryId: iid);
      await service.create(name: 'B', currency: 'EUR', intermediaryId: iid);

      final all = await service.getAll();
      expect(all.length, 2);
    });
  });

  group('update', () {
    test('update ticker', () async {
      final id = await service.create(name: 'Test', currency: 'EUR', intermediaryId: iid);
      final result = await service.update(
        id,
        const AssetsCompanion(ticker: Value('TST')),
      );
      expect(result, isTrue);

      final updated = await service.getById(id);
      expect(updated.ticker, 'TST');
    });

    test('update isin', () async {
      final id = await service.create(name: 'Test', currency: 'EUR', intermediaryId: iid);
      await service.update(
        id,
        const AssetsCompanion(isin: Value('IE00BK5BQT80')),
      );

      final updated = await service.getById(id);
      expect(updated.isin, 'IE00BK5BQT80');
    });

    test('update non-existent id returns false', () async {
      final result = await service.update(
        999,
        const AssetsCompanion(name: Value('Nope')),
      );
      expect(result, isFalse);
    });
  });

  group('delete', () {
    test('delete removes the asset', () async {
      final id = await service.create(name: 'ToDelete', currency: 'EUR', intermediaryId: iid);
      final deleted = await service.delete(id);
      expect(deleted, 1);

      final all = await service.getAll();
      expect(all, isEmpty);
    });

    test('delete cascades events', () async {
      final assetId = await service.create(name: 'WithEvents', currency: 'EUR', intermediaryId: iid);

      // Insert events directly
      await db.into(db.assetEvents).insert(AssetEventsCompanion.insert(
            assetId: assetId,
            date: DateTime(2024, 1, 1),
        valueDate: DateTime(2024, 1, 1),
            type: EventType.buy,
            amount: 1000.0,
            quantity: const Value(10.0),
            price: const Value(100.0),
          ));
      await db.into(db.assetEvents).insert(AssetEventsCompanion.insert(
            assetId: assetId,
            date: DateTime(2024, 6, 1),
        valueDate: DateTime(2024, 6, 1),
            type: EventType.buy,
            amount: 50.0,
          ));

      // Verify events exist
      final eventsBefore = await (db.select(db.assetEvents)
            ..where((e) => e.assetId.equals(assetId)))
          .get();
      expect(eventsBefore.length, 2);

      // Delete the asset
      await service.delete(assetId);

      // Verify events are gone
      final eventsAfter = await (db.select(db.assetEvents)
            ..where((e) => e.assetId.equals(assetId)))
          .get();
      expect(eventsAfter, isEmpty);
    });
  });

  group('deleteMany', () {
    test('empty list is a no-op', () async {
      await service.create(name: 'Keep', currency: 'EUR', intermediaryId: iid);
      final n = await service.deleteMany([]);
      expect(n, 0);
      expect((await service.getAll()).length, 1);
    });

    test('removes multiple assets in one call', () async {
      final a = await service.create(name: 'A', currency: 'EUR', intermediaryId: iid);
      final b = await service.create(name: 'B', currency: 'EUR', intermediaryId: iid);
      final c = await service.create(name: 'C', currency: 'EUR', intermediaryId: iid);

      final n = await service.deleteMany([a, c]);
      expect(n, 2);

      final remaining = await service.getAll();
      expect(remaining.map((x) => x.id), [b]);
    });

    test('cascades events, snapshots and prices for all deleted assets', () async {
      final a = await service.create(name: 'A', currency: 'EUR', intermediaryId: iid);
      final b = await service.create(name: 'B', currency: 'EUR', intermediaryId: iid);
      final keep = await service.create(name: 'Keep', currency: 'EUR', intermediaryId: iid);

      for (final id in [a, b, keep]) {
        await db.into(db.assetEvents).insert(AssetEventsCompanion.insert(
              assetId: id,
              date: DateTime(2024, 1, 1),
              valueDate: DateTime(2024, 1, 1),
              type: EventType.buy,
              amount: 100.0,
            ));
        await db.into(db.assetSnapshots).insert(AssetSnapshotsCompanion.insert(
              assetId: id,
              date: DateTime(2024, 1, 1),
              value: 100.0,
              invested: 90.0,
              growth: 10.0,
              growthPercent: 0.11,
              afterTaxValue: 97.0,
            ));
        await db.into(db.marketPrices).insert(MarketPricesCompanion.insert(
              assetId: id,
              date: DateTime(2024, 1, 1),
              closePrice: 10.0,
              currency: 'EUR',
            ));
      }

      await service.deleteMany([a, b]);

      final remainingEvents = await db.select(db.assetEvents).get();
      expect(remainingEvents.map((e) => e.assetId).toSet(), {keep});
      final remainingSnapshots = await db.select(db.assetSnapshots).get();
      expect(remainingSnapshots.map((s) => s.assetId).toSet(), {keep});
      final remainingPrices = await db.select(db.marketPrices).get();
      expect(remainingPrices.map((p) => p.assetId).toSet(), {keep});
    });
  });

  group('reorder', () {
    test('reorder updates sortOrder', () async {
      final id1 = await service.create(name: 'A', currency: 'EUR', intermediaryId: iid);
      final id2 = await service.create(name: 'B', currency: 'EUR', intermediaryId: iid);
      final id3 = await service.create(name: 'C', currency: 'EUR', intermediaryId: iid);

      await service.reorder([id3, id1, id2]);

      final all = await service.getAll();
      expect(all[0].name, 'C');
      expect(all[0].sortOrder, 0);
      expect(all[1].name, 'A');
      expect(all[1].sortOrder, 1);
      expect(all[2].name, 'B');
      expect(all[2].sortOrder, 2);
    });
  });

  group('getStatsForAll', () {
    test('returns empty map when no events', () async {
      await service.create(name: 'NoEvents', currency: 'EUR', intermediaryId: iid);
      final stats = await service.getStatsForAll();
      expect(stats, isEmpty);
    });

    test('returns correct stats with buy events', () async {
      final assetId = await service.create(name: 'Stats', currency: 'EUR', intermediaryId: iid);

      await db.into(db.assetEvents).insert(AssetEventsCompanion.insert(
            assetId: assetId,
            date: DateTime(2024, 1, 1),
        valueDate: DateTime(2024, 1, 1),
            type: EventType.buy,
            amount: 1000.0,
            quantity: const Value(10.0),
            price: const Value(100.0),
          ));
      await db.into(db.assetEvents).insert(AssetEventsCompanion.insert(
            assetId: assetId,
            date: DateTime(2024, 6, 1),
        valueDate: DateTime(2024, 6, 1),
            type: EventType.buy,
            amount: 500.0,
            quantity: const Value(5.0),
            price: const Value(100.0),
          ));

      final stats = await service.getStatsForAll();
      expect(stats.containsKey(assetId), isTrue);

      final s = stats[assetId]!;
      expect(s.eventCount, 2);
      expect(s.totalInvested, 1500.0);
      expect(s.totalQuantity, 15.0);
      expect(s.firstDate, isNotNull);
      expect(s.lastDate, isNotNull);
    });

    test('sell events reduce totalQuantity', () async {
      final assetId = await service.create(name: 'BuySell', currency: 'EUR', intermediaryId: iid);

      await db.into(db.assetEvents).insert(AssetEventsCompanion.insert(
            assetId: assetId,
            date: DateTime(2024, 1, 1),
        valueDate: DateTime(2024, 1, 1),
            type: EventType.buy,
            amount: 1000.0,
            quantity: const Value(10.0),
          ));
      await db.into(db.assetEvents).insert(AssetEventsCompanion.insert(
            assetId: assetId,
            date: DateTime(2024, 6, 1),
        valueDate: DateTime(2024, 6, 1),
            type: EventType.sell,
            amount: 300.0,
            quantity: const Value(3.0),
          ));

      final stats = await service.getStatsForAll();
      final s = stats[assetId]!;
      expect(s.eventCount, 2);
      expect(s.totalInvested, 1000.0); // only buy counts
      expect(s.totalQuantity, 7.0); // 10 - 3
    });

    test('revalue events do not affect quantity or invested', () async {
      final assetId = await service.create(name: 'RevalueTest', currency: 'EUR', intermediaryId: iid);

      await db.into(db.assetEvents).insert(AssetEventsCompanion.insert(
            assetId: assetId,
            date: DateTime(2024, 1, 1),
        valueDate: DateTime(2024, 1, 1),
            type: EventType.buy,
            amount: 1000.0,
            quantity: const Value(10.0),
          ));
      await db.into(db.assetEvents).insert(AssetEventsCompanion.insert(
            assetId: assetId,
            date: DateTime(2024, 6, 1),
        valueDate: DateTime(2024, 6, 1),
            type: EventType.revalue,
            amount: 1200.0,
          ));

      final stats = await service.getStatsForAll();
      final s = stats[assetId]!;
      expect(s.eventCount, 2);
      expect(s.totalInvested, 1000.0); // revalue doesn't count as invested
      expect(s.totalQuantity, 10.0);   // revalue doesn't change quantity
    });
  });
}
