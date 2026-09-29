// The yearly Income / Expense / Savings figures the Cash Flow tab, its Sankey
// and the Health tab share (read here from the Sankey card, which receives
// them per year, and from the Saving chart the velocity charts derive from).
//
// - Income records (salaries, refunds, pension contributions) are converted
//   to base at the rate of their value date; a record whose currency has no
//   rate is left out, never converted 1:1 — and now counted.
// - The first period starts from the first observed savings value: the
//   balances that already existed when tracking began are not a year of
//   savings (they used to read as savings, and as negative expenses).
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart';

import 'dashboard_harness.dart';

void main() {
  final h = DashboardHarness();

  setUpAll(() async => initializeDateFormatting());
  setUp(h.open);
  tearDown(h.close);

  Map<int, CashFlowYearTotals> yearly(WidgetTester tester) => tester.widget<CashFlowSankeyCard>(find.byType(CashFlowSankeyCard)).years;

  Future<void> income(DateTime day, double amount, {String currency = 'EUR', IncomeType type = IncomeType.income, int? assetId}) => h.db
      .into(h.db.incomes)
      .insert(
        IncomesCompanion.insert(
          date: day,
          valueDate: day,
          amount: amount,
          currency: Value(currency),
          type: Value(type),
          assetId: Value(assetId),
        ),
      );

  Future<void> bankRow(int account, DateTime day, double amount, double balance) => h.db
      .into(h.db.transactions)
      .insert(
        TransactionsCompanion.insert(
          accountId: account,
          operationDate: day,
          valueDate: day,
          amount: amount,
          balanceAfter: Value(balance),
        ),
      );

  /// On top of the harness portfolio (15,000 opening on 2024-12-01, a 1,000
  /// fund bought on 2024-12-02, a 3,000 salary every month from 2025): a USD
  /// salary, a refund and a pension contribution to the fund in EUR, and one
  /// of each in CHF — a currency with no rate at all.
  Future<void> seedForeignIncome() async {
    await h.seed();
    final fund = (await h.db.select(h.db.assets).get()).single.id;
    await h.db
        .into(h.db.exchangeRates)
        .insert(ExchangeRatesCompanion.insert(fromCurrency: 'EUR', toCurrency: 'USD', date: DateTime(2024, 11, 1), rate: 1.25));
    await h.db
        .into(h.db.exchangeRates)
        .insert(ExchangeRatesCompanion.insert(fromCurrency: 'USD', toCurrency: 'EUR', date: DateTime(2024, 11, 1), rate: 0.8));
    await income(DateTime(2025, 5, 15), 1000, currency: 'USD');
    await income(DateTime(2025, 6, 15), 500, currency: 'CHF');
    await income(DateTime(2025, 7, 1), 200, type: IncomeType.refund);
    await income(DateTime(2025, 8, 1), 100, currency: 'CHF', type: IncomeType.refund);
    await income(DateTime(2025, 9, 1), 500, type: IncomeType.pensionContribution, assetId: fund);
    await income(DateTime(2025, 10, 1), 50, currency: 'CHF', type: IncomeType.pensionContribution, assetId: fund);
  }

  testWidgets('income, refunds and pension contributions are converted at their value-date rate; no rate, left out', (tester) async {
    await seedForeignIncome();
    await h.pump(tester);
    try {
      await h.openTab(tester, 'Cash Flow');
      final years = yearly(tester);
      // 12 × 3,000 + 1,000 USD × 0.8; the 500 CHF is not added at 1:1.
      expect(years[2025]!.income, 36800);
      // No balance moved in 2025; the 500 pension contribution is not the
      // user's saving (the CHF one is not subtracted at 1:1 either).
      expect(years[2025]!.savings, -500);
      expect(years[2025]!.refunds, 200);
      expect(years[2026], (income: 6000.0, savings: 0.0, refunds: 0.0));

      // The Saving chart behind the velocity charts has the cumulative
      // pension contributions taken out from the day they were paid in.
      final saving = tester.widgetList<ChartCard>(find.byType(ChartCard)).expand((c) => c.series).singleWhere((s) => s.key == 'cf:saving').spots;
      final paidIn = DateTime.utc(2025, 9, 1).difference(DateTime.utc(2024, 12, 1)).inDays;
      expect(saving.where((p) => p.x < paidIn).last.y, 16000);
      expect(saving.where((p) => p.x >= paidIn).map((p) => p.y).toSet(), {15500});
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('the income records left out for want of a rate are counted', (tester) async {
    await seedForeignIncome();
    await h.pump(tester);
    try {
      expect(await h.container.read(incomeRowsWithoutRateProvider.future), 3, reason: 'the CHF salary, refund and pension contribution');
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('every income record converts: nothing left out', (tester) async {
    await h.seed();
    await h.pump(tester);
    try {
      expect(await h.container.read(incomeRowsWithoutRateProvider.future), 0);
    } finally {
      await h.unmount(tester);
    }
  });

  group('the first period starts from the first observed value', () {
    testWidgets('opening balances are not a year of savings', (tester) async {
      final acct = await h.db.into(h.db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
      await bankRow(acct, DateTime(2025, 3, 1), 10000, 10000); // opening
      await bankRow(acct, DateTime(2025, 3, 15), 3000, 13000); // salary
      await income(DateTime(2025, 3, 15), 3000);
      await bankRow(acct, DateTime(2025, 3, 20), -1000, 12000); // spent
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        final y2025 = yearly(tester)[2025]!;
        expect(y2025.income, 3000);
        expect(y2025.savings, 2000, reason: 'from the 10,000 opening to 12,000 — not 12,000 of savings');
        expect(y2025.income - y2025.savings, 1000, reason: 'expenses: the 1,000 spent, not -9,000');
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('the harness portfolio: its first December saves the fund bought, not the whole opening balance', (tester) async {
      await h.seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        final years = yearly(tester);
        expect(years[2024], (income: 0.0, savings: 1000.0, refunds: 0.0));
        expect(years[2025], (income: 36000.0, savings: 0.0, refunds: 0.0), reason: 'later years are unchanged');
      } finally {
        await h.unmount(tester);
      }
    });
  });
}
