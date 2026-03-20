import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Navigate to account detail and tap add transaction', (tester) async {
    final db = await pumpApp(tester, seed: (db) async {
      await seedAccount(db, name: 'Savings');
    });

    // Navigate to Accounts
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();

    // Tap account
    await tester.tap(find.text('Savings'));
    await tester.pumpAndSettle();

    // We're on AccountDetailScreen — has add button in AppBar
    expect(find.byIcon(Icons.add), findsOneWidget);

    // Tap add transaction
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // TransactionEditScreen opens — look for save/confirm button
    // The edit screen should have date and amount fields
    expect(find.byType(TextFormField).evaluate().isNotEmpty ||
           find.byType(TextField).evaluate().isNotEmpty, isTrue);

    await db.close();
  });
}
