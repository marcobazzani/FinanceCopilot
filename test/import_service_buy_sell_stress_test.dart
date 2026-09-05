// Sequential-imports stress test.
//
// Simulates the real-world case where a user imports several broker
// statements in chronological order, each statement being a SEPARATE
// import call:
//
//   batch 1: only buys
//   batch 2: only sells
//   batch 3: only buys
//   batch 4: only sells
//   batch 5: only buys
//
// Each batch covers a distinct (non-overlapping) date range. The
// wipe-and-replace logic in importAssetEventsGrouped uses the globally
// oldest companion date as the cutoff and deletes events `date >= cutoff`
// scoped to the intermediary's assets. With non-overlapping date ranges
// every prior import must survive, and the final stats must equal the
// hand-summed totals.
//
// Two scenarios:
//   E. Position passes through zero mid-stream, then re-opens (final qty ≠ 0).
//   F. Position closes flat at the end (final qty == 0).

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/utils/asset_value_math.dart';

void main() {
  late AppDatabase db;
  late ImportService importer;
  late AssetService assetService;
  late Directory tempDir;
  late int intermediaryId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = ImportService(db);
    assetService = AssetService(db);
    tempDir = Directory.systemTemp.createTempSync('seq_import_');
    intermediaryId = await db
        .into(db.intermediaries)
        .insert(
          IntermediariesCompanion.insert(name: 'Broker'),
        );
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  const mappings = [
    ColumnMapping(sourceColumn: 'date', targetField: 'date'),
    ColumnMapping(sourceColumn: 'isin', targetField: 'isin'),
    ColumnMapping(sourceColumn: 'type', targetField: 'type'),
    ColumnMapping(sourceColumn: 'quantity', targetField: 'quantity'),
    ColumnMapping(sourceColumn: 'price', targetField: 'price'),
    ColumnMapping(sourceColumn: 'amount', targetField: 'amount'),
  ];

  /// Import a single batch from a CSV string. Mirrors what the wizard does
  /// (parseFile → getFullRows → importAssetEventsGrouped) so the test
  /// reaches the same code path a real user does. Returns the asset id.
  Future<int> importBatch(String name, String csv) async {
    final file = File('${tempDir.path}/$name');
    file.writeAsStringSync('date,isin,type,quantity,price,amount\n$csv');
    final capped = await importer.parseFile(file.path);
    final preview = await importer.getFullRows(capped);
    final r = await importer.importAssetEventsGrouped(
      preview: preview,
      mappings: mappings,
      baseCurrency: 'EUR',
      intermediaryId: intermediaryId,
    );
    expect(r.result.errorRows, 0, reason: 'batch $name errors: ${r.result.errors}');
    return r.assetsByIsin.values.single;
  }

  /// Hand-summed stats helper. Mirrors the production moving-average-cost
  /// algorithm ([AssetService._computeAssetStats]) as an independently
  /// written cross-check: walk the SAME chronologically-ordered events and
  /// maintain a running (cost, qty) pool. A sell removes quantity at the
  /// pool's CURRENT average cost; once the pool's quantity reaches zero the
  /// position is fully closed and the pool resets, so a later re-buy starts
  /// a fresh average instead of blending in a disposed lot's price.
  ({double netQty, double totalInvested}) expected(
    List<(String type, double qty, double price)> events,
  ) {
    var poolCost = 0.0;
    var poolQty = 0.0;
    var netQty = 0.0;
    for (final (type, qty, price) in events) {
      if (type == 'buy') {
        poolCost += qty * price;
        poolQty += qty;
        netQty += qty;
      } else {
        netQty -= qty;
        if (poolQty > 0) {
          final avg = poolCost / poolQty;
          final removed = qty > poolQty ? poolQty : qty;
          poolCost -= avg * removed;
          poolQty -= removed;
          if (poolQty <= 1e-9) {
            poolCost = 0;
            poolQty = 0;
          }
        }
      }
    }
    final invested = netQty <= 0 ? 0.0 : poolCost;
    return (netQty: netQty, totalInvested: invested);
  }

  test('E. 5 batches buy/sell/buy/sell/buy — position crosses zero then re-opens', () async {
    // Per-batch quantities and per-share prices in EUR:
    //   B1 buys:  5×20 @ 10  → +100
    //   B2 sells: 3×20 @ 12  →  -60
    //   B3 buys:  4×20 @ 11  →  +80
    //   B4 sells: 6×20 @ 13  → -120
    //   B5 buys:  2×20 @ 14  →  +40
    //
    // Running net qty: 100 → 40 → 120 → 0 → 40.
    // Mid-stream zero must NOT zero-out history; final net qty MUST be 40.
    //
    // totalInvested tracks the cost basis of the *currently held* shares via
    // a moving-average-cost pool (see AssetService._computeAssetStats): a
    // sell removes quantity at the pool's CURRENT average without changing
    // the average of what remains; a later buy blends into whatever is
    // LEFT in the pool, not into the lifetime total of everything ever
    // bought. Each batch recomputes:
    //   After B1: pool = 1000 / 100                      → cost 1000.00
    //   After B2: sell 60 @ avg 10 → pool = 400 / 40      → cost  400.00
    //   After B3: buy 80@11=880 → pool = (400+880) / 120  → cost 1280.00
    //   After B4: sell 120 @ avg 10.667 → pool exactly 0  → cost    0.00
    //   After B5: buy 40@14=560 → FRESH pool (post-reset) → cost  560.00
    //
    // NOTE ON A PRIOR (INCORRECT) EXPECTATION: this test previously asserted
    // 1253.33 after B3 and 443.64 after B5, both computed as
    // "lifetime-average buy price (ignoring how much was already sold) ×
    // currently-held qty". That formula is wrong whenever a buy happens
    // after a partial sell (B3) and is catastrophically wrong across a full
    // liquidation (B5) — it blends the DISPOSED B1 lot's price back into a
    // brand-new position that has nothing to do with it. The moving-average
    // pool above is the standard cost-basis method (matches every other
    // passing test in this suite, e.g. asset_service_cost_basis_after_sells_test.dart)
    // and is what real brokerages report as "average cost".

    final assetId = await importBatch('b1.csv', '''
2024-01-05,IE0000HOLDXX,buy,20,10.00,200.00
2024-01-10,IE0000HOLDXX,buy,20,10.00,200.00
2024-01-15,IE0000HOLDXX,buy,20,10.00,200.00
2024-01-20,IE0000HOLDXX,buy,20,10.00,200.00
2024-01-25,IE0000HOLDXX,buy,20,10.00,200.00
''');

    var stats = (await assetService.getStatsForAll())[assetId]!;
    expect(stats.totalQuantity, 100, reason: 'after B1: 5×20');
    expect(stats.totalInvested, 1000.0);
    expect(stats.eventCount, 5);

    await importBatch('b2.csv', '''
2024-02-05,IE0000HOLDXX,sell,20,12.00,-240.00
2024-02-15,IE0000HOLDXX,sell,20,12.00,-240.00
2024-02-25,IE0000HOLDXX,sell,20,12.00,-240.00
''');

    stats = (await assetService.getStatsForAll())[assetId]!;
    expect(stats.totalQuantity, 40, reason: 'after B2 the 5 B1 buys must still be on file');
    expect(stats.totalInvested, 400.0, reason: 'avg 10/share × 40 remaining shares');
    expect(stats.eventCount, 8);

    await importBatch('b3.csv', '''
2024-03-05,IE0000HOLDXX,buy,20,11.00,220.00
2024-03-10,IE0000HOLDXX,buy,20,11.00,220.00
2024-03-15,IE0000HOLDXX,buy,20,11.00,220.00
2024-03-20,IE0000HOLDXX,buy,20,11.00,220.00
''');

    stats = (await assetService.getStatsForAll())[assetId]!;
    expect(stats.totalQuantity, 120);
    expect(
      stats.totalInvested,
      closeTo(1280.0, 0.01),
      reason: 'moving-average pool: (400 remaining-cost + 880 new buy) = 1280 for 120 shares',
    );
    expect(stats.eventCount, 12);

    await importBatch('b4.csv', '''
2024-04-05,IE0000HOLDXX,sell,20,13.00,-260.00
2024-04-07,IE0000HOLDXX,sell,20,13.00,-260.00
2024-04-09,IE0000HOLDXX,sell,20,13.00,-260.00
2024-04-11,IE0000HOLDXX,sell,20,13.00,-260.00
2024-04-13,IE0000HOLDXX,sell,20,13.00,-260.00
2024-04-15,IE0000HOLDXX,sell,20,13.00,-260.00
''');

    // *** Critical assertion: qty=0 mid-stream must not zero out prior buys'
    // raw history (they still count for the next batch's weighted-avg).
    stats = (await assetService.getStatsForAll())[assetId]!;
    expect(stats.totalQuantity, 0, reason: 'after B4: 12 buys × 20 = 240 = 12 sells × 20');
    expect(stats.totalInvested, 0, reason: 'closed position has no remaining cost basis');
    expect(stats.eventCount, 18);

    await importBatch('b5.csv', '''
2024-05-05,IE0000HOLDXX,buy,20,14.00,280.00
2024-05-15,IE0000HOLDXX,buy,20,14.00,280.00
''');

    // B5 re-opens the position AFTER a full liquidation. The moving-average
    // pool was reset to zero at the end of B4, so B5's cost basis is its
    // OWN price only (2×20 @ 14 = 560) — it must NOT be diluted by blending
    // in the B1/B3 lots that no longer exist.
    stats = (await assetService.getStatsForAll())[assetId]!;
    expect(stats.totalQuantity, 40, reason: 'B5 must add fresh shares without wiping any of B1..B4');
    expect(
      stats.totalInvested,
      closeTo(560.0, 0.01),
      reason: '40 shares @ 14/share — a fresh position after B4 fully closed, no blending with the disposed B1/B3 lots',
    );
    expect(stats.eventCount, 20);

    final hand = expected(const [
      ('buy', 20, 10),
      ('buy', 20, 10),
      ('buy', 20, 10),
      ('buy', 20, 10),
      ('buy', 20, 10),
      ('sell', 20, 12),
      ('sell', 20, 12),
      ('sell', 20, 12),
      ('buy', 20, 11),
      ('buy', 20, 11),
      ('buy', 20, 11),
      ('buy', 20, 11),
      ('sell', 20, 13),
      ('sell', 20, 13),
      ('sell', 20, 13),
      ('sell', 20, 13),
      ('sell', 20, 13),
      ('sell', 20, 13),
      ('buy', 20, 14),
      ('buy', 20, 14),
    ]);
    expect(stats.totalQuantity, hand.netQty);
    expect(stats.totalInvested, closeTo(hand.totalInvested, 0.01));

    // Final asset value via the same math `assetMarketValuesProvider` uses.
    const lastPrice = 15.0;
    await db
        .into(db.marketPrices)
        .insert(
          MarketPricesCompanion.insert(
            assetId: assetId,
            date: DateTime(2024, 6, 1),
            closePrice: lastPrice,
            currency: 'EUR',
          ),
        );
    final value = computeAssetBaseValue(
      quantity: stats.totalQuantity,
      price: lastPrice,
      bondDivisor: 1.0,
      fxRate: 1.0,
    );
    expect(value, 40 * lastPrice, reason: '40 shares × 15 EUR = 600');
  });

  test('F. 5 batches ending flat — sells in final batch close the position', () async {
    // B1 buys 100, B2 sells 30 (net 70), B3 buys 60 (net 130),
    // B4 sells 50 (net 80), B5 sells 80 (net 0). Final qty 0.
    // totalInvested = buys only = 100×10 + 60×12 = 1000 + 720 = 1720.

    final assetId = await importBatch('f1.csv', '''
2024-01-10,IE0000FLATXX,buy,100,10.00,1000.00
''');

    await importBatch('f2.csv', '''
2024-02-10,IE0000FLATXX,sell,30,11.00,-330.00
''');

    await importBatch('f3.csv', '''
2024-03-10,IE0000FLATXX,buy,60,12.00,720.00
''');

    await importBatch('f4.csv', '''
2024-04-10,IE0000FLATXX,sell,50,13.00,-650.00
''');

    await importBatch('f5.csv', '''
2024-05-10,IE0000FLATXX,sell,80,14.00,-1120.00
''');

    final stats = (await assetService.getStatsForAll())[assetId]!;
    expect(stats.totalQuantity, 0, reason: '(100 + 60) − (30 + 50 + 80) = 0');
    expect(stats.totalInvested, 0, reason: 'closed position: no remaining shares → no cost basis');
    expect(stats.eventCount, 5);

    // Closed position carries no value even with a current market price.
    const lastPrice = 14.5;
    await db
        .into(db.marketPrices)
        .insert(
          MarketPricesCompanion.insert(
            assetId: assetId,
            date: DateTime(2024, 6, 1),
            closePrice: lastPrice,
            currency: 'EUR',
          ),
        );
    final value = computeAssetBaseValue(
      quantity: stats.totalQuantity,
      price: lastPrice,
      bondDivisor: 1.0,
      fxRate: 1.0,
    );
    expect(value, 0);
  });
}
