// Regression test for #77 — "i titoli che hanno subito vendite nel corso
// della storia del portafoglio vengono riportati in portafoglio con
// quantità errata".
//
// Reporter: buys 399 shares total, sells 199 shares total. True net is
// 200. App reports 598 (= 399 + 199) — sells are added instead of
// subtracted.
//
// Root cause: the source CSV stores sells with NEGATIVE quantity (the
// convention many Italian retail brokers use — Directa, Fineco, some IB
// exports). The importer preserves the sign verbatim, then the SQL
// aggregation in lib/services/asset_service.dart:127-129 double-negates:
//
//   SUM(CASE WHEN type = 'buy'  THEN COALESCE(quantity, 0)
//            WHEN type = 'sell' THEN -COALESCE(quantity, 0) ELSE 0 END)
//
// With qty = -199 stored for a sell, `-COALESCE(-199, 0) = +199`. So a
// sell contributes +199 to net qty instead of -199.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/asset_service.dart';
import 'package:finance_copilot/services/import_service.dart';

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
    tempDir = Directory.systemTemp.createTempSync('issue77_');
    intermediaryId = await db
        .into(db.intermediaries)
        .insert(
          IntermediariesCompanion.insert(name: 'Directa'),
        );
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('issue #77: sells with negative qty + type column → net qty must subtract', () async {
    // Reporter's exact figures: buys total 399, sells total 199, expected
    // net 200. Source uses negative quantities for sells (Italian-broker
    // convention) AND maps the type column explicitly.
    final file = File('${tempDir.path}/directa.csv');
    file.writeAsStringSync('''date,isin,type,quantity,price,amount
2024-01-15,IT0000DIRECT,buy,200,10.00,2000.00
2024-02-15,IT0000DIRECT,buy,100,11.00,1100.00
2024-03-15,IT0000DIRECT,buy,99,12.00,1188.00
2024-04-15,IT0000DIRECT,sell,-100,13.00,-1300.00
2024-05-15,IT0000DIRECT,sell,-99,14.00,-1386.00
''');

    final capped = await importer.parseFile(file.path);
    final preview = await importer.getFullRows(capped);
    final result = await importer.importAssetEventsGrouped(
      preview: preview,
      mappings: const [
        ColumnMapping(sourceColumn: 'date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'isin', targetField: 'isin'),
        ColumnMapping(sourceColumn: 'type', targetField: 'type'),
        ColumnMapping(sourceColumn: 'quantity', targetField: 'quantity'),
        ColumnMapping(sourceColumn: 'price', targetField: 'price'),
        ColumnMapping(sourceColumn: 'amount', targetField: 'amount'),
      ],
      baseCurrency: 'EUR',
      intermediaryId: intermediaryId,
    );

    expect(result.result.errorRows, 0, reason: 'errors: ${result.result.errors}');
    expect(result.result.importedRows, 5);

    final assetId = result.assetsByIsin['IT0000DIRECT']!;
    final stats = (await assetService.getStatsForAll())[assetId]!;

    // Hand math: 200 + 100 + 99 − 100 − 99 = 200.
    expect(stats.totalQuantity, 200, reason: 'buys 399 − sells 199 = 200 effective shares');

    // Pre-fix observed (bug): -COALESCE(-199, 0) = +199 → net 598.
    expect(stats.totalQuantity, isNot(598), reason: 'reporter saw 598 (399 + 199) when sells are double-negated');

    // Cost basis of the remaining 200 shares is the weighted-average buy
    // price × remaining qty — the sale at 13/14 EUR/share doesn't subtract
    // its proceeds from invested, it reduces the qty whose cost we track.
    //   total buy amount = 2000 + 1100 + 1188 = 4288
    //   total buy qty    = 200 + 100 + 99    = 399
    //   avg cost / share = 4288 / 399        ≈ 10.7469
    //   invested         = 10.7469 × 200     ≈ 2149.37
    expect(stats.totalInvested, closeTo(2149.37, 0.01), reason: 'weighted-avg cost basis of remaining 200 shares');
  });

  test('sells with NEGATIVE amount + POSITIVE qty + type — already correct', () async {
    // Same totals as the bug test but qty is positive everywhere; only
    // amount carries the sign. This is the convention several other
    // brokers use (and what the app's own export round-trip produces).
    // Pin it green so any future "ABS on the SQL side" fix doesn't break
    // this path.
    final file = File('${tempDir.path}/posqty.csv');
    file.writeAsStringSync('''date,isin,type,quantity,price,amount
2024-01-15,IT0000POSQTY,buy,200,10.00,2000.00
2024-02-15,IT0000POSQTY,buy,100,11.00,1100.00
2024-03-15,IT0000POSQTY,buy,99,12.00,1188.00
2024-04-15,IT0000POSQTY,sell,100,13.00,-1300.00
2024-05-15,IT0000POSQTY,sell,99,14.00,-1386.00
''');

    final capped = await importer.parseFile(file.path);
    final preview = await importer.getFullRows(capped);
    final result = await importer.importAssetEventsGrouped(
      preview: preview,
      mappings: const [
        ColumnMapping(sourceColumn: 'date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'isin', targetField: 'isin'),
        ColumnMapping(sourceColumn: 'type', targetField: 'type'),
        ColumnMapping(sourceColumn: 'quantity', targetField: 'quantity'),
        ColumnMapping(sourceColumn: 'price', targetField: 'price'),
        ColumnMapping(sourceColumn: 'amount', targetField: 'amount'),
      ],
      baseCurrency: 'EUR',
      intermediaryId: intermediaryId,
    );
    expect(result.result.errorRows, 0, reason: 'errors: ${result.result.errors}');

    final assetId = result.assetsByIsin['IT0000POSQTY']!;
    final stats = (await assetService.getStatsForAll())[assetId]!;
    expect(stats.totalQuantity, 200);
    // Same weighted-avg cost basis as the negative-qty case above: this
    // shape is just a different storage convention for the identical
    // economic position, so the displayed cost basis must match.
    expect(stats.totalInvested, closeTo(2149.37, 0.01));
  });

  test('"From sign (+/-)" detection: no type column, qty negative on sells', () async {
    // Mirror the wizard's "From sign" detection — no `type` column mapped,
    // event type inferred from the qty/amount sign in import_service.dart
    // (`negativeIsBuy = false`). Source uses negative qty for sells. With
    // the qty.abs() fix at write time, this path produces the same canonical
    // rows as the "From column" path, so the same 200-share / 2149.37-EUR
    // expectation holds.
    final file = File('${tempDir.path}/sign_mode.csv');
    file.writeAsStringSync('''date,isin,quantity,price,amount
2024-01-15,IT0000SIGNMD,200,10.00,2000.00
2024-02-15,IT0000SIGNMD,100,11.00,1100.00
2024-03-15,IT0000SIGNMD,99,12.00,1188.00
2024-04-15,IT0000SIGNMD,-100,13.00,-1300.00
2024-05-15,IT0000SIGNMD,-99,14.00,-1386.00
''');

    final capped = await importer.parseFile(file.path);
    final preview = await importer.getFullRows(capped);
    final result = await importer.importAssetEventsGrouped(
      preview: preview,
      mappings: const [
        ColumnMapping(sourceColumn: 'date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'isin', targetField: 'isin'),
        // intentionally NO 'type' mapping — exercises sign-based inference
        ColumnMapping(sourceColumn: 'quantity', targetField: 'quantity'),
        ColumnMapping(sourceColumn: 'price', targetField: 'price'),
        ColumnMapping(sourceColumn: 'amount', targetField: 'amount'),
      ],
      baseCurrency: 'EUR',
      intermediaryId: intermediaryId,
    );
    expect(result.result.errorRows, 0, reason: 'errors: ${result.result.errors}');
    expect(result.result.importedRows, 5);

    final assetId = result.assetsByIsin['IT0000SIGNMD']!;
    final stats = (await assetService.getStatsForAll())[assetId]!;

    // Verify the SQL aggregated sells correctly (would have been 598 if the
    // qty.abs() write + ABS() SQL pair were missing).
    expect(stats.totalQuantity, 200, reason: 'sign-mode inference + qty.abs() must yield correct net');
    expect(stats.totalInvested, closeTo(2149.37, 0.01), reason: 'weighted-avg cost basis of remaining 200 shares');
  });
}
