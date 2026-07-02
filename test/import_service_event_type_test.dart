// T2 — `_parseEventType` classification for revalue/contribute event types.
//
// Built-in keyword aliases (TOTALEP/POSIZIONE/CONTRIBUTO/BEITRAG/VENDITA/…)
// were REMOVED: asset-event type is now purely explicit — the user's wizard
// chip tags (buyValues/sellValues/revalueValues/feeValues/contributeValues)
// plus a literal enum-name match (buy/sell/revalue). Any other value fails
// loudly. These tests exercise that via the public path
// `importAssetEventsGrouped`: untagged pension labels throw; the same labels
// classify correctly once tagged.

import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/import/import_service.dart';

void main() {
  late AppDatabase db;
  late ImportService importer;
  late Directory tempDir;
  late int intermediaryId;
  late int targetAssetId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = ImportService(db);
    tempDir = Directory.systemTemp.createTempSync('event_type_test_');
    intermediaryId = await db
        .into(db.intermediaries)
        .insert(
          IntermediariesCompanion.insert(name: 'Default'),
        );
    targetAssetId = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'Pension',
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

  group('event-type classification through importAssetEventsGrouped', () {
    test('untagged pension labels (TOTALEP / POSIZIONE) throw — no built-in alias', () async {
      // The built-in keyword aliases were removed: a position-snapshot label
      // must be tagged as revalue via the wizard chips, or it fails loudly.
      final file = writeCsv('aliases.csv', '''
date,type,amount,description
2024-12-31,TOTALEP,1000.00,Year-end position
2024-06-30,POSIZIONE,800.00,Mid-year position
2024-03-15,buy,100.00,Lump-sum buy
''');
      final preview = await importer.parseFile(file.path);
      final result = await importer.importAssetEventsGrouped(
        preview: preview,
        mappings: const [
          ColumnMapping(sourceColumn: 'date', targetField: 'date'),
          ColumnMapping(sourceColumn: 'type', targetField: 'type'),
          ColumnMapping(sourceColumn: 'amount', targetField: 'amount'),
          ColumnMapping(sourceColumn: 'description', targetField: 'description'),
        ],
        baseCurrency: 'EUR',
        intermediaryId: intermediaryId,
        targetAssetId: targetAssetId,
      );

      // The literal `buy` row imports (direct enum match); the two untagged
      // pension labels fail loudly.
      expect(result.result.errorRows, 2);
      final events = await (db.select(db.assetEvents)..orderBy([(e) => OrderingTerm.asc(e.valueDate)])).get();
      expect(events, hasLength(1));
      expect(events[0].type, EventType.buy);
    });

    test('tagged TOTALEP / POSIZIONE classify as revalue via revalueValues', () async {
      final file = writeCsv('aliases.csv', '''
date,type,amount,description
2024-12-31,TOTALEP,1000.00,Year-end position
2024-06-30,POSIZIONE,800.00,Mid-year position
2024-03-15,buy,100.00,Lump-sum buy
''');
      final preview = await importer.parseFile(file.path);
      final result = await importer.importAssetEventsGrouped(
        preview: preview,
        mappings: const [
          ColumnMapping(sourceColumn: 'date', targetField: 'date'),
          ColumnMapping(sourceColumn: 'type', targetField: 'type'),
          ColumnMapping(sourceColumn: 'amount', targetField: 'amount'),
          ColumnMapping(sourceColumn: 'description', targetField: 'description'),
        ],
        baseCurrency: 'EUR',
        intermediaryId: intermediaryId,
        targetAssetId: targetAssetId,
        revalueValues: const {'TOTALEP', 'POSIZIONE'},
      );

      expect(result.result.errorRows, 0);
      final events = await (db.select(db.assetEvents)..orderBy([(e) => OrderingTerm.asc(e.valueDate)])).get();
      expect(events, hasLength(3));
      // Ordered ascending by valueDate:
      // 2024-03-15 buy, 2024-06-30 POSIZIONE, 2024-12-31 TOTALEP
      expect(events[0].type, EventType.buy);
      expect(events[1].type, EventType.revalue);
      expect(events[1].amount, 800.00);
      expect(events[2].type, EventType.revalue);
      expect(events[2].amount, 1000.00);
    });

    test('untagged CONTRIBUTO / BEITRAG throw — must be tagged via contributeValues', () async {
      final file = writeCsv('contrib.csv', '''
date,type,amount
2024-01-15,CONTRIBUTO,100.00
2024-02-15,BEITRAG,200.00
2024-03-15,CONTRIBUTION,300.00
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
      );

      // No built-in alias: all three fail loudly until tagged.
      expect(result.result.errorRows, 3);
      expect(result.result.importedRows, 0);
    });

    test('tagged contribution labels classify as buy via contributeValues', () async {
      final file = writeCsv('contrib.csv', '''
date,type,amount
2024-01-15,CONTRIBUTO,100.00
2024-02-15,BEITRAG,200.00
2024-03-15,CONTRIBUTION,300.00
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
        contributeValues: const {'CONTRIBUTO', 'BEITRAG', 'CONTRIBUTION'},
      );

      expect(result.result.errorRows, 0);
      final events = await (db.select(db.assetEvents)..orderBy([(e) => OrderingTerm.asc(e.valueDate)])).get();
      expect(events.map((e) => e.type), everyElement(EventType.buy));
      expect(events.map((e) => e.amount), [100.00, 200.00, 300.00]);
    });

    test('user-provided contributeValues / revalueValues override', () async {
      // PPP-style labels that aren't in the built-in alias list: the user
      // tags them via the wizard chips, which become contributeValues /
      // revalueValues sets.
      final file = writeCsv('ppp.csv', '''
date,type,amount
2024-03-31,C/TFR,300.00
2024-03-31,C/Azienda,100.00
2024-12-31,TOTALE_PERIODO,17000.00
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
        contributeValues: const {'C/TFR', 'C/Azienda', 'C/Iscritto'},
        revalueValues: const {'TOTALE_PERIODO'},
      );

      expect(result.result.errorRows, 0);
      final events = await (db.select(db.assetEvents)..orderBy([(e) => OrderingTerm.asc(e.valueDate)])).get();
      expect(events, hasLength(3));
      expect(events[0].type, EventType.buy);
      expect(events[1].type, EventType.buy);
      expect(events[2].type, EventType.revalue);
      expect(events[2].amount, 17000.00);
    });

    test('unknown type still throws (no silent fallback)', () async {
      final file = writeCsv('unknown.csv', '''
date,type,amount
2024-01-15,DIVIDEND,100.00
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
      );

      expect(result.result.errorRows, 1);
      expect(result.result.importedRows, 0);
      expect(result.result.errors.first, contains('DIVIDEND'));
    });
  });

  group('removed buy/sell language aliases no longer auto-classify', () {
    // Pins the deletion of the hardcoded multi-language alias dictionaries
    // (VENDITA/ACQUISTO/VERKAUF/ACHAT/VENTE/COMPRA/S/V/B/A/…). These words
    // used to classify without any user tag; now they must be tagged or they
    // fail loudly. Literal enum names (buy/sell/revalue) still classify.
    Future<ImportResult> runType(String typeValue, {Set<String>? buyValues, Set<String>? sellValues}) async {
      final file = writeCsv('alias_$typeValue.csv', '''
date,type,amount
2024-01-15,$typeValue,100.00
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
        buyValues: buyValues,
        sellValues: sellValues,
      );
      return result.result;
    }

    for (final alias in ['VENDITA', 'ACQUISTO', 'VERKAUF', 'ACHAT', 'VENTE', 'COMPRA', 'S', 'V', 'B', 'A']) {
      test('"$alias" is no longer auto-classified → fails loudly', () async {
        final r = await runType(alias);
        expect(r.importedRows, 0, reason: '"$alias" must not auto-classify without a tag');
        expect(r.errorRows, 1);
        expect(r.errors.first, contains(alias));
      });
    }

    test('literal enum names still classify (buy / sell / revalue)', () async {
      expect((await runType('buy')).importedRows, 1);
      expect((await runType('sell')).importedRows, 1);
      expect((await runType('revalue')).importedRows, 1);
    });

    test('a removed alias classifies once tagged via buyValues/sellValues', () async {
      expect((await runType('VENDITA', sellValues: const {'VENDITA'})).importedRows, 1);
      expect((await runType('ACQUISTO', buyValues: const {'ACQUISTO'})).importedRows, 1);
    });
  });
}
