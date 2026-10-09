// The importer reads its balance mode through BalanceMode and the stored raw
// statement data through the shared tolerant reader.
//
//  * A balance mode that is not one of the stored names used to import every
//    row without a balance, as if it were 'none'. It is now refused before
//    anything is written.
//  * A stored row whose raw statement data is not JSON made a re-run from
//    stored rows, and the balance-difference seed, throw. It is now read as a
//    row without statement data (logged).
import 'package:drift/drift.dart' hide isNotNull, isNull;
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

  const preview = FilePreview(
    columns: ['Date', 'Amount', 'Balance'],
    rows: [
      {'Date': '01/03/2024', 'Amount': '100', 'Balance': '1100'},
      {'Date': '02/03/2024', 'Amount': '-30', 'Balance': '1070'},
    ],
    totalRows: 2,
    numberLocale: 'en_US',
  );
  const mappings = [
    ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
    ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
  ];

  group('a balance mode that is not a stored name is refused', () {
    test('import: nothing is written', () async {
      await expectLater(
        importer.importTransactions(preview: preview, mappings: mappings, accountId: acct, balanceMode: 'cumulativ'),
        throwsArgumentError,
      );
      expect(await db.select(db.transactions).get(), isEmpty);
      expect(await db.select(db.importConfigs).get(), isEmpty);
    });

    test('dry run', () async {
      await expectLater(
        importer.previewTransactionImport(preview: preview, mappings: mappings, accountId: acct, balanceMode: 'Column'),
        throwsArgumentError,
      );
    });

    test('pin: every stored name is accepted', () async {
      for (final mode in ['none', 'cumulative', 'column', 'filtered']) {
        final r = await importer.importTransactions(preview: preview, mappings: mappings, accountId: acct, balanceMode: mode);
        expect(r.importedRows, 2, reason: mode);
      }
    });
  });

  group('stored raw statement data that is not JSON', () {
    Future<void> stored(int day, double amount, String raw, {double? balance}) => db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: acct,
            operationDate: DateTime(2024, 2, day),
            valueDate: DateTime(2024, 2, day),
            amount: amount,
            balanceAfter: Value(balance),
            rawMetadata: Value(raw),
          ),
        );

    test('a re-run from stored rows leaves the row out', () async {
      await stored(1, 5, '{"Date":"01/02/2024","Amount":"5"}');
      await stored(2, 6, '{"Date": ');
      final rebuilt = await importer.previewFromStoredRows(acct, numberLocale: 'en_US');
      expect(rebuilt!.rows, [
        {'Date': '01/02/2024', 'Amount': '5'},
      ]);
    });

    test('the balance-difference seed falls back to the stored running balance', () async {
      await stored(28, 5, '{"Balance": ', balance: 1000);
      final r = await importer.importTransactions(
        preview: preview,
        mappings: const [
          ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
          ColumnMapping(targetField: 'amount', balanceDiffColumn: 'Balance'),
        ],
        accountId: acct,
      );
      expect(r.importedRows, 2);
      final rows = await (db.select(db.transactions)..orderBy([(t) => OrderingTerm.asc(t.operationDate)])).get();
      expect(rows.map((t) => t.amount), [5, 100, -30], reason: 'seeded on the stored balance 1000 before the file');
    });
  });
}
