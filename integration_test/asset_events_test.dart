import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Navigate to asset detail screen', (tester) async {
    await pumpApp(tester, seed: (db) async {
      await seedAsset(db, name: 'S&P 500 ETF', ticker: 'SPY');
    });

    // Navigate to Assets
    await tester.tap(find.text('Assets'));
    await settle(tester);

    // Tap asset
    await tester.tap(find.text('S&P 500 ETF'));
    await settle(tester);

    // AssetDetailScreen shows — has edit and delete icons
    expect(find.byIcon(Icons.edit), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    // Info card shows currency chip
    expect(find.text('EUR'), findsWidgets);

  });
}
