import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/import_service.dart';

void main() {
  late AppDatabase db;
  late ImportService importer;
  late Directory tempDir;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = ImportService(db);
    tempDir = Directory.systemTemp.createTempSync('import_test_');
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  File writeCsv(String name, String content) {
    final file = File('${tempDir.path}/$name');
    file.writeAsStringSync(content);
    return file;
  }

  group('CSV parsing', () {
    test('parse comma-separated CSV', () async {
      final file = writeCsv('test.csv', '''
Date,Amount,Description
15/01/2024,-42.50,Supermarket
16/01/2024,1500.00,Salary
''');
      final preview = await importer.parseFile(file.path);
      expect(preview.columns, ['Date', 'Amount', 'Description']);
      expect(preview.rows, hasLength(2));
      expect(preview.rows[0]['Date'], '15/01/2024');
      expect(preview.rows[0]['Amount'], '-42.50');
      expect(preview.rows[1]['Description'], 'Salary');
    });

    test('parse semicolon-separated CSV (European)', () async {
      final file = writeCsv('test.csv', '''
Data_Operazione;Data_Valuta;Entrate;Uscite;Descrizione
15/01/2024;15/01/2024;;42.50;Supermercato
16/01/2024;16/01/2024;1500.00;;Stipendio
''');
      final preview = await importer.parseFile(file.path);
      expect(preview.columns, ['Data_Operazione', 'Data_Valuta', 'Entrate', 'Uscite', 'Descrizione']);
      expect(preview.rows, hasLength(2));
      expect(preview.rows[0]['Descrizione'], 'Supermercato');
    });
  });

  group('Transaction import', () {
    test('import CSV as transactions', () async {
      final accountId = await db.into(db.accounts).insert(
        AccountsCompanion.insert(name: 'Fineco'),
      );

      final file = writeCsv('fineco.csv', '''
Date,Amount,Description,Extra
15/01/2024,-42.50,Supermarket,some extra data
16/01/2024,1500.00,Salary,more extra
''');
      final preview = await importer.parseFile(file.path);

      final result = await importer.importTransactions(
        preview: preview,
        mappings: [
          const ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
          const ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
          const ColumnMapping(sourceColumn: 'Description', targetField: 'description'),
        ],
        accountId: accountId,
      );

      expect(result.importedRows, 2);
      expect(result.errorRows, 0);

      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(2));
      expect(txs[0].amount, -42.50);
      expect(txs[0].description, 'Supermarket');
      // importHash is no longer set for transactions (date-based replace instead)

      // raw_metadata should contain unmapped 'Extra' column
      expect(txs[0].rawMetadata, contains('Extra'));
      expect(txs[0].rawMetadata, contains('some extra data'));
    });

    test('re-importing same file replaces rows cleanly', () async {
      final accountId = await db.into(db.accounts).insert(
        AccountsCompanion.insert(name: 'Fineco'),
      );

      final file = writeCsv('fineco.csv', '''
Date,Amount,Description
15/01/2024,-42.50,Supermarket
16/01/2024,1500.00,Salary
''');
      final preview = await importer.parseFile(file.path);
      final mappings = [
        const ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
        const ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
        const ColumnMapping(sourceColumn: 'Description', targetField: 'description'),
      ];

      // First import
      await importer.importTransactions(preview: preview, mappings: mappings, accountId: accountId);

      // Second import (same data) — deletes from oldest date, re-inserts
      final result2 = await importer.importTransactions(preview: preview, mappings: mappings, accountId: accountId);
      expect(result2.importedRows, 2);
      expect(result2.deletedRows, 2);

      // Still only 2 rows in DB
      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(2));
    });

    test('partial re-import: overlapping rows replaced, earlier rows kept', () async {
      final accountId = await db.into(db.accounts).insert(
        AccountsCompanion.insert(name: 'Revolut'),
      );

      // First import: 3 rows spanning Jan-Feb
      final file1 = writeCsv('rev1.csv', '''
Date,Amount,Desc
15/01/2024,-10.00,Coffee
01/02/2024,-20.00,Lunch
02/02/2024,-30.00,Dinner
''');
      final preview1 = await importer.parseFile(file1.path);
      await importer.importTransactions(
        preview: preview1,
        mappings: [
          const ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
          const ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
          const ColumnMapping(sourceColumn: 'Desc', targetField: 'description'),
        ],
        accountId: accountId,
      );
      expect((await db.select(db.transactions).get()).length, 3);

      // Second import: 2 rows from Feb onward (deletes Feb rows, keeps Jan)
      final file2 = writeCsv('rev2.csv', '''
Date,Amount,Desc
01/02/2024,-20.00,Lunch updated
03/02/2024,-15.00,Brunch
''');
      final preview2 = await importer.parseFile(file2.path);
      final result = await importer.importTransactions(
        preview: preview2,
        mappings: [
          const ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
          const ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
          const ColumnMapping(sourceColumn: 'Desc', targetField: 'description'),
        ],
        accountId: accountId,
      );

      expect(result.importedRows, 2);
      expect(result.deletedRows, 2); // Feb 1 + Feb 2 deleted

      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(3)); // Jan 15 kept + Feb 1 + Feb 3 inserted
    });
  });

  group('Date parsing', () {
    test('handles dd/MM/yyyy format', () async {
      final file = writeCsv('dates.csv', '''
Date,Amount
15/01/2024,-10
''');
      final accountId = await db.into(db.accounts).insert(
        AccountsCompanion.insert(name: 'Test'),
      );
      final preview = await importer.parseFile(file.path);
      await importer.importTransactions(
        preview: preview,
        mappings: [
          const ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
          const ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
        ],
        accountId: accountId,
      );
      final tx = (await db.select(db.transactions).get()).first;
      expect(tx.operationDate.year, 2024);
      expect(tx.operationDate.month, 1);
      expect(tx.operationDate.day, 15);
    });

    test('handles yyyy-MM-dd format', () async {
      final file = writeCsv('dates.csv', '''
Date,Amount
2024-03-14,-10
''');
      final accountId = await db.into(db.accounts).insert(
        AccountsCompanion.insert(name: 'Test'),
      );
      final preview = await importer.parseFile(file.path);
      await importer.importTransactions(
        preview: preview,
        mappings: [
          const ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
          const ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
        ],
        accountId: accountId,
      );
      final tx = (await db.select(db.transactions).get()).first;
      expect(tx.operationDate.month, 3);
      expect(tx.operationDate.day, 14);
    });
  });

  group('Amount parsing', () {
    test('handles European format with comma decimal', () async {
      final file = writeCsv('amounts.csv', '''
Date,Amount
01/01/2024,"1.234,56"
''');
      final accountId = await db.into(db.accounts).insert(
        AccountsCompanion.insert(name: 'Test'),
      );
      final preview = await importer.parseFile(file.path);
      await importer.importTransactions(
        preview: preview,
        mappings: [
          const ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
          const ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
        ],
        accountId: accountId,
      );
      final tx = (await db.select(db.transactions).get()).first;
      expect(tx.amount, 1234.56);
    });
  });
}
