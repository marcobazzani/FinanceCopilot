@Tags(['live'])
library;

import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';

import 'helpers/test_app.dart';

/// These tests hit real APIs (Investing.com, justETF).
/// Run with: flutter test integration_test/live_data_fetch_test.dart -d macos
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Full price pipeline: stock ETF, bond ETF, bonds, ETC', (tester) async {
    final db = await pumpApp(tester, seed: (db) async {
      // 1. Stock ETF — iShares MSCI World (Milan)
      final a1 = await seedAsset(db,
        name: 'iShares MSCI World', isin: 'IE00B4L5Y983',
        ticker: 'SWDA', exchange: 'MIL', currency: 'EUR');
      await seedBuyEvent(db, assetId: a1, date: DateTime(2024, 1, 15),
        amount: 955.0, quantity: 10, price: 95.5);

      // 2. Bond ETF — iShares EUR Govt Bond 1-3yr (Milan)
      final a2 = await seedAsset(db,
        name: 'iShares EUR Govt 1-3', isin: 'IE00B14X4Q57',
        ticker: 'IBGS', exchange: 'MIL', currency: 'EUR');
      await seedBuyEvent(db, assetId: a2, date: DateTime(2024, 3, 1),
        amount: 1500.0, quantity: 10, price: 150.0);

      // 3. Italian Government Bond — BTP 2.8% 2028
      final a3 = await _seedBond(db,
        name: 'BTP 2.80% 2028', isin: 'IT0005340929',
        exchange: 'MIL', currency: 'EUR');
      await seedBuyEvent(db, assetId: a3, date: DateTime(2024, 2, 1),
        amount: 9800.0, quantity: 100, price: 98.0);

      // 4. EU Bond — European Union 3.375% 2042 (Milan)
      final a4 = await _seedBond(db,
        name: 'EU 3.375% 2042', isin: 'EU000A3K4DV0',
        exchange: 'MIL', currency: 'EUR');
      await seedBuyEvent(db, assetId: a4, date: DateTime(2024, 4, 1),
        amount: 9500.0, quantity: 100, price: 95.0);

      // 5. US Treasury Bond — iShares $ Treasury 1-3yr (Milan)
      final a5 = await seedAsset(db,
        name: 'iShares USD Treasury 1-3', isin: 'IE00B3VWN179',
        ticker: 'CSBGU3', exchange: 'MIL', currency: 'EUR');
      await seedBuyEvent(db, assetId: a5, date: DateTime(2024, 1, 15),
        amount: 1080.0, quantity: 10, price: 108.0);

      // 6. ETC — WisdomTree Physical Gold (Milan)
      final a6 = await seedAsset(db,
        name: 'WisdomTree Physical Gold', isin: 'JE00B1VS3770',
        ticker: 'PHAU', exchange: 'MIL', currency: 'EUR');
      await seedBuyEvent(db, assetId: a6, date: DateTime(2024, 1, 15),
        amount: 1700.0, quantity: 10, price: 170.0);

      // 7. US Stock — Amazon (NYSE)
      final a7 = await seedAsset(db,
        name: 'Amazon', isin: 'US0231351067',
        ticker: 'AMZN', exchange: 'NYQ', currency: 'USD');
      await seedBuyEvent(db, assetId: a7, date: DateTime(2024, 6, 1),
        amount: 1800.0, quantity: 10, price: 180.0);

      // 8. Emerging Markets ETF — iShares Core MSCI EM (Milan)
      final a8 = await seedAsset(db,
        name: 'iShares Core MSCI EM', isin: 'IE00BKM4GZ66',
        ticker: 'EIMI', exchange: 'MIL', currency: 'EUR');
      await seedBuyEvent(db, assetId: a8, date: DateTime(2024, 3, 1),
        amount: 400.0, quantity: 10, price: 40.0);

      // 9. Commodity ETC — UBS CMCI Composite (Milan)
      final a9 = await seedAsset(db,
        name: 'UBS CMCI Composite', isin: 'IE00B53H0131',
        ticker: 'CCUSAS', exchange: 'MIL', currency: 'EUR');
      await seedBuyEvent(db, assetId: a9, date: DateTime(2024, 5, 1),
        amount: 1050.0, quantity: 10, price: 105.0);

      // 10. Small Cap ETF — Xtrackers MSCI EU Small Cap (Xetra)
      final a10 = await seedAsset(db,
        name: 'Xtrackers EU Small Cap', isin: 'LU0322253906',
        ticker: 'XXSC', exchange: 'XETRA', currency: 'EUR');
      await seedBuyEvent(db, assetId: a10, date: DateTime(2024, 2, 15),
        amount: 670.0, quantity: 10, price: 67.0);

      // 11. Italian Stock — ENEL (Milan)
      final a11 = await _seedStock(db,
        name: 'ENEL', isin: 'IT0003128367',
        ticker: 'ENEL', exchange: 'MIL', currency: 'EUR');
      await seedBuyEvent(db, assetId: a11, date: DateTime(2024, 3, 1),
        amount: 650.0, quantity: 100, price: 6.5);

      // 12. EU Stock — SAP (Xetra)
      final a12 = await _seedStock(db,
        name: 'SAP SE', isin: 'DE0007164600',
        ticker: 'SAP', exchange: 'XETRA', currency: 'EUR');
      await seedBuyEvent(db, assetId: a12, date: DateTime(2024, 4, 1),
        amount: 1800.0, quantity: 10, price: 180.0);
    }, useRealServices: true);

    // Wait for background sync — 10 assets, real HTTP
    // syncPrices resolves CIDs + fetches history; syncCompositions fetches TER
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 45)));
    await settle(tester);

    // -- Verify prices for each asset --
    final assets = await db.select(db.assets).get();
    expect(assets.length, 12, reason: 'Should have 12 seeded assets');

    int assetsWithPrices = 0;
    int assetsWithTer = 0;
    final results = <String>[];

    for (final asset in assets) {
      final prices = await (db.select(db.marketPrices)
        ..where((p) => p.assetId.equals(asset.id))).get();
      final hasPrices = prices.isNotEmpty;
      if (hasPrices) assetsWithPrices++;

      final hasTer = asset.ter != null && asset.ter! > 0;
      if (hasTer) assetsWithTer++;

      final priceRange = hasPrices
        ? '${prices.length} pts, ${prices.map((p) => p.closePrice).reduce((a, b) => a < b ? a : b).toStringAsFixed(2)}-${prices.map((p) => p.closePrice).reduce((a, b) => a > b ? a : b).toStringAsFixed(2)}'
        : 'NO PRICES';

      results.add('${asset.name} [${asset.isin}]: $priceRange${hasTer ? " TER=${asset.ter}%" : ""}');
    }

    // Print results for debugging
    for (final r in results) {
      // ignore: avoid_print
      print('  $r');
    }

    // At least 9 out of 12 should have prices
    expect(assetsWithPrices, greaterThanOrEqualTo(9),
      reason: 'At least 9/12 assets should have prices. Results:\n${results.join("\n")}');

    // ETFs should have TER (bonds/stocks don't)
    expect(assetsWithTer, greaterThanOrEqualTo(3),
      reason: 'At least 3 ETFs should have TER. Results:\n${results.join("\n")}');

    // -- Verify bond prices are quoted as % of face value (0-200 range, not 5000+) --
    final btpAsset = assets.where((a) => a.isin == 'IT0005340929').firstOrNull;
    if (btpAsset != null) {
      final btpPrices = await (db.select(db.marketPrices)
        ..where((p) => p.assetId.equals(btpAsset.id))).get();
      if (btpPrices.isNotEmpty) {
        final btpLatest = btpPrices.last.closePrice;
        expect(btpLatest, greaterThan(50), reason: 'BTP price should be >50 (% of face)');
        expect(btpLatest, lessThan(200), reason: 'BTP price should be <200 (% of face)');
        results.add('  BTP price check: $btpLatest (expected 50-200 range)');
      }
    }

    // Verify historical backfill for SWDA (oldest buy date Jan 2024)
    // Note: On weekends/holidays the API may return fewer historical data
    // points for some instrument types. Use a resilient assertion.
    final swdaPrices = await (db.select(db.marketPrices)
      ..where((p) => p.assetId.equals(assets.firstWhere((a) => a.isin == 'IE00B4L5Y983').id))).get();
    if (swdaPrices.isNotEmpty) {
      if (swdaPrices.length > 1) {
        final oldest = swdaPrices.map((p) => p.date).reduce((a, b) => a.isBefore(b) ? a : b);
        expect(oldest.year, lessThanOrEqualTo(2024),
          reason: 'SWDA backfill should reach 2024 (got ${swdaPrices.length} prices, oldest: $oldest)');
      }
      final latest = swdaPrices.last.closePrice;
      expect(latest, greaterThan(50), reason: 'SWDA price should be > 50');
      expect(latest, lessThan(500), reason: 'SWDA price should be < 500');
    }

    // Verify compositions exist for at least some ETFs
    final compositions = await db.select(db.assetCompositions).get();
    if (compositions.isNotEmpty) {
      expect(compositions.length, greaterThan(5),
        reason: 'Should have composition entries from multiple ETFs');
    }
  });
}

/// Seed a stock asset (instrumentType: stock, assetClass: equity).
Future<int> _seedStock(
  AppDatabase db, {
  required String name,
  required String isin,
  String? ticker,
  String exchange = 'MIL',
  String currency = 'EUR',
}) async {
  return db.into(db.assets).insert(AssetsCompanion.insert(
    name: name,
    assetType: AssetType.stockEtf,
    instrumentType: const Value(InstrumentType.stock),
    assetClass: const Value(AssetClass.equity),
    valuationMethod: ValuationMethod.marketPrice,
    isin: Value(isin),
    ticker: Value(ticker),
    exchange: Value(exchange),
    currency: Value(currency),
    sortOrder: const Value(1),
  ));
}

/// Seed a bond asset (instrumentType: bond, assetClass: fixedIncome).
Future<int> _seedBond(
  AppDatabase db, {
  required String name,
  required String isin,
  String exchange = 'MIL',
  String currency = 'EUR',
}) async {
  return db.into(db.assets).insert(AssetsCompanion.insert(
    name: name,
    assetType: AssetType.stockEtf,
    instrumentType: const Value(InstrumentType.bond),
    assetClass: const Value(AssetClass.fixedIncome),
    valuationMethod: ValuationMethod.marketPrice,
    isin: Value(isin),
    exchange: Value(exchange),
    currency: Value(currency),
    sortOrder: const Value(1),
  ));
}
