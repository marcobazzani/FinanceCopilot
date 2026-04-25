import 'dart:io';

import 'package:drift/native.dart';
import 'package:excel/excel.dart' as xl;
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/import_service.dart';

/// Pins the bug from 2026-04-25: import preview and the actual import must
/// agree on amounts regardless of the user's number locale, and integer/
/// double mixed XLSX cells must round-trip correctly. The latent bugs were:
///
///   1. `_xlsCellToString` emitted doubles via `toString()` (always `.`
///      decimal). With `it_IT` locale, `parseAmount` then re-read `.` as
///      thousands separator, multiplying values by 100/1000.
///   2. `_evaluateFormula` and `_resolveMultiColumn` returned
///      `result.toString()` (also always `.` decimal). Same misparse.
///
/// Both paths now format via `NumberFormat.decimalPattern(locale)`.
void main() {
  late AppDatabase db;
  late ImportService importer;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = ImportService(db);
    tempDir = Directory.systemTemp.createTempSync('import_roundtrip_');
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Writes a Fineco-shaped XLSX: Data_Operazione, Data_Valuta, Entrate,
  /// Uscite, Descrizione. Mixed integer/double cells just like the real
  /// bank exports — the bug only fires on this exact mix.
  File writeXlsx(String name, List<Map<String, dynamic>> rows) {
    final excel = xl.Excel.createExcel();
    // Excel.createExcel seeds an empty 'Sheet1'. We must reuse it (or
    // delete it) — otherwise parseFile picks 'Sheet1' (empty) over our
    // populated sheet because it reads `tables.values.first`.
    final sheet = excel[excel.getDefaultSheet()!];
    sheet.appendRow([
      xl.TextCellValue('Data_Operazione'),
      xl.TextCellValue('Data_Valuta'),
      xl.TextCellValue('Entrate'),
      xl.TextCellValue('Uscite'),
      xl.TextCellValue('Descrizione'),
    ]);
    for (final r in rows) {
      xl.CellValue? num(dynamic v) {
        if (v == null) return null;
        if (v is int) return xl.IntCellValue(v);
        if (v is double) return xl.DoubleCellValue(v);
        return xl.TextCellValue(v.toString());
      }
      sheet.appendRow([
        xl.TextCellValue(r['date'] as String),
        xl.TextCellValue(r['valueDate'] as String),
        num(r['entrate']),
        num(r['uscite']),
        xl.TextCellValue(r['descrizione'] as String),
      ]);
    }
    final bytes = excel.encode()!;
    final file = File('${tempDir.path}/$name');
    file.writeAsBytesSync(bytes);
    return file;
  }

  Future<int> seedAccount(String name) =>
      db.into(db.accounts).insert(AccountsCompanion.insert(name: name));

  /// Build the Fineco mappings: amount = Entrate + Uscite (formula).
  List<ColumnMapping> finecoMappings() => [
        ColumnMapping(targetField: 'date', sourceColumn: 'Data_Operazione'),
        ColumnMapping(targetField: 'valueDate', sourceColumn: 'Data_Valuta'),
        ColumnMapping(
          targetField: 'amount',
          sourceColumn: '',
          formulaTerms: const [
            FormulaTerm(operator: '+', sourceColumn: 'Entrate'),
            FormulaTerm(operator: '+', sourceColumn: 'Uscite'),
          ],
        ),
        ColumnMapping(targetField: 'description', sourceColumn: 'Descrizione'),
      ];

  /// Returns (preview sum, imported sum, imported count) for the given
  /// XLSX file under the given locale. Uses the *same* code paths the UI
  /// would, so any divergence between preview and import is a real bug.
  Future<(double, double, int)> previewAndImport({
    required File file,
    required int accountId,
    required String? numberLocale,
    String? appLocale,
  }) async {
    final preview = await importer.parseFile(file.path, numberLocale: numberLocale);
    final mappings = finecoMappings();
    final pv = await importer.previewTransactionImport(
      preview: preview,
      mappings: mappings,
      accountId: accountId,
      numberLocale: numberLocale,
      appLocale: appLocale,
    );
    await importer.importTransactions(
      preview: preview,
      mappings: mappings,
      accountId: accountId,
      numberLocaleOverride: numberLocale,
      appLocale: appLocale,
    );
    final txns = await db.select(db.transactions).get();
    final importedSum = txns.fold<double>(0, (a, t) => a + t.amount);
    return (pv.importSum, importedSum, txns.length);
  }

  group('Locale round-trip — preview ≡ import', () {
    // Real Fineco rows from the user's 2026-04-25 export. Mixes
    // IntCellValue (-500, -45925) with DoubleCellValue (-40.1, 7707.97).
    final finecoRows = [
      {'date': '20/04/2026', 'valueDate': '20/04/2026', 'entrate': null, 'uscite': -45925, 'descrizione': 'Bonifico SEPA'},
      {'date': '20/04/2026', 'valueDate': '18/04/2026', 'entrate': null, 'uscite': -500, 'descrizione': 'Visa Debit'},
      {'date': '10/04/2026', 'valueDate': '31/03/2026', 'entrate': null, 'uscite': -40.1, 'descrizione': 'Bollo dossier'},
      {'date': '01/04/2026', 'valueDate': '31/03/2026', 'entrate': null, 'uscite': -8.43, 'descrizione': 'Bollo conto'},
      {'date': '31/03/2026', 'valueDate': '31/03/2026', 'entrate': 7707.97, 'uscite': null, 'descrizione': 'Stipendio'},
      {'date': '31/03/2026', 'valueDate': '31/03/2026', 'entrate': 6.95, 'uscite': null, 'descrizione': 'Sconto canone'},
      {'date': '31/03/2026', 'valueDate': '31/03/2026', 'entrate': null, 'uscite': -6.95, 'descrizione': 'Canone'},
    ];
    const expectedSum = -45925 - 500 - 40.1 - 8.43 + 7707.97 + 6.95 - 6.95;

    for (final locale in const [null, 'it_IT', 'en_US', 'de_DE', 'fr_FR']) {
      test('Fineco-shape XLSX, locale=${locale ?? "auto/it_IT"}', () async {
        final accountId = await seedAccount('Fineco-${locale ?? 'auto'}');
        final file = writeXlsx('fineco_${locale ?? 'auto'}.xlsx', finecoRows);
        final (previewSum, importedSum, count) = await previewAndImport(
          file: file,
          accountId: accountId,
          numberLocale: locale,
          appLocale: 'it_IT', // simulates an it_IT user (the bug condition)
        );
        expect(count, finecoRows.length, reason: 'all rows imported');
        expect(previewSum, closeTo(expectedSum, 0.01),
            reason: 'preview sum must match real cell math, locale=$locale');
        expect(importedSum, closeTo(expectedSum, 0.01),
            reason: 'imported sum must match real cell math, locale=$locale');
        expect(previewSum, closeTo(importedSum, 0.01),
            reason: 'preview ≡ import, locale=$locale');
      });
    }

    test('European-formatted CSV (semicolon, comma decimal)', () async {
      // Fineco-style CSV with European number formatting.
      final file = File('${tempDir.path}/fineco_eu.csv')
        ..writeAsStringSync(
          'Data_Operazione;Data_Valuta;Entrate;Uscite;Descrizione\n'
          '20/04/2026;20/04/2026;;-459,25;Bonifico\n'
          '20/04/2026;18/04/2026;;-5,00;Visa\n'
          '10/04/2026;31/03/2026;;-40,10;Bollo\n'
          '31/03/2026;31/03/2026;7.707,97;;Stipendio\n',
        );
      final accountId = await seedAccount('FinecoCsvEu');
      final (previewSum, importedSum, count) = await previewAndImport(
        file: file,
        accountId: accountId,
        numberLocale: 'it_IT',
        appLocale: 'it_IT',
      );
      const expected = -459.25 - 5.00 - 40.10 + 7707.97;
      expect(count, 4);
      expect(previewSum, closeTo(expected, 0.01));
      expect(importedSum, closeTo(expected, 0.01));
      expect(previewSum, closeTo(importedSum, 0.01));
    });

    test('US-formatted CSV (comma, dot decimal)', () async {
      final file = File('${tempDir.path}/fineco_us.csv')
        ..writeAsStringSync(
          'Data_Operazione,Data_Valuta,Entrate,Uscite,Descrizione\n'
          '20/04/2026,20/04/2026,,"-459.25",Bonifico\n'
          '20/04/2026,18/04/2026,,"-5.00",Visa\n'
          '10/04/2026,31/03/2026,,"-40.10",Bollo\n'
          '31/03/2026,31/03/2026,"7,707.97",,Stipendio\n',
        );
      final accountId = await seedAccount('FinecoCsvUs');
      final (previewSum, importedSum, count) = await previewAndImport(
        file: file,
        accountId: accountId,
        numberLocale: 'en_US',
        appLocale: 'en_US',
      );
      const expected = -459.25 - 5.00 - 40.10 + 7707.97;
      expect(count, 4);
      expect(previewSum, closeTo(expected, 0.01));
      expect(importedSum, closeTo(expected, 0.01));
      expect(previewSum, closeTo(importedSum, 0.01));
    });

    test('multi-column description sum (numeric) round-trips under it_IT', () async {
      // Two numeric columns combined via __multi: tests _resolveMultiColumn,
      // which previously also leaked dot-decimal back into parseAmount.
      final file = writeXlsx('multi.xlsx', [
        {'date': '01/01/2026', 'valueDate': '01/01/2026', 'entrate': 100.5, 'uscite': 50.25, 'descrizione': 'A'},
      ]);
      final accountId = await seedAccount('Multi');
      final preview = await importer.parseFile(file.path, numberLocale: 'it_IT');
      final mappings = [
        ColumnMapping(targetField: 'date', sourceColumn: 'Data_Operazione'),
        ColumnMapping(targetField: 'valueDate', sourceColumn: 'Data_Valuta'),
        // amount = sum of (Entrate, Uscite) via multi-column mode
        ColumnMapping(
          targetField: 'amount',
          sourceColumn: '',
          multiColumns: const ['Entrate', 'Uscite'],
          multiDelimiter: ' ',
        ),
        ColumnMapping(targetField: 'description', sourceColumn: 'Descrizione'),
      ];
      final pv = await importer.previewTransactionImport(
        preview: preview, mappings: mappings, accountId: accountId,
        numberLocale: 'it_IT', appLocale: 'it_IT',
      );
      await importer.importTransactions(
        preview: preview, mappings: mappings, accountId: accountId,
        numberLocaleOverride: 'it_IT', appLocale: 'it_IT',
      );
      final txns = await db.select(db.transactions).get();
      const expected = 100.5 + 50.25;
      expect(pv.importSum, closeTo(expected, 0.01));
      expect(txns.first.amount, closeTo(expected, 0.01));
    });
  });
}
