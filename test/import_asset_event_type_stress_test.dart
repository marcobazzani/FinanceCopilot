// Edge-case STRESS tests for asset-event type resolution after removing the
// hardcoded multi-language alias dictionaries from _parseEventType. Goal: 0
// regressions. Type now comes ONLY from explicit chip tags + literal enum
// names; everything else fails loudly. Fee rows (feeValues) resolve to
// null and are dropped/folded, never errored.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/import/import_service.dart';

void main() {
  late AppDatabase db;
  late ImportService importer;
  late int intermediaryId;
  late int targetAssetId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = ImportService(db);
    intermediaryId = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Default'));
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

  tearDown(() async => db.close());

  // Build a FULL in-memory preview (rows == totalRows) to bypass parseFile's
  // head+tail cap, mirroring the production post-getFullRows state.
  FilePreview previewOf(List<(String date, String type, String amount)> rows) => FilePreview(
    columns: const ['date', 'type', 'amount'],
    rows: [
      for (final r in rows) {'date': r.$1, 'type': r.$2, 'amount': r.$3},
    ],
    totalRows: rows.length,
  );

  Future<ImportResult> run(
    FilePreview p, {
    Set<String>? buyValues,
    Set<String>? sellValues,
    Set<String>? revalueValues,
    Set<String>? contributeValues,
    Set<String>? feeValues,
  }) async {
    final r = await importer.importAssetEventsGrouped(
      preview: p,
      mappings: const [
        ColumnMapping(sourceColumn: 'date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'type', targetField: 'type'),
        ColumnMapping(sourceColumn: 'amount', targetField: 'amount'),
      ],
      baseCurrency: 'EUR',
      intermediaryId: intermediaryId,
      targetAssetId: targetAssetId,
      buyValues: buyValues,
      sellValues: sellValues,
      revalueValues: revalueValues,
      contributeValues: contributeValues,
      feeValues: feeValues,
    );
    return r.result;
  }

  group('normalization edge cases', () {
    test('whitespace + case variants of a tag all match', () async {
      final p = previewOf([
        ('2024-01-01', '  Acquisto  ', '100'),
        ('2024-01-02', 'ACQUISTO', '100'),
        ('2024-01-03', 'acquisto', '100'),
      ]);
      final r = await run(p, buyValues: const {'Acquisto'});
      expect(r.errorRows, 0);
      expect(r.importedRows, 3);
      final events = await db.select(db.assetEvents).get();
      expect(events.every((e) => e.type == EventType.buy), isTrue);
    });

    test('multi-word tag with internal spaces matches space→underscore normalized cell', () async {
      final p = previewOf([('2024-12-31', 'POSIZIONE INDIVIDUALE', '5000')]);
      final r = await run(p, revalueValues: const {'POSIZIONE INDIVIDUALE'});
      expect(r.errorRows, 0);
      expect((await db.select(db.assetEvents).get()).single.type, EventType.revalue);
    });

    test('empty type cell with a type column mapped fails loudly (not silently BUY)', () async {
      // An empty cell is a present-but-blank value → no enum match, no tag →
      // loud failure, consistent with the no-silent-guess design. (The 'BUY'
      // default only applies when the type column value is absent/null.)
      final p = previewOf([('2024-01-01', '', '100')]);
      final r = await run(p);
      expect(r.errorRows, 1);
      expect(r.importedRows, 0);
      expect(await db.select(db.assetEvents).get(), isEmpty);
    });
  });

  group('explicit tags win over enum names', () {
    test('value "sell" tagged as buy resolves to buy (tags take priority)', () async {
      final p = previewOf([('2024-01-01', 'sell', '100')]);
      final r = await run(p, buyValues: const {'sell'});
      expect(r.errorRows, 0);
      expect((await db.select(db.assetEvents).get()).single.type, EventType.buy);
    });

    test('contributeValues collapse to buy (3-type model)', () async {
      final p = previewOf([
        ('2024-01-01', 'C/Azienda', '100'),
        ('2024-02-01', 'C/TFR', '200'),
      ]);
      final r = await run(p, contributeValues: const {'C/Azienda', 'C/TFR'});
      expect(r.errorRows, 0);
      final events = await db.select(db.assetEvents).get();
      expect(events.every((e) => e.type == EventType.buy), isTrue);
    });
  });

  group('fee rows resolve to null (dropped, not errored)', () {
    test('feeValues without orderRef are silently dropped, no error', () async {
      final p = previewOf([
        ('2024-01-01', 'Acquisto', '1000'),
        ('2024-01-01', 'Commissioni', '5'),
      ]);
      final r = await run(p, buyValues: const {'Acquisto'}, feeValues: const {'Commissioni'});
      // Fee row dropped (no orderRef mapping) — counts as neither imported
      // event nor error.
      expect(r.errorRows, 0);
      final events = await db.select(db.assetEvents).get();
      expect(events, hasLength(1));
      expect(events.single.type, EventType.buy);
    });
  });

  group('loud failure on untagged + partial files', () {
    test('mix of literal-enum, tagged, and untagged rows', () async {
      final p = previewOf([
        ('2024-01-01', 'buy', '100'), // literal enum → ok
        ('2024-01-02', 'Acquisto', '200'), // tagged buy → ok
        ('2024-01-03', 'DIVIDENDO', '5'), // untagged → error
        ('2024-01-04', 'VENDITA', '50'), // removed alias, untagged → error
      ]);
      final r = await run(p, buyValues: const {'Acquisto'});
      expect(r.importedRows, 2);
      expect(r.errorRows, 2);
    });

    test('a whole file of removed aliases all error when untagged', () async {
      final p = previewOf([
        ('2024-01-01', 'VENDITA', '10'),
        ('2024-01-02', 'KAUF', '10'),
        ('2024-01-03', 'ACHAT', '10'),
      ]);
      final r = await run(p);
      expect(r.importedRows, 0);
      expect(r.errorRows, 3);
    });
  });

  group('scale', () {
    test('900 mixed rows (buy/sell/revalue tagged) classify with 0 errors', () async {
      final rows = <(String, String, String)>[];
      for (var i = 0; i < 900; i++) {
        final t = i % 3 == 0 ? 'Acq' : (i % 3 == 1 ? 'Vnd' : 'Pos');
        // unique dates so sells don't oversell; keep amounts positive
        final month = (i % 12) + 1;
        final day = (i % 28) + 1;
        rows.add(('2024-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}', t, '${i + 1}'));
      }
      final p = previewOf(rows);
      final r = await run(
        p,
        buyValues: const {'Acq'},
        sellValues: const {'Vnd'},
        revalueValues: const {'Pos'},
      );
      expect(r.errorRows, 0);
      final events = await db.select(db.assetEvents).get();
      // Every row produced an event of one of the three types.
      expect(events.every((e) => e.type == EventType.buy || e.type == EventType.sell || e.type == EventType.revalue), isTrue);
    });
  });
}
