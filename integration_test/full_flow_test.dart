import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Full flow: create account, navigate all screens, settings', (tester) async {
    final db = await pumpApp(tester);

    // 1. Create account
    await tester.tap(find.text('Accounts'));
    await settle(tester);

    await tester.tap(find.byType(FloatingActionButton).last);
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Fineco');
    await settle(tester);
    await tester.tap(find.text('Create'));
    await settle(tester);
    expect(find.text('Fineco'), findsOneWidget);

    // 2. Navigate to Assets
    await tester.tap(find.text('Assets'));
    await settle(tester);

    // 3. Navigate all tabs
    await tester.tap(find.text('Dashboard'));
    await settle(tester);

    await tester.tap(find.text('Adjustments'));
    await settle(tester);

    await tester.tap(find.text('Income'));
    await settle(tester);

    // 4. Open settings
    await tester.tap(find.byIcon(Icons.settings));
    await settle(tester);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Default Currency'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);

    // 5. Verify DB
    final accounts = await db.select(db.accounts).get();
    expect(accounts.length, 1);
    expect(accounts.first.name, 'Fineco');
  });
}
