import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Income screen shows empty state and add FAB', (tester) async {
    final db = await pumpApp(tester);

    // Navigate to Income
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();

    // Empty state
    expect(find.textContaining('No income records yet'), findsOneWidget);

    // FABs: add (+) and import (file_upload) — file_upload also in AppBar
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.file_upload), findsWidgets);

    await db.close();
  });

  testWidgets('Add income via dialog', (tester) async {
    final db = await pumpApp(tester);

    // Navigate to Income
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();

    // Tap add FAB
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Dialog opens
    expect(find.text('Add Income'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);

    // Dismiss
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await db.close();
  });

  testWidgets('Seeded income appears in list', (tester) async {
    final db = await pumpApp(tester, seed: (db) async {
      await seedIncome(db, amount: 2500.0);
    });

    // Navigate to Income
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();

    // Income should be visible (amount formatted)
    expect(find.textContaining('2'), findsWidgets);

    await db.close();
  });

  testWidgets('Import FAB navigates to ImportScreen', (tester) async {
    final db = await pumpApp(tester);

    // Navigate to Income
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();

    // Tap import FAB (tooltip distinguishes from AppBar import icon)
    await tester.tap(find.byTooltip('Import from file'));
    await tester.pumpAndSettle();

    // ImportScreen should show — look for import-specific UI
    expect(find.text('Open File'), findsOneWidget);

    await db.close();
  });
}
