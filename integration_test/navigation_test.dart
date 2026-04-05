import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Tap all 5 nav destinations and verify screens', (tester) async {
    await pumpApp(tester);

    // Dashboard is default
    expect(find.text('Dashboard'), findsWidgets);

    // Tap Accounts
    await tester.tap(find.text('Accounts'));
    await settle(tester);
    expect(find.byIcon(Icons.add), findsWidgets);

    // Tap Assets
    await tester.tap(find.text('Assets'));
    await settle(tester);
    expect(find.byIcon(Icons.add), findsWidgets);

    // Tap Adjustments
    await tester.tap(find.text('Adjustments'));
    await settle(tester);

    // Tap Income
    await tester.tap(find.text('Income'));
    await settle(tester);

    // Back to Dashboard
    await tester.tap(find.text('Dashboard'));
    await settle(tester);
  });
}
