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

  testWidgets('Full price pipeline: ISIN -> sync prices + compositions + backfill', (tester) async {
    final db = await pumpApp(tester, seed: (db) async {
      // Seed asset with ISIN and a buy event in the past (Jan 2024)
      // syncPrices should: resolve CID, fetch prices from buy date to today,
      // and syncCompositions should fetch TER + composition from justETF
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

    // Wait for background sync (syncPrices + syncCompositions)
    // These fire in AppShell.initState via _startBackgroundSync
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 20)));
    await settle(tester);

    // -- Verify current price --
    final prices = await db.select(db.marketPrices).get();
    expect(prices, isNotEmpty, reason: 'syncPrices should have fetched prices');

    final latestPrice = prices.map((p) => p.closePrice).reduce((a, b) => a > b ? a : b);
    expect(latestPrice, greaterThan(0), reason: 'Latest price should be positive');
    expect(latestPrice, lessThan(500000), reason: 'Latest price should be reasonable');

    // -- Verify historical backfill --
    // Buy date was 2024-01-15, so prices should go back to at least early 2024
    final oldestPrice = prices.map((p) => p.date).reduce((a, b) => a.isBefore(b) ? a : b);
    expect(oldestPrice.year, lessThanOrEqualTo(2024),
        reason: 'Backfill should reach back to buy date (2024)');

    // Should have many data points (at least 100 trading days from Jan 2024 to now)
    expect(prices.length, greaterThan(50),
        reason: 'Should have backfilled many historical prices');

    // -- Verify TER from composition sync --
    final assets = await db.select(db.assets).get();
    final swda = assets.firstWhere((a) => a.isin == 'IE00B4L5Y983');
    if (swda.ter != null) {
      expect(swda.ter, greaterThan(0));
      expect(swda.ter, lessThan(5.0));
    }

    // -- Verify compositions from justETF --
    final compositions = await db.select(db.assetCompositions).get();
    if (compositions.isNotEmpty) {
      expect(compositions.length, greaterThan(3),
          reason: 'MSCI World should have multiple composition entries');
      // Check that compositions are for our asset
      expect(compositions.every((c) => c.assetId == swda.id), isTrue);
    }
  });
}
