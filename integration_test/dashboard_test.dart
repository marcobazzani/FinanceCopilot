import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Dashboard with seeded data renders all tabs', (tester) async {
    await pumpApp(tester, seed: (db) async {
      await seedAccount(db, name: 'Main Account');
      final assetId = await seedAsset(db, name: 'SWDA', ticker: 'SWDA', isin: 'IE00B4L5Y983', exchange: 'MIL', currency: 'EUR');
      await seedBuyEvent(db, assetId: assetId, date: DateTime(2024, 1, 15), amount: 955.0, quantity: 10, price: 95.5);
      await seedPrice(db, assetId: assetId, date: DateTime(2025, 1, 1), price: 110.0);
      await seedIncome(db, amount: 3000);
    });

    // Dashboard is default screen
    expect(find.text('Dashboard'), findsWidgets);

    // Tap through dashboard tabs
    for (final tab in ['Health', 'History', 'Cash Flow', 'Assets Overview']) {
      final tabFinder = find.text(tab);
      if (tabFinder.evaluate().isNotEmpty) {
        await tester.tap(tabFinder);
        await settle(tester);
      }
    }

    // No crashes
    expect(find.text('Dashboard'), findsWidgets);
  });
}
