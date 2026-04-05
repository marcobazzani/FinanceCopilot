import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:finance_copilot/services/import_service.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Import: transactions, asset events, and wipe-and-replace', (tester) async {
    final db = await pumpApp(tester, seed: (db) async {
      await seedAccount(db, name: 'Fineco');
    });

    final importer = ImportService(db);
    final accounts = await db.select(db.accounts).get();
    final accountId = accounts.first.id;

    // -- Import transactions --
    final txPreview = makePreview('''Date,Amount,Description
15/01/2024,-42.50,Supermarket
16/01/2024,1500.00,Salary
17/01/2024,-120.00,Electricity bill''');

    final txResult = await importer.importTransactions(
      preview: txPreview,
      mappings: const [
        ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
        ColumnMapping(sourceColumn: 'Description', targetField: 'description'),
      ],
      accountId: accountId,
    );

    expect(txResult.importedRows, 3);
    expect(txResult.errorRows, 0);

    var transactions = await db.select(db.transactions).get();
    expect(transactions.length, 3);
    expect(transactions.any((t) => t.description == 'Supermarket'), isTrue);

    // -- Import asset events --
    final assetPreview = makePreview('''date,isin,quantity,price,currency,amount
2024-01-15,IE00B4L5Y983,10,95.50,EUR,955.00
2024-03-01,IE00B4L5Y983,5,98.20,EUR,491.00
2024-01-15,LU0908500753,20,210.50,EUR,4210.00''');

    final assetResult = await importer.importAssetEventsGrouped(
      preview: assetPreview,
      mappings: const [
        ColumnMapping(sourceColumn: 'date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'isin', targetField: 'isin'),
        ColumnMapping(sourceColumn: 'quantity', targetField: 'quantity'),
        ColumnMapping(sourceColumn: 'price', targetField: 'price'),
        ColumnMapping(sourceColumn: 'currency', targetField: 'currency'),
        ColumnMapping(sourceColumn: 'amount', targetField: 'amount'),
      ],
      baseCurrency: 'EUR',
    );

    expect(assetResult.result.importedRows, 3);
    expect(assetResult.assetsByIsin.length, 2);

    // -- Wipe-and-replace transactions --
    final txPreview2 = makePreview('''Date,Amount,Description
15/01/2024,-50.00,Grocery
16/01/2024,1600.00,Bonus''');

    await importer.importTransactions(
      preview: txPreview2,
      mappings: const [
        ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
        ColumnMapping(sourceColumn: 'Description', targetField: 'description'),
      ],
      accountId: accountId,
    );

    transactions = await db.select(db.transactions).get();
    expect(transactions.length, 2);
    expect(transactions.any((t) => t.description == 'Grocery'), isTrue);
    expect(transactions.any((t) => t.description == 'Supermarket'), isFalse);

    // Verify imported assets appear on screen
    await tester.tap(find.text('Assets'));
    await settle(tester);
    // Assets created from ISIN import — ISIN used as name when lookup is stubbed
    expect(find.textContaining('IE00B4L5Y983'), findsWidgets);
  });
}
