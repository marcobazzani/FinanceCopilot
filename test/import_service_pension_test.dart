// T3 + T4 — End-to-end pension imports across three statement formats.
//
// F1 — PPP-style synthetic fixture, cash-only, monthly + yearly snapshot.
// F2 — 401(k): synthesized US shape, units×NAV, 5 buckets, multi-sub-fund.
// F3 — UK SIPP: synthesized annual summary, contribute-only (no revalue).
//
// Each fixture exercises a different branch of the importer:
//   - F1 → targetAssetId mode + A3 auto-fill (qty=amount, price=1.0)
//   - F2 → ISIN-grouped mode + explicit qty/price (auto-fill skipped)
//   - F3 → targetAssetId mode + zero revalues (close_price never written)
//
// Truth: synthetic year-end positions from import.tsv:
// 1900.00 / 6800.00 / 11900.00 / 17000.00 / 22200.00 / 23100.00.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/asset_event_service.dart';
import 'package:finance_copilot/services/import/import_service.dart';

void main() {
  late AppDatabase db;
  late ImportService importer;
  late int intermediaryId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = ImportService(db);
    intermediaryId = await db
        .into(db.intermediaries)
        .insert(
          IntermediariesCompanion.insert(name: 'Default'),
        );
  });

  tearDown(() => db.close());

  Future<int> createPensionAsset({String currency = 'EUR'}) {
    return db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'Pension',
            assetType: AssetType.pension,
            instrumentType: const Value(InstrumentType.pension),
            assetClass: const Value(AssetClass.multiAsset),
            valuationMethod: ValuationMethod.eventDriven,
            currency: Value(currency),
            intermediaryId: intermediaryId,
          ),
        );
  }

  group('T3a — F1 (PPP) into single eventDriven asset', () {
    test('cash-only contributes synthesize qty=amount, price=1.0', () async {
      final assetId = await createPensionAsset();
      final capped = await importer.parseFile(
        'test/fixtures/ppp/import.tsv',
        skipRows: 0,
        noHeader: true,
        numberLocale: 'it_IT',
      );
      final preview = await importer.getFullRows(capped, numberLocale: 'it_IT');

      // 5 columns: description, type, freq, period (MM/YYYY), amount.
      // No header → wizard-style synthetic names "Column 1".."Column 5".
      final result = await importer.importAssetEventsGrouped(
        preview: preview,
        mappings: const [
          ColumnMapping(sourceColumn: 'Column 4', targetField: 'date'),
          ColumnMapping(sourceColumn: 'Column 2', targetField: 'type'),
          ColumnMapping(sourceColumn: 'Column 5', targetField: 'amount'),
          ColumnMapping(sourceColumn: 'Column 1', targetField: 'description'),
        ],
        baseCurrency: 'EUR',
        intermediaryId: intermediaryId,
        targetAssetId: assetId,
        contributeValues: const {'C/TFR', 'C/Azienda', 'C/Iscritto'},
        revalueValues: const {'TOTALEP'},
        numberLocaleOverride: 'it_IT',
      );

      expect(result.result.errorRows, 0, reason: 'errors: ${result.result.errors}');

      final events = await (db.select(db.assetEvents)..orderBy([(e) => OrderingTerm.asc(e.valueDate)])).get();
      // PPP fixture: 105 contributes + 6 revalues = 111 rows total.
      expect(events.length, 111, reason: 'fixture has 111 rows, all should import');

      final contributes = events.where((e) => e.type == EventType.buy);
      final revalues = events.where((e) => e.type == EventType.revalue);
      expect(revalues, hasLength(6));
      expect(contributes, hasLength(105));

      // A3 auto-fill: every contribute has quantity=amount, price=1.0.
      for (final c in contributes) {
        expect(c.quantity, c.amount, reason: 'contribute qty must equal amount');
        expect(c.price, 1.0, reason: 'contribute price must be 1.0');
      }
      // Revalues have no quantity/price.
      for (final r in revalues) {
        expect(r.quantity, isNull);
        expect(r.price, isNull);
      }
    });

    test('latest revalue.amount matches synthetic year-end (23100.00)', () async {
      final assetId = await createPensionAsset();
      final capped = await importer.parseFile(
        'test/fixtures/ppp/import.tsv',
        skipRows: 0,
        noHeader: true,
        numberLocale: 'it_IT',
      );
      final preview = await importer.getFullRows(capped, numberLocale: 'it_IT');
      await importer.importAssetEventsGrouped(
        preview: preview,
        mappings: const [
          ColumnMapping(sourceColumn: 'Column 4', targetField: 'date'),
          ColumnMapping(sourceColumn: 'Column 2', targetField: 'type'),
          ColumnMapping(sourceColumn: 'Column 5', targetField: 'amount'),
        ],
        baseCurrency: 'EUR',
        intermediaryId: intermediaryId,
        targetAssetId: assetId,
        contributeValues: const {'C/TFR', 'C/Azienda', 'C/Iscritto'},
        revalueValues: const {'TOTALEP'},
        numberLocaleOverride: 'it_IT',
      );

      final eventService = AssetEventService(db);
      final latest = await eventService.getLatestRevalueAmount(assetId);
      expect(latest, isNotNull);
      expect(latest!, closeTo(23100.00, 0.01));

      // All six synthetic anchor revalues.
      final expected = <DateTime, double>{
        DateTime(2021, 12, 31): 1900.00,
        DateTime(2022, 12, 31): 6800.00,
        DateTime(2023, 12, 31): 11900.00,
        DateTime(2024, 12, 31): 17000.00,
        DateTime(2025, 12, 31): 22200.00,
        DateTime(2026, 2, 28): 23100.00,
      };
      for (final entry in expected.entries) {
        final r = await (db.select(
          db.assetEvents,
        )..where((e) => e.assetId.equals(assetId) & e.type.equalsValue(EventType.revalue) & e.valueDate.equals(entry.key))).getSingleOrNull();
        expect(r, isNotNull, reason: 'no revalue at ${entry.key}');
        expect(r!.amount, closeTo(entry.value, 0.01));
      }
    });
  });

  group('T3b — F2 (401(k)) ISIN-grouped, explicit qty/price', () {
    test('multi-sub-fund split + explicit unit pricing wins over auto-fill', () async {
      final capped = await importer.parseFile(
        'test/fixtures/pension/us_401k_sample.csv',
        numberLocale: 'en_US',
      );
      final preview = await importer.getFullRows(capped, numberLocale: 'en_US');
      final result = await importer.importAssetEventsGrouped(
        preview: preview,
        mappings: const [
          ColumnMapping(sourceColumn: 'date', targetField: 'date'),
          ColumnMapping(sourceColumn: 'bucket', targetField: 'type'),
          ColumnMapping(sourceColumn: 'fund_isin', targetField: 'isin'),
          ColumnMapping(sourceColumn: 'units', targetField: 'quantity'),
          ColumnMapping(sourceColumn: 'unit_price', targetField: 'price'),
          ColumnMapping(sourceColumn: 'amount', targetField: 'amount'),
          ColumnMapping(sourceColumn: 'description', targetField: 'description'),
        ],
        baseCurrency: 'USD',
        intermediaryId: intermediaryId,
        contributeValues: const {
          'employee_pretax',
          'employee_roth',
          'employer_match',
          'employer_nonelective',
          'rollover',
        },
        revalueValues: const {'position_snapshot'},
        numberLocaleOverride: 'en_US',
      );

      expect(result.result.errorRows, 0, reason: 'errors: ${result.result.errors}');

      // 3 unique ISINs → 3 assets created.
      final assets = await db.select(db.assets).get();
      expect(assets, hasLength(3));
      expect(
        assets.map((a) => a.isin),
        containsAll([
          'US9229087690',
          'US9229087443',
          'US922908769C',
        ]),
      );

      // Explicit qty/price on every contribute — A3 auto-fill must not
      // have synthesized 1.0 prices.
      final contribs = await (db.select(db.assetEvents)..where((e) => e.type.equalsValue(EventType.buy))).get();
      expect(contribs, isNotEmpty);
      for (final c in contribs) {
        expect(c.price, isNotNull);
        expect(c.price! > 1.0, isTrue, reason: 'real NAVs are >1; if price=1.0 the auto-fill misfired');
      }

      // 3 position-snapshot rows (one per sub-fund) → 3 revalue events.
      final revalues = await (db.select(db.assetEvents)..where((e) => e.type.equalsValue(EventType.revalue))).get();
      expect(revalues, hasLength(3));
    });
  });

  group('T3c — F3 (UK SIPP) contribute-only, no revalue', () {
    test('contribute-only import produces zero revalues, no market_prices', () async {
      final assetId = await createPensionAsset(currency: 'GBP');
      final capped = await importer.parseFile(
        'test/fixtures/pension/uk_sipp_summary.csv',
        numberLocale: 'en_GB',
      );
      final preview = await importer.getFullRows(capped, numberLocale: 'en_GB');
      final result = await importer.importAssetEventsGrouped(
        preview: preview,
        mappings: const [
          ColumnMapping(sourceColumn: 'date', targetField: 'date'),
          ColumnMapping(sourceColumn: 'bucket', targetField: 'type'),
          ColumnMapping(sourceColumn: 'amount', targetField: 'amount'),
          ColumnMapping(sourceColumn: 'description', targetField: 'description'),
        ],
        baseCurrency: 'GBP',
        intermediaryId: intermediaryId,
        targetAssetId: assetId,
        contributeValues: const {'employee_contribution', 'tax_relief'},
        // No revalueValues — there are no position rows in F3.
        numberLocaleOverride: 'en_GB',
      );

      expect(result.result.errorRows, 0);

      final events = await db.select(db.assetEvents).get();
      expect(events, hasLength(8)); // 4 employee + 4 tax_relief
      expect(events.every((e) => e.type == EventType.buy), isTrue);

      // No revalues → no market_prices rows materialized.
      final prices = await (db.select(db.marketPrices)..where((p) => p.assetId.equals(assetId))).get();
      expect(prices, isEmpty);

      // Every contribute auto-filled qty=amount, price=1.0 (eventDriven asset).
      for (final c in events) {
        expect(c.quantity, c.amount);
        expect(c.price, 1.0);
      }
    });
  });

  group('T4 — Idempotency: re-import inserts 0 net new rows', () {
    test('PPP re-import is a no-op (wipe+replace under targetAssetId)', () async {
      final assetId = await createPensionAsset();

      Future<void> importPPP() async {
        final capped = await importer.parseFile(
          'test/fixtures/ppp/import.tsv',
          skipRows: 0,
          noHeader: true,
          numberLocale: 'it_IT',
        );
        final preview = await importer.getFullRows(capped, numberLocale: 'it_IT');
        await importer.importAssetEventsGrouped(
          preview: preview,
          mappings: const [
            ColumnMapping(sourceColumn: 'Column 4', targetField: 'date'),
            ColumnMapping(sourceColumn: 'Column 2', targetField: 'type'),
            ColumnMapping(sourceColumn: 'Column 5', targetField: 'amount'),
          ],
          baseCurrency: 'EUR',
          intermediaryId: intermediaryId,
          targetAssetId: assetId,
          contributeValues: const {'C/TFR', 'C/Azienda', 'C/Iscritto'},
          revalueValues: const {'TOTALEP'},
          numberLocaleOverride: 'it_IT',
        );
      }

      await importPPP();
      final firstCount = (await db.select(db.assetEvents).get()).length;
      expect(firstCount, 111);

      await importPPP();
      final secondCount = (await db.select(db.assetEvents).get()).length;
      expect(secondCount, 111, reason: 'second import wipes+replaces, no net change');
    });
  });

  group('revalueAmountColumn — per-type amount source', () {
    test('Revalue rows read amount from the override column (Saldo), '
        'contributions still read the primary amount column (Entrate)', () async {
      final assetId = await createPensionAsset();
      // Two contributions (value in Entrate, Saldo empty) and one position
      // snapshot (Entrate empty, value in Saldo). Mirrors a PPP statement.
      final preview = FilePreview(
        columns: const ['Periodo', 'Operazione', 'Entrate', 'Saldo'],
        rows: const [
          {'Periodo': '01/2026', 'Operazione': 'C/Azienda', 'Entrate': '358,35', 'Saldo': ''},
          {'Periodo': '01/2026', 'Operazione': 'C/TFR', 'Entrate': '428,42', 'Saldo': ''},
          {'Periodo': '05/2026', 'Operazione': 'POSIZIONE INDIVIDUALE', 'Entrate': '', 'Saldo': '52.610,23'},
        ],
        totalRows: 3,
      );

      final result = await importer.importAssetEventsGrouped(
        preview: preview,
        mappings: const [
          ColumnMapping(sourceColumn: 'Periodo', targetField: 'date'),
          ColumnMapping(sourceColumn: 'Operazione', targetField: 'type'),
          ColumnMapping(sourceColumn: 'Entrate', targetField: 'amount'),
        ],
        baseCurrency: 'EUR',
        intermediaryId: intermediaryId,
        targetAssetId: assetId,
        buyValues: const {'C/Azienda', 'C/TFR'},
        revalueValues: const {'POSIZIONE INDIVIDUALE'},
        revalueAmountColumn: 'Saldo',
        numberLocaleOverride: 'it_IT',
      );

      expect(result.result.errorRows, 0, reason: 'errors: ${result.result.errors}');

      final events = await (db.select(db.assetEvents)..orderBy([(e) => OrderingTerm.asc(e.valueDate)])).get();
      final buys = events.where((e) => e.type == EventType.buy).toList();
      final revalues = events.where((e) => e.type == EventType.revalue).toList();

      expect(buys, hasLength(2));
      expect(buys.map((b) => b.amount).toList(), [358.35, 428.42], reason: 'buys keep Entrate values');

      expect(revalues, hasLength(1));
      expect(revalues.single.amount, 52610.23, reason: 'revalue amount comes from Saldo, not the empty Entrate');
    });

    test('without revalueAmountColumn, a Revalue row with empty primary '
        'amount is skipped as an error (not silently zeroed)', () async {
      final assetId = await createPensionAsset();
      final preview = FilePreview(
        columns: const ['Periodo', 'Operazione', 'Entrate', 'Saldo'],
        rows: const [
          {'Periodo': '01/2026', 'Operazione': 'C/Azienda', 'Entrate': '358,35', 'Saldo': ''},
          {'Periodo': '05/2026', 'Operazione': 'POSIZIONE INDIVIDUALE', 'Entrate': '', 'Saldo': '52.610,23'},
        ],
        totalRows: 2,
      );

      final result = await importer.importAssetEventsGrouped(
        preview: preview,
        mappings: const [
          ColumnMapping(sourceColumn: 'Periodo', targetField: 'date'),
          ColumnMapping(sourceColumn: 'Operazione', targetField: 'type'),
          ColumnMapping(sourceColumn: 'Entrate', targetField: 'amount'),
        ],
        baseCurrency: 'EUR',
        intermediaryId: intermediaryId,
        targetAssetId: assetId,
        buyValues: const {'C/Azienda'},
        revalueValues: const {'POSIZIONE INDIVIDUALE'},
        // No revalueAmountColumn.
        numberLocaleOverride: 'it_IT',
      );

      // The revalue row's primary (Entrate) amount is empty → strict parse
      // throws → the row is skipped as an error. This is exactly the
      // "Skipped 1" behavior that motivated the override.
      expect(result.result.errorRows, 1);
      final revalues = await (db.select(db.assetEvents)..where((e) => e.type.equalsValue(EventType.revalue))).get();
      expect(revalues, isEmpty, reason: 'errored revalue row is not stored');
    });

    test('dry-run preview surfaces the empty-date Revalue error (so the user '
        'can fix it before importing)', () async {
      final assetId = await createPensionAsset();
      final preview = FilePreview(
        columns: const ['Data Breve', 'Operazione', 'Entrate', 'Saldo'],
        rows: const [
          {'Data Breve': '01/2026', 'Operazione': 'C/Azienda', 'Entrate': '358,35', 'Saldo': ''},
          // Revalue row with an EMPTY date (snapshot period was stripped).
          {'Data Breve': '', 'Operazione': 'POSIZIONE INDIVIDUALE', 'Entrate': '', 'Saldo': '52.610,23'},
        ],
        totalRows: 2,
      );

      final result = await importer.previewAssetEventImport(
        preview: preview,
        mappings: const [
          ColumnMapping(sourceColumn: 'Data Breve', targetField: 'date'),
          ColumnMapping(sourceColumn: 'Operazione', targetField: 'type'),
          ColumnMapping(sourceColumn: 'Entrate', targetField: 'amount'),
        ],
        targetAssetId: assetId,
        buyValues: const {'C/Azienda'},
        revalueValues: const {'POSIZIONE INDIVIDUALE'},
        revalueAmountColumn: 'Saldo',
        numberLocale: 'it_IT',
      );

      // The empty-date revalue row must be reported as an error in the
      // PREVIEW (not silently passed through to fail only at import time).
      expect(result.errorRows, 1, reason: 'preview must predict the empty-date failure');
      expect(result.errors.any((e) => e.contains('date')), isTrue, reason: 'errors: ${result.errors}');
      // The valid contribution still parses.
      expect(result.parsedRows, 1);
    });
  });
}
