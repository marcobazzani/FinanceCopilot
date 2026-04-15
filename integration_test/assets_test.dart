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
    await longSettle(tester);

    // Verify the event creation form opened
    expect(find.widgetWithText(TextFormField, 'Quantity *'), findsOneWidget,
      reason: 'Event creation form should be visible after FAB tap');

    // Fill quantity
    await tester.enterText(find.widgetWithText(TextFormField, 'Quantity *'), '10');
    await settle(tester);

    // Fill price
    await tester.enterText(find.widgetWithText(TextFormField, 'Price *'), '95.50');
    await settle(tester);

    // Dismiss soft keyboard so the Create Event button is visible
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);

    // Scroll to Create Event button (may be off-screen on small CI emulator)
    final createBtn = find.text('Create Event');
    await tester.ensureVisible(createBtn);
    await settle(tester);
    await tester.tap(createBtn);
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
