// Health tab, end to end, for a leveraged investor: overdrawn accounts drawn on
// a credit line, a money-market ETF and an equity ETF. The credit line is money
// that can be borrowed, not wealth: it is in no ratio but its own usage; the
// money-market fund is cash; what is owed has its own category; the score is
// the mean of the categories; the FIRE card heads with how much of the number
// is reached; and in privacy mode the FIRE number is hidden while every
// percentage stays readable.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';

import 'dashboard_harness.dart';

void main() {
  const s = AppStrings.en;
  final h = DashboardHarness();

  setUpAll(() async => initializeDateFormatting());
  setUp(h.open);
  tearDown(h.close);

  Finder inKpi(String kpi, String text) => find.descendant(of: h.kpiCard(kpi), matching: find.text(text));
  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  Future<void> account(String name, double balance) async {
    final id = await h.db.into(h.db.accounts).insert(AccountsCompanion.insert(name: name));
    await h.db
        .into(h.db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: id,
            operationDate: DateTime(2025, 6, 1),
            valueDate: DateTime(2025, 6, 1),
            amount: balance,
            balanceAfter: Value(balance),
          ),
        );
  }

  Future<void> holding(String name, int broker, double units, {AssetClass assetClass = AssetClass.equity}) async {
    final id = await h.db
        .into(h.db.assets)
        .insert(
          AssetsCompanion.insert(
            name: name,
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: broker,
            assetClass: Value(assetClass),
          ),
        );
    await h.db
        .into(h.db.assetEvents)
        .insert(
          AssetEventsCompanion.insert(
            assetId: id,
            date: DateTime(2025, 6, 1),
            valueDate: DateTime(2025, 6, 1),
            type: EventType.buy,
            amount: units * 100,
            quantity: Value(units),
            price: const Value(100),
          ),
        );
    for (final day in [DateTime(2025, 6, 1), DateTime.utc(2026, 3, 10)]) {
      await h.db.into(h.db.marketPrices).insert(MarketPricesCompanion.insert(assetId: id, date: day, closePrice: 100, currency: 'EUR'));
    }
  }

  /// In euro: Main −30,000 (overdrawn) and Spare +2,000; a world ETF of
  /// 50,000 and a money-market ETF of 60,000; a credit line of 100,000; a
  /// salary of 3,000 every month of 2025 and of January–February 2026.
  ///
  ///  * cash = −28,000 + 60,000 = 32,000; net worth (Total Assets) = 110,000 − 28,000 = 82,000;
  ///  * owed = 30,000; gross assets = 82,000 + 30,000 = 112,000.
  Future<void> seedLeveraged() async {
    await account('Main', -30000);
    await account('Spare', 2000);
    final broker = await h.db.into(h.db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    await holding('World', broker, 500);
    await holding('Money market', broker, 600, assetClass: AssetClass.moneyMarket);
    await h.db
        .into(h.db.extraordinaryEvents)
        .insert(
          ExtraordinaryEventsCompanion.insert(
            name: 'Credit line',
            direction: EventDirection.inflow,
            treatment: EventTreatment.instant,
            totalAmount: 100000,
            eventDate: DateTime(2025, 6, 1),
            isEphemeral: const Value(true),
          ),
        );
    for (final (year, months) in [(2025, 12), (2026, 2)]) {
      for (var m = 1; m <= months; m++) {
        final d = DateTime(year, m, 15);
        await h.db.into(h.db.incomes).insert(IncomesCompanion.insert(date: d, valueDate: d, amount: 3000));
      }
    }
  }

  testWidgets('the credit line is in no ratio but its own usage; the money-market fund is cash', (tester) async {
    await seedLeveraged();
    await h.pump(tester);
    try {
      // Liquidity: cash 32,000 over a net worth of 82,000. With the credit line counted as cash it would read 72%.
      expect(inKpi(s.kpiLiquidityRatio, '39.02%'), findsOneWidget);
      expect(inKpi(s.kpiLiquidityRatio, s.ratingOttimo), findsOneWidget);
      // Wealth: 110,000 invested over 112,000 owned; (2,000 + 110,000) liquid over the same.
      expect(inKpi(s.kpiInvestmentWeight, '98.21%'), findsOneWidget);
      expect(inKpi(s.kpiInvestmentWeight, s.ratingOttimo), findsOneWidget);
      expect(inKpi(s.kpiLiquidAssetRatio, '100.00%'), findsOneWidget);
      // Debt: 30,000 owed over 112,000 owned, 30,000 drawn on 100,000 of lines.
      expect(inKpi(s.kpiDebtToAssets, '26.79%'), findsOneWidget);
      expect(inKpi(s.kpiDebtToAssets, s.ratingBuono), findsOneWidget);
      expect(inKpi(s.kpiCreditLineUsage, '30.00%'), findsOneWidget);
      expect(inKpi(s.kpiCreditLineUsage, s.ratingBuono), findsOneWidget);
      // 32,000 of cash over 3,000 a month.
      expect(inKpi(s.kpiExpenseCoverage, '11 months'), findsOneWidget);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('the categories are Liquidity, Financial & Wealth, Debt, then Performance & Diversification', (tester) async {
    await seedLeveraged();
    await h.pump(tester);
    try {
      final tops = [
        for (final name in [s.healthCatLiquidity, s.healthCatWealth, s.healthCatDebt, s.healthPerformance])
          tester.getTopLeft(find.text(name).last).dy,
      ];
      expect(tops, orderedEquals([...tops]..sort()), reason: 'in this order, one under the other');
      expect(tops.toSet().length, 4);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('the score is the mean of the categories, each one weighing the same', (tester) async {
    await seedLeveraged();
    await h.pump(tester);
    try {
      // Liquidity (100 + 75 + 25) / 3 = 66.7; Wealth (100 + 100 + 100 + 25) / 4 = 81.25; Debt 75; Performance: the
      // largest position alone is rated, 100. Their mean is 80.7 → 81. Over the KPIs one by one it would be 77.5 → 78.
      final summary = find.ancestor(of: find.text(s.healthSummary), matching: find.byType(Card)).first;
      expect(find.descendant(of: summary, matching: find.text('81')), findsOneWidget);
      expect(find.descendant(of: summary, matching: find.text(s.ratingBuono)), findsWidgets);
      expect(find.descendant(of: summary, matching: find.text(s.healthCatDebt)), findsOneWidget);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('the progress is the headline, the FIRE number the target under the name', (tester) async {
    await seedLeveraged();
    await h.pump(tester);
    try {
      // Expenses of 36,000 a year over a 2.75% withdrawal rate; 82,000 of investable net worth covers 6.26% of it.
      expect(inKpi(s.kpiFireNumber, '6.26%'), findsOneWidget);
      expect(inKpi(s.kpiFireNumber, s.kpiFireTarget('1,309,090.91 €')), findsOneWidget);
      expect(inKpi(s.kpiFireNumber, s.ratingScarso), findsOneWidget);
      expect(find.text('FI Target Progress'), findsNothing);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('privacy mode hides the FIRE number and keeps every percentage readable', (tester) async {
    await seedLeveraged();
    await h.pump(tester, isPrivate: true);
    try {
      expect(masked(inKpi(s.kpiFireNumber, '1,309,090.91 €')), isTrue, reason: 'an amount is position size');
      expect(masked(inKpi(s.kpiFireNumber, '6.26%')), isFalse, reason: 'a percentage is shape');
      for (final (kpi, value) in [
        (s.kpiLiquidityRatio, '39.02%'),
        (s.kpiInvestmentWeight, '98.21%'),
        (s.kpiDebtToAssets, '26.79%'),
        (s.kpiCreditLineUsage, '30.00%'),
        (s.kpiExpenseCoverage, '11 months'),
      ]) {
        expect(masked(inKpi(kpi, value)), isFalse, reason: '$kpi: $value describes composition, not size');
      }
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('the formulas name their figures; in privacy mode only their amounts are hidden', (tester) async {
    await seedLeveraged();
    await h.pump(tester, isPrivate: true);
    try {
      await h.openInfo(tester, s.kpiDebtToAssets);
      final dialog = find.byType(AlertDialog);
      const figures =
          '30,000.00 / 112,000.00 x 100\n'
          'Owed = overdrawn Accounts + Liabilities: 30,000.00 + 0.00\n'
          'Gross Assets = Net Worth + Owed: 82,000.00 + 30,000.00';
      expect(find.descendant(of: dialog, matching: find.text('Owed / Gross Assets x 100')), findsOneWidget);
      expect(masked(find.descendant(of: dialog, matching: find.text('Owed / Gross Assets x 100'))), isFalse);
      expect(masked(find.descendant(of: dialog, matching: find.text(figures))), isTrue);
      await h.tapDialogButton(tester, s.close);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('Expense Coverage says where its months come from and what the credit line would add, without counting it', (tester) async {
    await seedLeveraged();
    await h.pump(tester);
    try {
      await h.openInfo(tester, s.kpiExpenseCoverage);
      final text = h.dialogText(tester);
      expect(text, contains('32,000.00 / 3,000.00'));
      expect(text, contains('Monthly Expenses = estimated annual expenses / 12: 36,000.00 / 12'));
      expect(text, contains('Cash = Accounts + Money Market: -28,000.00 + 60,000.00'));
      expect(text, contains('Unused Credit Lines: 70,000.00 (about 23 more months, not counted)'));
      await h.tapDialogButton(tester, s.close);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('Income-to-Wealth counts the 12 months up to today, by the day', (tester) async {
    await seedLeveraged();
    await h.pump(tester);
    try {
      // On 10 March 2026: the salaries from 15 March 2025 on, twelve of them. A window of whole months
      // starting after the 10th of March 2025 would have lost March's, and read 33,000.
      await h.openInfo(tester, s.kpiIncomeToWealth);
      expect(h.dialogText(tester), contains('36,000.00 / 82,000.00 x 100'));
      await h.tapDialogButton(tester, s.close);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('the old price-change and HHI cards are gone', (tester) async {
    await seedLeveraged();
    await h.pump(tester);
    try {
      for (final gone in ['Today', 'YTD', 'All Time', 'HHI', 'Investment Weight ']) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
    } finally {
      await h.unmount(tester);
    }
  });
}
