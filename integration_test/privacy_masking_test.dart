// Pins the privacy rule on a real screen: privacy mode must hide the SIZE of
// the position, not public market data.
//
// The asset tile renders `unit price  ×  quantity` plus the market value. The
// tile used to wrap that whole line in a single blur, which hid the unit price
// — public data, identical for every holder, and exactly the analysis privacy
// mode exists to preserve. The quantity, which carries no currency symbol, is
// the part that must be masked: multiplied by the public price it reveals the
// position value.
//
// Asserting both halves in the SAME test is deliberate. A test that only checks
// "the amount is blurred" passes just as happily on a screen where everything
// is blurred, which is the other way this rule breaks.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/ui/widgets/privacy_text.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// True when [finder]'s widget is rendered inside a privacy wrapper.
  ///
  /// Keyed on `PrivacyText`/`PrivacyBlur` rather than on `ImageFiltered`:
  /// ImageFiltered is NOT exclusive to privacy mode. Android's overscroll
  /// stretch installs a shader-based one, so a global
  /// `find.byType(ImageFiltered)` assertion passed on macOS and failed on the
  /// Android emulator, for a reason that had nothing to do with privacy.
  bool insidePrivacyWrapper(Finder finder) =>
      find.ancestor(of: finder, matching: find.byType(PrivacyBlur)).evaluate().isNotEmpty ||
      find.ancestor(of: finder, matching: find.byType(PrivacyText)).evaluate().isNotEmpty;

  /// How many blurs are actually installed BY a privacy wrapper.
  int privacyBlurCount() =>
      find.descendant(of: find.byType(PrivacyText), matching: find.byType(ImageFiltered)).evaluate().length +
      find.descendant(of: find.byType(PrivacyBlur), matching: find.byType(ImageFiltered)).evaluate().length;

  testWidgets('privacy mode masks quantity and value but not the unit price', (tester) async {
    await pumpApp(
      tester,
      seed: (database) async {
        final interId = await database.into(database.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
        final assetId = await database
            .into(database.assets)
            .insert(
              AssetsCompanion.insert(
                name: 'World ETF',
                assetType: AssetType.stockEtf,
                valuationMethod: ValuationMethod.marketPrice,
                isin: const Value('IE00B4L5Y983'),
                ticker: const Value('SWDA'),
                currency: const Value('EUR'),
                intermediaryId: interId,
              ),
            );
        await database
            .into(database.assetEvents)
            .insert(
              AssetEventsCompanion.insert(
                assetId: assetId,
                date: DateTime(2025, 1, 10),
                valueDate: DateTime(2025, 1, 10),
                type: EventType.buy,
                amount: 1000,
                quantity: const Value(10),
                price: const Value(100),
                currency: const Value('EUR'),
              ),
            );
        // A price for today so the tile renders a market value (and therefore
        // the `price × quantity` line).
        final today = DateTime.now();
        await database
            .into(database.marketPrices)
            .insert(
              MarketPricesCompanion.insert(
                assetId: assetId,
                date: DateTime(today.year, today.month, today.day),
                closePrice: 120,
                currency: 'EUR',
              ),
            );
      },
    );
    await longSettle(tester);

    await tester.tap(find.text('Assets').first);
    await longSettle(tester);
    await pumpFor(tester, const Duration(seconds: 2));

    // The `×` separator lives on the unit-price line of the tile.
    final priceLine = find.textContaining('×');
    expect(priceLine, findsWidgets, reason: 'asset tile should render the price × quantity line');

    // ── Privacy OFF: no privacy wrapper is blurring ───────────────────────
    expect(privacyBlurCount(), 0, reason: 'nothing should be masked before enabling privacy');

    // ── Turn privacy on the way the app exposes it ────────────────────────
    // Wide layouts put the toggle straight in the app bar; phones collapse the
    // global actions into an overflow PopupMenuButton, so tapping a bar icon
    // finds nothing there. Privacy off renders Icons.visibility in both.
    final barToggle = find.widgetWithIcon(IconButton, Icons.visibility);
    if (barToggle.evaluate().isNotEmpty) {
      await tester.tap(barToggle.first);
    } else {
      final overflow = find.byType(PopupMenuButton<String>);
      expect(overflow, findsWidgets, reason: 'a phone layout should collapse the global actions into an overflow menu');
      await tester.tap(overflow.first);
      await longSettle(tester);
      final item = find.byIcon(Icons.visibility);
      expect(item, findsWidgets, reason: 'the overflow menu should offer the privacy toggle');
      await tester.tap(item.first);
    }
    await longSettle(tester);

    // Something must be masked, otherwise the assertion below is vacuous.
    expect(privacyBlurCount(), greaterThan(0), reason: 'privacy mode should mask the position figures');

    // ── The public half stays readable ────────────────────────────────────
    expect(
      insidePrivacyWrapper(priceLine.first),
      isFalse,
      reason: 'the unit price is public market data and must stay readable in privacy mode',
    );
  });
}
