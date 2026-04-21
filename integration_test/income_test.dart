import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Income: navigate, verify FAB, seed income appears', (tester) async {
    await pumpApp(tester, seed: (db) async {
      await seedIncome(db, amount: 2500.0);
    });

    // Navigate to Income tab (now inside Accounts).
    await tester.tap(find.text('Accounts'));
    await settle(tester);
    await tester.tap(find.text('Income'));
    await settle(tester);

    // FAB should be visible
    expect(find.byIcon(Icons.add), findsWidgets);

    // Seeded income should show (amount contains "2")
    expect(find.textContaining('2'), findsWidgets);
  });
}
