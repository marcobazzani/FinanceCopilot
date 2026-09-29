// Health tab: the four ratios over the net worth — liquidity, investment
// weight, liquid-asset ratio, income-to-wealth — are N/A without a net worth
// to divide by, and say why:
//  * no net worth at all (no balance or holding, or every one of them left out
//    for want of an exchange rate): "No data";
//  * a net worth of zero or less: a ratio over it is not meaningful, and the
//    KPI says so — it is not missing data;
//  * a KPI missing an input of its own (the income of income-to-wealth) has
//    no data, whatever the net worth.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/l10n/app_strings.dart';

import 'dashboard_harness.dart';

void main() {
  final h = DashboardHarness();

  setUpAll(() async => initializeDateFormatting());
  setUp(h.open);
  tearDown(h.close);

  /// One account whose balance is [balance] from December 2024, in [currency].
  Future<void> account(double balance, {String currency = 'EUR'}) async {
    final acct = await h.db.into(h.db.accounts).insert(AccountsCompanion.insert(name: 'Main', currency: Value(currency)));
    await h.db
        .into(h.db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: acct,
            operationDate: DateTime(2024, 12, 1),
            valueDate: DateTime(2024, 12, 1),
            amount: balance,
            balanceAfter: Value(balance),
          ),
        );
  }

  /// A 3,000 salary every month of 2025 and of January–February 2026.
  Future<void> salaries() async {
    for (final (year, months) in [(2025, 12), (2026, 2)]) {
      for (var m = 1; m <= months; m++) {
        final d = DateTime(year, m, 15);
        await h.db.into(h.db.incomes).insert(IncomesCompanion.insert(date: d, valueDate: d, amount: 3000));
      }
    }
  }

  /// [text] in [kpi]'s details, which open on a tap on their label in [s].
  Future<Finder> description(WidgetTester tester, String kpi, String text, {AppStrings s = AppStrings.en}) async {
    final details = find.descendant(of: h.kpiCard(kpi), matching: find.text(s.healthDetails));
    await tester.ensureVisible(details);
    await h.settle(tester);
    await tester.tap(details);
    await h.settle(tester);
    return find.descendant(of: h.kpiCard(kpi), matching: find.text(text));
  }

  for (final language in ['en', 'it']) {
    final s = AppStrings.of(language);
    final ratios = [s.kpiLiquidityRatio, s.kpiInvestmentWeight, s.kpiLiquidAssetRatio, s.kpiIncomeToWealth];

    void expectNa(String kpi) {
      expect(
        find.descendant(of: h.kpiCard(kpi), matching: find.text('-')),
        findsOneWidget,
        reason: '$kpi has no value',
      );
      expect(
        find.descendant(of: h.kpiCard(kpi), matching: find.text(s.ratingNa)),
        findsOneWidget,
        reason: '$kpi is not rated',
      );
    }

    Future<void> pump(WidgetTester tester) => h.pump(tester, language: language, locale: language == 'it' ? 'it_IT' : 'en_US');

    for (final (label, balance) in [('negative', -2000.0), ('zero', 0.0)]) {
      testWidgets('$language: a $label net worth: the ratios over it are N/A and not meaningful, not missing', (tester) async {
        await account(balance);
        await salaries();
        await pump(tester);
        try {
          for (final kpi in ratios) {
            expectNa(kpi);
            expect(await description(tester, kpi, s.kpiNetWorthNotPositive, s: s), findsOneWidget, reason: kpi);
            expect(
              find.descendant(of: h.kpiCard(kpi), matching: find.text(s.noData)),
              findsNothing,
              reason: '$kpi has its data',
            );
          }
        } finally {
          await h.unmount(tester);
        }
      });
    }

    testWidgets('$language: a negative net worth and no income: the income-to-wealth ratio misses its income', (tester) async {
      await account(-2000);
      await pump(tester);
      try {
        for (final kpi in ratios) {
          expectNa(kpi);
          final why = kpi == s.kpiIncomeToWealth ? s.noData : s.kpiNetWorthNotPositive;
          expect(await description(tester, kpi, why, s: s), findsOneWidget, reason: kpi);
        }
        // No income and no expenses: the KPIs of the Liquidity category miss
        // their own inputs.
        expectNa(s.kpiSavingsRate);
        expect(await description(tester, s.kpiSavingsRate, s.noData, s: s), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('$language: nothing at all: the ratios over the net worth have no data', (tester) async {
      await pump(tester);
      try {
        for (final kpi in ratios) {
          expectNa(kpi);
          expect(await description(tester, kpi, s.noData, s: s), findsOneWidget, reason: kpi);
          expect(
            find.descendant(of: h.kpiCard(kpi), matching: find.text(s.kpiNetWorthNotPositive)),
            findsNothing,
            reason: kpi,
          );
        }
      } finally {
        await h.unmount(tester);
      }
    });
  }

  testWidgets('every balance left out for want of a rate: the net worth is missing, not zero', (tester) async {
    const s = AppStrings.en;
    // A balance in CHF: a currency with no rate at all, in no total.
    await account(5000, currency: 'CHF');
    await h.pump(tester);
    try {
      expect(find.text(s.unpricedExcludedFromTotals(1)), findsOneWidget, reason: 'counted under the summary');
      for (final kpi in [s.kpiLiquidityRatio, s.kpiInvestmentWeight, s.kpiLiquidAssetRatio, s.kpiIncomeToWealth]) {
        expect(await description(tester, kpi, s.noData), findsOneWidget, reason: kpi);
        expect(
          find.descendant(of: h.kpiCard(kpi), matching: find.text(s.kpiNetWorthNotPositive)),
          findsNothing,
          reason: kpi,
        );
      }
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('a positive net worth: the ratios keep their value and reading', (tester) async {
    const s = AppStrings.en;
    await account(15000);
    await h.pump(tester);
    try {
      expect(find.descendant(of: h.kpiCard(s.kpiLiquidityRatio), matching: find.text('100.00%')), findsOneWidget);
      expect(await description(tester, s.kpiLiquidityRatio, s.kpiLiquidityDescOttimo), findsOneWidget);
    } finally {
      await h.unmount(tester);
    }
  });
}
