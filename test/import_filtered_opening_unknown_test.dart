// Filtered balance mode seeds an import from the stored balance of the row
// before it. When that row has no stored balance, the opening balance is
// unknown: the dry run must not predict a balance from an invented 0 (it
// flags it instead) and the import must not store balances computed from it.
// Rows with nothing before them legitimately start from 0.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/import/import_service.dart';

void main() {
  late AppDatabase db;
  late ImportService importer;
  late int acct;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = ImportService(db);
    acct = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Revolut'));
  });
  tearDown(() => db.close());

  const statement = FilePreview(
    columns: ['Date', 'Amount', 'State'],
    rows: [
      {'Date': '2025-01-15', 'Amount': '50', 'State': 'COMPLETED'},
      {'Date': '2025-01-16', 'Amount': '999', 'State': 'DECLINED'},
    ],
    totalRows: 2,
  );
  const mappings = [
    ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
    ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
  ];

  Future<void> storedRow({double? balanceAfter}) => db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          accountId: acct,
          operationDate: DateTime(2025, 1, 10),
          valueDate: DateTime(2025, 1, 10),
          amount: 100,
          balanceAfter: Value(balanceAfter),
        ),
      );

  Future<TransactionImportPreview> preview() => importer.previewTransactionImport(
    preview: statement,
    mappings: mappings,
    accountId: acct,
    balanceMode: 'filtered',
    balanceFilterColumn: 'State',
    balanceFilterInclude: {'COMPLETED'},
  );

  Future<void> import() => importer.importTransactions(
    preview: statement,
    mappings: mappings,
    accountId: acct,
    balanceMode: 'filtered',
    balanceFilterColumn: 'State',
    balanceFilterInclude: {'COMPLETED'},
  );

  Future<List<Transaction>> imported() =>
      (db.select(db.transactions)
            ..where((t) => t.rawMetadata.isNotNull())
            ..orderBy([(t) => OrderingTerm.asc(t.valueDate)]))
          .get();

  test('the row before the import has no stored balance: no predicted balance, flagged', () async {
    await storedRow();
    final p = await preview();
    expect(p.importSum, 50);
    expect(p.predictedBalance, isNull, reason: 'not 0 + 50: the opening balance is unknown');
    expect(p.openingBalanceUnknown, isTrue);
  });

  test('the row before the import has no stored balance: the import stores no invented balance', () async {
    await storedRow();
    await import();
    final rows = await imported();
    expect(rows, hasLength(2));
    expect(rows.map((t) => t.balanceAfter), [isNull, isNull]);
    expect(rows.last.status, TransactionStatus.cancelled, reason: 'the excluded row is still marked cancelled');
  });

  test('a stored balance before the import still seeds both', () async {
    await storedRow(balanceAfter: 70);
    final p = await preview();
    expect(p.predictedBalance, 120);
    expect(p.openingBalanceUnknown, isFalse);
    await import();
    expect((await imported()).map((t) => t.balanceAfter), [120, 120]);
  });

  test('nothing before the import: starts from 0, not flagged', () async {
    final p = await preview();
    expect(p.predictedBalance, 50);
    expect(p.openingBalanceUnknown, isFalse);
    await import();
    expect((await imported()).map((t) => t.balanceAfter), [50, 50]);
  });
}
