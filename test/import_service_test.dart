import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/import_service.dart';
import 'package:finance_copilot/services/isin_lookup_service.dart';
import 'package:finance_copilot/utils/amount_parser.dart' as amt;

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

  group('Preview row capping', () {
    test('preview caps rows to first 5 + last 5 for files > 10 rows', () async {
      final rows = List.generate(15, (i) => '2024-01-${(i + 1).toString().padLeft(2, '0')},${100 + i},Row $i');
      final file = writeCsv('large.csv', 'Date,Amount,Description\n${rows.join('\n')}\n');
      final preview = await importer.parseFile(file.path);

      expect(preview.totalRows, 15);
      expect(preview.rows.length, 10); // first 5 + last 5
      // First row is row 0, last row is row 14
      expect(preview.rows.first['Description'], 'Row 0');
      expect(preview.rows.last['Description'], 'Row 14');
      // Middle rows (5-9) are missing from preview
    });

    test('getFullRows returns all rows even when preview is capped', () async {
      final rows = List.generate(15, (i) => '2024-01-${(i + 1).toString().padLeft(2, '0')},${100 + i},Row $i');
      final file = writeCsv('large.csv', 'Date,Amount,Description\n${rows.join('\n')}\n');
      final preview = await importer.parseFile(file.path);

      expect(preview.rows.length, 10); // capped
      final full = await importer.getFullRows(preview);
      expect(full.rows.length, 15); // all rows
      expect(full.rows[7]['Description'], 'Row 7'); // middle row present
    });

    test('files with <= 10 rows are not capped', () async {
      final rows = List.generate(10, (i) => '2024-01-${(i + 1).toString().padLeft(2, '0')},${100 + i},Row $i');
      final file = writeCsv('small.csv', 'Date,Amount,Description\n${rows.join('\n')}\n');
      final preview = await importer.parseFile(file.path);

      expect(preview.totalRows, 10);
      expect(preview.rows.length, 10); // no capping
    });

    test('11 rows caps to 10 and middle row is lost', () async {
      // Simulates the Directa bug: 11 rows, position 6 is in the gap
      final isins = [
        'LU2009202107', 'IT0003128367', 'IE00BHZRQZ17', 'IE00BP3QZB59', 'IE00B3CNHJ55',
        'DK0062498333', // position 6 -- the gap!
        'LU0322253906', 'IT0005661498', 'XS3213330791', 'US0919471013',
        '', // empty trailing row
      ];
      final rows = isins.map((isin) => '$isin,100,Test').toList();
      final file = writeCsv('directa.csv', 'ISIN,Amount,Name\n${rows.join('\n')}\n');
      final preview = await importer.parseFile(file.path);

      expect(preview.totalRows, 11);
      expect(preview.rows.length, 10); // capped

      // Extract ISINs from capped preview -- DK0062498333 is MISSING
      final cappedIsins = preview.rows
          .map((r) => r['ISIN']?.trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toSet();
      expect(cappedIsins, isNot(contains('DK0062498333')));

      // getFullRows recovers it
      final full = await importer.getFullRows(preview);
      final fullIsins = full.rows
          .map((r) => r['ISIN']?.trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toSet();
      expect(fullIsins, contains('DK0062498333'));
      expect(fullIsins.length, 10); // 10 unique ISINs
    });
  });

  group('Amount parser', () {
    test('standard decimal values', () {
      expect(amt.parseAmount('260.44'), 260.44);
      expect(amt.parseAmount('1.5'), 1.5);
      expect(amt.parseAmount('12.34'), 12.34);
    });

    test('3 decimal places from XLSX (was bug: treated as thousands)', () {
      // After XLSX fix, these arrive as "260.4370" (4 digits) and are parsed correctly.
      // But even without XLSX fix, parseAmount should handle them:
      expect(amt.parseAmount('260.4370'), closeTo(260.437, 0.0001));
      expect(amt.parseAmount('238.7110'), closeTo(238.711, 0.0001));
    });

    test('European thousands with dot', () {
      expect(amt.parseAmount('1.234'), 1234.0);
      expect(amt.parseAmount('1.234.567'), 1234567.0);
    });

    test('European decimal with comma', () {
      expect(amt.parseAmount('260,44'), 260.44);
      expect(amt.parseAmount('1,5'), 1.5);
    });

    test('European thousands + decimal', () {
      expect(amt.parseAmount('1.234,56'), 1234.56);
      expect(amt.parseAmount('1,234.56'), 1234.56);
    });
  });

  group('Asset event import', () {
    FilePreview makeAssetPreview(List<List<String>> rows) {
      return FilePreview(
        columns: ['date', 'isin', 'quantity', 'price', 'currency', 'amount'],
        rows: rows.map((r) => {
          'date': r[0], 'isin': r[1], 'quantity': r[2],
          'price': r[3], 'currency': r[4], 'amount': r[5],
        }).toList(),
        totalRows: rows.length,
      );
    }

    const mappings = [
      ColumnMapping(sourceColumn: 'date', targetField: 'date'),
      ColumnMapping(sourceColumn: 'isin', targetField: 'isin'),
      ColumnMapping(sourceColumn: 'quantity', targetField: 'quantity'),
      ColumnMapping(sourceColumn: 'price', targetField: 'price'),
      ColumnMapping(sourceColumn: 'currency', targetField: 'currency'),
      ColumnMapping(sourceColumn: 'amount', targetField: 'amount'),
    ];

    test('imported assets use marketPrice valuation method', () async {
      final preview = makeAssetPreview([
        ['2024-01-15', 'IE00B4L5Y983', '10', '100.50', 'EUR', '1005.00'],
      ]);
      final result = await importer.importAssetEventsGrouped(
        preview: preview, mappings: mappings, baseCurrency: 'EUR',
      );
      expect(result.result.importedRows, 1);

      final assetId = result.assetsByIsin['IE00B4L5Y983']!;
      final asset = await (db.select(db.assets)..where((a) => a.id.equals(assetId))).getSingle();
      expect(asset.valuationMethod, ValuationMethod.marketPrice);
    });

    test('imported assets store exchange code not Investing.com name', () async {
      final preview = makeAssetPreview([
        ['2024-01-15', 'IE00B4L5Y983', '10', '100.50', 'EUR', '1005.00'],
      ]);
      // Provide a selected exchange with Investing.com name
      final result = await importer.importAssetEventsGrouped(
        preview: preview, mappings: mappings, baseCurrency: 'EUR',
        selectedExchanges: {
          'IE00B4L5Y983': const IsinExchangeOption(
            cid: 46925, ticker: 'SWDA', name: 'iShares MSCI World',
            exchange: 'London', // Investing.com name, not code
          ),
        },
      );
      final assetId = result.assetsByIsin['IE00B4L5Y983']!;
      final asset = await (db.select(db.assets)..where((a) => a.id.equals(assetId))).getSingle();
      expect(asset.exchange, 'LON'); // Should be converted to code
    });

    test('excludedIsins skips assets during import', () async {
      final preview = makeAssetPreview([
        ['2024-01-15', 'IE00B4L5Y983', '10', '100.50', 'EUR', '1005.00'],
        ['2024-01-15', 'LU0908500753', '5', '260.44', 'EUR', '1302.20'],
      ]);
      final result = await importer.importAssetEventsGrouped(
        preview: preview, mappings: mappings, baseCurrency: 'EUR',
        excludedIsins: {'LU0908500753'},
      );
      expect(result.result.importedRows, 1);
      expect(result.assetsByIsin.containsKey('IE00B4L5Y983'), isTrue);
      expect(result.assetsByIsin.containsKey('LU0908500753'), isFalse);
    });

    test('existing asset is reused by ISIN, not recreated', () async {
      // Pre-create an asset with ISIN and TER
      final existingId = await db.into(db.assets).insert(AssetsCompanion.insert(
        name: 'SWDA ETF',
        assetType: AssetType.stockEtf,
        instrumentType: const Value(InstrumentType.etf),
        assetClass: const Value(AssetClass.equity),
        valuationMethod: ValuationMethod.marketPrice,
        isin: const Value('IE00B4L5Y983'),
        exchange: const Value('MIL'),
        ter: const Value(0.20),
      ));

      final preview = makeAssetPreview([
        ['2024-01-15', 'IE00B4L5Y983', '10', '100.50', 'EUR', '1005.00'],
      ]);
      final result = await importer.importAssetEventsGrouped(
        preview: preview, mappings: mappings, baseCurrency: 'EUR',
      );

      // Should reuse existing asset, preserving TER
      expect(result.assetsByIsin['IE00B4L5Y983'], existingId);
      final asset = await (db.select(db.assets)..where((a) => a.id.equals(existingId))).getSingle();
      expect(asset.ter, 0.20); // TER preserved
      expect(asset.exchange, 'MIL'); // Exchange preserved
    });
  });
}
