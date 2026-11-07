import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/pillars/financial_health_service.dart';
import 'package:finance_copilot/services/pillars/health_balance_sheet.dart';
import 'package:finance_copilot/services/pillars/pillar_performance.dart';
import 'package:finance_copilot/utils/privacy_slots.dart';

Asset _asset(int id, InstrumentType type, {String? ticker}) => Asset(
  id: id,
  intermediaryId: 1,
  name: 'Asset $id',
  ticker: ticker,
  assetType: AssetType.stockEtf,
  instrumentType: type,
  assetClass: AssetClass.equity,
  assetGroup: '',
  valuationMethod: ValuationMethod.marketPrice,
  currency: 'EUR',
  isActive: true,
  includeInSavings: true,
  sortOrder: 0,
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
);

void main() {
  const s = AppStrings.en;
  const locale = 'en_US';

  setUpAll(() async => initializeDateFormatting());

  /// Cash only: [bank] in the accounts, nothing owed, nothing invested.
  HealthBalanceSheet cashOnly(double bank) => HealthBalanceSheet(bankBalances: bank, positiveBankBalances: bank, netWorth: bank);

  List<KpiCategory> kpis({
    HealthBalanceSheet? sheet,
    double annualIncome = 0,
    double annualSavings = 0,
    double rollingIncome = 0,
    double? estimatedAnnualExpenses,
    double thisYearMonthlyExpenses = 0,
    AppStrings strings = s,
    String loc = locale,
  }) => computeKpis(
    sheet: sheet,
    annualIncome: annualIncome,
    annualSavings: annualSavings,
    rollingIncome: rollingIncome,
    estimatedAnnualExpenses: estimatedAnnualExpenses,
    thisYearMonthlyExpenses: thisYearMonthlyExpenses,
    s: strings,
    locale: loc,
  );

  HealthKpi liquidityRatio(List<KpiCategory> c) => c[0].kpis[0];
  HealthKpi coverage(List<KpiCategory> c) => c[0].kpis[1];
  HealthKpi savingsRate(List<KpiCategory> c) => c[0].kpis[2];
  HealthKpi investmentWeight(List<KpiCategory> c) => c[1].kpis[0];
  HealthKpi liquidAssetRatio(List<KpiCategory> c) => c[1].kpis[1];
  HealthKpi incomeToWealth(List<KpiCategory> c) => c[1].kpis[2];
  HealthKpi debtToAssets(List<KpiCategory> c) => c[2].kpis[0];
  HealthKpi creditLineUsage(List<KpiCategory> c) => c[2].kpis[1];

  /// A leveraged investor: two accounts overdrawn by 130,000 (drawn on credit
  /// lines of 440,000), 360,000 in a money-market fund, 1,000,000 invested.
  /// Total Assets = 1,000,000 − 128,000 = 872,000; the credit lines are not
  /// wealth, so none of them is in any figure but the lines themselves.
  const leveraged = HealthBalanceSheet(
    bankBalances: -128000,
    positiveBankBalances: 2000,
    overdrawnAccounts: 130000,
    moneyMarket: 360000,
    netWorth: 872000,
    investments: 1000000,
    liquidInvestments: 940000,
    creditLines: 440000,
    netAssetValue: 810000,
    investableNetWorth: 810000,
  );

  group('rateNormal', () {
    // Thresholds: scarso < 10, sufficiente [10,15), buono [15,25), ottimo >= 25
    test('returns scarso when value is below scarso threshold', () {
      expect(rateNormal(5, 10, 15, 25), Rating.scarso);
    });

    test('returns sufficiente when value equals scarso threshold', () {
      expect(rateNormal(10, 10, 15, 25), Rating.sufficiente);
    });

    test('returns buono when value equals suff threshold', () {
      expect(rateNormal(15, 10, 15, 25), Rating.buono);
    });

    test('returns ottimo when value equals buono threshold', () {
      expect(rateNormal(25, 10, 15, 25), Rating.ottimo);
    });

    test('returns ottimo when value exceeds buono threshold', () {
      expect(rateNormal(50, 10, 15, 25), Rating.ottimo);
    });
  });

  group('rateLowerBetter', () {
    test('strict: the limit itself already belongs to the worse rating', () {
      expect(rateLowerBetter(9.99, 10, 30, 50), Rating.ottimo);
      expect(rateLowerBetter(10, 10, 30, 50), Rating.buono);
      expect(rateLowerBetter(29.99, 10, 30, 50), Rating.buono);
      expect(rateLowerBetter(30, 10, 30, 50), Rating.sufficiente);
      expect(rateLowerBetter(49.99, 10, 30, 50), Rating.sufficiente);
      expect(rateLowerBetter(50, 10, 30, 50), Rating.scarso);
    });

    test('inclusive: the limit itself still belongs to the better rating', () {
      expect(rateLowerBetter(5, 5, 10, 20, inclusive: true), Rating.ottimo);
      expect(rateLowerBetter(5.01, 5, 10, 20, inclusive: true), Rating.buono);
      expect(rateLowerBetter(10, 5, 10, 20, inclusive: true), Rating.buono);
      expect(rateLowerBetter(20, 5, 10, 20, inclusive: true), Rating.sufficiente);
      expect(rateLowerBetter(20.01, 5, 10, 20, inclusive: true), Rating.scarso);
    });
  });

  group('categoryRating', () {
    test('returns na for empty list', () {
      expect(categoryRating([]), Rating.na);
    });

    test('returns na when all kpis are na', () {
      final kpis = [
        const HealthKpi(name: 'a', rating: Rating.na),
        const HealthKpi(name: 'b', rating: Rating.na),
      ];
      expect(categoryRating(kpis), Rating.na);
    });

    test('returns ottimo when avg score >= 87', () {
      // All ottimo (score 100) -> avg 100
      final kpis = [
        const HealthKpi(name: 'a', rating: Rating.ottimo),
        const HealthKpi(name: 'b', rating: Rating.ottimo),
      ];
      expect(categoryRating(kpis), Rating.ottimo);
    });

    test('returns buono when avg score >= 62 and < 87', () {
      // ottimo (100) + sufficiente (50) -> avg 75
      final kpis = [
        const HealthKpi(name: 'a', rating: Rating.ottimo),
        const HealthKpi(name: 'b', rating: Rating.sufficiente),
      ];
      expect(categoryRating(kpis), Rating.buono);
    });

    test('returns sufficiente when avg score >= 37 and < 62', () {
      // buono (75) + scarso (25) -> avg 50
      final kpis = [
        const HealthKpi(name: 'a', rating: Rating.buono),
        const HealthKpi(name: 'b', rating: Rating.scarso),
      ];
      expect(categoryRating(kpis), Rating.sufficiente);
    });

    test('returns scarso when avg score < 37', () {
      // All scarso (score 25) -> avg 25
      final kpis = [
        const HealthKpi(name: 'a', rating: Rating.scarso),
        const HealthKpi(name: 'b', rating: Rating.scarso),
      ];
      expect(categoryRating(kpis), Rating.scarso);
    });

    test('ignores na-rated kpis in average', () {
      final kpis = [
        const HealthKpi(name: 'a', rating: Rating.ottimo),
        const HealthKpi(name: 'b', rating: Rating.na),
      ];
      // Only ottimo counts -> avg 100
      expect(categoryRating(kpis), Rating.ottimo);
    });
  });

  group('overallHealth: the score is the mean of the categories', () {
    KpiCategory category(String name, List<Rating> ratings) => KpiCategory(
      name: name,
      kpis: [for (final (i, r) in ratings.indexed) HealthKpi(name: '$name$i', rating: r)],
    );

    test('every category weighs the same, whatever its number of KPIs', () {
      final health = overallHealth([
        category('big', [Rating.ottimo, Rating.ottimo, Rating.ottimo, Rating.ottimo, Rating.ottimo]),
        category('small', [Rating.scarso]),
      ]);
      // A mean over the six KPIs would be 87.5 (Excellent); over the categories it is (100 + 25) / 2.
      expect(health.score, 62.5);
      expect(health.rating, Rating.buono);
    });

    test('a category score is not rounded to its rating before it is averaged', () {
      final health = overallHealth([
        category('liquidity', [Rating.ottimo, Rating.ottimo, Rating.ottimo]), // 100
        category('wealth', [Rating.ottimo, Rating.ottimo, Rating.buono, Rating.sufficiente]), // 81.25: Good
        category('debt', [Rating.buono, Rating.buono]), // 75
        category('performance', [Rating.ottimo, Rating.sufficiente, Rating.ottimo]), // 83.33
      ]);
      expect(health.score, closeTo(84.896, 0.001));
      expect(health.rating, Rating.buono);
    });

    test('a category with nothing rated takes no part', () {
      final health = overallHealth([
        category('rated', [Rating.buono]),
        category('empty', [Rating.na, Rating.na]),
      ]);
      expect(health.score, 75);
    });

    test('nothing rated at all: no score, not a Poor 0', () {
      final health = overallHealth([
        category('empty', [Rating.na]),
      ]);
      expect(health.score, isNull);
      expect(health.rating, Rating.na);
      expect(overallHealth(const []).score, isNull);
    });

    test('the category carries its own score and rating', () {
      final c = category('wealth', [Rating.ottimo, Rating.ottimo, Rating.buono, Rating.sufficiente]);
      expect(c.score, 81.25);
      expect(c.overallRating, Rating.buono);
      expect(category('none', [Rating.na]).score, isNull);
      expect(category('none', [Rating.na]).overallRating, Rating.na);
    });
  });

  group('computeKpis', () {
    test('returns three categories: Liquidity, Financial & Wealth and Debt', () {
      final cats = kpis(sheet: leveraged, annualIncome: 60000, annualSavings: 20000);
      expect(cats.map((c) => c.name), [s.healthCatLiquidity, s.healthCatWealth, s.healthCatDebt]);
    });

    test('Liquidity has 3 KPIs, Wealth 3 (the FIRE number joins it), Debt 2', () {
      final cats = kpis(sheet: leveraged);
      expect(cats.map((c) => c.kpis.length), [3, 3, 2]);
    });

    test('the KPIs are named as the app names them', () {
      final cats = kpis(sheet: leveraged);
      expect(cats[0].kpis.map((k) => k.name), [s.kpiLiquidityRatio, s.kpiExpenseCoverage, s.kpiSavingsRate]);
      expect(cats[1].kpis.map((k) => k.name), [s.kpiInvestmentWeight, s.kpiLiquidAssetRatio, s.kpiIncomeToWealth]);
      expect(cats[2].kpis.map((k) => k.name), [s.kpiDebtToAssets, s.kpiCreditLineUsage]);
    });
  });

  group('balance sheet figures', () {
    test('cash is the accounts plus the money-market funds; credit lines are not in it', () {
      expect(leveraged.cash, 232000);
    });

    test('owed is the overdrawn accounts plus the liabilities', () {
      expect(const HealthBalanceSheet(netWorth: 0, overdrawnAccounts: 130000, liabilities: 70000).owed, 200000);
    });

    test('gross assets are the net worth plus what is owed', () {
      expect(leveraged.grossAssets, 1002000);
    });
  });

  group('Liquidity ratio thresholds', () {
    // liquidityRatio = cash / net worth * 100
    // Thresholds: scarso < 10, sufficiente [10,15), buono [15,25), ottimo >= 25

    HealthKpi ratioOf(double cashShare) => liquidityRatio(
      kpis(
        sheet: HealthBalanceSheet(bankBalances: cashShare, positiveBankBalances: cashShare, netWorth: 100000),
      ),
    );

    test('0% cash -> scarso', () => expect(ratioOf(0).rating, Rating.scarso));
    test('12% cash -> sufficiente', () => expect(ratioOf(12000).rating, Rating.sufficiente));
    test('20% cash -> buono', () => expect(ratioOf(20000).rating, Rating.buono));
    test('30% cash -> ottimo', () => expect(ratioOf(30000).rating, Rating.ottimo));

    test('the money-market funds count as cash, the credit lines do not', () {
      final kpi = liquidityRatio(kpis(sheet: leveraged));
      // (-128,000 + 360,000) / 872,000
      expect(kpi.value, closeTo(26.606, 0.001));
      expect(kpi.rating, Rating.ottimo);
    });

    test('overdrawn accounts take cash down: cash can be negative', () {
      final kpi = liquidityRatio(
        kpis(sheet: const HealthBalanceSheet(bankBalances: -20000, overdrawnAccounts: 20000, netWorth: 80000, investments: 100000)),
      );
      expect(kpi.value, -25);
      expect(kpi.rating, Rating.scarso);
    });
  });

  group('Expense coverage', () {
    // coverageMonths = cash / monthly expenses
    // Thresholds: scarso < 3, sufficiente [3,6), buono [6,12), ottimo >= 12

    HealthKpi monthsOf(double cash) => coverage(kpis(sheet: cashOnly(cash), estimatedAnnualExpenses: 12000));

    test('1 month coverage -> scarso', () => expect(monthsOf(1000).rating, Rating.scarso));
    test('4 months coverage -> sufficiente', () => expect(monthsOf(4000).rating, Rating.sufficiente));
    test('8 months coverage -> buono', () => expect(monthsOf(8000).rating, Rating.buono));
    test('15 months coverage -> ottimo', () => expect(monthsOf(15000).rating, Rating.ottimo));

    test('monthly expenses are the estimated annual expenses over 12', () {
      final kpi = coverage(kpis(sheet: leveraged, estimatedAnnualExpenses: 48000));
      expect(kpi.value, 58); // 232,000 / 4,000
      expect(kpi.rating, Rating.ottimo);
      expect(kpi.formula.split('\n'), contains('Monthly Expenses = estimated annual expenses / 12: 48,000.00 / 12'));
    });

    test('with no estimate yet, the average of this year stands in and the formula says so', () {
      final kpi = coverage(kpis(sheet: leveraged, thisYearMonthlyExpenses: 5800));
      expect(kpi.value, 40); // 232,000 / 5,800
      expect(kpi.formula.split('\n'), contains("Monthly Expenses = this year's average (no previous year yet)"));
    });

    test('the estimate wins over this year\'s pace', () {
      final kpi = coverage(kpis(sheet: leveraged, estimatedAnnualExpenses: 48000, thisYearMonthlyExpenses: 1));
      expect(kpi.value, 58);
    });

    test('unused credit lines are mentioned, never counted', () {
      final kpi = coverage(kpis(sheet: leveraged, estimatedAnnualExpenses: 48000));
      // 440,000 of lines − 130,000 drawn = 310,000, 77.5 months of 4,000 (rounds to 78).
      expect(kpi.formula.split('\n'), contains('Unused Credit Lines: 310,000.00 (about 78 more months, not counted)'));
      expect(kpi.value, 58, reason: 'the lines are not cash');
    });

    test('no credit lines left unused: no note', () {
      final kpi = coverage(
        kpis(
          sheet: const HealthBalanceSheet(bankBalances: -100000, overdrawnAccounts: 100000, creditLines: 100000, netWorth: 1),
          estimatedAnnualExpenses: 12000,
        ),
      );
      expect(kpi.formula, isNot(contains('Unused')));
    });

    test('negative cash is not "a negative number of months covered"', () {
      final kpi = coverage(
        kpis(sheet: const HealthBalanceSheet(bankBalances: -50000, overdrawnAccounts: 50000, netWorth: 1), estimatedAnnualExpenses: 12000),
      );
      expect(kpi.value, closeTo(-50, 0.001));
      expect(kpi.rating, Rating.scarso);
      expect(kpi.description, s.kpiCoverageNoCash);
    });

    test('no expenses: N/A, not 0 months rated Poor', () {
      for (final kpi in [coverage(kpis(sheet: leveraged)), coverage(kpis(sheet: leveraged, estimatedAnnualExpenses: 0))]) {
        expect(kpi.value, isNull);
        expect(kpi.rating, Rating.na);
        expect(kpi.description, s.noData);
        expect(kpi.formula, s.kpiFormulaExpenseCoverage, reason: 'only the symbolic line: no placeholder figures');
      }
    });
  });

  group('Savings rate thresholds', () {
    // savingsRate = annualSavings / annualIncome * 100
    // Thresholds: scarso < 10, sufficiente [10,20), buono [20,40), ottimo >= 40

    HealthKpi rateOf(double savings) => savingsRate(kpis(annualIncome: 100000, annualSavings: savings));

    test('5% savings rate -> scarso', () => expect(rateOf(5000).rating, Rating.scarso));
    test('15% savings rate -> sufficiente', () => expect(rateOf(15000).rating, Rating.sufficiente));
    test('25% savings rate -> buono', () => expect(rateOf(25000).rating, Rating.buono));
    test('50% savings rate -> ottimo', () => expect(rateOf(50000).rating, Rating.ottimo));

    test('needs no balances: it is income and savings', () {
      expect(rateOf(25000).value, 25);
    });
  });

  group('Investment weight', () {
    // investWeight = investments / gross assets * 100
    // Thresholds: scarso < 20, sufficiente [20,40), buono [40,60), ottimo >= 60

    HealthKpi weightOf(double investments) => investmentWeight(
      kpis(
        sheet: HealthBalanceSheet(
          bankBalances: 100000 - investments,
          positiveBankBalances: 100000 - investments,
          netWorth: 100000,
          investments: investments,
        ),
      ),
    );

    test('10% investment weight -> scarso', () => expect(weightOf(10000).rating, Rating.scarso));
    test('30% investment weight -> sufficiente', () => expect(weightOf(30000).rating, Rating.sufficiente));
    test('50% investment weight -> buono', () => expect(weightOf(50000).rating, Rating.buono));

    test('70% investment weight -> ottimo: the top of the scale is reachable', () {
      expect(weightOf(70000).rating, Rating.ottimo);
      expect(weightOf(70000).rating.score, 100);
    });

    test('it is measured over what is owned, before debts: leverage does not push it past 100%', () {
      final kpi = investmentWeight(kpis(sheet: leveraged));
      // 1,000,000 / (872,000 + 130,000)
      expect(kpi.value, closeTo(99.800, 0.001));
      expect(kpi.value, lessThanOrEqualTo(100));
    });

    test('each rating has its own text', () {
      final texts = {
        for (final invested in [90000.0, 50000.0, 30000.0, 10000.0]) weightOf(invested).rating: weightOf(invested).description,
      };
      expect(texts.keys, {Rating.ottimo, Rating.buono, Rating.sufficiente, Rating.scarso});
      expect(texts.values.toSet().length, 4);
    });
  });

  group('Liquid asset ratio', () {
    test('only the accounts above zero and the liquid investments count', () {
      final kpi = liquidAssetRatio(
        kpis(
          sheet: const HealthBalanceSheet(
            bankBalances: 10000,
            positiveBankBalances: 10000,
            netWorth: 110000,
            investments: 100000,
            liquidInvestments: 60000, // 40000 is illiquid (pension, real estate)
          ),
        ),
      );
      // (10,000 + 60,000) / 110,000
      expect(kpi.value, closeTo(63.6, 0.1));
    });

    test('with no liquid investments it is the accounts over the gross assets', () {
      final kpi = liquidAssetRatio(
        kpis(sheet: const HealthBalanceSheet(bankBalances: 10000, positiveBankBalances: 10000, netWorth: 110000, investments: 100000)),
      );
      expect(kpi.value, closeTo(9.1, 0.1));
    });

    test('an overdrawn account is a debt, not a negative liquid asset', () {
      final kpi = liquidAssetRatio(kpis(sheet: leveraged));
      // (2,000 + 940,000) / 1,002,000: the 130,000 overdrawn are in the gross assets as owed
      expect(kpi.value, closeTo(94.012, 0.001));
    });

    test('the money-market funds are not counted twice: they are already liquid investments', () {
      expect(
        liquidAssetRatio(kpis(sheet: leveraged)).formula.split('\n')[1],
        '(2,000.00 + 940,000.00) / 1,002,000.00 x 100',
        reason: 'cash (with the money market) would add it again',
      );
    });
  });

  group('Income-to-wealth', () {
    test('income of the last 12 months over the net worth', () {
      final kpi = incomeToWealth(kpis(sheet: leveraged, rollingIncome: 90000));
      expect(kpi.value, closeTo(10.321, 0.001));
      expect(kpi.rating, Rating.buono);
    });

    test('keeps its scale: under 5% Poor, 5-10% Fair, 10-20% Good, 20% or more Excellent', () {
      Rating at(double income) => incomeToWealth(kpis(sheet: cashOnly(100000), rollingIncome: income)).rating;
      expect(at(4000), Rating.scarso);
      expect(at(5000), Rating.sufficiente);
      expect(at(10000), Rating.buono);
      expect(at(20000), Rating.ottimo);
    });
  });

  group('Debt-to-assets', () {
    // owed / gross assets * 100. Thresholds: ottimo < 10, buono [10,30), sufficiente [30,50), scarso >= 50

    HealthKpi debtOf(double owed) => debtToAssets(
      kpis(
        sheet: HealthBalanceSheet(overdrawnAccounts: owed, bankBalances: -owed, netWorth: 100000 - owed),
      ),
    );

    test('under 10% of what you own -> ottimo', () => expect(debtOf(5000).rating, Rating.ottimo));
    test('10-30% -> buono', () => expect(debtOf(20000).rating, Rating.buono));
    test('30-50% -> sufficiente', () => expect(debtOf(40000).rating, Rating.sufficiente));
    test('50% or more -> scarso', () => expect(debtOf(60000).rating, Rating.scarso));

    test('nothing owed is 0%, Excellent', () {
      final kpi = debtToAssets(kpis(sheet: cashOnly(5000)));
      expect(kpi.value, 0);
      expect(kpi.rating, Rating.ottimo);
    });

    test('overdrawn accounts and liabilities are both debts, over the gross assets', () {
      final kpi = debtToAssets(
        kpis(sheet: const HealthBalanceSheet(overdrawnAccounts: 10000, liabilities: 80000, bankBalances: -10000, netWorth: 910000)),
      );
      // 90,000 / (910,000 + 90,000)
      expect(kpi.value, closeTo(9, 1e-9));
      expect(kpi.rating, Rating.ottimo);
    });

    test('the leveraged investor owes about 13% of what he owns', () {
      final kpi = debtToAssets(kpis(sheet: leveraged));
      expect(kpi.value, closeTo(12.974, 0.001));
      expect(kpi.rating, Rating.buono);
      expect(kpi.formula.split('\n'), [
        'Owed / Gross Assets x 100',
        '130,000.00 / 1,002,000.00 x 100',
        'Owed = overdrawn Accounts + Liabilities: 130,000.00 + 0.00',
        'Gross Assets = Net Worth + Owed: 872,000.00 + 130,000.00',
      ]);
    });
  });

  group('Credit-line usage', () {
    // overdrawn accounts / credit lines * 100. Thresholds: ottimo < 25, buono [25,50), sufficiente [50,75), scarso >= 75

    HealthKpi usageOf(double drawn) => creditLineUsage(
      kpis(
        sheet: HealthBalanceSheet(overdrawnAccounts: drawn, bankBalances: -drawn, creditLines: 100000, netWorth: 1),
      ),
    );

    test('under 25% -> ottimo', () => expect(usageOf(10000).rating, Rating.ottimo));
    test('25-50% -> buono', () => expect(usageOf(30000).rating, Rating.buono));
    test('50-75% -> sufficiente', () => expect(usageOf(60000).rating, Rating.sufficiente));
    test('75% or more -> scarso', () => expect(usageOf(80000).rating, Rating.scarso));

    test('more drawn than the lines allow reads over 100%', () {
      expect(usageOf(150000).value, 150);
      expect(usageOf(150000).rating, Rating.scarso);
    });

    test('the leveraged investor uses 130,000 of 440,000', () {
      final kpi = creditLineUsage(kpis(sheet: leveraged));
      expect(kpi.value, closeTo(29.545, 0.001));
      expect(kpi.rating, Rating.buono);
      expect(kpi.formula, 'Overdrawn Accounts / Credit Lines x 100\n130,000.00 / 440,000.00 x 100');
    });

    test('no credit lines: N/A, and it says why — it is not missing data', () {
      final kpi = creditLineUsage(kpis(sheet: cashOnly(5000)));
      expect(kpi.value, isNull);
      expect(kpi.rating, Rating.na);
      expect(kpi.description, s.kpiNoCreditLines);
      expect(kpi.description, isNot(s.noData));
    });
  });

  group('missing inputs are N/A, never a rated placeholder', () {
    test('no balance at all: every ratio over them says "No data"', () {
      final cats = kpis(annualIncome: 50000, annualSavings: 10000, rollingIncome: 50000, estimatedAnnualExpenses: 40000);
      for (final kpi in [
        liquidityRatio(cats),
        coverage(cats),
        investmentWeight(cats),
        liquidAssetRatio(cats),
        incomeToWealth(cats),
        debtToAssets(cats),
        creditLineUsage(cats),
      ]) {
        expect(kpi.value, isNull, reason: kpi.name);
        expect(kpi.rating, Rating.na, reason: kpi.name);
        expect(kpi.description, s.noData, reason: kpi.name);
        expect(kpi.formula.contains('\n'), isFalse, reason: '${kpi.name} keeps only its symbolic line');
      }
      expect(savingsRate(cats).value, closeTo(20, 1e-9), reason: 'it needs no balance');
    });

    test('no income: no savings rate (not 0% rated Poor) and no income-to-wealth', () {
      final cats = kpis(sheet: leveraged);
      expect(savingsRate(cats).rating, Rating.na);
      expect(savingsRate(cats).description, s.noData);
      expect(savingsRate(cats).formula, s.kpiFormulaSavingsRate);
      expect(incomeToWealth(cats).rating, Rating.na);
      expect(incomeToWealth(cats).description, s.noData);
    });

    test('a net worth of zero or less: the ratios over it are N/A and not meaningful, not missing', () {
      for (final netWorth in [0.0, -2000.0]) {
        final cats = kpis(
          sheet: HealthBalanceSheet(bankBalances: netWorth, overdrawnAccounts: netWorth < 0 ? -netWorth : 0, netWorth: netWorth),
          rollingIncome: 40000,
        );
        for (final kpi in [liquidityRatio(cats), incomeToWealth(cats), investmentWeight(cats), liquidAssetRatio(cats), debtToAssets(cats)]) {
          expect(kpi.rating, Rating.na, reason: '${kpi.name} over a net worth of $netWorth');
          expect(kpi.description, s.kpiNetWorthNotPositive, reason: kpi.name);
        }
      }
    });

    test('a negative net worth with something owned: the ratios over the gross assets still hold', () {
      // 100,000 invested, 150,000 owed on a liability: net worth −50,000, gross assets 100,000.
      final cats = kpis(sheet: const HealthBalanceSheet(netWorth: -50000, investments: 100000, liquidInvestments: 100000, liabilities: 150000));
      expect(liquidityRatio(cats).description, s.kpiNetWorthNotPositive);
      expect(investmentWeight(cats).value, 100);
      expect(debtToAssets(cats).value, 150);
      expect(debtToAssets(cats).rating, Rating.scarso);
    });

    test('a missing income says "No data", whatever the net worth', () {
      final cats = kpis(sheet: const HealthBalanceSheet(netWorth: -2000, bankBalances: -2000, overdrawnAccounts: 2000));
      expect(incomeToWealth(cats).description, s.noData);
    });
  });

  group('Rating properties', () {
    test('score values are correct', () {
      expect(Rating.ottimo.score, 100);
      expect(Rating.buono.score, 75);
      expect(Rating.sufficiente.score, 50);
      expect(Rating.scarso.score, 25);
      expect(Rating.na.score, 0);
    });

    test('labels return localized strings', () {
      expect(Rating.ottimo.label(s), s.ratingOttimo);
      expect(Rating.scarso.label(s), s.ratingScarso);
    });
  });

  group('the formulas', () {
    test('every figure of the leveraged investor can be traced to a named figure', () {
      final c = kpis(sheet: leveraged, annualIncome: 80000, annualSavings: 32000, rollingIncome: 90000, estimatedAnnualExpenses: 48000);
      expect(liquidityRatio(c).formula.split('\n'), [
        'Cash / Net Worth x 100',
        '232,000.00 / 872,000.00 x 100',
        'Cash = Accounts + Money Market: -128,000.00 + 360,000.00',
        'Net Worth = Total Assets chart',
      ]);
      expect(coverage(c).formula.split('\n'), [
        'Cash / Monthly Expenses',
        '232,000.00 / 4,000.00',
        'Monthly Expenses = estimated annual expenses / 12: 48,000.00 / 12',
        'Cash = Accounts + Money Market: -128,000.00 + 360,000.00',
        'Unused Credit Lines: 310,000.00 (about 78 more months, not counted)',
      ]);
      expect(investmentWeight(c).formula.split('\n'), [
        'Investments / Gross Assets x 100',
        '1,000,000.00 / 1,002,000.00 x 100',
        'Gross Assets = Net Worth + Owed: 872,000.00 + 130,000.00',
      ]);
      expect(liquidAssetRatio(c).formula.split('\n'), [
        '(Accounts above zero + Liquid Investments) / Gross Assets x 100',
        '(2,000.00 + 940,000.00) / 1,002,000.00 x 100',
        'Gross Assets = Net Worth + Owed: 872,000.00 + 130,000.00',
      ]);
      expect(incomeToWealth(c).formula.split('\n'), [
        'Income (12m) / Net Worth x 100',
        '90,000.00 / 872,000.00 x 100',
        'Net Worth = Total Assets chart',
      ]);
    });

    test('the figures in every formula are position size: privacy mode blurs them', () {
      final c = kpis(sheet: leveraged, annualIncome: 80000, annualSavings: 32000, rollingIncome: 90000, estimatedAnnualExpenses: 48000);
      for (final category in c) {
        for (final kpi in category.kpis) {
          expect(kpi.formulaFiguresPrivate, isTrue, reason: kpi.name);
        }
      }
    });
  });

  group('the whole picture, end to end', () {
    test('the leveraged investor scores Good, with every category weighing the same', () {
      var c = kpis(sheet: leveraged, annualIncome: 80000, annualSavings: 33000, rollingIncome: 90000, estimatedAnnualExpenses: 48000);
      final fire = computeFire(netWorth: leveraged.investableNetWorth, annualExpenses: 48000, swrPct: 2.75);
      final fireCard = fireKpi(fire: fire, s: s, money: (v) => '${v.round()} €');
      c = [
        for (final cat in c)
          if (cat.name == s.healthCatWealth) KpiCategory(name: cat.name, kpis: [...cat.kpis, fireCard]) else cat,
      ];
      final performance = KpiCategory(
        name: s.healthPerformance,
        kpis: const [
          HealthKpi(name: 'return', rating: Rating.ottimo), // 13% a year
          HealthKpi(name: 'position', rating: Rating.sufficiente), // 12.5% in one stock
          HealthKpi(name: 'ter', rating: Rating.ottimo),
        ],
      );

      expect(c[0].score, 100);
      expect(c[1].score, 81.25); // 100, 100, 75 (10.3% of income), 50 (46% of the FIRE number)
      expect(c[2].score, 75);
      expect(performance.score, closeTo(83.333, 0.001));
      final health = overallHealth([...c, performance]);
      expect(health.score, closeTo(84.896, 0.001));
      expect(health.rating, Rating.buono);
    });
  });

  group('incomeOverLastYear', () {
    ({int id, DateTime date, double amount}) record(DateTime date, double amount) => (id: 0, date: date, amount: amount);

    // A salary on the last day of every month, as the records of a real year run.
    final salaries = [
      record(DateTime(2025, 10, 31), 4800),
      record(DateTime(2025, 11, 28), 4800),
      record(DateTime(2025, 12, 31), 5800),
      for (var m = 1; m <= 9; m++) record(DateTime(2026, m, 28), 5000),
      record(DateTime(2026, 10, 30), 4900),
    ];
    const lastYear = 4800 + 5800 + 9 * 5000 + 4900;

    test('on the last day of the month it counts the salaries after the same day a year ago', () {
      expect(incomeOverLastYear(salaries, DateTime(2026, 10, 31)), lastYear);
    });

    test('the next day it counts the same salaries: a window of whole months would lose November\'s', () {
      expect(incomeOverLastYear(salaries, DateTime(2026, 11, 1)), lastYear);
      expect(incomeOverLastYear(salaries, DateTime(2026, 11, 27)), lastYear);
    });

    test('the day a year ago itself is out, today is in, the future is out', () {
      final records = [
        record(DateTime(2025, 10, 31), 1),
        record(DateTime(2025, 11, 1), 10),
        record(DateTime(2026, 10, 31), 100),
        record(DateTime(2026, 11, 1), 1000),
      ];
      expect(incomeOverLastYear(records, DateTime(2026, 10, 31)), 110);
    });

    test('a time of day on today or on the day a year ago does not move a record in or out', () {
      final records = [
        record(DateTime(2025, 10, 31, 23, 59), 1),
        record(DateTime(2026, 10, 31, 15, 30), 100),
      ];
      expect(incomeOverLastYear(records, DateTime(2026, 10, 31, 8)), 100);
    });

    test('no records: nothing', () {
      expect(incomeOverLastYear(const [], DateTime(2026, 10, 31)), 0);
    });
  });

  group('fireKpi: the FIRE number card', () {
    String money(double v) => '${NumberFormat.decimalPattern(locale).format(v.round())} €';

    test('the headline is the progress, a percentage; the FIRE number is the target under the name, its amount masked', () {
      final fire = computeFire(netWorth: 800000, annualExpenses: 48000, swrPct: 2.75);
      final kpi = fireKpi(fire: fire, s: s, money: money);
      expect(kpi.name, 'FIRE number');
      expect(kpi.value, closeTo(45.83, 0.01));
      expect(kpi.unit, '%');
      expect(kpi.subtitle, s.kpiFireTarget(privacySlot(0)), reason: 'the words readable, the amount in a slot');
      expect(kpi.subtitleFigures, ['1,745,455 €']);
    });

    test('it is rated on the progress, not on the amount', () {
      Rating at(double netWorth) => fireKpi(
        fire: computeFire(netWorth: netWorth, annualExpenses: 30000, swrPct: 2.75),
        s: s,
        money: money,
      ).rating;
      final number = 30000 / 0.0275;
      expect(at(number * 1.2), Rating.ottimo);
      expect(at(number * 0.6), Rating.buono);
      expect(at(number * 0.3), Rating.sufficiente);
      expect(at(number * 0.1), Rating.scarso);
    });

    test('without expenses there is no FIRE number: N/A with the reason, no amount', () {
      final kpi = fireKpi(fire: computeFire(netWorth: 810000, annualExpenses: 0, swrPct: 2.75), s: s, money: money);
      expect(kpi.value, isNull);
      expect(kpi.subtitleFigures, isEmpty);
      expect(kpi.subtitle, isNull);
      expect(kpi.rating, Rating.na);
      expect(kpi.description, s.kpiFireInsufficientData());
    });
  });

  group('computeLargestPosition', () {
    final stock = _asset(1, InstrumentType.stock, ticker: 'ACME');
    final other = _asset(2, InstrumentType.stock, ticker: 'OTHR');
    final etf = _asset(3, InstrumentType.etf, ticker: 'WRLD');
    final bond = _asset(4, InstrumentType.bond, ticker: 'BND');
    final coin = _asset(5, InstrumentType.crypto, ticker: 'BTC');

    test('the biggest single stock or crypto over everything held', () {
      final p = computeLargestPosition([stock, other, etf, bond, coin], {1: 125, 2: 50, 3: 700, 4: 100, 5: 25})!;
      expect(p.name, 'ACME');
      expect(p.value, 125);
      expect(p.total, 1000);
      expect(p.pct, 12.5);
    });

    test('a fund or bond bigger than any stock is not a concentration: funds are spread over many names', () {
      final p = computeLargestPosition([stock, etf], {1: 10, 2: 0, 3: 990})!;
      expect(p.name, 'ACME');
      expect(p.pct, 1);
    });

    test('a crypto counts like a stock', () {
      expect(computeLargestPosition([stock, coin], {1: 10, 5: 90})!.name, 'BTC');
    });

    test('assets sharing a ticker are one position', () {
      final twin = _asset(6, InstrumentType.stock, ticker: 'ACME');
      final p = computeLargestPosition([stock, twin, other], {1: 30, 6: 30, 2: 50})!;
      expect(p.name, 'ACME');
      expect(p.value, 60);
    });

    test('an asset without a ticker is named by its name', () {
      final p = computeLargestPosition([_asset(7, InstrumentType.stock)], {7: 10})!;
      expect(p.name, 'Asset 7');
    });

    test('no single stock or crypto held: nothing concentrated — 0%, but a total to measure against', () {
      final p = computeLargestPosition([etf, bond], {3: 90, 4: 10})!;
      expect(p.name, isNull);
      expect(p.value, 0);
      expect(p.pct, 0);
    });

    test('an asset without a market value, or a liability, is left out — never weighed as worth 0', () {
      final p = computeLargestPosition([stock, etf, other], {1: 100, 2: -50})!;
      expect(p.total, 100, reason: 'the liability and the unvalued asset are in no total');
      expect(p.name, 'ACME');
    });

    test('nothing valued: nothing to measure', () {
      expect(computeLargestPosition([stock], const {}), isNull);
      expect(computeLargestPosition(const [], const {}), isNull);
      expect(computeLargestPosition([stock], {1: 0}), isNull);
    });
  });

  group('largestPositionKpi', () {
    HealthKpi kpiOf(double stockValue, {double total = 1000}) => largestPositionKpi(
      position: LargestPosition(name: 'ACME', value: stockValue, total: total),
      s: s,
      locale: locale,
    );

    test('up to 5% Excellent, up to 10% Good, up to 20% Fair, above Poor', () {
      expect(kpiOf(50).rating, Rating.ottimo);
      expect(kpiOf(51).rating, Rating.buono);
      expect(kpiOf(100).rating, Rating.buono);
      expect(kpiOf(125).rating, Rating.sufficiente);
      expect(kpiOf(200).rating, Rating.sufficiente);
      expect(kpiOf(201).rating, Rating.scarso);
    });

    test('the formula names the position and its amounts, so its amounts are private', () {
      final kpi = kpiOf(125);
      expect(kpi.value, 12.5);
      expect(kpi.formula.split('\n'), ['Largest Stock or Crypto / Portfolio value x 100', 'ACME: 125.00 / 1,000.00 x 100']);
      expect(kpi.formulaFiguresPrivate, isTrue);
    });

    test('no single stock or crypto: 0%, Excellent', () {
      final kpi = largestPositionKpi(position: const LargestPosition(name: null, value: 0, total: 1000), s: s, locale: locale);
      expect(kpi.value, 0);
      expect(kpi.rating, Rating.ottimo);
      expect(kpi.formula.split('\n').last, s.kpiNoSinglePositions);
    });

    test('nothing to measure: N/A', () {
      final kpi = largestPositionKpi(position: null, s: s, locale: locale);
      expect(kpi.value, isNull);
      expect(kpi.rating, Rating.na);
      expect(kpi.description, s.noData);
    });
  });

  group('annualizedReturnKpi', () {
    PillarPerformanceSnapshot snapshot({required DateTime since, double? twrr = 1.0, double? cagr = 0.13, DateTime? asOf}) =>
        PillarPerformanceSnapshot(
          asOfDate: asOf ?? DateTime(2026, 10, 31),
          inceptionDate: since,
          marketValue: 1000,
          netInvested: 800,
          absoluteReturnAmount: 200,
          absoluteReturnPct: 0.25,
          twrr: twrr,
          cagr: cagr,
          hasSufficientHistory: true,
        );

    test('the time-weighted return per year, and the whole stretch it comes from', () {
      final kpi = annualizedReturnKpi(
        snapshot: snapshot(since: DateTime(2018, 2, 15), twrr: 1.951, cagr: 0.1322),
        s: s,
        locale: locale,
      );
      expect(kpi.value, closeTo(13.22, 1e-9));
      expect(kpi.rating, Rating.ottimo);
      expect(kpi.formula.split('\n'), [
        'Time-weighted return, per year',
        'Since Feb 15, 2018: +195.1%',
        'Per year: 13.22%',
      ]);
    });

    test('only percentages and a date: nothing to mask', () {
      final kpi = annualizedReturnKpi(
        snapshot: snapshot(since: DateTime(2018, 2, 15)),
        s: s,
        locale: locale,
      );
      expect(kpi.formulaFiguresPrivate, isFalse);
    });

    test('rating: under 0 Poor, 0-2 Fair, 2-5 Good, 5 or more Excellent', () {
      Rating at(double cagr) => annualizedReturnKpi(
        snapshot: snapshot(since: DateTime(2020, 1, 1), cagr: cagr),
        s: s,
        locale: locale,
      ).rating;
      expect(at(-0.01), Rating.scarso);
      expect(at(0), Rating.sufficiente);
      expect(at(0.019), Rating.sufficiente);
      expect(at(0.02), Rating.buono);
      expect(at(0.049), Rating.buono);
      expect(at(0.05), Rating.ottimo);
    });

    test('a loss is shown as a loss', () {
      final kpi = annualizedReturnKpi(
        snapshot: snapshot(since: DateTime(2020, 1, 1), twrr: -0.2, cagr: -0.04),
        s: s,
        locale: locale,
      );
      expect(kpi.value, closeTo(-4, 1e-9));
      expect(kpi.formula.split('\n')[1], contains('-20.0%'));
    });

    test('under a year of history there is no annual rate to speak of: N/A with the reason', () {
      final kpi = annualizedReturnKpi(
        snapshot: snapshot(since: DateTime(2026, 1, 1), cagr: 0.4, asOf: DateTime(2026, 10, 31)),
        s: s,
        locale: locale,
      );
      expect(kpi.value, isNull);
      expect(kpi.rating, Rating.na);
      expect(kpi.description, s.kpiAnnualizedReturnNeedsYear);
    });

    test('exactly a year of history is enough', () {
      final kpi = annualizedReturnKpi(
        snapshot: snapshot(since: DateTime(2025, 10, 31), cagr: 0.06),
        s: s,
        locale: locale,
      );
      expect(kpi.value, closeTo(6, 1e-9));
    });

    test('no return could be computed: N/A', () {
      expect(
        annualizedReturnKpi(
          snapshot: snapshot(since: DateTime(2020, 1, 1), cagr: null),
          s: s,
          locale: locale,
        ).rating,
        Rating.na,
      );
      expect(
        annualizedReturnKpi(
          snapshot: snapshot(since: DateTime(2020, 1, 1), twrr: null),
          s: s,
          locale: locale,
        ).rating,
        Rating.na,
      );
      expect(annualizedReturnKpi(snapshot: null, s: s, locale: locale).rating, Rating.na);
      expect(
        annualizedReturnKpi(snapshot: PillarPerformanceSnapshot.empty(DateTime(2026, 10, 31)), s: s, locale: locale).rating,
        Rating.na,
        reason: 'nothing invested',
      );
    });

    test('the dates are spelled in the display language', () {
      final kpi = annualizedReturnKpi(
        snapshot: snapshot(since: DateTime(2018, 2, 15)),
        s: AppStrings.it,
        locale: 'it_IT',
      );
      expect(kpi.formula.split('\n')[1], startsWith('Dal 15 feb 2018: '));
    });
  });

  group('rateTer', () {
    test('the cheaper, the better', () {
      expect(rateTer(0.2), Rating.ottimo);
      expect(rateTer(0.5), Rating.buono);
      expect(rateTer(1.0), Rating.sufficiente);
      expect(rateTer(1.01), Rating.scarso);
    });
  });

  group('computeFire', () {
    test('insufficientData when annualExpenses <= 0', () {
      final r = computeFire(netWorth: 100000, annualExpenses: 0, swrPct: 2.75);
      expect(r.insufficientData, true);
      expect(r.rating, Rating.na);
    });

    test('insufficientData when swrPct <= 0', () {
      final r = computeFire(netWorth: 100000, annualExpenses: 30000, swrPct: 0);
      expect(r.insufficientData, true);
      expect(r.rating, Rating.na);
    });

    test('FI number = annualExpenses / (swr/100)', () {
      final r = computeFire(netWorth: 0, annualExpenses: 30000, swrPct: 2.75);
      // 30000 / 0.0275 = 1,090,909.09…
      expect(r.fiNumber, closeTo(1090909.09, 0.5));
    });

    test('progress 0% when netWorth = 0', () {
      final r = computeFire(netWorth: 0, annualExpenses: 30000, swrPct: 2.75);
      expect(r.progressPct, 0);
      expect(r.rating, Rating.scarso);
    });

    test('progress capped at 0 when netWorth is negative', () {
      final r = computeFire(netWorth: -1000, annualExpenses: 30000, swrPct: 2.75);
      expect(r.progressPct, 0);
    });

    test('progress 100% is ottimo', () {
      final fi = 30000 / 0.0275;
      final r = computeFire(netWorth: fi, annualExpenses: 30000, swrPct: 2.75);
      expect(r.progressPct, closeTo(100, 1e-9));
      expect(r.rating, Rating.ottimo);
    });

    test('progress above 100% stays ottimo', () {
      final fi = 30000 / 0.0275;
      final r = computeFire(netWorth: fi * 2, annualExpenses: 30000, swrPct: 2.75);
      expect(r.progressPct, closeTo(200, 1e-9));
      expect(r.rating, Rating.ottimo);
    });

    test('progress 50% is buono', () {
      final fi = 30000 / 0.0275;
      final netWorth = fi * 0.5;
      final r = computeFire(netWorth: netWorth, annualExpenses: 30000, swrPct: 2.75);
      expect(r.progressPct, closeTo(50, 1e-9));
      expect(r.rating, Rating.buono);
    });

    test('progress 25% is sufficiente', () {
      final fi = 30000 / 0.0275;
      final netWorth = fi * 0.25;
      final r = computeFire(netWorth: netWorth, annualExpenses: 30000, swrPct: 2.75);
      expect(r.progressPct, closeTo(25, 1e-9));
      expect(r.rating, Rating.sufficiente);
    });

    test('progress below 25% is scarso', () {
      final fi = 30000 / 0.0275;
      final netWorth = fi * 0.249;
      final r = computeFire(netWorth: netWorth, annualExpenses: 30000, swrPct: 2.75);
      expect(r.progressPct, closeTo(24.9, 1e-9));
      expect(r.rating, Rating.scarso);
    });

    test('default SWR constant is 2.75%', () {
      expect(kDefaultFireSwrPct, 2.75);
    });

    test('rateFire uses progress thresholds', () {
      expect(rateFire(100), Rating.ottimo);
      expect(rateFire(50), Rating.buono);
      expect(rateFire(25), Rating.sufficiente);
      expect(rateFire(0), Rating.scarso);
    });
  });
}
