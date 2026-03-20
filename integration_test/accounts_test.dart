import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Create account via FAB dialog', (tester) async {
    final db = await pumpApp(tester);

    // Navigate to Accounts
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();

    // Empty state
    expect(find.textContaining('No accounts yet'), findsOneWidget);

    // Tap FAB
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Dialog opens
    expect(find.text('New Account'), findsOneWidget);

    // Enter name
    await tester.enterText(find.byType(TextField), 'Test Bank');
    await tester.pumpAndSettle();

    // Tap Create
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // Account appears in list
    expect(find.text('Test Bank'), findsOneWidget);

    await db.close();
  });

  testWidgets('Tap account navigates to detail screen', (tester) async {
    final db = await pumpApp(tester, seed: (db) async {
      await seedAccount(db, name: 'Fineco');
    });

    // Navigate to Accounts
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();

    // Tap the account
    await tester.tap(find.text('Fineco'));
    await tester.pumpAndSettle();

    // AccountDetailScreen shows account name in AppBar
    expect(find.text('Fineco'), findsWidgets);
    // Has Add Transaction button
    expect(find.byIcon(Icons.add), findsOneWidget);

    // Go back
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await db.close();
  });
}
