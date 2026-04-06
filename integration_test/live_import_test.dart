@Tags(['live'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

/// Live import test: real ISIN lookup + import with some unknown ISINs.
/// Requires network access. Run with:
///   flutter test integration_test/live_import_test.dart -d macos
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Live import: real ISIN lookup with valid + unknown ISINs', (tester) async {
    final db = await pumpApp(tester, useRealServices: true);

    await tester.tap(find.byIcon(Icons.file_upload));
    await settle(tester);

    // Switch to Asset Event target
    await tester.tap(find.text('Asset Event'));
    await settle(tester);

    // Mix of real ISINs and one fake
    const csv = 'date,isin,quantity,price,currency,amount\n'
        '2025-01-10,IE00B4L5Y983,10,95.00,EUR,950.00\n'     // iShares MSCI World (real)
        '2025-01-10,LU0908500753,20,210.00,EUR,4200.00\n'    // Amundi Stoxx 600 (real)
        '2025-01-10,XX00FAKE1234,5,100.00,EUR,500.00\n';     // Fake ISIN
    await Clipboard.setData(const ClipboardData(text: csv));
    await tester.tap(find.text('Paste from Clipboard'));
    await settle(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Switch type to "From sign" (no type column)
    await tester.drag(find.byType(ListView).first, const Offset(0, -200));
    await settle(tester);
    await tester.tap(find.text('From sign (+/-)'));
    await settle(tester);

    // Scroll to Next
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await settle(tester);

    // Next -> confirm step (triggers real ISIN lookup)
    await tester.tap(find.text('Next'));
    await settle(tester);

    // Wait for real network ISIN lookup to complete
    await waitForNetwork(tester, seconds: 15);

    // Verify: real ISINs should show exchanges, fake should show "not found"
    expect(find.text('IE00B4L5Y983'), findsOneWidget);
    expect(find.text('LU0908500753'), findsOneWidget);
    expect(find.text('XX00FAKE1234'), findsOneWidget);

    // The real ISINs should have ticker info visible
    // (e.g., "SWDA — Milano" or similar exchange listing)
    // The fake one should show "Not found" or similar
    // We verify indirectly: after import, the real ISINs get proper tickers

    // Import
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Import Complete'), findsOneWidget);

    // Verify assets created
    final assets = await db.select(db.assets).get();
    final realAssets = assets.where((a) => a.name != '_test_seed').toList();

    // All 3 ISINs should have assets (including the fake one)
    expect(realAssets.length, 3);

    // Real ISINs should have proper tickers from lookup
    final worldEtf = realAssets.firstWhere((a) => a.isin == 'IE00B4L5Y983');
    expect(worldEtf.ticker, isNotNull);
    expect(worldEtf.ticker, isNotEmpty);

    final stoxxEtf = realAssets.firstWhere((a) => a.isin == 'LU0908500753');
    expect(stoxxEtf.ticker, isNotNull);
    expect(stoxxEtf.ticker, isNotEmpty);

    // Fake ISIN: should still be imported but without ticker
    final fakeAsset = realAssets.firstWhere((a) => a.isin == 'XX00FAKE1234');
    expect(fakeAsset.ticker, anyOf(isNull, isEmpty));

    // All events imported
    final events = await db.select(db.assetEvents).get();
    expect(events.length, 3);
  });
}
