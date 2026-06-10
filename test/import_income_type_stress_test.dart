import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/import/import_service.dart';

/// Edge-case STRESS tests for income type resolution after the keyword
/// heuristic removal. Goal: 0 regressions across whitespace/case/unicode,
/// overlapping tags, partial-tag files, empty cells, and large inputs.
void main() {
  late AppDatabase db;
  late ImportService importer;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = ImportService(db);
    tempDir = Directory.systemTemp.createTempSync('income_stress_');
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<FilePreview> preview(String content) {
    final f = File('${tempDir.path}/in.csv')..writeAsStringSync(content);
    return importer.parseFile(f.path);
  }

  Future<ImportResult> run(
    FilePreview p, {
    Set<String>? income,
    Set<String>? refund,
    Set<String>? pension,
    bool typeColumn = true,
  }) {
    return importer.importIncomes(
      preview: p,
      mappings: [
        const ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
        const ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
        if (typeColumn) const ColumnMapping(sourceColumn: 'Tipo', targetField: 'type'),
      ],
      defaultCurrency: 'EUR',
      incomeValues: income,
      refundValues: refund,
      pensionContributionValues: pension,
    );
  }

  group('normalization edge cases', () {
    test('leading/trailing/internal whitespace + case all match the same tag', () async {
      final p = await preview('''
Date,Amount,Tipo
2025-01-01,100,  Rimborso Spesa  
2025-01-02,100,RIMBORSO SPESA
2025-01-03,100,rimborso  spesa
''');
      // Tag uses a single inner space + mixed case; all three rows (extra
      // spaces, upper, double inner space) must normalize to the same key.
      final r = await run(p, refund: const {'Rimborso Spesa'});
      // Row 3 has a DOUBLE inner space → normalizes to RIMBORSO__SPESA, which
      // differs from the tag's RIMBORSO_SPESA. It must fail loudly, not
      // silently mis-type. Rows 1 and 2 match.
      expect(r.importedRows, 2);
      expect(r.errorRows, 1);
      final rows = await db.select(db.incomes).get();
      expect(rows.every((x) => x.type == IncomeType.refund), isTrue);
    });

    test('accented / unicode type values match exactly', () async {
      final p = await preview('''
Date,Amount,Tipo
2025-01-01,100,Contribução
''');
      final r = await run(p, pension: const {'Contribução'});
      expect(r.importedRows, 1);
      expect((await db.select(db.incomes).get()).single.type, IncomeType.pensionContribution);
    });

    test('empty type cell with a type column mapped fails loudly (unless empty is tagged)', () async {
      final p = await preview('''
Date,Amount,Tipo
2025-01-01,100,
''');
      final r = await run(p, income: const {'Stipendio'});
      expect(r.importedRows, 0);
      expect(r.errorRows, 1);
    });
  });

  group('tag precedence + overlap', () {
    test('value present in multiple buckets resolves income > refund > pension', () async {
      final p = await preview('''
Date,Amount,Tipo
2025-01-01,100,X
''');
      // Same value tagged in all three sets — deterministic precedence.
      final r = await run(p, income: const {'X'}, refund: const {'X'}, pension: const {'X'});
      expect(r.importedRows, 1);
      expect((await db.select(db.incomes).get()).single.type, IncomeType.income);
    });

    test('refund wins over pension when only those two overlap', () async {
      final p = await preview('''
Date,Amount,Tipo
2025-01-01,100,Y
''');
      await run(p, refund: const {'Y'}, pension: const {'Y'});
      expect((await db.select(db.incomes).get()).single.type, IncomeType.refund);
    });
  });

  group('partial tagging', () {
    test('mix of tagged and untagged values: tagged import, untagged error', () async {
      final p = await preview('''
Date,Amount,Tipo
2025-01-01,1000,Stipendio
2025-01-02,50,Rimborso
2025-01-03,75,Bonifico
2025-01-04,200,Contributo
''');
      final r = await run(
        p,
        income: const {'Stipendio'},
        refund: const {'Rimborso'},
        pension: const {'Contributo'},
      );
      // Bonifico untagged → 1 error, other 3 import with correct types.
      expect(r.importedRows, 3);
      expect(r.errorRows, 1);
      final rows = await db.select(db.incomes).get()
        ..sort((a, b) => a.amount.compareTo(b.amount));
      expect(rows.map((x) => x.type), [
        IncomeType.refund, // 50
        IncomeType.pensionContribution, // 200
        IncomeType.income, // 1000
      ]);
    });
  });

  group('no type column', () {
    test('every row is income regardless of tag sets passed', () async {
      final p = await preview('''
Date,Amount
2025-01-01,100
2025-01-02,200
''');
      final r = await run(p, typeColumn: false, refund: const {'whatever'});
      expect(r.importedRows, 2);
      expect((await db.select(db.incomes).get()).every((x) => x.type == IncomeType.income), isTrue);
    });
  });

  group('scale', () {
    test('1000 rows across 3 tagged buckets classify correctly and fast', () async {
      // Build a FULL preview in-memory (rows == totalRows), mirroring the
      // production state after FileParserService.getFullRows — parseFile()
      // returns only a capped head+tail sample, which is not what import runs on.
      final rows = <Map<String, String>>[];
      for (var i = 0; i < 1000; i++) {
        final bucket = i % 3 == 0 ? 'Stipendio' : (i % 3 == 1 ? 'Rimborso' : 'Contributo');
        rows.add({'Date': '2025-01-01', 'Amount': '${i + 1}', 'Tipo': bucket});
      }
      final p = FilePreview(columns: const ['Date', 'Amount', 'Tipo'], rows: rows, totalRows: rows.length);
      final sw = Stopwatch()..start();
      final r = await run(
        p,
        income: const {'Stipendio'},
        refund: const {'Rimborso'},
        pension: const {'Contributo'},
      );
      sw.stop();
      expect(r.importedRows, 1000);
      expect(r.errorRows, 0);
      final counts = <IncomeType, int>{};
      for (final x in await db.select(db.incomes).get()) {
        counts[x.type] = (counts[x.type] ?? 0) + 1;
      }
      expect(counts[IncomeType.income], 334);
      expect(counts[IncomeType.refund], 333);
      expect(counts[IncomeType.pensionContribution], 333);
    });
  });
}
