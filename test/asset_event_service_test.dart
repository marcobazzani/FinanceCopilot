import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/asset_event_service.dart';

void main() {
  late AppDatabase db;
  late AssetEventService service;
  late int iid;

  /// Helper: insert a parent asset and return its id.
  Future<int> createAsset(String name) async {
    return db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: name,
            assetType: AssetType.stockEtf,
            instrumentType: const Value(InstrumentType.etf),
            assetClass: const Value(AssetClass.equity),
            valuationMethod: ValuationMethod.eventDriven,
            intermediaryId: iid,
          ),
        );
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

    test('orders by valueDate (CLAUDE.md convention) when dates differ', () async {
      // Two events whose `date` and `valueDate` are flipped:
      //   A: date=2024-06-01 (op), valueDate=2024-01-15 (val) — amount 100
      //   B: date=2024-01-15 (op), valueDate=2024-06-01 (val) — amount 200
      // valueDate-desc order should be B then A. Pre-fix order (by `date`)
      // would have been A then B.
      final assetId = await createAsset('ValueDateOrdered');
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

      final events = await service.getByAsset(assetId);
      expect(events, hasLength(2));
      expect(events[0].amount, 200, reason: 'event B has the later valueDate and must come first');
      expect(events[1].amount, 100);
    });
  });

  group('through date filtering', () {
    test(
      'getByAsset includes the full selected valueDate and keeps raw rows',
      () async {
        final assetId = await createAsset('Wayback');
        await db
            .into(db.assetEvents)
            .insert(
              AssetEventsCompanion.insert(
                assetId: assetId,
                date: DateTime(2024, 6, 1),
                valueDate: DateTime(2024, 2, 29, 12),
                type: EventType.buy,
                amount: 100,
              ),
            );
        await db
            .into(db.assetEvents)
            .insert(
              AssetEventsCompanion.insert(
                assetId: assetId,
                date: DateTime(2024, 1, 1),
                valueDate: DateTime(2024, 3, 1),
                type: EventType.buy,
                amount: 200,
              ),
            );

        final events = await service.getByAsset(
          assetId,
          through: DateTime(2024, 2, 29),
        );
        expect(events.map((e) => e.amount), [100]);

        final rawRows = await db.select(db.assetEvents).get();
        expect(rawRows, hasLength(2));
      },
    );
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
        assetId: assetId,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 100.0,
        currency: 'EUR',
      );
      final b = await service.create(
        assetId: assetId,
        date: DateTime(2024, 2, 1),
        type: EventType.buy,
        amount: 200.0,
        currency: 'EUR',
      );
      final c = await service.create(
        assetId: assetId,
        date: DateTime(2024, 3, 1),
        type: EventType.buy,
        amount: 300.0,
        currency: 'EUR',
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
        assetId: assetId,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 1000,
        currency: 'EUR',
      );
      final result = await service.getLatestRevalueAmount(assetId);
      expect(result, isNull);
    });

    test('returns latest revalue amount', () async {
      final assetId = await createAsset('BFP');
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 1),
        type: EventType.revalue,
        amount: 5000,
        currency: 'EUR',
      );
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 6, 1),
        type: EventType.revalue,
        amount: 5200,
        currency: 'EUR',
      );
      final result = await service.getLatestRevalueAmount(assetId);
      expect(result, 5200);
    });

    test('ignores non-revalue events', () async {
      final assetId = await createAsset('Mixed');
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 1),
        type: EventType.revalue,
        amount: 3000,
        currency: 'EUR',
      );
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 6, 1),
        type: EventType.buy,
        amount: 9999,
        currency: 'EUR',
      );
      final result = await service.getLatestRevalueAmount(assetId);
      expect(result, 3000);
    });

    test('returns null for non-existent asset', () async {
      final result = await service.getLatestRevalueAmount(99999);
      expect(result, isNull);
    });

    test('through date uses valueDate for latest revalue', () async {
      final assetId = await createAsset('WaybackRevalue');
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2024, 6, 1),
              valueDate: DateTime(2024, 1, 1),
              type: EventType.revalue,
              amount: 3000,
            ),
          );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2024, 1, 1),
              valueDate: DateTime(2024, 6, 1),
              type: EventType.revalue,
              amount: 4000,
            ),
          );

      final result = await service.getLatestRevalueAmount(
        assetId,
        through: DateTime(2024, 3, 31),
      );
      expect(result, 3000);
    });
  });

  group('getByAssets', () {
    test('returns events grouped by asset ID', () async {
      final asset1 = await createAsset('Asset1');
      final asset2 = await createAsset('Asset2');

      // 3 events for asset1
      await service.create(
        assetId: asset1,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 100,
        currency: 'EUR',
      );
      await service.create(
        assetId: asset1,
        date: DateTime(2024, 2, 1),
        type: EventType.buy,
        amount: 200,
        currency: 'EUR',
      );
      await service.create(
        assetId: asset1,
        date: DateTime(2024, 3, 1),
        type: EventType.sell,
        amount: 50,
        currency: 'EUR',
      );

      // 2 events for asset2
      await service.create(
        assetId: asset2,
        date: DateTime(2024, 1, 15),
        type: EventType.buy,
        amount: 500,
        currency: 'USD',
      );
      await service.create(
        assetId: asset2,
        date: DateTime(2024, 4, 1),
        type: EventType.buy,
        amount: 300,
        currency: 'USD',
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
        assetId: asset1,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 100,
        currency: 'EUR',
      );
      await service.create(
        assetId: asset2,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 200,
        currency: 'EUR',
      );
      await service.create(
        assetId: asset3,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 300,
        currency: 'EUR',
      );

      final result = await service.getByAssets([asset1, asset3]);
      expect(result.length, 2);
      expect(result.containsKey(asset1), isTrue);
      expect(result.containsKey(asset2), isFalse);
      expect(result.containsKey(asset3), isTrue);
    });

    test('applies through date by valueDate', () async {
      final asset1 = await createAsset('A1');
      final asset2 = await createAsset('A2');

      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: asset1,
              date: DateTime(2024, 6, 1),
              valueDate: DateTime(2024, 2, 29),
              type: EventType.buy,
              amount: 100,
            ),
          );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: asset2,
              date: DateTime(2024, 1, 1),
              valueDate: DateTime(2024, 3, 1),
              type: EventType.buy,
              amount: 200,
            ),
          );

      final result = await service.getByAssets(
        [asset1, asset2],
        through: DateTime(2024, 2, 29),
      );
      expect(result.keys, {asset1});
      expect(result[asset1]!.single.amount, 100);
    });
  });

  group('getAverageBuyPrice', () {
    test('returns weighted average of buy events', () async {
      final assetId = await createAsset('Bond');
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 9800,
        quantity: 100,
        price: 98.0,
        currency: 'EUR',
      );
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 6, 1),
        type: EventType.buy,
        amount: 4900,
        quantity: 50,
        price: 98.0,
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

    test('through date excludes future valueDate buys', () async {
      final assetId = await createAsset('Bond');
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2024, 6, 1),
              valueDate: DateTime(2024, 1, 1),
              type: EventType.buy,
              amount: 1000,
              quantity: const Value(10),
              price: const Value(100),
            ),
          );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2024, 1, 1),
              valueDate: DateTime(2024, 6, 1),
              type: EventType.buy,
              amount: 2000,
              quantity: const Value(10),
              price: const Value(200),
            ),
          );

      final result = await service.getAverageBuyPrice(
        assetId,
        through: DateTime(2024, 3, 31),
      );
      expect(result, 100);
    });
  });

  group('stampExchangeRateBase', () {
    // Regression: a stored `exchangeRate` carries no record of which base
    // currency it was quoted against, so changing the app's base currency
    // would silently reuse a rate belonging to the OLD base — see
    // `computed_providers.dart`'s `convertToBase`/`convertedEventAmountsProvider`.
    //
    // The fix must NOT delete the rates to achieve that. The column also
    // holds rates the user typed in the event editor and rates a broker file
    // supplied; an execution rate differs from that day's reference rate and
    // no market lookup can reconstruct it. Stamping the outgoing base keeps
    // the value while making it unusable for the new base.
    test('preserves every rate while recording the base it was quoted against', () async {
      final assetId = await createAsset('USD Fund');
      final id1 = await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 100,
        currency: 'USD',
        exchangeRate: 1.1,
        exchangeRateBase: 'EUR',
      );
      final id2 = await service.create(
        assetId: assetId,
        date: DateTime(2024, 2, 1),
        type: EventType.buy,
        amount: 200,
        currency: 'USD',
        exchangeRate: 1.2,
      );

      // id2 was stored without provenance (the legacy/unstamped shape).
      expect((await service.getByAsset(assetId)).firstWhere((e) => e.id == id2).exchangeRateBase, isNull);

      final stamped = await service.stampExchangeRateBase('EUR');
      expect(stamped, 1, reason: 'only the unattributed row needs stamping; id1 already records its base');

      final events = await service.getByAsset(assetId);
      expect(
        events.map((e) => e.exchangeRate).toList()..sort(),
        [1.1, 1.2],
        reason: 'user-entered and imported execution rates are original data — never destroyed',
      );
      expect(events.every((e) => e.exchangeRateBase == 'EUR'), isTrue);
      expect(events.map((e) => e.id).toSet(), {id1, id2});
    });

    test('a stamped rate is no longer usable for a different base, but stays usable for its own', () async {
      final assetId = await createAsset('USD Fund');
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 100,
        currency: 'USD',
        exchangeRate: 1.1,
        exchangeRateBase: 'EUR',
      );
      final event = (await service.getByAsset(assetId)).single;

      expect(AssetEventService.isExchangeRateUsableFor(event, 'EUR'), isTrue);
      expect(
        AssetEventService.isExchangeRateUsableFor(event, 'GBP'),
        isFalse,
        reason: 'a EUR-quoted rate must not be applied to a GBP base',
      );
    });

    test('an unstamped rate counts as quoted against the current base', () async {
      final assetId = await createAsset('USD Fund');
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 100,
        currency: 'USD',
        exchangeRate: 1.1,
      );
      final event = (await service.getByAsset(assetId)).single;

      expect(
        AssetEventService.isExchangeRateUsableFor(event, 'EUR'),
        isTrue,
        reason: 'rows predating the provenance column must keep working while the base is unchanged',
      );
    });

    test('is a no-op when no event has a rate', () async {
      final assetId = await createAsset('EUR Fund');
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 100,
        currency: 'EUR',
      );
      expect(await service.stampExchangeRateBase('EUR'), 0);
    });
  });
}
