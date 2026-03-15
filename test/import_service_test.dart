import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asset_manager/database/database.dart';
import 'package:asset_manager/database/tables.dart';
import 'package:asset_manager/services/import_service.dart';

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

  File _writeCsv(String name, String content) {
    final file = File('${tempDir.path}/$name');
    file.writeAsStringSync(content);
    return file;
  }

  group('CSV parsing', () {
    test('parse comma-separated CSV', () async {
      final file = _writeCsv('test.csv', '''
Date,Amount,Description
15/01/2024,-42.50,Supermarket
16/01/2024,1500.00,Salary
''');
      final preview = await importer.parseFile(file.path);
      expect(preview.columns, ['Date', 'Amount', 'Description']);
      expect(preview.rows, hasLength(2));
      expect(preview.rows[0]['Date'], '15/01/2024');
      expect(preview.rows[0]['Amount'], '-42.5');
      expect(preview.rows[1]['Description'], 'Salary');
    });

    test('parse semicolon-separated CSV (European)', () async {
      final file = _writeCsv('test.csv', '''
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
        AccountsCompanion.insert(name: 'Fineco', type: AccountType.bank),
      );

      final file = _writeCsv('fineco.csv', '''
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
      expect(result.skippedDuplicates, 0);
      expect(result.errorRows, 0);

      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(2));
      expect(txs[0].amount, -42.50);
      expect(txs[0].description, 'Supermarket');
      expect(txs[0].importHash, isNotNull);

      // raw_metadata should contain unmapped 'Extra' column
      expect(txs[0].rawMetadata, contains('Extra'));
      expect(txs[0].rawMetadata, contains('some extra data'));
    });

    test('deduplication: re-importing same file skips rows', () async {
      final accountId = await db.into(db.accounts).insert(
        AccountsCompanion.insert(name: 'Fineco', type: AccountType.bank),
      );

      final file = _writeCsv('fineco.csv', '''
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
      final result1 = await importer.importTransactions(
        preview: preview,
        mappings: mappings,
        accountId: accountId,
      );
      expect(result1.importedRows, 2);
      expect(result1.skippedDuplicates, 0);

      // Second import (same data)
      final result2 = await importer.importTransactions(
        preview: preview,
        mappings: mappings,
        accountId: accountId,
      );
      expect(result2.importedRows, 0);
      expect(result2.skippedDuplicates, 2);

      // Still only 2 rows in DB
      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(2));
    });

    test('partial re-import: new rows imported, old rows skipped', () async {
      final accountId = await db.into(db.accounts).insert(
        AccountsCompanion.insert(name: 'Revolut', type: AccountType.bank),
      );

      // First import: 2 rows
      final file1 = _writeCsv('rev1.csv', '''
Date,Amount,Desc
01/02/2024,-10.00,Coffee
02/02/2024,-20.00,Lunch
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

      // Second import: 3 rows (2 old + 1 new)
      final file2 = _writeCsv('rev2.csv', '''
Date,Amount,Desc
01/02/2024,-10.00,Coffee
02/02/2024,-20.00,Lunch
03/02/2024,-15.00,Dinner
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

      expect(result.importedRows, 1);
      expect(result.skippedDuplicates, 2);

      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(3));
    });
  });

  group('AssetEvent import', () {
    test('import as asset events', () async {
      final assetId = await db.into(db.assets).insert(
        AssetsCompanion.insert(
          name: 'iShares MSCI World',
          assetType: AssetType.stockEtf,
          valuationMethod: ValuationMethod.marketPrice,
        ),
      );

      final file = _writeCsv('dossier.csv', '''
Date,Type,Quantity,Price,Amount,ISIN
01/03/2024,BUY,10,85.50,855.00,IE00B4L5Y983
15/03/2024,BUY,5,86.00,430.00,IE00B4L5Y983
''');
      final preview = await importer.parseFile(file.path);
      final result = await importer.importAssetEvents(
        preview: preview,
        mappings: [
          const ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
          const ColumnMapping(sourceColumn: 'Type', targetField: 'type'),
          const ColumnMapping(sourceColumn: 'Quantity', targetField: 'quantity'),
          const ColumnMapping(sourceColumn: 'Price', targetField: 'price'),
          const ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
        ],
        assetId: assetId,
      );

      expect(result.importedRows, 2);

      final events = await db.select(db.assetEvents).get();
      expect(events, hasLength(2));
      expect(events[0].type, EventType.buy);
      expect(events[0].quantity, 10.0);
      expect(events[0].price, 85.50);
      expect(events[0].amount, 855.00);
      // ISIN should be in rawMetadata (unmapped)
      expect(events[0].rawMetadata, contains('IE00B4L5Y983'));
    });
  });

  group('Date parsing', () {
    test('handles dd/MM/yyyy format', () async {
      final file = _writeCsv('dates.csv', '''
Date,Amount
15/01/2024,-10
''');
      final accountId = await db.into(db.accounts).insert(
        AccountsCompanion.insert(name: 'Test', type: AccountType.bank),
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
      final file = _writeCsv('dates.csv', '''
Date,Amount
2024-03-14,-10
''');
      final accountId = await db.into(db.accounts).insert(
        AccountsCompanion.insert(name: 'Test', type: AccountType.bank),
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
      final file = _writeCsv('amounts.csv', '''
Date,Amount
01/01/2024,"1.234,56"
''');
      final accountId = await db.into(db.accounts).insert(
        AccountsCompanion.insert(name: 'Test', type: AccountType.bank),
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
