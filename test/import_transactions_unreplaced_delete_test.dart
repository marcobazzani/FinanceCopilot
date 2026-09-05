// Regression: a wipe-and-replace transaction import must never delete a row
// it cannot replace.
//
// `importTransactions` deletes everything in the account from the import's
// oldest date onward, then inserts the parsed rows. Skipping a row that fails
// a DB-level constraint (e.g. a mapped currency column that isn't exactly 3
// characters) makes the file an INCOMPLETE record of that range — so the
// delete removes the previously-stored copy of that transaction and nothing
// is inserted in its place. Making delete+insert atomic does not help: the
// incomplete replacement commits successfully.
//
// The import must refuse the whole replacement in that case, leaving the
// database untouched, and still import normally when the range holds no rows
// yet (nothing to lose).

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

  Future<int> seedAccount() => db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Checking'));

  Future<void> seedTransaction(int accountId, DateTime date, double amount) => db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          accountId: accountId,
          operationDate: date,
          valueDate: date,
          amount: amount,
        ),
      );

  Future<ImportResult> import(int accountId, List<Map<String, String>> rows) => importer.importTransactions(
    preview: FilePreview(
      columns: const ['date', 'amount', 'currency'],
      rows: rows,
      totalRows: rows.length,
      numberLocale: 'en_US',
    ),
    accountId: accountId,
    numberLocaleOverride: 'en_US',
    mappings: const [
      ColumnMapping(targetField: 'date', sourceColumn: 'date'),
      ColumnMapping(targetField: 'amount', sourceColumn: 'amount'),
      ColumnMapping(targetField: 'currency', sourceColumn: 'currency'),
    ],
  );

  test('a rejected row does not cost an existing transaction that the import would have replaced', () async {
    final accountId = await seedAccount();
    // Already stored from a previous import of the same statement.
    await seedTransaction(accountId, DateTime(2026, 1, 2), 200);

    final result = await import(accountId, const [
      {'date': '2026-01-01', 'amount': '100', 'currency': 'EUR'},
      {'date': '2026-01-02', 'amount': '200', 'currency': 'EURO'}, // 4 chars — rejected
    ]);

    final amounts = (await db.select(db.transactions).get()).map((t) => t.amount).toList();
    expect(
      amounts,
      [200],
      reason: 'the Jan-2 transaction the rejected row was meant to replace must still exist',
    );
    expect(result.importedRows, 0, reason: 'the replacement is refused as a whole, not applied halfway');
    expect(result.errorRows, 1);
    expect(
      result.errors.join('\n'),
      contains('Aborted'),
      reason: 'the user must be told the import was refused, not left thinking it succeeded',
    );
  });

  test('a rejected row still blocks the replacement when every valid row lands on another date', () async {
    final accountId = await seedAccount();
    await seedTransaction(accountId, DateTime(2026, 3, 15), 999);

    await import(accountId, const [
      {'date': '2026-03-01', 'amount': '10', 'currency': 'EUR'},
      {'date': '2026-03-20', 'amount': '20', 'currency': 'EURO'}, // rejected
    ]);

    expect(
      (await db.select(db.transactions).get()).map((t) => t.amount),
      [999],
      reason: 'an unrelated in-range transaction must not be collateral damage',
    );
  });

  test('good rows still import when the replaced range holds nothing to lose', () async {
    final accountId = await seedAccount();

    final result = await import(accountId, const [
      {'date': '2026-01-01', 'amount': '100', 'currency': 'EUR'},
      {'date': '2026-01-02', 'amount': '200', 'currency': 'EURO'}, // rejected
      {'date': '2026-01-03', 'amount': '300', 'currency': 'EUR'},
    ]);

    expect(result.importedRows, 2);
    expect(result.errorRows, 1);
    expect((await db.select(db.transactions).get()).map((t) => t.amount).toList()..sort(), [100.0, 300.0]);
  });

  test('a rejected row OUTSIDE the replaced range does not block the import', () async {
    final accountId = await seedAccount();
    // Sits before the oldest valid row, so the delete never reaches it.
    await seedTransaction(accountId, DateTime(2025, 6, 1), 50);

    final result = await import(accountId, const [
      {'date': '2025-01-01', 'amount': '10', 'currency': 'EURO'}, // rejected, pre-cutoff
      {'date': '2026-01-01', 'amount': '20', 'currency': 'EUR'},
    ]);

    expect(result.importedRows, 1, reason: 'nothing in the replaced range was at risk');
    expect(
      (await db.select(db.transactions).get()).map((t) => t.amount).toList()..sort(),
      [20.0, 50.0],
      reason: 'the pre-cutoff row is untouched by the date-scoped delete',
    );
  });

  test('a clean re-import of the same statement still replaces in full', () async {
    final accountId = await seedAccount();
    await seedTransaction(accountId, DateTime(2026, 1, 1), 111);

    final result = await import(accountId, const [
      {'date': '2026-01-01', 'amount': '100', 'currency': 'EUR'},
      {'date': '2026-01-02', 'amount': '200', 'currency': 'EUR'},
    ]);

    expect(result.errorRows, 0);
    expect(result.importedRows, 2);
    expect(
      (await db.select(db.transactions).get()).map((t) => t.amount).toList()..sort(),
      [100.0, 200.0],
      reason: 'wipe-and-replace still works normally when the file is complete',
    );
  });
}
