import 'package:drift/drift.dart';
import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Allocation tab renders with bond using cost basis',
      (tester) async {
    await pumpApp(tester, seed: (db) async {
      await seedAccount(db, name: 'Main Account');

      // Bond with cost basis but no market price
      final bondId = await db.into(db.assets).insert(AssetsCompanion.insert(
            name: 'IPI Bond',
            assetType: AssetType.stockEtf,
            instrumentType: const Value(InstrumentType.bond),
            assetClass: const Value(AssetClass.fixedIncome),
            valuationMethod: ValuationMethod.marketPrice,
            isin: const Value('IT0005661498'),
            currency: const Value('EUR'),
            sortOrder: const Value(1),
          ));
      await seedBuyEvent(db,
          assetId: bondId,
          date: DateTime(2024, 6, 1),
          amount: 9800.0,
          quantity: 10000,
          price: 98.0);

      // ETF with a market price (ensures the tab renders)
      final etfId = await seedAsset(db,
          name: 'SWDA', ticker: 'SWDA', isin: 'IE00B4L5Y983', currency: 'EUR');
      await seedBuyEvent(db,
          assetId: etfId,
          date: DateTime(2024, 1, 15),
          amount: 955.0,
          quantity: 10,
          price: 95.5);
      await seedPrice(db,
          assetId: etfId, date: DateTime(2025, 1, 1), price: 110.0);
    });

    // Tap the last dashboard tab (Assets Overview / Allocation)
    final tabs = find.byType(Tab);
    expect(tabs, findsWidgets);
    await tester.tap(tabs.last);
    await settle(tester);

    // Asset Class chart card visible means allocation rendered
    expect(find.text('Asset Class'), findsOneWidget);
  });
}
