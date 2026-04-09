import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:finance_copilot/database/database.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Account: delete via detail screen icon', (tester) async {
    await pumpApp(tester, seed: (db) async {
      await seedAccount(db, name: 'ToDelete');
    });

    // Navigate to Accounts
    await tester.tap(find.text('Accounts'));
    await settle(tester);
    expect(find.text('ToDelete'), findsOneWidget);

    // Open account detail
    await tester.tap(find.text('ToDelete'));
    await settle(tester);

    // Tap red delete icon in app bar
    await tester.tap(find.byIcon(Icons.delete_outline));
    await settle(tester);

    // Confirmation dialog appears
    expect(find.text('Delete Account?'), findsOneWidget);

    // Confirm deletion
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);

    // Back on accounts list — account is gone
    expect(find.text('ToDelete'), findsNothing);
  });

  testWidgets('Asset: delete via detail screen icon', (tester) async {
    await pumpApp(tester, seed: (db) async {
      await seedAsset(db, name: 'DeleteMe ETF', ticker: 'DEL');
    });

    // Navigate to Assets
    await tester.tap(find.text('Assets'));
    await settle(tester);
    expect(find.text('DeleteMe ETF'), findsOneWidget);

    // Open asset detail
    await tester.tap(find.text('DeleteMe ETF'));
    await settle(tester);

    // Tap red delete icon in app bar
    await tester.tap(find.byIcon(Icons.delete_outline));
    await settle(tester);

    // Confirmation dialog appears
    expect(find.text('Delete Asset?'), findsOneWidget);

    // Confirm deletion
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);

    // Back on assets list — asset is gone
    expect(find.text('DeleteMe ETF'), findsNothing);
  });

  testWidgets('Income: delete via edit dialog trash icon', (tester) async {
    await pumpApp(tester, seed: (db) async {
      await seedIncome(db, amount: 7777.0);
    });

    // Navigate to Income
    await tester.tap(find.text('Income'));
    await settle(tester);
    expect(find.textContaining('7'), findsWidgets);

    // Tap the income entry to open edit dialog
    final listTile = find.byType(ListTile).last;
    await tester.tap(listTile);
    await settle(tester);

    // Edit dialog should be open — find the red delete icon
    expect(find.byIcon(Icons.delete), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete));
    await settle(tester);

    // Confirmation dialog appears
    expect(find.text('Delete Income?'), findsOneWidget);

    // Confirm deletion
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);

    // Income should be gone from the list
    expect(find.textContaining('7,777'), findsNothing);
    expect(find.textContaining('7.777'), findsNothing);
  });

  testWidgets('Income: long press no longer triggers delete', (tester) async {
    await pumpApp(tester, seed: (db) async {
      await seedIncome(db, amount: 3333.0);
    });

    // Navigate to Income
    await tester.tap(find.text('Income'));
    await settle(tester);

    // Long press on the income entry
    final listTile = find.byType(ListTile).last;
    await tester.longPress(listTile);
    await settle(tester);

    // No delete confirmation dialog should appear
    expect(find.text('Delete Income?'), findsNothing);
  });

  testWidgets('Transaction: delete via edit screen icon', (tester) async {
    await pumpApp(tester, seed: (db) async {
      final acctId = await seedAccount(db, name: 'TxnAcct');
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
        accountId: acctId,
        operationDate: DateTime(2025, 3, 1),
        valueDate: DateTime(2025, 3, 1),
        description: const Value('Test Payment'),
        amount: -50.0,
      ));
    });

    // Navigate to Accounts
    await tester.tap(find.text('Accounts'));
    await settle(tester);

    // Open account detail
    await tester.tap(find.text('TxnAcct'));
    await settle(tester);

    // Tap the transaction to open edit screen
    await tester.tap(find.text('Test Payment'));
    await settle(tester);

    // Tap red delete icon in app bar
    await tester.tap(find.byIcon(Icons.delete_outline));
    await settle(tester);

    // Confirmation dialog
    expect(find.text('Delete Transaction?'), findsOneWidget);

    // Confirm
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);

    // Transaction gone from account detail
    expect(find.text('Test Payment'), findsNothing);
  });
}
