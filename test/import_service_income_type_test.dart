import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/import/import_service.dart';

/// Income import type resolution.
///
/// The old heuristic classified a row as [IncomeType.refund] when the type
/// text contained "rimborso"/"refund". That keyword guess has been removed:
/// income type now comes ONLY from explicit wizard-chip tags
/// (`incomeValues` / `refundValues` / `pensionContributionValues`). These
/// tests pin the new explicit behavior.
void main() {
  late AppDatabase db;
  late ImportService importer;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = ImportService(db);
    tempDir = Directory.systemTemp.createTempSync('income_type_test_');
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<FilePreview> previewCsv(String content) {
    final file = File('${tempDir.path}/income.csv')..writeAsStringSync(content);
    return importer.parseFile(file.path);
  }

  group('importIncomes type resolution (no keyword guessing)', () {
    test('no type column → every row is plain income', () async {
      final preview = await previewCsv('''
Date,Amount
15/01/2025,3500.00
15/02/2025,3500.00
''');
      final result = await importer.importIncomes(
        preview: preview,
        mappings: const [
          ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
          ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
        ],
        defaultCurrency: 'EUR',
      );
      expect(result.importedRows, 2);
      final rows = await db.select(db.incomes).get();
      expect(rows, hasLength(2));
      expect(rows.every((r) => r.type == IncomeType.income), isTrue);
    });

    test('text "Rimborso" is NOT auto-classified as refund without a tag', () async {
      // Pins removal of the old heuristic: the word "Rimborso" alone must not
      // produce a refund. With the value tagged as income, it is income.
      final preview = await previewCsv('''
Date,Amount,Tipo
15/01/2025,3500.00,Stipendio
20/01/2025,275.00,Rimborso
''');
      final result = await importer.importIncomes(
        preview: preview,
        mappings: const [
          ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
          ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
          ColumnMapping(sourceColumn: 'Tipo', targetField: 'type'),
        ],
        defaultCurrency: 'EUR',
        incomeValues: const {'Stipendio', 'Rimborso'},
      );
      expect(result.importedRows, 2);
      final rows = await db.select(db.incomes).get();
      expect(
        rows.every((r) => r.type == IncomeType.income),
        isTrue,
        reason: '"Rimborso" tagged as income must stay income — no keyword override',
      );
    });

    test('tagged values resolve to refund and pension contribution', () async {
      final preview = await previewCsv('''
Date,Amount,Tipo
15/01/2025,3500.00,Stipendio
20/01/2025,275.00,Rimborso
31/01/2025,150.00,Contributo
''');
      final result = await importer.importIncomes(
        preview: preview,
        mappings: const [
          ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
          ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
          ColumnMapping(sourceColumn: 'Tipo', targetField: 'type'),
        ],
        defaultCurrency: 'EUR',
        incomeValues: const {'Stipendio'},
        refundValues: const {'Rimborso'},
        pensionContributionValues: const {'Contributo'},
      );
      expect(result.importedRows, 3);
      final rows = await db.select(db.incomes).get()
        ..sort((a, b) => a.amount.compareTo(b.amount));
      // 150 Contributo, 275 Rimborso, 3500 Stipendio
      expect(rows[0].type, IncomeType.pensionContribution);
      expect(rows[1].type, IncomeType.refund);
      expect(rows[2].type, IncomeType.income);
    });

    test('matching is normalized (case + spaces)', () async {
      final preview = await previewCsv('''
Date,Amount,Tipo
20/01/2025,275.00,rimborso spesa
''');
      final result = await importer.importIncomes(
        preview: preview,
        mappings: const [
          ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
          ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
          ColumnMapping(sourceColumn: 'Tipo', targetField: 'type'),
        ],
        defaultCurrency: 'EUR',
        refundValues: const {'RIMBORSO SPESA'},
      );
      expect(result.importedRows, 1);
      final rows = await db.select(db.incomes).get();
      expect(rows.single.type, IncomeType.refund);
    });

    test('untagged value with a type column fails loudly (row skipped)', () async {
      final preview = await previewCsv('''
Date,Amount,Tipo
15/01/2025,3500.00,Stipendio
20/01/2025,275.00,Bonifico
''');
      final result = await importer.importIncomes(
        preview: preview,
        mappings: const [
          ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
          ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
          ColumnMapping(sourceColumn: 'Tipo', targetField: 'type'),
        ],
        defaultCurrency: 'EUR',
        incomeValues: const {'Stipendio'},
      );
      // "Bonifico" is untagged → its row fails (no silent fallback to income).
      expect(result.importedRows, 1);
      expect(result.errorRows, 1);
      final rows = await db.select(db.incomes).get();
      expect(rows.single.type, IncomeType.income);
    });
  });
}
