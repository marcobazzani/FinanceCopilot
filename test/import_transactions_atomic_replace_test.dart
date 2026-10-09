// Regression: a failed replacement (one row that fails a DB-level
// constraint only enforced at write time, e.g. a mapped currency column
// that isn't exactly 3 characters) must NOT delete the account's prior
// transactions. Deletion and insertion now run in one transaction.

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

  test('a row with an invalid currency does not wipe previously imported transactions', () async {
    final accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Checking'));
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: accountId,
            operationDate: DateTime(2026, 1, 1),
            valueDate: DateTime(2026, 1, 1),
            amount: 100,
          ),
        );

    final preview = FilePreview(
      columns: const ['date', 'amount', 'currency'],
      rows: const [
        {'date': '2026-01-01', 'amount': '200', 'currency': 'EURO'}, // 4 chars — fails the column's 3-char constraint
      ],
      totalRows: 1,
      numberLocale: 'en_US',
    );

    final result = await importer.importTransactions(
      preview: preview,
      accountId: accountId,
      numberLocaleOverride: 'en_US',
      mappings: const [
        ColumnMapping(targetField: 'date', sourceColumn: 'date'),
        ColumnMapping(targetField: 'amount', sourceColumn: 'amount'),
        ColumnMapping(targetField: 'currency', sourceColumn: 'currency'),
      ],
    );

    expect(result.errorRows, 1, reason: 'the bad-currency row is skipped, not silently dropped without a trace');
    expect(result.importedRows, 0);
    final txns = await db.select(db.transactions).get();
    expect(txns.map((t) => t.amount), [100], reason: 'the pre-existing transaction must survive the failed replacement row');
  });

  test('a valid row still replaces prior transactions when every row succeeds', () async {
    final accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Checking'));
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: accountId,
            operationDate: DateTime(2026, 1, 1),
            valueDate: DateTime(2026, 1, 1),
            amount: 100,
          ),
        );

    final preview = FilePreview(
      columns: const ['date', 'amount'],
      rows: const [
        {'date': '2026-01-01', 'amount': '200'},
      ],
      totalRows: 1,
      numberLocale: 'en_US',
    );

    final result = await importer.importTransactions(
      preview: preview,
      accountId: accountId,
      numberLocaleOverride: 'en_US',
      mappings: const [
        ColumnMapping(targetField: 'date', sourceColumn: 'date'),
        ColumnMapping(targetField: 'amount', sourceColumn: 'amount'),
      ],
    );

    expect(result.errorRows, 0);
    expect(result.importedRows, 1);
    final txns = await db.select(db.transactions).get();
    expect(txns.map((t) => t.amount), [200]);
  });

  test('one bad row among good ones is skipped without blocking the valid replacement rows', () async {
    final accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Checking'));

    final preview = FilePreview(
      columns: const ['date', 'amount', 'currency'],
      rows: const [
        {'date': '2026-01-01', 'amount': '100', 'currency': 'EUR'},
        {'date': '2026-01-02', 'amount': '200', 'currency': 'EURO'}, // invalid — skipped
        {'date': '2026-01-03', 'amount': '300', 'currency': 'EUR'},
      ],
      totalRows: 3,
      numberLocale: 'en_US',
    );

    final result = await importer.importTransactions(
      preview: preview,
      accountId: accountId,
      numberLocaleOverride: 'en_US',
      mappings: const [
        ColumnMapping(targetField: 'date', sourceColumn: 'date'),
        ColumnMapping(targetField: 'amount', sourceColumn: 'amount'),
        ColumnMapping(targetField: 'currency', sourceColumn: 'currency'),
      ],
    );

    expect(result.errorRows, 1);
    expect(result.importedRows, 2);
    final txns = await db.select(db.transactions).get();
    expect(txns.map((t) => t.amount).toList()..sort(), [100.0, 300.0]);
  });
}
