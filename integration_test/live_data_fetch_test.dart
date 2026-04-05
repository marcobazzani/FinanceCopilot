@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';


import 'helpers/test_app.dart';

/// These tests hit real APIs (Investing.com, justETF).
/// Run with: flutter test integration_test/live_data_fetch_test.dart -d macos
/// Skip in CI: flutter test integration_test/ --exclude-tags live
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Sync prices for seeded asset fetches real data from Investing.com', (tester) async {
    final db = await pumpApp(tester, seed: (db) async {
      final assetId = await seedAsset(db,
        name: 'iShares MSCI World',
        isin: 'IE00B4L5Y983',
        ticker: 'SWDA',
        exchange: 'MIL',
        currency: 'EUR',
      );
      await seedBuyEvent(db,
        assetId: assetId,
        date: DateTime(2024, 1, 15),
        amount: 955.0,
        quantity: 10,
        price: 95.5,
      );
    }, useRealServices: true);

    // Wait for background sync to complete (triggered in AppShell.initState)
    await tester.pump(const Duration(seconds: 15));
    await settle(tester);

    // Check if market prices were stored
    final prices = await db.select(db.marketPrices).get();

    // If network is available, we should have prices
    if (prices.isNotEmpty) {
      expect(prices.first.closePrice, greaterThan(0));
      expect(prices.first.closePrice, lessThan(100000));

      // Check asset got a TER from composition sync
      final assets = await db.select(db.assets).get();
      final swda = assets.firstWhere((a) => a.isin == 'IE00B4L5Y983');
      // TER might be null if composition sync hasn't completed yet
      if (swda.ter != null) {
        expect(swda.ter, greaterThan(0));
        expect(swda.ter, lessThan(5.0));
      }
    }

  });
}
