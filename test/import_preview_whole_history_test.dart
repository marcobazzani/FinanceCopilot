// TransactionImportPreview.replacesWholeHistory: whether the account holds
// nothing but the file's rows once it is imported — it has no row yet, or the
// file reaches back far enough to replace every one. Only then does the
// import offer to state the bank's balance as the account's opening: on an
// account with earlier rows, a difference from the bank is a gap in those
// rows, not an opening.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/import/import_service.dart';

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

  // The file starts on 2026-03-01: a re-import replaces every row from then on.
  const statement = FilePreview(
    columns: ['Date', 'Amount'],
    rows: [
      {'Date': '2026-03-01', 'Amount': '100'},
      {'Date': '2026-03-05', 'Amount': '-40'},
    ],
    totalRows: 2,
  );
  const mappings = [
    ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
    ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
  ];

  Future<void> row(DateTime day, double amount) =>
      db.into(db.transactions).insert(TransactionsCompanion.insert(accountId: acct, operationDate: day, valueDate: day, amount: amount));

  Future<TransactionImportPreview> preview() => importer.previewTransactionImport(preview: statement, mappings: mappings, accountId: acct);

  test('an empty account: the file is its whole history', () async {
    final p = await preview();
    expect(p.existingRows, 0);
    expect(p.rowsToReplace, 0);
    expect(p.replacesWholeHistory, isTrue);
  });

  test('a row before the file starts stays: not the whole history', () async {
    await row(DateTime(2026, 2, 15), 500);
    final p = await preview();
    expect(p.existingRows, 1);
    expect(p.rowsToReplace, 0);
    expect(p.replacesWholeHistory, isFalse);
  });

  test('a file reaching back before every row replaces the whole history', () async {
    await row(DateTime(2026, 3, 2), 300);
    await row(DateTime(2026, 3, 4), -20);
    final p = await preview();
    expect(p.existingRows, 2);
    expect(p.rowsToReplace, 2);
    expect(p.replacesWholeHistory, isTrue);
  });

  test('an overlap that leaves an earlier row: not the whole history', () async {
    await row(DateTime(2026, 2, 27), 300);
    await row(DateTime(2026, 3, 3), -20);
    final p = await preview();
    expect(p.existingRows, 2);
    expect(p.rowsToReplace, 1);
    expect(p.replacesWholeHistory, isFalse);
  });

  test('another account\'s rows do not count', () async {
    final other = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Other'));
    final day = DateTime(2026, 2, 15);
    await db.into(db.transactions).insert(TransactionsCompanion.insert(accountId: other, operationDate: day, valueDate: day, amount: 10));
    final p = await preview();
    expect(p.existingRows, 0);
    expect(p.replacesWholeHistory, isTrue);
  });
}
