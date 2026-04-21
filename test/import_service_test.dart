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
  // Every asset needs an intermediary (schema v29). Tests that don't care
  // about intermediary specifics use this default.
  late int defaultIntermediaryId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = ImportService(db);
    tempDir = Directory.systemTemp.createTempSync('import_test_');
    defaultIntermediaryId = await db.into(db.intermediaries).insert(
      IntermediariesCompanion.insert(name: 'Default'),
    );
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
        intermediaryId: defaultIntermediaryId,
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
        intermediaryId: defaultIntermediaryId,
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
        intermediaryId: defaultIntermediaryId,
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
        intermediaryId: defaultIntermediaryId,
      ));

      final preview = makeAssetPreview([
        ['2024-01-15', 'IE00B4L5Y983', '10', '100.50', 'EUR', '1005.00'],
      ]);
      final result = await importer.importAssetEventsGrouped(
        preview: preview, mappings: mappings, baseCurrency: 'EUR',
        intermediaryId: defaultIntermediaryId,
      );

      // Should reuse existing asset, preserving TER
      expect(result.assetsByIsin['IE00B4L5Y983'], existingId);
      final asset = await (db.select(db.assets)..where((a) => a.id.equals(existingId))).getSingle();
      expect(asset.ter, 0.20); // TER preserved
      expect(asset.exchange, 'MIL'); // Exchange preserved
    });

    test('bond ISINs apply price /100 divisor when amount is auto-calculated', () async {
      // Pre-create a bond asset
      final bondId = await db.into(db.assets).insert(AssetsCompanion.insert(
        name: 'Italian BTP',
        assetType: AssetType.stockEtf,
        instrumentType: const Value(InstrumentType.bond),
        assetClass: const Value(AssetClass.fixedIncome),
        valuationMethod: ValuationMethod.marketPrice,
        isin: const Value('XS1234567890'),
        intermediaryId: defaultIntermediaryId,
      ));

      // Use mappings WITHOUT amount so the auto-calc path (qty * price / 100) fires
      final preview = FilePreview(
        columns: ['date', 'isin', 'quantity', 'price', 'currency'],
        rows: [
          {'date': '2024-06-15', 'isin': 'XS1234567890', 'quantity': '10', 'price': '98.50', 'currency': 'EUR'},
        ],
        totalRows: 1,
      );
      const bondMappings = [
        ColumnMapping(sourceColumn: 'date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'isin', targetField: 'isin'),
        ColumnMapping(sourceColumn: 'quantity', targetField: 'quantity'),
        ColumnMapping(sourceColumn: 'price', targetField: 'price'),
        ColumnMapping(sourceColumn: 'currency', targetField: 'currency'),
      ];

      final result = await importer.importAssetEventsGrouped(
        preview: preview, mappings: bondMappings, baseCurrency: 'EUR',
        intermediaryId: defaultIntermediaryId,
      );

      expect(result.result.importedRows, 1);
      expect(result.assetsByIsin['XS1234567890'], bondId);

      final events = await db.select(db.assetEvents).get();
      expect(events.length, 1);
      // Bond: amount = qty * price / 100 = 10 * 98.50 / 100 = 9.85
      expect(events.first.amount, closeTo(9.85, 0.001));
    });
  });

  group('Date fallback', () {
    test('operation date falls back to value date when unparsable', () async {
      final account = await db.into(db.accounts).insert(AccountsCompanion.insert(
        name: 'Test', sortOrder: const Value(0),
      ));
      // Row with invalid operation date '-' but valid value date
      final preview = FilePreview(
        columns: ['Data_Operazione', 'Data_Valuta', 'Amount', 'Description'],
        rows: [
          {'Data_Operazione': '-', 'Data_Valuta': '2026-04-07', 'Amount': '-500', 'Description': 'VISA DEBIT'},
          {'Data_Operazione': '2026-04-06', 'Data_Valuta': '2026-04-03', 'Amount': '-100', 'Description': 'Normal tx'},
        ],
        totalRows: 2,
      );

      final result = await importer.importTransactions(
        preview: preview,
        mappings: const [
          ColumnMapping(sourceColumn: 'Data_Operazione', targetField: 'date'),
          ColumnMapping(sourceColumn: 'Data_Valuta', targetField: 'valueDate'),
          ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
          ColumnMapping(sourceColumn: 'Description', targetField: 'description'),
        ],
        accountId: account,
      );

      expect(result.importedRows, 2);
      expect(result.errorRows, 0);

      final txs = await db.select(db.transactions).get();
      expect(txs.length, 2);
      // First tx: operation date fell back to value date (Apr 7)
      final visa = txs.firstWhere((t) => t.description == 'VISA DEBIT');
      expect(visa.operationDate.day, 7);
      expect(visa.valueDate.day, 7);
      // Second tx: both dates parsed independently
      final normal = txs.firstWhere((t) => t.description == 'Normal tx');
      expect(normal.operationDate.day, 6);
      expect(normal.valueDate.day, 3);
    });

    test('value date falls back to operation date when unmapped', () async {
      final account = await db.into(db.accounts).insert(AccountsCompanion.insert(
        name: 'Test2', sortOrder: const Value(0),
      ));
      final preview = FilePreview(
        columns: ['Date', 'Amount', 'Description'],
        rows: [
          {'Date': '2026-01-15', 'Amount': '100', 'Description': 'Income'},
        ],
        totalRows: 1,
      );

      final result = await importer.importTransactions(
        preview: preview,
        mappings: const [
          ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
          ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
          ColumnMapping(sourceColumn: 'Description', targetField: 'description'),
        ],
        accountId: account,
      );

      expect(result.importedRows, 1);
      final txs = await db.select(db.transactions).get();
      // valueDate should equal date when not mapped
      expect(txs.first.operationDate.day, 15);
      expect(txs.first.valueDate.day, 15);
    });

    test('row skipped when both dates are unparsable', () async {
      final account = await db.into(db.accounts).insert(AccountsCompanion.insert(
        name: 'Test3', sortOrder: const Value(0),
      ));
      final preview = FilePreview(
        columns: ['Data_Operazione', 'Data_Valuta', 'Amount', 'Description'],
        rows: [
          {'Data_Operazione': '-', 'Data_Valuta': '-', 'Amount': '-500', 'Description': 'Bad row'},
          {'Data_Operazione': '2026-01-10', 'Data_Valuta': '2026-01-10', 'Amount': '100', 'Description': 'Good row'},
        ],
        totalRows: 2,
      );

      final result = await importer.importTransactions(
        preview: preview,
        mappings: const [
          ColumnMapping(sourceColumn: 'Data_Operazione', targetField: 'date'),
          ColumnMapping(sourceColumn: 'Data_Valuta', targetField: 'valueDate'),
          ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
          ColumnMapping(sourceColumn: 'Description', targetField: 'description'),
        ],
        accountId: account,
      );

      expect(result.importedRows, 1);
      expect(result.errorRows, 1);
      final txs = await db.select(db.transactions).get();
      expect(txs.length, 1);
      expect(txs.first.description, 'Good row');
    });
  });

  group('Asset event wipe-and-replace', () {
    // Helper: build a preview with date column (transaction-style import)
    FilePreview makeDatedPreview(List<List<String>> rows) {
      return FilePreview(
        columns: ['date', 'isin', 'quantity', 'price', 'currency', 'amount'],
        rows: rows.map((r) => {
          'date': r[0], 'isin': r[1], 'quantity': r[2],
          'price': r[3], 'currency': r[4], 'amount': r[5],
        }).toList(),
        totalRows: rows.length,
      );
    }

    const datedMappings = [
      ColumnMapping(sourceColumn: 'date', targetField: 'date'),
      ColumnMapping(sourceColumn: 'isin', targetField: 'isin'),
      ColumnMapping(sourceColumn: 'quantity', targetField: 'quantity'),
      ColumnMapping(sourceColumn: 'price', targetField: 'price'),
      ColumnMapping(sourceColumn: 'currency', targetField: 'currency'),
      ColumnMapping(sourceColumn: 'amount', targetField: 'amount'),
    ];

    // Helper: build a preview WITHOUT date column (spot-style import)
    FilePreview makeSpotPreview(List<List<String>> rows) {
      return FilePreview(
        columns: ['isin', 'quantity', 'price', 'currency', 'amount'],
        rows: rows.map((r) => {
          'isin': r[0], 'quantity': r[1], 'price': r[2],
          'currency': r[3], 'amount': r[4],
        }).toList(),
        totalRows: rows.length,
      );
    }

    const spotMappings = [
      ColumnMapping(sourceColumn: 'isin', targetField: 'isin'),
      ColumnMapping(sourceColumn: 'quantity', targetField: 'quantity'),
      ColumnMapping(sourceColumn: 'price', targetField: 'price'),
      ColumnMapping(sourceColumn: 'currency', targetField: 'currency'),
      ColumnMapping(sourceColumn: 'amount', targetField: 'amount'),
    ];

    test('transaction re-import replaces only from oldest imported date onward', () async {
      // First import: two events on different dates
      final preview1 = makeDatedPreview([
        ['2024-01-15', 'IE00B4L5Y983', '10', '100', 'EUR', '1000'],
        ['2024-02-15', 'IE00B4L5Y983', '5', '110', 'EUR', '550'],
      ]);
      await importer.importAssetEventsGrouped(
        preview: preview1, mappings: datedMappings, baseCurrency: 'EUR',
        intermediaryId: defaultIntermediaryId,
      );
      var events = await db.select(db.assetEvents).get();
      expect(events.length, 2);

      // Re-import: only Feb onward, different quantity
      final preview2 = makeDatedPreview([
        ['2024-02-15', 'IE00B4L5Y983', '8', '115', 'EUR', '920'],
      ]);
      await importer.importAssetEventsGrouped(
        preview: preview2, mappings: datedMappings, baseCurrency: 'EUR',
        intermediaryId: defaultIntermediaryId,
      );

      events = await db.select(db.assetEvents).get();
      // Jan event (before cutoff) should survive, Feb event should be replaced
      expect(events.length, 2);
      final quantities = events.map((e) => e.quantity).toList()..sort();
      expect(quantities, [8.0, 10.0]); // Jan=10 preserved, Feb=8 replaced
    });

    test('transaction re-import with intermediary wipes all intermediary assets from cutoff', () async {
      final intermediaryId = await db.into(db.intermediaries).insert(
        IntermediariesCompanion.insert(name: 'Broker A'),
      );

      // First import: two ISINs under same intermediary
      final preview1 = makeDatedPreview([
        ['2024-01-15', 'IE00B4L5Y983', '10', '100', 'EUR', '1000'],
        ['2024-02-15', 'LU0908500753', '5', '260', 'EUR', '1300'],
      ]);
      await importer.importAssetEventsGrouped(
        preview: preview1, mappings: datedMappings, baseCurrency: 'EUR',
        intermediaryId: intermediaryId,
      );
      var events = await db.select(db.assetEvents).get();
      expect(events.length, 2);

      // Re-import: only the second ISIN with updated quantity
      // Cutoff = Feb 15, so Jan event should survive
      final preview2 = makeDatedPreview([
        ['2024-02-15', 'LU0908500753', '8', '270', 'EUR', '2160'],
      ]);
      await importer.importAssetEventsGrouped(
        preview: preview2, mappings: datedMappings, baseCurrency: 'EUR',
        intermediaryId: intermediaryId,
      );

      events = await db.select(db.assetEvents).get();
      expect(events.length, 2); // Jan SWDA + Feb replaced
      final quantities = events.map((e) => e.quantity).toList()..sort();
      expect(quantities, [8.0, 10.0]); // Jan=10 preserved, Feb=8 replaced
    });

    test('transaction re-import does not wipe events from other intermediary', () async {
      final brokerA = await db.into(db.intermediaries).insert(
        IntermediariesCompanion.insert(name: 'Broker A'),
      );
      final brokerB = await db.into(db.intermediaries).insert(
        IntermediariesCompanion.insert(name: 'Broker B'),
      );

      // Import under Broker B
      final previewB = makeDatedPreview([
        ['2024-01-15', 'IE00B4L5Y983', '20', '100', 'EUR', '2000'],
      ]);
      await importer.importAssetEventsGrouped(
        preview: previewB, mappings: datedMappings, baseCurrency: 'EUR',
        intermediaryId: brokerB,
      );

      // Import under Broker A with overlapping date
      final previewA = makeDatedPreview([
        ['2024-01-15', 'IE00B4L5Y983', '10', '100', 'EUR', '1000'],
      ]);
      await importer.importAssetEventsGrouped(
        preview: previewA, mappings: datedMappings, baseCurrency: 'EUR',
        intermediaryId: brokerA,
      );

      // Broker B's event must survive
      final allEvents = await db.select(db.assetEvents).get();
      expect(allEvents.length, 2);
      final quantities = allEvents.map((e) => e.quantity).toSet();
      expect(quantities, {10.0, 20.0});
    });

    // Reproduces GitHub issue #51: re-importing a spot portfolio file doubles
    // quantities because old events from a previous day are never deleted.
    test('issue #51: spot re-import does not double quantities', () async {
      final intermediaryId = await db.into(db.intermediaries).insert(
        IntermediariesCompanion.insert(name: 'My Broker'),
      );

      final preview = makeSpotPreview([
        ['IE00B4L5Y983', '10', '100', 'EUR', '1000'],
        ['LU0908500753', '5', '260', 'EUR', '1300'],
      ]);

      // First import
      await importer.importAssetEventsGrouped(
        preview: preview, mappings: spotMappings, baseCurrency: 'EUR',
        intermediaryId: intermediaryId,
      );

      // Simulate time passing: backdate events to yesterday
      await db.customUpdate(
        "UPDATE asset_events SET date = strftime('%s', '2024-01-01')",
        updates: {db.assetEvents},
      );

      // Re-import the exact same file (spot, so all events get today's date)
      await importer.importAssetEventsGrouped(
        preview: preview, mappings: spotMappings, baseCurrency: 'EUR',
        intermediaryId: intermediaryId,
      );

      final events = await db.select(db.assetEvents).get();
      expect(events.length, 2, reason: 'should have 2 events (one per ISIN), not 4');
      final totalQty = events.fold<double>(0, (sum, e) => sum + (e.quantity ?? 0));
      expect(totalQty, 15.0, reason: 'total quantity should be 15 (10+5), not 30');
    });

    test('spot re-import with intermediary replaces all events', () async {
      final intermediaryId = await db.into(db.intermediaries).insert(
        IntermediariesCompanion.insert(name: 'Broker A'),
      );

      // First spot import
      final preview1 = makeSpotPreview([
        ['IE00B4L5Y983', '10', '100', 'EUR', '1000'],
      ]);
      await importer.importAssetEventsGrouped(
        preview: preview1, mappings: spotMappings, baseCurrency: 'EUR',
        intermediaryId: intermediaryId,
      );
      var events = await db.select(db.assetEvents).get();
      expect(events.length, 1);
      expect(events.first.quantity, 10.0);

      // Simulate re-import on a different day by manually backdating the
      // existing event so that its date != today (mirrors the real-world
      // scenario where the first import was done yesterday).
      await db.customUpdate(
        "UPDATE asset_events SET date = strftime('%s', '2024-01-01')",
        updates: {db.assetEvents},
      );

      // Re-import same file (spot, so date = today)
      await importer.importAssetEventsGrouped(
        preview: preview1, mappings: spotMappings, baseCurrency: 'EUR',
        intermediaryId: intermediaryId,
      );

      events = await db.select(db.assetEvents).get();
      // With fix: should be 1 event (old wiped, new inserted)
      // Bug behavior: 2 events (old NOT wiped because date cutoff = today)
      expect(events.length, 1, reason: 'spot re-import should fully replace, not accumulate');
      expect(events.first.quantity, 10.0);
    });

    // Removed: "spot re-import without intermediary" scenario is no longer
    // valid since schema v29 — every asset must have an intermediary.

    test('spot re-import with intermediary does not wipe other intermediary events', () async {
      final brokerA = await db.into(db.intermediaries).insert(
        IntermediariesCompanion.insert(name: 'Broker A'),
      );
      final brokerB = await db.into(db.intermediaries).insert(
        IntermediariesCompanion.insert(name: 'Broker B'),
      );

      // Import same ISIN under Broker B first
      final preview = makeSpotPreview([
        ['IE00B4L5Y983', '20', '100', 'EUR', '2000'],
      ]);
      await importer.importAssetEventsGrouped(
        preview: preview, mappings: spotMappings, baseCurrency: 'EUR',
        intermediaryId: brokerB,
      );

      // Now spot import under Broker A
      final previewA = makeSpotPreview([
        ['IE00B4L5Y983', '10', '100', 'EUR', '1000'],
      ]);
      await importer.importAssetEventsGrouped(
        preview: previewA, mappings: spotMappings, baseCurrency: 'EUR',
        intermediaryId: brokerA,
      );

      // Each broker holds its OWN asset row for this ISIN (same-ISIN-at-
      // different-brokers scoping). Both events survive, on separate assets.
      final assets = await (db.select(db.assets)..where((a) => a.isin.equals('IE00B4L5Y983'))).get();
      expect(assets.length, 2, reason: 'one asset row per (ISIN, intermediary)');
      final allEvents = await db.select(db.assetEvents).get();
      expect(allEvents.length, 2); // 1 for each broker
      final quantities = allEvents.map((e) => e.quantity).toSet();
      expect(quantities, {10.0, 20.0});
    });

    test('issue #61: disjoint-ISIN spot imports under two intermediaries do not accumulate', () async {
      final brokerA = await db.into(db.intermediaries).insert(
        IntermediariesCompanion.insert(name: 'Broker A'),
      );
      final brokerB = await db.into(db.intermediaries).insert(
        IntermediariesCompanion.insert(name: 'Broker B'),
      );

      await importer.importAssetEventsGrouped(
        preview: makeSpotPreview([
          ['AAAA00000001', '10', '100', 'EUR', '1000'],
          ['AAAA00000002', '5',  '200', 'EUR', '1000'],
          ['AAAA00000003', '2',  '300', 'EUR',  '600'],
        ]),
        mappings: spotMappings, baseCurrency: 'EUR',
        intermediaryId: brokerA,
      );
      expect((await db.select(db.assetEvents).get()).length, 3);

      await importer.importAssetEventsGrouped(
        preview: makeSpotPreview([
          ['BBBB00000001', '7', '50',  'EUR', '350'],
          ['BBBB00000002', '4', '125', 'EUR', '500'],
        ]),
        mappings: spotMappings, baseCurrency: 'EUR',
        intermediaryId: brokerB,
      );
      expect((await db.select(db.assetEvents).get()).length, 5,
          reason: "A's 3 + B's 2 = 5 (disjoint ISINs, both portfolios preserved)");

      // Re-import Broker A with NEW quantities. Pre-fix this would have left
      // Broker A's old events behind because the wipe only scoped to the
      // current batch's asset ids.
      await importer.importAssetEventsGrouped(
        preview: makeSpotPreview([
          ['AAAA00000001', '20', '110', 'EUR', '2200'],
          ['AAAA00000002', '15', '210', 'EUR', '3150'],
          ['AAAA00000003', '12', '310', 'EUR', '3720'],
        ]),
        mappings: spotMappings, baseCurrency: 'EUR',
        intermediaryId: brokerA,
      );

      final joined = await db.customSelect(
        'SELECT ae.quantity, a.intermediary_id FROM asset_events ae '
        'JOIN assets a ON a.id = ae.asset_id',
      ).get();
      final aQtys = joined.where((r) => r.read<int>('intermediary_id') == brokerA)
          .map((r) => r.read<double>('quantity')).toList()..sort();
      final bQtys = joined.where((r) => r.read<int>('intermediary_id') == brokerB)
          .map((r) => r.read<double>('quantity')).toList()..sort();
      expect(aQtys, [12.0, 15.0, 20.0], reason: 'Broker A wiped and replaced with NEW quantities');
      expect(bQtys, [4.0, 7.0],         reason: 'Broker B untouched');
    });

    test('same ISIN at two intermediaries produces two independent asset rows', () async {
      final brokerA = await db.into(db.intermediaries).insert(
        IntermediariesCompanion.insert(name: 'Broker A'),
      );
      final brokerB = await db.into(db.intermediaries).insert(
        IntermediariesCompanion.insert(name: 'Broker B'),
      );

      await importer.importAssetEventsGrouped(
        preview: makeSpotPreview([
          ['IE00B4L5Y983', '10', '100', 'EUR', '1000'],
        ]),
        mappings: spotMappings, baseCurrency: 'EUR',
        intermediaryId: brokerA,
      );
      await importer.importAssetEventsGrouped(
        preview: makeSpotPreview([
          ['IE00B4L5Y983', '5', '100', 'EUR', '500'],
        ]),
        mappings: spotMappings, baseCurrency: 'EUR',
        intermediaryId: brokerB,
      );

      final assets = await (db.select(db.assets)..where((a) => a.isin.equals('IE00B4L5Y983'))).get();
      expect(assets.length, 2, reason: 'one asset row per (ISIN, intermediary)');
      final byBroker = {for (final a in assets) a.intermediaryId: a.id};
      expect(byBroker.keys.toSet(), {brokerA, brokerB});

      final eventsA = await (db.select(db.assetEvents)..where((e) => e.assetId.equals(byBroker[brokerA]!))).get();
      final eventsB = await (db.select(db.assetEvents)..where((e) => e.assetId.equals(byBroker[brokerB]!))).get();
      expect(eventsA.map((e) => e.quantity), [10.0]);
      expect(eventsB.map((e) => e.quantity), [5.0]);

      // Re-importing Broker A must not touch Broker B.
      await importer.importAssetEventsGrouped(
        preview: makeSpotPreview([
          ['IE00B4L5Y983', '99', '110', 'EUR', '10890'],
        ]),
        mappings: spotMappings, baseCurrency: 'EUR',
        intermediaryId: brokerA,
      );
      final eventsAAfter = await (db.select(db.assetEvents)..where((e) => e.assetId.equals(byBroker[brokerA]!))).get();
      final eventsBAfter = await (db.select(db.assetEvents)..where((e) => e.assetId.equals(byBroker[brokerB]!))).get();
      expect(eventsAAfter.map((e) => e.quantity), [99.0]);
      expect(eventsBAfter.map((e) => e.quantity), [5.0]);
    });
  });

  group('Cumulative balance seeding from pre-cutoff sum', () {
    test('previewTransactionImport predicts balance from true pre-cutoff sum, not stale balance_after', () async {
      final accountId = await db.into(db.accounts).insert(
        AccountsCompanion.insert(name: 'Test'),
      );

      // Pre-existing row with intentionally stale balance_after (mirrors a previous
      // partial-period import that started its cumulative from 0).
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
        accountId: accountId,
        operationDate: DateTime(2024, 12, 1),
        valueDate: DateTime(2024, 12, 1),
        amount: 1000.0,
        balanceAfter: const Value(500.0), // wrong: true cumulative is 1000
      ));

      final preview = const FilePreview(
        columns: ['Date', 'Amount'],
        rows: [{'Date': '2025-01-01', 'Amount': '-100'}],
        totalRows: 1,
      );

      final result = await importer.previewTransactionImport(
        preview: preview,
        mappings: const [
          ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
          ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
        ],
        accountId: accountId,
      );

      // True balance before cutoff = SUM(amount) = 1000. Plus import sum (-100) = 900.
      expect(result.predictedBalance, 900.0);
    });

    test('importTransactions seeds cumulative balance_after from pre-cutoff sum', () async {
      final accountId = await db.into(db.accounts).insert(
        AccountsCompanion.insert(name: 'Test'),
      );

      // Pre-existing row that the import will NOT touch (op_date < cutoff).
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
        accountId: accountId,
        operationDate: DateTime(2024, 12, 1),
        valueDate: DateTime(2024, 12, 1),
        amount: 1000.0,
        balanceAfter: const Value(1000.0),
      ));

      final preview = const FilePreview(
        columns: ['Date', 'Amount'],
        rows: [
          {'Date': '2025-01-01', 'Amount': '-100'},
          {'Date': '2025-01-02', 'Amount': '-200'},
        ],
        totalRows: 2,
      );

      await importer.importTransactions(
        preview: preview,
        mappings: const [
          ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
          ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
        ],
        accountId: accountId,
      );

      final txs = await (db.select(db.transactions)
            ..orderBy([(t) => OrderingTerm.asc(t.operationDate)]))
          .get();
      expect(txs.length, 3);
      // Pre-existing untouched
      expect(txs[0].balanceAfter, 1000.0);
      // Newly imported rows continue cumulative from pre-cutoff balance (1000)
      expect(txs[1].balanceAfter, 900.0);
      expect(txs[2].balanceAfter, 700.0);
    });

    test('previewTransactionImport in filtered mode uses stored balance_after, not SUM(amount)', () async {
      // Filtered mode: some CSV rows are excluded from the running balance
      // (e.g. Revolut internal transfers). The DB stores ALL rows but
      // balance_after on each row is the FILTERED cumulative. SUM(amount)
      // would include the excluded rows and produce a wildly wrong answer.
      final accountId = await db.into(db.accounts).insert(
        AccountsCompanion.insert(name: 'Revolut'),
      );

      // Pre-existing rows: amounts sum to 1000, but stored balance_after on
      // the latest row is 200 (because 800 was excluded by the filter when
      // the previous import wrote those rows).
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
        accountId: accountId,
        operationDate: DateTime(2024, 12, 1),
        valueDate: DateTime(2024, 12, 1),
        amount: 800.0,
        balanceAfter: const Value(0.0), // excluded by filter
      ));
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
        accountId: accountId,
        operationDate: DateTime(2024, 12, 2),
        valueDate: DateTime(2024, 12, 2),
        amount: 200.0,
        balanceAfter: const Value(200.0), // filtered cumulative = 200
      ));

      final preview = const FilePreview(
        columns: ['Date', 'Amount', 'State'],
        rows: [
          {'Date': '2025-01-01', 'Amount': '50', 'State': 'COMPLETATO'},
          {'Date': '2025-01-02', 'Amount': '999', 'State': 'EXCLUDED'},
        ],
        totalRows: 2,
      );

      final result = await importer.previewTransactionImport(
        preview: preview,
        mappings: const [
          ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
          ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
        ],
        accountId: accountId,
        balanceMode: 'filtered',
        balanceFilterColumn: 'State',
        balanceFilterInclude: {'COMPLETATO'},
      );

      // Filtered import sum = 50 (the 999 row is excluded).
      // Pre-cutoff balance (filtered cumulative from stored balance_after) = 200.
      // Predicted = 200 + 50 = 250.
      expect(result.importSum, 50.0);
      expect(result.predictedBalance, 250.0);
    });

    test('importTransactions starting balance is 0 when no pre-cutoff rows exist', () async {
      final accountId = await db.into(db.accounts).insert(
        AccountsCompanion.insert(name: 'FreshAccount'),
      );

      final preview = const FilePreview(
        columns: ['Date', 'Amount'],
        rows: [
          {'Date': '2025-01-01', 'Amount': '500'},
          {'Date': '2025-01-02', 'Amount': '-200'},
        ],
        totalRows: 2,
      );

      await importer.importTransactions(
        preview: preview,
        mappings: const [
          ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
          ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
        ],
        accountId: accountId,
      );

      final txs = await (db.select(db.transactions)
            ..orderBy([(t) => OrderingTerm.asc(t.operationDate)]))
          .get();
      expect(txs.length, 2);
      expect(txs[0].balanceAfter, 500.0);
      expect(txs[1].balanceAfter, 300.0);
    });
  });
}
