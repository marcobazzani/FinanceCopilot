import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Tap all top-level nav destinations and the Accounts inner tabs', (tester) async {
    await pumpApp(tester);

    // Dashboard is default
    expect(find.text('Dashboard'), findsWidgets);

    // Tap Accounts — this is now the only place Income and Adjustments live.
    await tester.tap(find.text('Accounts'));
    await settle(tester);
    expect(find.byIcon(Icons.add), findsWidgets);

    // Inside Accounts: inner TabBar has Accounts / Income / Adjustments tabs.
    await tester.tap(find.text('Income'));
    await settle(tester);

    await tester.tap(find.text('Adjustments'));
    await settle(tester);

    // Switch to Assets.
    await tester.tap(find.text('Assets'));
    await settle(tester);
    expect(find.byIcon(Icons.add), findsWidgets);

    // Back to Dashboard
    await tester.tap(find.text('Dashboard'));
    await settle(tester);
  });
}
