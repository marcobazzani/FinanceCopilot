// The currency an import records a row in is never a silent guess:
//
//  * income import: a BLANK cell in a MAPPED currency column was imported in
//    the default currency. The row is now refused with a structured issue
//    (`rejected`, field `currency`) — the issue a transaction import already
//    raises for the same blank cell — and the other rows still import.
//  * asset import: with NO currency column mapped every event (and every
//    asset the import creates) is recorded in the base currency. That stays,
//    but the preview says so, for the wizard to disclose.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/import/import_service.dart';

void main() {
  late AppDatabase db;
  late ImportService importer;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = ImportService(db);
  });
  tearDown(() => db.close());

  group('income import', () {
    const mappings = [
      ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
      ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
      ColumnMapping(sourceColumn: 'Currency', targetField: 'currency'),
    ];

    test('a blank cell in the mapped currency column refuses the row, never imports it in the default currency', () async {
      final r = await importer.importIncomes(
        preview: const FilePreview(
          columns: ['Date', 'Amount', 'Currency'],
          rows: [
            {'Date': '2026-01-01', 'Amount': '100', 'Currency': 'USD'},
            {'Date': '2026-01-02', 'Amount': '200', 'Currency': ''},
            {'Date': '2026-01-03', 'Amount': '300', 'Currency': '   '},
            {'Date': '2026-01-04', 'Amount': '400', 'Currency': 'CHF'},
          ],
          totalRows: 4,
        ),
        mappings: mappings,
        defaultCurrency: 'EUR',
        numberLocaleOverride: 'en_US',
      );
      expect(r.importedRows, 2);
      expect(r.errorRows, 2);
      expect(
        [for (final i in r.issues) (i.kind, i.line, i.fields.join(','))],
        [
          (ImportIssueKind.rejected, 2, 'currency'),
          (ImportIssueKind.rejected, 3, 'currency'),
        ],
      );
      expect(r.errors.first, startsWith('Skipped line 2'), reason: 'English text for the logs');
      final stored = await db.select(db.incomes).get();
      expect({for (final i in stored) i.amount: i.currency}, {100.0: 'USD', 400.0: 'CHF'});
    });

    test('no currency column mapped: every row is in the default currency the wizard passes', () async {
      final r = await importer.importIncomes(
        preview: const FilePreview(
          columns: ['Date', 'Amount'],
          rows: [
            {'Date': '2026-01-01', 'Amount': '100'},
          ],
          totalRows: 1,
        ),
        mappings: const [
          ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
          ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
        ],
        defaultCurrency: 'EUR',
        numberLocaleOverride: 'en_US',
      );
      expect(r.issues, isEmpty);
      expect((await db.select(db.incomes).getSingle()).currency, 'EUR');
    });
  });

  group('asset import: an unmapped currency column is disclosed', () {
    late int broker;
    setUp(() async => broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker')));

    const preview = FilePreview(
      columns: ['date', 'isin', 'quantity', 'amount', 'ccy'],
      rows: [
        {'date': '2026-01-01', 'isin': 'IE00B4L5Y983', 'quantity': '1', 'amount': '-100', 'ccy': 'USD'},
      ],
      totalRows: 1,
    );
    const base = [
      ColumnMapping(sourceColumn: 'date', targetField: 'date'),
      ColumnMapping(sourceColumn: 'isin', targetField: 'isin'),
      ColumnMapping(sourceColumn: 'quantity', targetField: 'quantity'),
      ColumnMapping(sourceColumn: 'amount', targetField: 'amount'),
    ];
    const withCurrency = [...base, ColumnMapping(sourceColumn: 'ccy', targetField: 'currency')];

    test('the preview says whether every event is recorded in the base currency', () async {
      expect((await importer.previewAssetEventImport(preview: preview, mappings: base, numberLocale: 'en_US')).baseCurrencyAssumed, isTrue);
      expect(
        (await importer.previewAssetEventImport(preview: preview, mappings: withCurrency, numberLocale: 'en_US')).baseCurrencyAssumed,
        isFalse,
      );
    });

    test('unmapped: the events and the created asset are in the base currency', () async {
      await importer.importAssetEventsGrouped(
        preview: preview,
        mappings: base,
        baseCurrency: 'EUR',
        intermediaryId: broker,
        numberLocaleOverride: 'en_US',
      );
      expect((await db.select(db.assetEvents).getSingle()).currency, 'EUR');
      expect((await db.select(db.assets).getSingle()).currency, 'EUR');
    });

    test('mapped: the file\'s currency', () async {
      await importer.importAssetEventsGrouped(
        preview: preview,
        mappings: withCurrency,
        baseCurrency: 'EUR',
        intermediaryId: broker,
        numberLocaleOverride: 'en_US',
      );
      expect((await db.select(db.assetEvents).getSingle()).currency, 'USD');
    });
  });
}
