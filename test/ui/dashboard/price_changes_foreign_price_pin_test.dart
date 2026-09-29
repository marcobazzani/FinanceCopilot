// Pins the unit prices of the Price Changes card for assets quoted in another
// currency: the row's price in base and, below it, the native price. A listed
// instrument's price is public market data and stays readable in privacy mode;
// a manually valued asset's "price" is its own valuation per unit — position
// size — and is masked in both places. Either way the price keeps its
// alignment and its size.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/providers/providers.dart';

import 'dashboard_harness.dart';

void main() {
  const s = AppStrings.en;
  final h = DashboardHarness();

  setUpAll(() async => initializeDateFormatting());
  setUp(h.open);
  tearDown(h.close);

  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  const changes = [
    // A listed fund quoted in USD: 10 units, 48 → 50.
    AssetDailyChange(
      name: 'US fund',
      ticker: 'USDF',
      currency: 'USD',
      todayPrice: 50,
      previousPrice: 48,
      quantity: 10,
      todayFxRate: 0.9,
      previousFxRate: 0.9,
      baseCurrency: 'EUR',
    ),
    // A villa valued by hand in USD: one unit.
    AssetDailyChange(
      name: 'Villa',
      ticker: 'VILLA',
      currency: 'USD',
      todayPrice: 300000,
      previousPrice: 300000,
      quantity: 1,
      todayFxRate: 0.9,
      previousFxRate: 0.9,
      baseCurrency: 'EUR',
      valuationMethod: ValuationMethod.eventDriven,
    ),
  ];

  testWidgets('privacy on: a listed price is readable in base and in its own currency, a hand-valued one masked in both', (tester) async {
    await h.seed();
    await h.pump(tester, isPrivate: true, overrides: [assetDailyChangesProvider.overrideWith((ref, date) async => changes)]);
    try {
      await h.openTab(tester, 'History');
      final card = find.ancestor(of: find.text(s.dashPriceChanges), matching: find.byType(Card)).first;
      Finder inCard(String text) => find.descendant(of: card, matching: find.text(text));

      // The row's price, in base: 50 × 0.9 and 300,000 × 0.9.
      for (final (price, isMasked) in [('45.00', false), ('270,000.00', true)]) {
        expect(inCard(price), findsOneWidget, reason: price);
        expect(masked(inCard(price)), isMasked, reason: price);
        final text = tester.widget<Text>(inCard(price));
        expect(text.textAlign, TextAlign.right, reason: price);
        expect(text.style?.fontSize, 11, reason: price);
        expect(text.style?.fontWeight, FontWeight.w400, reason: price);
      }
      // The native price on the line below.
      for (final (price, isMasked) in [('50.00', false), ('300,000.00', true)]) {
        expect(inCard(price), findsOneWidget, reason: price);
        expect(masked(inCard(price)), isMasked, reason: price);
        final text = tester.widget<Text>(inCard(price));
        expect(text.textAlign, TextAlign.right, reason: price);
        expect(text.style, TextStyle(fontSize: 9, color: Colors.grey.shade500), reason: price);
      }
      expect(inCard('\u21B3 USD'), findsNWidgets(2));
      // The percentages are shape; the value changes are position size.
      expect(inCard('+4.17%'), findsNWidgets(2));
      expect(masked(inCard('+4.17%').first), isFalse);
      expect(masked(inCard('\u25B2 18.00')), isTrue);
      expect(masked(inCard('+20.00')), isTrue);
    } finally {
      await h.unmount(tester);
    }
  });
}
