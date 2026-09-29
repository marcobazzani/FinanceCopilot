// The import service reports why rows were not imported as structured issues
// (kind + data row + offending cell), so the wizard can word them in the
// user's language instead of showing an English exception text. The English
// `errors` text stays available for logs.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/utils/amount_parser.dart';
import 'package:finance_copilot/utils/date_parser.dart';

void main() {
  late AppDatabase db;
  late ImportService importer;
  late int acct;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = ImportService(db);
    acct = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
  });
  tearDown(() => db.close());

  const dateAmount = [
    ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
    ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
  ];

  // Row 1 is fine; rows 2-5 each fail for a different reason.
  const statement = FilePreview(
    columns: ['Date', 'Amount'],
    rows: [
      {'Date': '2026-01-01', 'Amount': '1.000,50'},
      {'Date': '2026-01-02', 'Amount': 'abc'},
      {'Date': '', 'Amount': '5'},
      {'Date': '2026-13-45', 'Amount': '5'},
      {'Date': '2026-01-03', 'Amount': ''},
    ],
    totalRows: 5,
    numberLocale: 'it_IT',
  );

  List<(ImportIssueKind, int, String)> shape(List<ImportIssue> issues) => [for (final i in issues) (i.kind, i.line, i.value)];

  group('parsers say what they could not read', () {
    test('an empty or unreadable date is a DateParseException carrying the text', () {
      expect(() => parseDate('  '), throwsA(isA<DateParseException>().having((e) => e.empty, 'empty', isTrue)));
      expect(
        () => parseDate('99/99/2024'),
        throwsA(isA<DateParseException>().having((e) => e.raw, 'raw', '99/99/2024').having((e) => e.empty, 'empty', isFalse)),
      );
      expect(() => parseDate('not-a-date'), throwsA(isA<DateParseException>().having((e) => e.raw, 'raw', 'not-a-date')));
      // Still a FormatException with the English message the logs show.
      expect(() => parseDate(''), throwsA(isA<FormatException>().having((e) => '$e', 'text', 'FormatException: Empty date')));
    });

    test('an empty or unreadable amount is an AmountParseException carrying the text and the locale', () {
      expect(
        () => parseAmount('abc', locale: 'it_IT'),
        throwsA(
          isA<AmountParseException>()
              .having((e) => e.raw, 'raw', 'abc')
              .having((e) => e.locale, 'locale', 'it_IT')
              .having((e) => e.empty, 'empty', isFalse),
        ),
      );
      expect(() => parseAmount('€', locale: 'it_IT'), throwsA(isA<AmountParseException>().having((e) => e.empty, 'empty', isTrue)));
      expect(
        () => parseAmount('', locale: 'en_US'),
        throwsA(isA<FormatException>().having((e) => '$e', 'text', 'FormatException: Empty amount')),
      );
    });
  });

  group('transactions', () {
    test('each skipped row reports its kind, line and cell', () async {
      final r = await importer.importTransactions(preview: statement, mappings: dateAmount, accountId: acct, numberLocaleOverride: 'it_IT');
      expect(r.importedRows, 1);
      expect(r.errorRows, 4);
      expect(shape(r.issues), [
        (ImportIssueKind.invalidAmount, 2, 'abc'),
        (ImportIssueKind.emptyDate, 3, ''),
        (ImportIssueKind.invalidDate, 4, '2026-13-45'),
        (ImportIssueKind.emptyAmount, 5, ''),
      ]);
      expect(r.issues.first.locale, 'it_IT', reason: 'the number format the cell was read with');
      // English text for the logs, one per issue.
      expect(r.errors, hasLength(4));
      expect(r.errors.first, startsWith('Skipped line 2:'));
      expect(r.errors.first, contains('abc'));
    });

    test('the dry run reports the same issues', () async {
      final p = await importer.previewTransactionImport(preview: statement, mappings: dateAmount, accountId: acct, numberLocale: 'it_IT');
      expect(p.errorRows, 4);
      expect(shape(p.issues), [
        (ImportIssueKind.invalidAmount, 2, 'abc'),
        (ImportIssueKind.emptyDate, 3, ''),
        (ImportIssueKind.invalidDate, 4, '2026-13-45'),
        (ImportIssueKind.emptyAmount, 5, ''),
      ]);
      expect(p.issues.first.message, startsWith('Line 2:'));
    });

    test('missing date/amount mapping is one whole-import issue', () async {
      const onlyDate = [ColumnMapping(sourceColumn: 'Date', targetField: 'date')];
      final r = await importer.importTransactions(preview: statement, mappings: onlyDate, accountId: acct);
      expect(shape(r.issues), [(ImportIssueKind.dateAndAmountRequired, 0, '')]);
      expect(r.errors, ['date and amount columns are required']);
      final p = await importer.previewTransactionImport(preview: statement, mappings: onlyDate, accountId: acct);
      expect(shape(p.issues), [(ImportIssueKind.dateAndAmountRequired, 0, '')]);
    });

    test('a row the database refuses names the field; a refused replacement reports counts and the first replaced day', () async {
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(accountId: acct, operationDate: DateTime(2026, 1, 2), valueDate: DateTime(2026, 1, 2), amount: 200),
          );
      final r = await importer.importTransactions(
        preview: const FilePreview(
          columns: ['Date', 'Amount', 'Currency'],
          rows: [
            {'Date': '2026-01-01', 'Amount': '100', 'Currency': 'EUR'},
            {'Date': '2026-01-02', 'Amount': '200', 'Currency': 'EURO'},
          ],
          totalRows: 2,
          numberLocale: 'en_US',
        ),
        mappings: const [
          ...dateAmount,
          ColumnMapping(sourceColumn: 'Currency', targetField: 'currency'),
        ],
        accountId: acct,
        numberLocaleOverride: 'en_US',
      );
      expect(r.importedRows, 0);
      expect(r.issues, hasLength(2));
      final rejected = r.issues.first;
      expect((rejected.kind, rejected.line), (ImportIssueKind.rejected, 2));
      expect(rejected.fields, ['currency']);
      final aborted = r.issues.last;
      expect(aborted.kind, ImportIssueKind.replaceAborted);
      expect((aborted.rejectedRows, aborted.existingRows, aborted.replaceFrom), (1, 1, DateTime(2026, 1, 1)));
      expect(r.errors.last, startsWith('Aborted:'), reason: 'the English log text is unchanged');
    });
  });

  group('incomes', () {
    test('an untagged type value and a missing mapping are structured', () async {
      final r = await importer.importIncomes(
        preview: const FilePreview(
          columns: ['Date', 'Amount', 'Type'],
          rows: [
            {'Date': '2026-01-01', 'Amount': '100', 'Type': 'SALARY'},
            {'Date': '2026-01-02', 'Amount': '50', 'Type': 'BONUS'},
          ],
          totalRows: 2,
        ),
        mappings: const [
          ...dateAmount,
          ColumnMapping(sourceColumn: 'Type', targetField: 'type'),
        ],
        defaultCurrency: 'EUR',
        incomeValues: const {'SALARY'},
        numberLocaleOverride: 'en_US',
      );
      expect(r.importedRows, 1);
      expect(shape(r.issues), [(ImportIssueKind.untaggedType, 2, 'BONUS')]);

      final missing = await importer.importIncomes(preview: statement, mappings: const [], defaultCurrency: 'EUR');
      expect(shape(missing.issues), [(ImportIssueKind.dateAndAmountRequired, 0, '')]);
    });
  });

  group('asset events', () {
    late int intermediaryId;
    setUp(() async => intermediaryId = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker')));

    const trades = FilePreview(
      columns: ['Date', 'ISIN', 'Type', 'Amount'],
      rows: [
        {'Date': '2026-01-01', 'ISIN': 'IE00B4L5Y983', 'Type': 'BUY', 'Amount': '100'},
        {'Date': '2026-01-02', 'ISIN': '', 'Type': 'BUY', 'Amount': '100'},
        {'Date': '2026-01-03', 'ISIN': 'IE00B4L5Y983', 'Type': 'DIVIDEND', 'Amount': '5'},
      ],
      totalRows: 3,
    );
    const tradeMappings = [
      ...dateAmount,
      ColumnMapping(sourceColumn: 'ISIN', targetField: 'isin'),
      ColumnMapping(sourceColumn: 'Type', targetField: 'type'),
    ];

    test('empty ISIN and an untagged event type are structured, in the import and the dry run', () async {
      final r = await importer.importAssetEventsGrouped(
        preview: trades,
        mappings: tradeMappings,
        baseCurrency: 'EUR',
        intermediaryId: intermediaryId,
        numberLocaleOverride: 'en_US',
      );
      expect(r.result.importedRows, 1);
      expect(shape(r.result.issues), [(ImportIssueKind.emptyIsin, 2, ''), (ImportIssueKind.untaggedType, 3, 'DIVIDEND')]);

      final p = await importer.previewAssetEventImport(preview: trades, mappings: tradeMappings, numberLocale: 'en_US');
      expect(shape(p.issues), [(ImportIssueKind.emptyIsin, 2, ''), (ImportIssueKind.untaggedType, 3, 'DIVIDEND')]);
    });

    test('no ISIN column and no target asset is one whole-import issue', () async {
      final r = await importer.importAssetEventsGrouped(
        preview: trades,
        mappings: dateAmount,
        baseCurrency: 'EUR',
        intermediaryId: intermediaryId,
      );
      expect(shape(r.result.issues), [(ImportIssueKind.isinRequired, 0, '')]);
      expect(r.result.errors.single, contains('ISIN'));
      final p = await importer.previewAssetEventImport(preview: trades, mappings: dateAmount);
      expect(shape(p.issues), [(ImportIssueKind.isinRequired, 0, '')]);
    });
  });
}
