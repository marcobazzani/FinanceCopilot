// Value date derived from the description (column split + fallback), and
// re-running an import from the raw statement columns stored on each row.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/services/import/preview_transforms.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ImportService importer;
  late int acct;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = ImportService(db);
    acct = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'KBC'));
  });
  tearDown(() => db.close());

  /// A headerless card-statement export: one booking-date column, the real
  /// transaction date only inside the description.
  FilePreview kbcPreview() => FilePreview(
    columns: const ['Column 1', 'Column 2', 'Column 3'],
    rows: const [
      {'Column 1': '11 May 2022', 'Column 2': 'POS Revolut1946 20220509', 'Column 3': '-2500.00'},
      {'Column 1': '11 May 2022', 'Column 2': 'POS Revolut1946 20220510', 'Column 3': '-134.33'},
      {'Column 1': '12 May 2022', 'Column 2': 'Non-Euro Point Of Sales Fee', 'Column 3': '-0.46'},
      {'Column 1': '13 May 2022', 'Column 2': 'ATM RIF 20190101', 'Column 3': '-50.00'},
    ],
    totalRows: 4,
    numberLocale: 'en_US',
  );

  /// The real transaction date lives in the description; derive it with a
  /// regex split and fall back to the booking date when the text has none.
  final txDateSplit = const ColumnSplit(
    sourceColumn: 'Column 2',
    newColumns: ['TxDate'],
    byRegex: true,
    pattern: r'(\d{8})$',
    fallbackColumn: 'Column 1',
  );

  FilePreview withTxDate(FilePreview p) {
    final t = PreviewTransforms(splits: [txDateSplit]);
    return FilePreview(
      columns: t.transformColumns(p.columns),
      rows: t.transformRows(p.rows),
      totalRows: p.totalRows,
      numberLocale: p.numberLocale,
    );
  }

  List<ColumnMapping> kbcMappings({bool dateFromText = true}) => [
    const ColumnMapping(sourceColumn: 'Column 1', targetField: 'date'),
    const ColumnMapping(sourceColumn: 'Column 3', targetField: 'amount'),
    const ColumnMapping(sourceColumn: 'Column 2', targetField: 'description'),
    if (dateFromText) const ColumnMapping(sourceColumn: 'TxDate', targetField: 'valueDate'),
  ];

  Future<List<Transaction>> rows() =>
      (db.select(db.transactions)..orderBy([(t) => OrderingTerm.asc(t.operationDate), (t) => OrderingTerm.asc(t.id)])).get();

  group('value date derived from the description via split + fallback', () {
    test('uses the embedded date; the fallback column supplies the booking date when there is none', () async {
      final r = await importer.importTransactions(preview: withTxDate(kbcPreview()), mappings: kbcMappings(), accountId: acct);
      expect(r.importedRows, 4);
      final t = await rows();
      // Booking date stays the operation date (import dedup key); value date is the real one.
      expect(t[0].operationDate, DateTime(2022, 5, 11));
      expect(t[0].valueDate, DateTime(2022, 5, 9));
      expect(t[1].valueDate, DateTime(2022, 5, 10));
      // No date in the text → fallback column → booking date.
      expect(t[2].valueDate, DateTime(2022, 5, 12));
      // A stray 8-digit reference is captured by the regex: the split is the user's contract.
      expect(t[3].valueDate, DateTime(2019, 1, 1));
    });

    test('value date unmapped → operation date', () async {
      await importer.importTransactions(preview: kbcPreview(), mappings: kbcMappings(dateFromText: false), accountId: acct);
      expect((await rows()).every((t) => t.valueDate == t.operationDate), isTrue);
    });
  });

  group('re-run from stored rows', () {
    test('previewFromStoredRows rebuilds columns and rows from raw metadata, excluding manual rows', () async {
      await importer.importTransactions(preview: kbcPreview(), mappings: kbcMappings(dateFromText: false), accountId: acct);
      // A manual row: no raw metadata.
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              accountId: acct,
              operationDate: DateTime(2022, 5, 12),
              valueDate: DateTime(2022, 5, 12),
              amount: -7,
              description: const Value('Coffee (manual)'),
            ),
          );

      final p = (await importer.previewFromStoredRows(acct, numberLocale: 'en_US'))!;
      expect(p.columns, ['Column 1', 'Column 2', 'Column 3']);
      expect(p.rows, hasLength(4));
      expect(p.totalRows, 4);
      expect(p.rows.first['Column 2'], 'POS Revolut1946 20220509');
      expect(p.filePath, isNull);
      expect(p.numberLocale, 'en_US');
      expect(await importer.previewFromStoredRows(999), isNull);
    });

    test('re-running with a changed mapping regenerates imported rows, keeps manual rows and user annotations', () async {
      await importer.importTransactions(preview: kbcPreview(), mappings: kbcMappings(dateFromText: false), accountId: acct);
      final before = await rows();
      expect(before.every((t) => t.valueDate == t.operationDate), isTrue, reason: 'plain column mapping first');

      // User annotates one imported row and adds a manual row inside the range.
      final groceries = await db.into(db.categories).insert(CategoriesCompanion.insert(name: 'Groceries', type: CategoryType.expense));
      await (db.update(db.transactions)..where((t) => t.id.equals(before[1].id))).write(
        TransactionsCompanion(categoryId: Value(groceries), tags: const Value('["x"]'), expenseType: const Value(ExpenseType.opex)),
      );
      final manualId = await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              accountId: acct,
              operationDate: DateTime(2022, 5, 12),
              valueDate: DateTime(2022, 5, 12),
              amount: -7,
              description: const Value('Coffee (manual)'),
            ),
          );

      // Re-run from stored rows, now deriving TxDate with the split.
      final stored = withTxDate((await importer.previewFromStoredRows(acct, numberLocale: 'en_US'))!);
      final r = await importer.importTransactions(
        preview: stored,
        mappings: kbcMappings(),
        accountId: acct,
        replaceOnlyImportedRows: true,
      );
      expect(r.importedRows, 4);
      expect(r.deletedRows, 4, reason: 'only the 4 imported rows are replaced');

      final after = await rows();
      expect(after, hasLength(5));
      final manual = after.singleWhere((t) => t.id == manualId);
      expect(manual.description, 'Coffee (manual)', reason: 'manual row untouched');

      final regenerated = after.where((t) => t.id != manualId).toList();
      expect(regenerated.map((t) => t.valueDate), [
        DateTime(2022, 5, 9),
        DateTime(2022, 5, 10),
        DateTime(2022, 5, 12),
        DateTime(2019, 1, 1),
      ]);
      // Annotations carried over to the regenerated row with the same identity.
      final annotated = regenerated.singleWhere((t) => t.description == 'POS Revolut1946 20220510');
      expect(annotated.categoryId, groceries);
      expect(annotated.tags, '["x"]');
      expect(annotated.expenseType, ExpenseType.opex);
      expect(regenerated.where((t) => t.categoryId != null), hasLength(1));
      // Raw metadata survives the round trip, so it can be re-run again.
      expect(regenerated.every((t) => t.rawMetadata != null && t.rawMetadata!.contains('Column 2')), isTrue);
    });

    test('column splits re-derive idempotently from the stored source column, and can be edited', () async {
      // Import with a split: description → [Merchant, TxDate] by regex.
      final split = ColumnSplit(
        sourceColumn: 'Column 2',
        newColumns: const ['Merchant', 'TxDate'],
        byRegex: true,
        pattern: r'^POS (\S+) (\d{8})$',
      );
      final transforms = PreviewTransforms(splits: [split], filters: const []);
      final raw = kbcPreview();
      final transformed = FilePreview(
        columns: transforms.transformColumns(raw.columns),
        rows: transforms.transformRows(raw.rows),
        totalRows: raw.totalRows,
        numberLocale: 'en_US',
      );
      expect(transformed.rows.first['Merchant'], 'Revolut1946');
      await importer.importTransactions(preview: transformed, mappings: kbcMappings(dateFromText: false), accountId: acct);

      // Stored rows carry BOTH the source column and the derived ones.
      final stored = (await importer.previewFromStoredRows(acct, numberLocale: 'en_US'))!;
      expect(stored.columns, containsAll(['Column 2', 'Merchant', 'TxDate']));

      // Re-applying the same split changes nothing (idempotent) …
      final again = transforms.transformRows(stored.rows);
      expect(again.map((r) => r['Merchant']), stored.rows.map((r) => r['Merchant']));
      expect(transforms.transformColumns(stored.columns), stored.columns, reason: 'no duplicate derived columns');

      // … and an edited split re-derives from the original column.
      final edited = PreviewTransforms(
        splits: [
          ColumnSplit(sourceColumn: 'Column 2', newColumns: const ['Merchant', 'TxDate'], byRegex: true, pattern: r'^POS (\D+)\d* (\d{8})$'),
        ],
        filters: const [],
      );
      expect(edited.transformRows(stored.rows).first['Merchant'], 'Revolut');
    });

    test('the stored preview carries the saved number locale only; none saved → null (the wizard must ask)', () async {
      await importer.importTransactions(preview: kbcPreview(), mappings: kbcMappings(dateFromText: false), accountId: acct);
      expect((await importer.previewFromStoredRows(acct))!.numberLocale, isNull);
      expect((await importer.previewFromStoredRows(acct, numberLocale: 'en_US'))!.numberLocale, 'en_US');
    });

    test('a plain file re-import (replaceOnlyImportedRows=false) still replaces the whole range, as before', () async {
      await importer.importTransactions(preview: kbcPreview(), mappings: kbcMappings(dateFromText: false), accountId: acct);
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              accountId: acct,
              operationDate: DateTime(2022, 5, 12),
              valueDate: DateTime(2022, 5, 12),
              amount: -7,
              description: const Value('Coffee (manual)'),
            ),
          );
      final r = await importer.importTransactions(preview: kbcPreview(), mappings: kbcMappings(dateFromText: false), accountId: acct);
      expect(r.deletedRows, 5);
      expect(await rows(), hasLength(4));
    });

    test('a re-run replaces EVERY imported row, even ones whose stored date is off (no orphan duplicates)', () async {
      await importer.importTransactions(preview: kbcPreview(), mappings: kbcMappings(dateFromText: false), accountId: acct);
      // Simulate a previous bad re-run that pushed one row's booking date far
      // into the past: a date-cutoff delete would leave it behind.
      final first = (await rows()).first;
      await (db.update(db.transactions)..where((t) => t.id.equals(first.id))).write(
        TransactionsCompanion(operationDate: Value(DateTime(1964, 11, 15)), valueDate: Value(DateTime(1964, 11, 15))),
      );
      // A hand-entered row must survive regardless of its date.
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(accountId: acct, operationDate: DateTime(2000, 1, 1), valueDate: DateTime(2000, 1, 1), amount: -1),
          );

      final stored = (await importer.previewFromStoredRows(acct, numberLocale: 'en_US'))!;
      final r = await importer.importTransactions(
        preview: stored,
        mappings: kbcMappings(dateFromText: false),
        accountId: acct,
        replaceOnlyImportedRows: true,
      );
      expect(r.deletedRows, 4, reason: 'all four imported rows, including the mis-dated one');
      expect(r.importedRows, 4);
      final t = await rows();
      expect(t, hasLength(5));
      expect(t.where((x) => x.rawMetadata == null).single.amount, -1);
      expect(t.where((x) => x.operationDate.year == 1964), isEmpty);
      expect(t.where((x) => x.rawMetadata != null).map((x) => x.amount).reduce((a, b) => a + b), closeTo(-2684.79, 1e-6));
    });

    test('balance-diff re-run: the seed is learned from the stored first row, and a corrupted one cannot poison it', () async {
      const bal = ColumnMapping(sourceColumn: 'Column 4', targetField: 'amount', balanceDiffColumn: 'Column 4');
      const balAfter = ColumnMapping(sourceColumn: 'Column 4', targetField: 'balanceAfter');
      final preview = FilePreview(
        columns: const ['Column 1', 'Column 2', 'Column 4'],
        rows: const [
          {'Column 1': '20 Feb 2017', 'Column 2': 'SCT opening', 'Column 4': '2,000.00'},
          {'Column 1': '24 Feb 2017', 'Column 2': 'POS shop', 'Column 4': '1,997.00'},
          {'Column 1': '28 Feb 2017', 'Column 2': 'POS carpark', 'Column 4': '1,994.00'},
        ],
        totalRows: 3,
        numberLocale: 'en_US',
      );
      final maps = [
        const ColumnMapping(sourceColumn: 'Column 1', targetField: 'date'),
        bal,
        balAfter,
        const ColumnMapping(sourceColumn: 'Column 2', targetField: 'description'),
      ];
      Future<ImportResult> rerun() async => importer.importTransactions(
        preview: (await importer.previewFromStoredRows(acct, numberLocale: 'en_US'))!,
        mappings: maps,
        accountId: acct,
        balanceMode: 'column',
        replaceOnlyImportedRows: true,
      );
      Future<List<double>> amounts() async => (await rows()).map((x) => x.amount).toList();

      // Fresh import, nothing before it: the opening balance is unknown, the first row contributes 0.
      await importer.importTransactions(preview: preview, mappings: maps, accountId: acct, balanceMode: 'column');
      expect(await amounts(), [0, -3, -3]);
      // A re-run learns "seed = first balance" from the stored first row and reproduces it.
      await rerun();
      expect(await amounts(), [0, -3, -3]);

      // Accounts imported by older versions stored the first row as the opening deposit: learned and kept too.
      final first = (await rows()).first;
      await (db.update(db.transactions)..where((x) => x.id.equals(first.id))).write(const TransactionsCompanion(amount: Value(2000)));
      await rerun();
      expect(await amounts(), [2000, -3, -3]);

      // A corrupted stored first amount (neither rule fits) must not become the seed of the next run.
      final again = (await rows()).first;
      await (db.update(db.transactions)..where((x) => x.id.equals(again.id))).write(const TransactionsCompanion(amount: Value(-201546.14)));
      final r = await rerun();
      expect(r.errorRows, 0);
      expect(await amounts(), [0, -3, -3], reason: 'seed unknown → 0; the chain is intact');
      expect((await rows()).map((x) => x.balanceAfter), [2000, 1997, 1994]);
    });
  });
}
