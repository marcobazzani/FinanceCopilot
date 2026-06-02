// T9 — `targetAssetId` parameter on importAssetEventsGrouped.
//
// Existing path: rows are grouped by ISIN, one asset per ISIN.
// New path: caller passes `targetAssetId`, all rows route to that asset
// without an `isin` column mapping. Used for pension imports (single
// asset, no per-row ISIN), German Riester, UK SIPP — anything where
// the user pre-creates the asset and just feeds it events.

import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/import_service.dart';

void main() {
  late AppDatabase db;
  late ImportService importer;
  late Directory tempDir;
  late int intermediaryId;
  late int targetAssetId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = ImportService(db);
    tempDir = Directory.systemTemp.createTempSync('target_asset_test_');
    intermediaryId = await db
        .into(db.intermediaries)
        .insert(
          IntermediariesCompanion.insert(name: 'Default'),
        );
    targetAssetId = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'Pension Fund',
            assetType: AssetType.pension,
            instrumentType: const Value(InstrumentType.pension),
            assetClass: const Value(AssetClass.multiAsset),
            valuationMethod: ValuationMethod.eventDriven,
            currency: const Value('EUR'),
            intermediaryId: intermediaryId,
          ),
        );
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  File writeCsv(String name, String content) {
    final f = File('${tempDir.path}/$name');
    f.writeAsStringSync(content);
    return f;
  }

  test('targetAssetId routes every row to that asset, no isin needed', () async {
    final file = writeCsv('pension.csv', '''
date,type,amount
2024-01-31,buy,100.00
2024-02-29,buy,150.00
2024-03-31,buy,200.00
''');
    final preview = await importer.parseFile(file.path);

    final result = await importer.importAssetEventsGrouped(
      preview: preview,
      mappings: const [
        ColumnMapping(sourceColumn: 'date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'type', targetField: 'type'),
        ColumnMapping(sourceColumn: 'amount', targetField: 'amount'),
        // No `isin` mapping — targetAssetId takes over.
      ],
      baseCurrency: 'EUR',
      intermediaryId: intermediaryId,
      targetAssetId: targetAssetId,
    );

    expect(result.result.errorRows, 0);
    expect(result.result.importedRows, 3);

    final events = await db.select(db.assetEvents).get();
    expect(events, hasLength(3));
    expect(events.map((e) => e.assetId), everyElement(targetAssetId));
  });

  test('without targetAssetId AND without isin mapping, request fails', () async {
    final file = writeCsv('no_isin.csv', '''
date,type,amount
2024-01-31,buy,100.00
''');
    final preview = await importer.parseFile(file.path);

    final result = await importer.importAssetEventsGrouped(
      preview: preview,
      mappings: const [
        ColumnMapping(sourceColumn: 'date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'type', targetField: 'type'),
        ColumnMapping(sourceColumn: 'amount', targetField: 'amount'),
      ],
      baseCurrency: 'EUR',
      intermediaryId: intermediaryId,
      // no targetAssetId, no isin mapping
    );

    expect(result.result.importedRows, 0);
    expect(result.result.errors, isNotEmpty);
    expect(result.result.errors.first, contains('ISIN'));
  });

  test('targetAssetId AND isin mapping together: targetAssetId wins, '
      'all rows still route to that asset', () async {
    // Defensive contract: if both are passed (e.g. wizard wiring bug),
    // targetAssetId takes precedence and the isin mapping is ignored.
    // Asserts no rows leak into other assets.
    final file = writeCsv('with_isin.csv', '''
date,type,amount,isin
2024-01-31,buy,100.00,US9229087690
2024-02-29,buy,150.00,US9229087690
''');
    final preview = await importer.parseFile(file.path);

    final result = await importer.importAssetEventsGrouped(
      preview: preview,
      mappings: const [
        ColumnMapping(sourceColumn: 'date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'type', targetField: 'type'),
        ColumnMapping(sourceColumn: 'amount', targetField: 'amount'),
        ColumnMapping(sourceColumn: 'isin', targetField: 'isin'),
      ],
      baseCurrency: 'EUR',
      intermediaryId: intermediaryId,
      targetAssetId: targetAssetId,
    );

    expect(result.result.errorRows, 0);
    final events = await db.select(db.assetEvents).get();
    expect(events.map((e) => e.assetId), everyElement(targetAssetId));
    // No phantom asset was created from the ISIN.
    final assets = await db.select(db.assets).get();
    expect(assets.where((a) => a.isin == 'US9229087690'), isEmpty);
  });

  // Cross-product audit (post-merge of HEAD's Fee chip with the worktree's
  // single-asset mode): the two features were merged independently, so
  // verify the combinations behave the way the merge plan says they do.

  test('single-asset + Fee bucket: fee rows drop silently, no errors', () async {
    // 2 buy rows + 1 fee row, all routed to the pre-existing pension
    // asset. Fee is a pure no-op in single-asset mode (the pre-pass is
    // gated on targetAssetId == null, and the per-row main loop drops
    // fee rows via _parseEventType returning null). The merge audit
    // verified this by reading code; this test pins it.
    final file = writeCsv('pension_with_fee.csv', '''
date,type,amount
2024-01-31,buy,100.00
2024-02-29,buy,150.00
2024-02-29,COMMISSION,-2.50
''');
    final preview = await importer.parseFile(file.path);

    final result = await importer.importAssetEventsGrouped(
      preview: preview,
      mappings: const [
        ColumnMapping(sourceColumn: 'date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'type', targetField: 'type'),
        ColumnMapping(sourceColumn: 'amount', targetField: 'amount'),
      ],
      baseCurrency: 'EUR',
      intermediaryId: intermediaryId,
      targetAssetId: targetAssetId,
      feeValues: const {'COMMISSION'},
    );

    expect(result.result.importedRows, 2, reason: '2 buy rows imported; the fee row drops silently');
    expect(result.result.errorRows, 0, reason: 'fee in single-asset mode is by-design no-op, not an error');
    expect(result.result.attachedFees, 0, reason: 'pre-pass is gated on targetAssetId == null');
    expect(result.result.unmatchedFees, 0, reason: 'no orderRef → nothing to match → counted as 0, not as orphan');
    final events = await db.select(db.assetEvents).get();
    expect(events, hasLength(2));
    expect(events.every((e) => e.type == EventType.buy), isTrue);
  });

  test('single-asset + Revalue: synthesis does NOT fire on revalue rows', () async {
    // Pension cash-only synthesis (effectiveQty=amount, price=1.0) is
    // narrowly gated on EventType.buy. A revalue row in the same file
    // must store quantity=null/price=null verbatim, so the
    // materialise-revalue resync produces a market_prices row from
    // amount/qty-at-date rather than a fabricated price.
    final file = writeCsv('pension_with_revalue.csv', '''
date,type,amount
2024-01-31,buy,100.00
2024-12-31,TOTALEP,1234.56
''');
    final preview = await importer.parseFile(file.path);

    final result = await importer.importAssetEventsGrouped(
      preview: preview,
      mappings: const [
        ColumnMapping(sourceColumn: 'date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'type', targetField: 'type'),
        ColumnMapping(sourceColumn: 'amount', targetField: 'amount'),
      ],
      baseCurrency: 'EUR',
      intermediaryId: intermediaryId,
      targetAssetId: targetAssetId,
      revalueValues: const {'TOTALEP'},
    );

    expect(result.result.importedRows, 2);
    expect(result.result.errorRows, 0);
    final events = await db.select(db.assetEvents).get();
    final buy = events.firstWhere((e) => e.type == EventType.buy);
    final revalue = events.firstWhere((e) => e.type == EventType.revalue);
    // Buy synthesised cash-only fields.
    expect(buy.quantity, 100.00, reason: 'effectiveQty=amount');
    expect(buy.price, 1.0, reason: 'effectivePrice=1.0');
    // Revalue stays unsynthesised — the resync uses qty-at-date, not these fields.
    expect(revalue.quantity, isNull, reason: 'synthesis is gated on EventType.buy; revalue is left as-is');
    expect(revalue.price, isNull);
    expect(revalue.amount, 1234.56);
  });
}
