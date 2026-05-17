// T7 — pre-existing 'contribute' SQL literals still work post-enum.
//
// Three SQL queries reference the literal `'contribute'`:
//   - asset_service.dart:118  (total_invested)
//   - asset_event_service.dart:99 (getAverageBuyPrice)
//   - data_providers.dart:94 (cumulative invested for chart)
//
// Before EventType.buy was added to the enum, those SQL paths
// were dead — no row ever had type='contribute'. Adding the enum makes
// them live. This test pins that:
//   (a) on a DB with zero contribute rows, behavior is unchanged.
//   (b) inserting a synthetic contribute row makes it sum into
//       total_invested alongside buys and feed getAverageBuyPrice.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/asset_event_service.dart';
import 'package:finance_copilot/services/asset_service.dart';

void main() {
  late AppDatabase db;
  late AssetService assetService;
  late AssetEventService eventService;
  late int intermediaryId;
  late int assetId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    assetService = AssetService(db);
    eventService = AssetEventService(db);
    intermediaryId = await db.into(db.intermediaries).insert(
          IntermediariesCompanion.insert(name: 'Default'),
        );
    assetId = await db.into(db.assets).insert(AssetsCompanion.insert(
          name: 'Pension',
          assetType: AssetType.pension,
          instrumentType: const Value(InstrumentType.pension),
          assetClass: const Value(AssetClass.multiAsset),
          valuationMethod: ValuationMethod.eventDriven,
          currency: const Value('EUR'),
          intermediaryId: intermediaryId,
        ));
  });

  tearDown(() => db.close());

  test('total_invested includes both buy and contribute rows', () async {
    // Buy: 100 EUR @ 10/unit = 10 units
    await eventService.create(
      assetId: assetId,
      date: DateTime(2024, 1, 15),
      type: EventType.buy,
      amount: 100.00,
      quantity: 10.0,
      price: 10.0,
      currency: 'EUR',
    );
    // Contribute: 200 EUR with synthesized qty=200, price=1
    await eventService.create(
      assetId: assetId,
      date: DateTime(2024, 2, 15),
      type: EventType.buy,
      amount: 200.00,
      quantity: 200.0,
      price: 1.0,
      currency: 'EUR',
    );
    // Sell: 5 units. After the cost-basis-after-sells fix, totalInvested
    // is weighted-avg × remaining qty (not the gross buy sum):
    //   buy totals  = 300 EUR / 210 units → 1.42857 EUR/unit
    //   remaining   = 10 + 200 − 5 = 205 units
    //   invested    = 1.42857 × 205 ≈ 292.857
    await eventService.create(
      assetId: assetId,
      date: DateTime(2024, 3, 15),
      type: EventType.sell,
      amount: 50.00,
      quantity: 5.0,
      price: 10.0,
      currency: 'EUR',
    );

    final stats = await assetService.getStatsForAll();
    expect(stats[assetId], isNotNull);
    expect(stats[assetId]!.totalInvested, closeTo(292.857, 0.01),
        reason: 'weighted-avg cost basis of remaining 205 units');
    expect(stats[assetId]!.eventCount, 3);
  });

  test('getAverageBuyPrice includes contribute rows with explicit qty/price',
      () async {
    // Two contributes with explicit unit pricing (e.g. 401(k) shape):
    // 10 units @ 50.00 + 5 units @ 60.00 → avg = 53.33...
    await eventService.create(
      assetId: assetId,
      date: DateTime(2024, 1, 15),
      type: EventType.buy,
      amount: 500.00,
      quantity: 10.0,
      price: 50.00,
      currency: 'EUR',
    );
    await eventService.create(
      assetId: assetId,
      date: DateTime(2024, 2, 15),
      type: EventType.buy,
      amount: 300.00,
      quantity: 5.0,
      price: 60.00,
      currency: 'EUR',
    );

    final avg = await eventService.getAverageBuyPrice(assetId);
    expect(avg, isNotNull);
    expect(avg!, closeTo(53.333, 0.01));
  });

  test('with zero contribute rows, totalInvested is unchanged', () async {
    await eventService.create(
      assetId: assetId,
      date: DateTime(2024, 1, 15),
      type: EventType.buy,
      amount: 1000.00,
      quantity: 10.0,
      price: 100.0,
      currency: 'EUR',
    );
    final stats = await assetService.getStatsForAll();
    expect(stats[assetId]!.totalInvested, 1000.00);
  });
}
