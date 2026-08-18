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

  /// True when [finder]'s widget sits inside a privacy blur.
  bool isBlurred(Finder finder) => find.ancestor(of: finder, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

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
    debugPrint(
      'DIAG priceLine=${priceLine.evaluate().length} '
      'privacyTexts=${find.byType(PrivacyText).evaluate().length} '
      'blurs=${find.byType(ImageFiltered).evaluate().length}',
    );
    expect(priceLine, findsWidgets, reason: 'asset tile should render the price × quantity line');

    // ── Privacy OFF: nothing is blurred ───────────────────────────────────
    expect(find.byType(ImageFiltered), findsNothing, reason: 'nothing should be blurred before enabling privacy');

    // ── Turn privacy on via the global toolbar action ─────────────────────
    final toggle = find.byIcon(Icons.visibility_off).evaluate().isNotEmpty ? find.byIcon(Icons.visibility_off) : find.byIcon(Icons.visibility);
    expect(toggle, findsWidgets, reason: 'privacy toggle should be in the global app bar');
    await tester.tap(toggle.first);
    await longSettle(tester);

    // Something must be masked, otherwise the assertions below are vacuous.
    expect(find.byType(ImageFiltered), findsWidgets, reason: 'privacy mode should blur the position figures');
    expect(
      find.descendant(of: find.byType(PrivacyText), matching: find.byType(ImageFiltered)),
      findsWidgets,
      reason: 'PrivacyText should be blurring in privacy mode',
    );

    // ── The public half stays readable ────────────────────────────────────
    expect(
      isBlurred(priceLine.first),
      isFalse,
      reason: 'the unit price is public market data and must stay readable in privacy mode',
    );
  });
}
