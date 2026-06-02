// T2 — `_parseEventType` aliases for revalue/contribute event types.
//
// Tested via the public path `importAssetEventsGrouped`: a tiny CSV with
// rows whose `type` column carries pension-shaped labels (TOTALEP,
// POSIZIONE, CONTRIBUTO, BEITRAG, plus a user-override) drives the
// import. We assert each row produces the expected EventType in the DB.
//
// Why public-path testing rather than poking _parseEventType directly:
// the function is private, the value sets are passed through as
// parameters, and the regression we care about is "the wizard's chip
// labels actually classify rows correctly" — that's what this exercises.

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

  group('event-type aliases through importAssetEventsGrouped', () {
    test('built-in TOTALEP / POSIZIONE alias to revalue', () async {
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

    test('built-in CONTRIBUTO / BEITRAG / CONTRIBUTION alias to contribute', () async {
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
}
