import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Tap all 5 nav destinations and verify screens', (tester) async {
    final db = await pumpApp(tester);

    // Dashboard is default — charts area (DashboardScreen renders)
    expect(find.text('Dashboard'), findsWidgets);

    // Tap Accounts
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    // Accounts screen has a FAB with add icon
    expect(find.byIcon(Icons.add), findsOneWidget);

    // Tap Assets
    await tester.tap(find.text('Assets'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add), findsOneWidget);

    // Tap Adjustments
    await tester.tap(find.text('Adjustments'));
    await tester.pumpAndSettle();
    // CapexScreen has a TabBar with these tabs
    expect(find.text('Saving Spent'), findsOneWidget);
    expect(find.text('Donation Spent'), findsOneWidget);

    // Tap Income
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    // Income empty state
    expect(find.textContaining('No income records yet'), findsOneWidget);

    // Back to Dashboard
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();

    await db.close();
  });
}
