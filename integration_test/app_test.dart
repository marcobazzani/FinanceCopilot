import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App launches and shows AppShell with navigation', (tester) async {
    final db = await pumpApp(tester);

    // AppBar title
    expect(find.text('FinanceCopilot'), findsOneWidget);

    // NavigationRail destinations (wide layout in test)
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Accounts'), findsWidgets);
    expect(find.text('Assets'), findsWidgets);
    expect(find.text('Adjustments'), findsWidgets);
    expect(find.text('Income'), findsWidgets);

    // AppBar action icons
    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.byIcon(Icons.file_upload), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);

    await db.close();
  });
}
