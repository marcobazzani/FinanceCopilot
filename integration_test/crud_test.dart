import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Full CRUD: create account, seed asset with event, verify income', (tester) async {
    final db = await pumpApp(tester, seed: (db) async {
      final assetId = await seedAsset(db, name: 'Gold ETF', ticker: 'PHAU');
      await seedBuyEvent(db, assetId: assetId, date: DateTime(2024, 3, 15), amount: 1000.0, quantity: 5, price: 200.0);
      await seedIncome(db, amount: 2500);
    });

    // -- Account CRUD --
    await tester.tap(find.text('Accounts'));
    await settle(tester);

    // Create account (last FAB = main account FAB)
    await tester.tap(find.byType(FloatingActionButton).last);
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'Bank A');
    await settle(tester); // Let StatefulBuilder rebuild with non-empty text
    await tester.tap(find.text('Create'));
    await settle(tester);

    // Verify in DB
    var accounts = await db.select(db.accounts).get();
    expect(accounts.length, 2);
    expect(accounts.any((a) => a.name == 'Bank A'), isTrue);

    // Tap into detail
    await tester.tap(find.text('Bank A'));
    await settle(tester);
    expect(find.text('Bank A'), findsWidgets);

    // Go back
    await tester.tap(find.byType(BackButton));
    await settle(tester);

    // -- Asset verification --
    await tester.tap(find.text('Assets'));
    await settle(tester);
    expect(find.text('Gold ETF'), findsOneWidget);

    // Tap into detail
    await tester.tap(find.text('Gold ETF'));
    await settle(tester);
    expect(find.text('Gold ETF'), findsWidgets);

    // Verify event in DB
    final events = await db.select(db.assetEvents).get();
    expect(events.length, 1);
    expect(events.first.amount, 1000.0);

    // Go back
    await tester.tap(find.byType(BackButton));
    await settle(tester);

    // -- Income verification (tab inside Accounts) --
    await tester.tap(find.text('Accounts'));
    await settle(tester);
    await tester.tap(find.text('Income'));
    await settle(tester);
    expect(find.textContaining('2'), findsWidgets);
  });
}
