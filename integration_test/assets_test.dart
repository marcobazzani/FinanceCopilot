import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Asset FAB opens create dialog', (tester) async {
    final db = await pumpApp(tester);

    // Navigate to Assets
    await tester.tap(find.text('Assets'));
    await tester.pumpAndSettle();

    // Empty state
    expect(find.textContaining('No assets yet'), findsOneWidget);

    // Tap FAB
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Dialog opens with search field
    expect(find.text('New Asset'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Dismiss
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await db.close();
  });

  testWidgets('Seeded asset appears in list and tappable', (tester) async {
    final db = await pumpApp(tester, seed: (db) async {
      await seedAsset(db, name: 'VWCE', ticker: 'VWCE.MI');
    });

    // Navigate to Assets
    await tester.tap(find.text('Assets'));
    await tester.pumpAndSettle();

    // Asset appears
    expect(find.text('VWCE'), findsOneWidget);

    // Tap asset → detail screen
    await tester.tap(find.text('VWCE'));
    await tester.pumpAndSettle();

    // AssetDetailScreen shows asset name
    expect(find.text('VWCE'), findsWidgets);

    await db.close();
  });
}
