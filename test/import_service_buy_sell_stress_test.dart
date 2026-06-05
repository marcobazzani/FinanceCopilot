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

  /// Hand-summed stats helper. Each item is (qty, price). Buys and sells are
  /// stored with positive qty; the SQL aggregates buy.qty − sell.qty, so the
  /// sign comes from event.type. totalInvested is the weighted-average buy
  /// price times remaining quantity — sells don't subtract their proceeds,
  /// they reduce the qty whose cost we still track (cost-basis-after-sells
  /// fix). Returns 0 for fully-closed positions.
  ({double netQty, double totalInvested}) expected({
    required List<(double qty, double price)> buys,
    required List<(double qty, double price)> sells,
  }) {
    final buyQty = buys.fold<double>(0, (s, e) => s + e.$1);
    final sellQty = sells.fold<double>(0, (s, e) => s + e.$1);
    final buyAmount = buys.fold<double>(0, (s, e) => s + e.$1 * e.$2);
    final netQty = buyQty - sellQty;
    final invested = (buyQty <= 0 || netQty <= 0) ? 0.0 : (buyAmount / buyQty) * netQty;
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
    // totalInvested now tracks the cost basis of the *currently held*
    // shares (weighted-avg buy price × remaining qty), so each batch
    // recomputes:
    //   After B1: avg = 1000/100 = 10        → 10  × 100 = 1000.00
    //   After B2: avg = 1000/100 = 10        → 10  × 40  =  400.00
    //   After B3: avg = 1880/180 ≈ 10.4444   → ×120     ≈ 1253.33
    //   After B4: net qty = 0                → 0
    //   After B5: avg = 2440/220 ≈ 11.0909   → ×40      ≈  443.64

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
    expect(stats.totalInvested, closeTo(1253.33, 0.01), reason: 'avg (1880/180) × 120 remaining');
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

    // B5 re-opens the position. Weighted-avg uses the FULL buy history
    // (B1+B3+B5), not just B5 — same convention retail brokerages use.
    stats = (await assetService.getStatsForAll())[assetId]!;
    expect(stats.totalQuantity, 40, reason: 'B5 must add fresh shares without wiping any of B1..B4');
    expect(stats.totalInvested, closeTo(443.636, 0.01), reason: 'avg (2440/220) × 40 — pure weighted-avg, no reset on re-open');
    expect(stats.eventCount, 20);

    final hand = expected(
      buys: const [
        (20, 10),
        (20, 10),
        (20, 10),
        (20, 10),
        (20, 10),
        (20, 11),
        (20, 11),
        (20, 11),
        (20, 11),
        (20, 14),
        (20, 14),
      ],
      sells: const [
        (20, 12),
        (20, 12),
        (20, 12),
        (20, 13),
        (20, 13),
        (20, 13),
        (20, 13),
        (20, 13),
        (20, 13),
      ],
    );
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
