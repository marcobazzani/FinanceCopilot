import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Accounts: create, verify, navigate to detail', (tester) async {
    await pumpApp(tester);

    // Navigate to Accounts
    await tester.tap(find.text('Accounts'));
    await settle(tester);

    // Empty state
    expect(find.textContaining('No accounts yet'), findsOneWidget);

    // Tap the main FAB to create account
    await tester.tap(find.byType(FloatingActionButton).last);
    await settle(tester);

    // Enter name and create
    await tester.enterText(find.byType(TextField), 'Fineco');
    await settle(tester);
    await tester.tap(find.text('Create'));
    await settle(tester);

    // Account appears in list
    expect(find.text('Fineco'), findsOneWidget);

    // Tap into detail screen
    await tester.tap(find.text('Fineco'));
    await settle(tester);

    // Detail screen shows account name
    expect(find.text('Fineco'), findsWidgets);
    expect(find.byIcon(Icons.add), findsOneWidget);

    // Go back
    await tester.tap(find.byType(BackButton));
    await settle(tester);
  });
}
