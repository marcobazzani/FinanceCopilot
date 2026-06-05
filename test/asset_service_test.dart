import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';

void main() {
  late AppDatabase db;
  late AssetService service;
  late int iid;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = AssetService(db);
    iid = await db
        .into(db.intermediaries)
        .insert(
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

  group('bond reclassification rescales event amounts (issue #87)', () {
    // Helper: read current invested cost-basis for an asset.
    Future<double> investedOf(int assetId) async {
      final stats = await service.getStatsForAll();
      return stats[assetId]!.totalInvested;
    }

    test('reclassifying ETF→bond divides buy/sell amounts by 100', () async {
      // A bond the provider didn't recognize, imported as an ETF: face value
      // 3000, price 100 (% of par) → amount stored as 3000*100 = 300000.
      final id = await service.create(
        name: 'Mystery BTP',
        isin: 'IT0005340929',
        currency: 'EUR',
        intermediaryId: iid,
        instrumentType: InstrumentType.etf,
      );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: id,
              date: DateTime(2024, 1, 10),
              valueDate: DateTime(2024, 1, 10),
              type: EventType.buy,
              amount: 300000.0, // 3000 * 100, no bond divisor applied at import
              quantity: const Value(3000.0),
              price: const Value(100.0),
            ),
          );

      expect(await investedOf(id), closeTo(300000.0, 0.01), reason: 'pre-fix: invested is 100x too large');

      // User corrects the instrument type to bond.
      await service.update(id, const AssetsCompanion(instrumentType: Value(InstrumentType.bond)));

      expect(await investedOf(id), closeTo(3000.0, 0.01), reason: 'amount rescaled to qty*price/100');

      final ev = await (db.select(db.assetEvents)..where((e) => e.assetId.equals(id))).getSingle();
      expect(ev.amount, closeTo(3000.0, 0.01));
      expect(ev.quantity, 3000.0, reason: 'quantity is untouched');
      expect(ev.price, 100.0, reason: 'price is untouched (still per-100-face-value)');
    });

    test('reclassifying bond→ETF multiplies buy/sell amounts by 100', () async {
      final id = await service.create(
        name: 'Was a bond',
        currency: 'EUR',
        intermediaryId: iid,
        instrumentType: InstrumentType.bond,
      );
      // Correctly stored bond amount: 3000 * 100 / 100 = 3000.
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: id,
              date: DateTime(2024, 1, 10),
              valueDate: DateTime(2024, 1, 10),
              type: EventType.buy,
              amount: 3000.0,
              quantity: const Value(3000.0),
              price: const Value(100.0),
            ),
          );

      await service.update(id, const AssetsCompanion(instrumentType: Value(InstrumentType.etf)));

      final ev = await (db.select(db.assetEvents)..where((e) => e.assetId.equals(id))).getSingle();
      expect(ev.amount, closeTo(300000.0, 0.01), reason: 'amount rescaled back to qty*price');
    });

    test('preserves amount sign for sell events', () async {
      final id = await service.create(
        name: 'Bond with sell',
        currency: 'EUR',
        intermediaryId: iid,
        instrumentType: InstrumentType.etf,
      );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: id,
              date: DateTime(2024, 1, 10),
              valueDate: DateTime(2024, 1, 10),
              type: EventType.sell,
              amount: -300000.0, // negative-amount sell convention
              quantity: const Value(3000.0),
              price: const Value(100.0),
            ),
          );

      await service.update(id, const AssetsCompanion(instrumentType: Value(InstrumentType.bond)));

      final ev = await (db.select(db.assetEvents)..where((e) => e.assetId.equals(id))).getSingle();
      expect(ev.amount, closeTo(-3000.0, 0.01), reason: 'sign preserved, magnitude /100');
    });

    test('leaves cash-only events (no qty/price) untouched', () async {
      final id = await service.create(
        name: 'Cash-only',
        currency: 'EUR',
        intermediaryId: iid,
        instrumentType: InstrumentType.etf,
      );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: id,
              date: DateTime(2024, 1, 10),
              valueDate: DateTime(2024, 1, 10),
              type: EventType.buy,
              amount: 5000.0, // no quantity / price → not derived from qty*price
            ),
          );

      await service.update(id, const AssetsCompanion(instrumentType: Value(InstrumentType.bond)));

      final ev = await (db.select(db.assetEvents)..where((e) => e.assetId.equals(id))).getSingle();
      expect(ev.amount, 5000.0, reason: 'cash-only amount must not be rescaled');
    });

    test('no-op when instrument type does not cross the bond boundary', () async {
      final id = await service.create(
        name: 'ETF stays ETF kind',
        currency: 'EUR',
        intermediaryId: iid,
        instrumentType: InstrumentType.etf,
      );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: id,
              date: DateTime(2024, 1, 10),
              valueDate: DateTime(2024, 1, 10),
              type: EventType.buy,
              amount: 1000.0,
              quantity: const Value(10.0),
              price: const Value(100.0),
            ),
          );

      // etf → stock: neither is bond, so amounts must be untouched.
      await service.update(id, const AssetsCompanion(instrumentType: Value(InstrumentType.stock)));

      final ev = await (db.select(db.assetEvents)..where((e) => e.assetId.equals(id))).getSingle();
      expect(ev.amount, 1000.0, reason: 'non-bond ↔ non-bond change must not rescale');
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
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2024, 1, 1),
              valueDate: DateTime(2024, 1, 1),
              type: EventType.buy,
              amount: 1000.0,
              quantity: const Value(10.0),
              price: const Value(100.0),
            ),
          );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2024, 6, 1),
              valueDate: DateTime(2024, 6, 1),
              type: EventType.buy,
              amount: 50.0,
            ),
          );

      // Verify events exist
      final eventsBefore = await (db.select(db.assetEvents)..where((e) => e.assetId.equals(assetId))).get();
      expect(eventsBefore.length, 2);

      // Delete the asset
      await service.delete(assetId);

      // Verify events are gone
      final eventsAfter = await (db.select(db.assetEvents)..where((e) => e.assetId.equals(assetId))).get();
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
        await db
            .into(db.assetEvents)
            .insert(
              AssetEventsCompanion.insert(
                assetId: id,
                date: DateTime(2024, 1, 1),
                valueDate: DateTime(2024, 1, 1),
                type: EventType.buy,
                amount: 100.0,
              ),
            );
        await db
            .into(db.assetSnapshots)
            .insert(
              AssetSnapshotsCompanion.insert(
                assetId: id,
                date: DateTime(2024, 1, 1),
                value: 100.0,
                invested: 90.0,
                growth: 10.0,
                growthPercent: 0.11,
                afterTaxValue: 97.0,
              ),
            );
        await db
            .into(db.marketPrices)
            .insert(
              MarketPricesCompanion.insert(
                assetId: id,
                date: DateTime(2024, 1, 1),
                closePrice: 10.0,
                currency: 'EUR',
              ),
            );
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

      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2024, 1, 1),
              valueDate: DateTime(2024, 1, 1),
              type: EventType.buy,
              amount: 1000.0,
              quantity: const Value(10.0),
              price: const Value(100.0),
            ),
          );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2024, 6, 1),
              valueDate: DateTime(2024, 6, 1),
              type: EventType.buy,
              amount: 500.0,
              quantity: const Value(5.0),
              price: const Value(100.0),
            ),
          );

      final stats = await service.getStatsForAll();
      expect(stats.containsKey(assetId), isTrue);

      final s = stats[assetId]!;
      expect(s.eventCount, 2);
      expect(s.totalInvested, 1500.0);
      expect(s.totalQuantity, 15.0);
      expect(s.firstDate, isNotNull);
      expect(s.lastDate, isNotNull);
    });

    test('through date limits quantity and cost basis without deleting data', () async {
      final assetId = await service.create(
        name: 'Wayback',
        currency: 'EUR',
        intermediaryId: iid,
      );

      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2024, 1, 1),
              valueDate: DateTime(2024, 1, 1),
              type: EventType.buy,
              amount: 1000.0,
              quantity: const Value(10.0),
            ),
          );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2024, 6, 1),
              valueDate: DateTime(2024, 6, 1),
              type: EventType.sell,
              amount: 300.0,
              quantity: const Value(3.0),
            ),
          );

      final stats = await service.getStatsForAll(through: DateTime(2024, 3, 31));
      final s = stats[assetId]!;
      expect(s.eventCount, 1);
      expect(s.totalQuantity, 10.0);
      expect(s.totalInvested, 1000.0);
      expect(s.lastDate, DateTime(2024, 1, 1));

      final allRows = await db.select(db.assetEvents).get();
      expect(allRows.length, 2);
    });

    test('firstDate/lastDate use valueDate, not operationDate', () async {
      // Two events whose `date` (operationDate) and `valueDate` are flipped:
      //   A: date=2024-06-01, valueDate=2024-01-15  (early valueDate)
      //   B: date=2024-01-15, valueDate=2024-06-01  (late valueDate)
      // Pre-fix code aggregated MIN/MAX of `date`, returning Jan 15 .. Jun 1
      // by coincidence. Force a case where they diverge: A's valueDate is
      // *earlier* than B's. firstDate must be A.valueDate (Jan 15) and
      // lastDate must be B.valueDate (Jun 1) — same dates, just sourced
      // from valueDate not operationDate. Verify by adding a third event
      // whose operationDate is OUTSIDE the valueDate range:
      //   C: date=2025-01-01 (way later op), valueDate=2024-03-15 (mid val)
      // If stats used `date`, lastDate would be 2025-01-01. With valueDate,
      // lastDate stays 2024-06-01.
      final iid = await db
          .into(db.intermediaries)
          .insert(
            IntermediariesCompanion.insert(name: 'IM-VD'),
          );
      final assetId = await service.create(name: 'VD', currency: 'EUR', intermediaryId: iid);
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2024, 6, 1),
              valueDate: DateTime(2024, 1, 15),
              type: EventType.buy,
              amount: 100,
            ),
          );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2024, 1, 15),
              valueDate: DateTime(2024, 6, 1),
              type: EventType.buy,
              amount: 200,
            ),
          );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2025, 1, 1),
              valueDate: DateTime(2024, 3, 15),
              type: EventType.buy,
              amount: 50,
            ),
          );

      final stats = await service.getStatsForAll();
      final s = stats[assetId]!;
      expect(s.firstDate, DateTime(2024, 1, 15), reason: 'firstDate must be the earliest valueDate');
      expect(s.lastDate, DateTime(2024, 6, 1), reason: 'lastDate must be the latest valueDate, ignoring operationDate');
    });

    test('sell events reduce totalQuantity and shrink cost basis proportionally', () async {
      // 10 shares bought for 1000 (= 100/share weighted-avg), 3 sold.
      // Remaining cost basis is 7 × 100 = 700, NOT the all-time 1000.
      // Sale proceeds (300) don't flow into totalInvested — that's a
      // realised cash event, separate from unrealised-position cost.
      final assetId = await service.create(name: 'BuySell', currency: 'EUR', intermediaryId: iid);

      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2024, 1, 1),
              valueDate: DateTime(2024, 1, 1),
              type: EventType.buy,
              amount: 1000.0,
              quantity: const Value(10.0),
            ),
          );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2024, 6, 1),
              valueDate: DateTime(2024, 6, 1),
              type: EventType.sell,
              amount: 300.0,
              quantity: const Value(3.0),
            ),
          );

      final stats = await service.getStatsForAll();
      final s = stats[assetId]!;
      expect(s.eventCount, 2);
      expect(s.totalInvested, 700.0, reason: 'weighted-avg 100/share × 7 remaining shares');
      expect(s.totalQuantity, 7.0); // 10 - 3
    });

    test('fully closed position has zero cost basis', () async {
      // Once every share is sold, totalInvested must collapse to 0 —
      // there's no remaining position to hold an unrealised gain against.
      final assetId = await service.create(name: 'Closed', currency: 'EUR', intermediaryId: iid);
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2024, 1, 1),
              valueDate: DateTime(2024, 1, 1),
              type: EventType.buy,
              amount: 1000.0,
              quantity: const Value(10.0),
            ),
          );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2024, 6, 1),
              valueDate: DateTime(2024, 6, 1),
              type: EventType.sell,
              amount: 1200.0,
              quantity: const Value(10.0),
            ),
          );
      final stats = await service.getStatsForAll();
      final s = stats[assetId]!;
      expect(s.totalQuantity, 0);
      expect(s.totalInvested, 0, reason: 'closed position carries no unrealised cost basis');
    });

    test('cash-only events fall back to gross buy sum', () async {
      // No per-share quantity on buys (e.g. pension cash deposits before
      // the A3 auto-fill applies, or manual entries). Weighted-avg cannot
      // be computed; the gross deposit total is the only meaningful figure.
      final assetId = await service.create(
        name: 'Cash-only',
        currency: 'EUR',
        intermediaryId: iid,
        valuationMethod: ValuationMethod.eventDriven,
      );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2024, 1, 1),
              valueDate: DateTime(2024, 1, 1),
              type: EventType.buy,
              amount: 500.0,
            ),
          );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2024, 2, 1),
              valueDate: DateTime(2024, 2, 1),
              type: EventType.buy,
              amount: 300.0,
            ),
          );
      final stats = await service.getStatsForAll();
      final s = stats[assetId]!;
      expect(s.totalQuantity, 0, reason: 'no qty data → totalQty stays at 0');
      expect(s.totalInvested, 800.0, reason: 'gross sum of buy amounts, used as fallback');
    });

    test('revalue events do not affect quantity or invested', () async {
      final assetId = await service.create(name: 'RevalueTest', currency: 'EUR', intermediaryId: iid);

      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2024, 1, 1),
              valueDate: DateTime(2024, 1, 1),
              type: EventType.buy,
              amount: 1000.0,
              quantity: const Value(10.0),
            ),
          );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2024, 6, 1),
              valueDate: DateTime(2024, 6, 1),
              type: EventType.revalue,
              amount: 1200.0,
            ),
          );

      final stats = await service.getStatsForAll();
      final s = stats[assetId]!;
      expect(s.eventCount, 2);
      expect(s.totalInvested, 1000.0); // revalue doesn't count as invested
      expect(s.totalQuantity, 10.0); // revalue doesn't change quantity
    });
  });
}
