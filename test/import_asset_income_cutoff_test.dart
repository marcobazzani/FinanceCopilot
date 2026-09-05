// Regression: a partial pension re-import (e.g. importing March alone
// after Jan+Feb were already imported) must preserve older
// pension-contribution INCOME rows, not just the asset events.
//
// `importAssetEventsGrouped`'s asset-event wipe is scoped to a date
// cutoff (only events `date >= cutoff` are replaced), but its mirrored
// pension-contribution income wipe deleted EVERY income row for the
// asset regardless of that cutoff — so a later partial import silently
// erased earlier months' contribution history from the income ledger
// even though the corresponding asset events were left untouched.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/import/import_service.dart';

void main() {
  late AppDatabase db;
  late ImportService importer;
  late int intermediaryId;
  late int assetId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = ImportService(db);
    intermediaryId = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    assetId = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'Pension',
            assetType: AssetType.pension,
            valuationMethod: ValuationMethod.eventDriven,
            intermediaryId: intermediaryId,
          ),
        );
  });

  tearDown(() => db.close());

  Future<void> importRows(List<Map<String, String>> rows) async {
    final preview = FilePreview(columns: const ['date', 'type', 'amount'], rows: rows, totalRows: rows.length, numberLocale: 'en_US');
    final result = await importer.importAssetEventsGrouped(
      preview: preview,
      mappings: const [
        ColumnMapping(targetField: 'date', sourceColumn: 'date'),
        ColumnMapping(targetField: 'type', sourceColumn: 'type'),
        ColumnMapping(targetField: 'amount', sourceColumn: 'amount'),
      ],
      baseCurrency: 'EUR',
      intermediaryId: intermediaryId,
      targetAssetId: assetId,
      contributeValues: const {'contribution'},
      revalueValues: const {'revalue'},
      numberLocaleOverride: 'en_US',
    );
    expect(result.result.errorRows, 0, reason: 'errors: ${result.result.errors}');
  }

  test('importing March alone preserves January and February contribution income rows', () async {
    await importRows([
      {'date': '2026-01-01', 'type': 'contribution', 'amount': '100'},
      {'date': '2026-02-01', 'type': 'contribution', 'amount': '100'},
      {'date': '2026-02-28', 'type': 'revalue', 'amount': '210'},
    ]);
    expect(await db.select(db.incomes).get(), hasLength(2), reason: 'Jan + Feb contributions mirrored as income');

    await importRows([
      {'date': '2026-03-01', 'type': 'contribution', 'amount': '100'},
      {'date': '2026-03-31', 'type': 'revalue', 'amount': '320'},
    ]);

    final events = await db.select(db.assetEvents).get();
    expect(events.where((e) => e.type == EventType.buy), hasLength(3), reason: 'Jan/Feb/Mar contributions all present');

    final incomes = await db.select(db.incomes).get();
    expect(incomes, hasLength(3), reason: 'Jan/Feb income mirrors must survive a March-only re-import');
    expect(incomes.map((i) => i.date.month).toList()..sort(), [1, 2, 3]);
  });

  test('re-importing the same month is idempotent (no duplicate income rows)', () async {
    Future<void> importJanuary() => importRows([
      {'date': '2026-01-01', 'type': 'contribution', 'amount': '100'},
      {'date': '2026-01-31', 'type': 'revalue', 'amount': '100'},
    ]);

    await importJanuary();
    await importJanuary();

    expect(await db.select(db.incomes).get(), hasLength(1), reason: 'second import of the same month replaces, not duplicates');
  });
}
