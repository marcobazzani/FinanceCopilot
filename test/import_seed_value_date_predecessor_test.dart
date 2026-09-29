// A transaction import that appends to rows already stored seeds its running
// balance from them. Stored `balance_after` is the VALUE-DATE running balance
// (see running_balance.dart), so the balance "before the import" is the one on
// the value-date last of the kept rows — not on the last one booked.
//
// Kept rows: booked 01-10 / value 01-12 +100 and booked 01-11 / value 01-09
// −30. On the value-date timeline the −30 comes first (balance −30), then the
// +100 (balance 70): 70 is what the account holds before the import. Seeding
// from the last BOOKED row read −30 instead.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/import/import_service.dart';

void main() {
  late AppDatabase db;
  late ImportService importer;
  late int accountId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = ImportService(db);
    accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Bank'));
    // Hand-entered rows (no statement data), stored with their value-date
    // running balance.
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: accountId,
            operationDate: DateTime(2025, 1, 10),
            valueDate: DateTime(2025, 1, 12),
            amount: 100,
            balanceAfter: const Value(70),
          ),
        );
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: accountId,
            operationDate: DateTime(2025, 1, 11),
            valueDate: DateTime(2025, 1, 9),
            amount: -30,
            balanceAfter: const Value(-30),
          ),
        );
  });

  tearDown(() => db.close());

  Future<List<Transaction>> importedRows() =>
      (db.select(db.transactions)
            ..where((t) => t.operationDate.isBiggerOrEqualValue(DateTime(2025, 1, 15)))
            ..orderBy([(t) => OrderingTerm.asc(t.valueDate), (t) => OrderingTerm.asc(t.id)]))
          .get();

  test('filtered mode: the predicted and the stored balance continue from the value-date predecessor', () async {
    const preview = FilePreview(
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

    final predicted = await importer.previewTransactionImport(
      preview: preview,
      mappings: mappings,
      accountId: accountId,
      balanceMode: 'filtered',
      balanceFilterColumn: 'State',
      balanceFilterInclude: {'COMPLETED'},
    );
    expect(predicted.importSum, 50);
    expect(predicted.predictedBalance, 120, reason: '70 held before the import + 50');

    await importer.importTransactions(
      preview: preview,
      mappings: mappings,
      accountId: accountId,
      balanceMode: 'filtered',
      balanceFilterColumn: 'State',
      balanceFilterInclude: {'COMPLETED'},
    );
    expect((await importedRows()).map((t) => t.balanceAfter), [120, 120], reason: 'the declined row does not move it');
  });

  test('balance-diff mode: a kept row without a statement balance seeds from the value-date predecessor', () async {
    const preview = FilePreview(
      columns: ['Date', 'Balance'],
      rows: [
        {'Date': '2025-01-15', 'Balance': '170'},
        {'Date': '2025-01-16', 'Balance': '200'},
      ],
      totalRows: 2,
    );
    const mappings = [
      ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
      ColumnMapping(sourceColumn: 'Balance', targetField: 'amount', balanceDiffColumn: 'Balance'),
    ];

    final predicted = await importer.previewTransactionImport(preview: preview, mappings: mappings, accountId: accountId);
    expect(predicted.importSum, closeTo(130, 1e-9), reason: '(170 − 70) + (200 − 170)');

    await importer.importTransactions(preview: preview, mappings: mappings, accountId: accountId);
    expect((await importedRows()).map((t) => t.amount), [closeTo(100, 1e-9), closeTo(30, 1e-9)]);
  });
}
