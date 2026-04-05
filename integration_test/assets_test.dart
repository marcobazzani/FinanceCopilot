import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Assets: create asset, add buy event, verify in DB', (tester) async {
    final db = await pumpApp(tester, seed: (db) async {
      await seedAsset(db, name: 'VWCE', ticker: 'VWCE.MI', isin: 'IE00BK5BQT80');
    });

    // Navigate to Assets
    await tester.tap(find.text('Assets'));
    await settle(tester);
    expect(find.text('VWCE'), findsOneWidget);

    // Tap into asset detail
    await tester.tap(find.text('VWCE'));
    await settle(tester);
    expect(find.text('VWCE'), findsWidgets);
    expect(find.textContaining('0 events'), findsOneWidget);

    // Tap FAB to add event
    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);

    // Fill quantity
    final quantityField = find.widgetWithText(TextFormField, 'Quantity *');
    await tester.enterText(quantityField, '10');
    await settle(tester);

    // Fill price
    final priceField = find.widgetWithText(TextFormField, 'Price *');
    await tester.enterText(priceField, '95.50');
    await settle(tester);

    // Tap Create Event
    await tester.tap(find.text('Create Event'));
    await settle(tester);

    // Verify event in DB
    final events = await db.select(db.assetEvents).get();
    expect(events.length, 1);
    expect(events.first.quantity, 10.0);
    expect(events.first.price, 95.5);

    // Go back to assets list
    await tester.tap(find.byType(BackButton));
    await settle(tester);
  });
}
