import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:finance_copilot/services/import_service.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Import: 3 consecutive transaction imports with dedup', (tester) async {
    final db = await pumpApp(tester, seed: (db) async {
      await seedAccount(db, name: 'Dedup Account');
    });

    final importer = ImportService(db);
    final accounts = await db.select(db.accounts).get();
    final accountId = accounts.firstWhere((a) => a.name == 'Dedup Account').id;

    final mappings = [
      const ColumnMapping(sourceColumn: 'Data_Operazione', targetField: 'date'),
      const ColumnMapping(sourceColumn: 'Data_Valuta', targetField: 'valueDate'),
      const ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
      const ColumnMapping(sourceColumn: 'Description', targetField: 'description'),
    ];

    // Import 1: January transactions
    late FilePreview p1;
    await tester.runAsync(() async {
      p1 = await parseFixture(db, 'dedup_import1.csv');
    });
    var result = await importer.importTransactions(
      preview: p1, mappings: mappings, accountId: accountId,
    );
    expect(result.importedRows, 3);
    var txs = await db.select(db.transactions).get();
    expect(txs.length, 3);

    // Import 2: January + February (overlaps with import 1)
    // Wipes Jan onward, re-inserts 5 rows — total 5, not 8
    late FilePreview p2;
    await tester.runAsync(() async {
      p2 = await parseFixture(db, 'dedup_import2.csv');
    });
    result = await importer.importTransactions(
      preview: p2, mappings: mappings, accountId: accountId,
    );
    expect(result.importedRows, 5);
    txs = await db.select(db.transactions).get();
    expect(txs.length, 5);
    expect(txs.any((t) => t.description == 'Groceries Updated' && t.amount == -55.00), isTrue);
    expect(txs.any((t) => t.description == 'Groceries' && t.amount == -50.00), isFalse);

    // Import 3: Only February (narrower range)
    // Wipes from Feb 10 onward, keeps Jan rows from import 2
    late FilePreview p3;
    await tester.runAsync(() async {
      p3 = await parseFixture(db, 'dedup_import3.csv');
    });
    result = await importer.importTransactions(
      preview: p3, mappings: mappings, accountId: accountId,
    );
    expect(result.importedRows, 3);
    txs = await db.select(db.transactions).get();
    // Jan: 3 rows preserved, Feb: 3 rows from import 3
    expect(txs.length, 6);
    expect(txs.any((t) => t.description == 'Groceries Updated'), isTrue);
    expect(txs.any((t) => t.description == 'Salary Jan'), isTrue);
    expect(txs.any((t) => t.description == 'Utilities'), isTrue);
    expect(txs.any((t) => t.description == 'Insurance'), isTrue);
    expect(txs.any((t) => t.description == 'Salary Feb'), isTrue);
    expect(txs.any((t) => t.description == 'Phone Bill'), isTrue);
    // No duplicates
    expect(txs.where((t) => t.description == 'Insurance').length, 1);
    expect(txs.where((t) => t.description == 'Salary Feb').length, 1);
  });
}
