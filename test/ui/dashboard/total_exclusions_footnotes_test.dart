// Every contributor a dashboard total leaves out for want of a price or an
// exchange rate is counted under it — not only the assets without a price.
// These were left out of the totals without a word:
//  * an account in a currency without any rate to base: its balance is in no
//    total (never converted 1:1);
//  * an asset bought in a currency without a rate: its units are valued, but
//    the amount paid is in no cost basis, so no invested amount, gain or net
//    value is drawn for it.
// The Totals table and the Health summary count them from the same
// exclusions as every total ([totalExclusions]), each contributor once; a Gain
// chart counts the asset whose gain it cannot draw, priced or not.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/models/dashboard_chart.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show ChartCard;

import 'dashboard_harness.dart';

void main() {
  const s = AppStrings.en;
  final h = DashboardHarness();

  setUpAll(() async => initializeDateFormatting());
  setUp(h.open);
  tearDown(h.close);

  /// 400 on an account in USD: there is no USD rate at all.
  Future<void> seedDollarAccount() async {
    final id = await h.db.into(h.db.accounts).insert(AccountsCompanion.insert(name: 'Dollars', currency: const Value('USD')));
    await h.db
        .into(h.db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: id,
            operationDate: DateTime(2025, 1, 10),
            valueDate: DateTime(2025, 1, 10),
            amount: 400,
            balanceAfter: const Value(400),
            description: const Value('Opening'),
          ),
        );
  }

  Future<int> seedAsset(String name, String ticker) async {
    final broker = await h.db.into(h.db.intermediaries).insert(IntermediariesCompanion.insert(name: '$name broker'));
    return h.db
        .into(h.db.assets)
        .insert(
          AssetsCompanion.insert(
            name: name,
            ticker: Value(ticker),
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: broker,
          ),
        );
  }

  Future<void> buy(int asset, {required double amount, required double qty, double? price, String currency = 'EUR'}) => h.db
      .into(h.db.assetEvents)
      .insert(
        AssetEventsCompanion.insert(
          assetId: asset,
          date: DateTime(2025, 1, 10),
          valueDate: DateTime(2025, 1, 10),
          type: EventType.buy,
          amount: amount,
          quantity: Value(qty),
          price: Value(price),
          currency: Value(currency),
        ),
      );

  /// 5 units of a fund quoted in EUR (closing at 100), bought for 550 USD:
  /// the units are valued, the amount paid is in no cost basis.
  Future<int> seedFundBoughtInDollars() async {
    final fund = await seedAsset('Dollar fund', 'DFND');
    await buy(fund, amount: 550, qty: 5, price: 110, currency: 'USD');
    for (final date in [DateTime(2025, 1, 10), DateTime(2026, 3, 9), DashboardHarness.today]) {
      await h.db.into(h.db.marketPrices).insert(MarketPricesCompanion.insert(assetId: fund, date: date, closePrice: 100, currency: 'EUR'));
    }
    return fund;
  }

  /// 10 units bought for 1,000, with no price on record at all.
  Future<int> seedUnpriced() async {
    final asset = await seedAsset('Unpriced', 'UNPR');
    await buy(asset, amount: 1000, qty: 10);
    return asset;
  }

  Future<int> fundOfSeed() async => (await h.db.select(h.db.assets).get()).firstWhere((a) => a.name == 'Fund').id;

  /// The Price Changes widget (it hosts the Totals table) and one chart adding
  /// up the gain of [assetIds].
  List<DashboardChart> gainOnly(List<int> assetIds) => [
    DashboardChart(
      id: -1,
      title: 'Price Changes',
      widgetType: 'price_changes',
      sortOrder: 0,
      seriesJson: '[]',
      createdAt: DashboardHarness.today,
    ),
    DashboardChart(
      id: -2,
      title: 'Gain',
      widgetType: 'chart',
      sortOrder: 1,
      seriesJson: '[${assetIds.map((id) => '{"type":"asset_gain","id":$id}').join(',')}]',
      createdAt: DashboardHarness.today,
    ),
  ];

  Finder totalsCard() => find.ancestor(of: find.text(s.vsATH), matching: find.byType(Card)).first;
  Finder rowOf(String label) => find
      .ancestor(
        of: find.descendant(of: totalsCard(), matching: find.text(label)),
        matching: find.byType(Row),
      )
      .first;
  Finder inTotals(String text) => find.descendant(of: totalsCard(), matching: find.text(text));
  Finder chartCard(String title) => find.byWidgetPredicate((w) => w is ChartCard && w.chart.title == title);
  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  Future<void> openTotals(WidgetTester tester) async {
    await h.openTab(tester, 'History');
    await tester.ensureVisible(find.text(s.vsATH));
    await h.settle(tester);
  }

  group('an account without a rate and an asset bought without one', () {
    testWidgets('Totals: both are counted under the table, once each', (tester) async {
      await h.seed();
      await seedDollarAccount();
      await seedFundBoughtInDollars();
      await h.pump(tester);
      try {
        await openTotals(tester);
        expect(inTotals(s.unpricedExcludedFromTotals(2)), findsOneWidget);
        // Left out, never added 1:1: Cash is the 15,000 in euros alone.
        expect(find.descendant(of: rowOf('Cash'), matching: find.text('+€15,000.00')), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('Health: both are counted under the summary', (tester) async {
      await h.seed();
      await seedDollarAccount();
      await seedFundBoughtInDollars();
      await h.pump(tester);
      try {
        expect(find.text(s.unpricedExcludedFromTotals(2)), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('privacy: the counts stay readable, the totals beside them are masked', (tester) async {
      await h.seed();
      await seedDollarAccount();
      await seedFundBoughtInDollars();
      await h.pump(tester, isPrivate: true);
      try {
        final healthNote = find.text(s.unpricedExcludedFromTotals(2));
        expect(healthNote, findsOneWidget);
        expect(masked(healthNote), isFalse, reason: 'a count of contributors: shape, not magnitude');
        await openTotals(tester);
        expect(inTotals(s.unpricedExcludedFromTotals(2)), findsOneWidget);
        expect(masked(inTotals(s.unpricedExcludedFromTotals(2))), isFalse);
        final cash = find.descendant(of: rowOf('Cash'), matching: find.text('+€15,000.00'));
        expect(cash, findsOneWidget);
        expect(masked(cash), isTrue, reason: 'a balance is position size');
      } finally {
        await h.unmount(tester);
      }
    });
  });

  group('an account without a rate alone', () {
    testWidgets('is counted under the Totals table and under the Health summary', (tester) async {
      await h.seed();
      await seedDollarAccount();
      await h.pump(tester);
      try {
        expect(find.text(s.unpricedExcludedFromTotals(1)), findsOneWidget, reason: 'Health');
        await openTotals(tester);
        expect(inTotals(s.unpricedExcludedFromTotals(1)), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });
  });

  group('a Gain chart', () {
    testWidgets('counts the asset bought without a rate: no gain is drawn for it', (tester) async {
      await h.seed();
      final dollarFund = await seedFundBoughtInDollars();
      await h.pump(
        tester,
        overrides: [
          dashboardChartsProvider.overrideWithValue(gainOnly([await fundOfSeed(), dollarFund])),
        ],
      );
      try {
        await openTotals(tester);
        // The priced fund's gain alone: 10 x (121 - 100).
        expect(find.descendant(of: rowOf('Gain'), matching: find.text('+€210.00')), findsOneWidget);
        expect(inTotals(s.unpricedExcludedFromTotals(1)), findsOneWidget);
        expect(find.descendant(of: chartCard('Gain'), matching: find.text(s.unpricedExcludedFromTotal(1))), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('counts an asset without a price as well', (tester) async {
      await h.seed();
      final unpriced = await seedUnpriced();
      await h.pump(
        tester,
        overrides: [
          dashboardChartsProvider.overrideWithValue(gainOnly([await fundOfSeed(), unpriced])),
        ],
      );
      try {
        await openTotals(tester);
        expect(find.descendant(of: rowOf('Gain'), matching: find.text('+€210.00')), findsOneWidget);
        expect(inTotals(s.unpricedExcludedFromTotals(1)), findsOneWidget);
        expect(find.descendant(of: chartCard('Gain'), matching: find.text(s.unpricedExcludedFromTotal(1))), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('priced assets with a complete cost basis: no note', (tester) async {
      await h.seed();
      await h.pump(
        tester,
        overrides: [
          dashboardChartsProvider.overrideWithValue(gainOnly([await fundOfSeed()])),
        ],
      );
      try {
        await openTotals(tester);
        expect(find.descendant(of: rowOf('Gain'), matching: find.text('+€210.00')), findsOneWidget);
        expect(find.textContaining('excluded from the total'), findsNothing);
      } finally {
        await h.unmount(tester);
      }
    });
  });
}
