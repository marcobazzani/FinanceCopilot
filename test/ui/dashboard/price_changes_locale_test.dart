// Price Changes card: the percentage changes — of each row, of the native-
// currency sub-row of a foreign asset, and of the total — are spelled in the
// active locale ("+0,83%" in it_IT, not "+0.83%"); English reads as before.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/database/database.dart';

import 'dashboard_harness.dart';

void main() {
  final h = DashboardHarness();
  final today = DashboardHarness.today;

  setUpAll(() async => initializeDateFormatting());
  setUp(h.open);
  tearDown(h.close);

  /// Beside the harness fund (121 today, 120 yesterday: +0.83%), a fund quoted
  /// in USD: 202 today, 200 yesterday (+1.00% in USD and, at a steady 0.9, in
  /// EUR), below its March high so no all-time-high celebration fires.
  Future<void> seedUsdFund() async {
    final broker = await h.db.into(h.db.intermediaries).insert(IntermediariesCompanion.insert(name: 'US broker'));
    final fund = await h.db
        .into(h.db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'US Fund',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: broker,
            currency: const Value('USD'),
          ),
        );
    await h.db
        .into(h.db.assetEvents)
        .insert(
          AssetEventsCompanion.insert(
            assetId: fund,
            date: DateTime(2024, 12, 2),
            valueDate: DateTime(2024, 12, 2),
            type: EventType.buy,
            amount: 1000,
            quantity: const Value(10),
            price: const Value(100),
            currency: const Value('USD'),
          ),
        );
    final days = [DateTime(2024, 12, 2), DateTime(2026, 3, 2), DateTime(2026, 3, 9), today];
    for (final (date, close) in [(days[0], 100.0), (days[1], 250.0), (days[2], 200.0), (days[3], 202.0)]) {
      await h.db.into(h.db.marketPrices).insert(MarketPricesCompanion.insert(assetId: fund, date: date, closePrice: close, currency: 'USD'));
    }
    for (final date in days) {
      await h.db.into(h.db.exchangeRates).insert(ExchangeRatesCompanion.insert(fromCurrency: 'USD', toCurrency: 'EUR', date: date, rate: 0.9));
    }
  }

  for (final (language, locale, tab, title, fund, usd, total) in [
    ('en', 'en_US', 'History', 'Price Changes', '+0.83%', '+1.00%', '+0.93%'),
    ('it', 'it_IT', 'Storico', 'Variazioni prezzo', '+0,83%', '+1,00%', '+0,93%'),
  ]) {
    testWidgets('$language: row, sub-row and total changes in the locale', (tester) async {
      await h.seed();
      await seedUsdFund();
      await h.pump(tester, language: language, locale: locale);
      try {
        await h.openTab(tester, tab);
        final card = find.ancestor(of: find.text(title), matching: find.byType(Card)).first;
        Finder inCard(String text) => find.descendant(of: card, matching: find.text(text));
        for (var i = 0; i < 100 && inCard(total).evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(inCard(fund), findsOneWidget, reason: '121 against 120');
        expect(inCard(usd), findsNWidgets(2), reason: 'the USD fund in EUR, and its sub-row in USD');
        expect(inCard(total), findsOneWidget, reason: '28 on 3,000');
      } finally {
        await h.unmount(tester);
      }
    });
  }
}
