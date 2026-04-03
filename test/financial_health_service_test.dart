import 'package:flutter_test/flutter_test.dart';
import 'package:finance_copilot/services/financial_health_service.dart';
import 'package:finance_copilot/l10n/app_strings.dart';

void main() {
  const s = AppStrings.en;
  const locale = 'en_US';

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

  group('computeKpis', () {
    test('returns exactly 2 categories (Liquidity and Wealth)', () {
      final cats = computeKpis(
        cash: 10000, investments: 50000,
        annualIncome: 60000, annualExpenses: 40000,
        annualSavings: 20000, monthlyExpenses: 3333,
        s: s, locale: locale,
      );
      expect(cats.length, 2);
      expect(cats[0].name, s.healthCatLiquidity);
      expect(cats[1].name, s.healthCatWealth);
    });

    test('Liquidity category has 3 KPIs', () {
      final cats = computeKpis(
        cash: 10000, investments: 50000,
        annualIncome: 60000, annualExpenses: 40000,
        annualSavings: 20000, monthlyExpenses: 3333,
        s: s, locale: locale,
      );
      expect(cats[0].kpis.length, 3);
    });

    test('Wealth category has 3 KPIs', () {
      final cats = computeKpis(
        cash: 10000, investments: 50000,
        annualIncome: 60000, annualExpenses: 40000,
        annualSavings: 20000, monthlyExpenses: 3333,
        s: s, locale: locale,
      );
      expect(cats[1].kpis.length, 3);
    });
  });

  group('Liquidity ratio thresholds', () {
    // liquidityRatio = cash / (cash + investments) * 100
    // Thresholds: scarso < 10, sufficiente [10,15), buono [15,25), ottimo >= 25

    test('0% cash -> scarso', () {
      final cats = computeKpis(
        cash: 0, investments: 100000,
        annualIncome: 0, annualExpenses: 0,
        annualSavings: 0, monthlyExpenses: 0,
        s: s, locale: locale,
      );
      final kpi = cats[0].kpis[0]; // liquidity ratio
      expect(kpi.rating, Rating.scarso);
    });

    test('12% cash -> sufficiente', () {
      // cash=12000, investments=88000 -> 12%
      final cats = computeKpis(
        cash: 12000, investments: 88000,
        annualIncome: 0, annualExpenses: 0,
        annualSavings: 0, monthlyExpenses: 0,
        s: s, locale: locale,
      );
      final kpi = cats[0].kpis[0];
      expect(kpi.rating, Rating.sufficiente);
    });

    test('20% cash -> buono', () {
      // cash=20000, investments=80000 -> 20%
      final cats = computeKpis(
        cash: 20000, investments: 80000,
        annualIncome: 0, annualExpenses: 0,
        annualSavings: 0, monthlyExpenses: 0,
        s: s, locale: locale,
      );
      final kpi = cats[0].kpis[0];
      expect(kpi.rating, Rating.buono);
    });

    test('30% cash -> ottimo', () {
      // cash=30000, investments=70000 -> 30%
      final cats = computeKpis(
        cash: 30000, investments: 70000,
        annualIncome: 0, annualExpenses: 0,
        annualSavings: 0, monthlyExpenses: 0,
        s: s, locale: locale,
      );
      final kpi = cats[0].kpis[0];
      expect(kpi.rating, Rating.ottimo);
    });
  });

  group('Expense coverage thresholds', () {
    // coverageMonths = cash / monthlyExpenses
    // Thresholds: scarso < 3, sufficiente [3,6), buono [6,12), ottimo >= 12

    test('1 month coverage -> scarso', () {
      final cats = computeKpis(
        cash: 1000, investments: 0,
        annualIncome: 0, annualExpenses: 0,
        annualSavings: 0, monthlyExpenses: 1000,
        s: s, locale: locale,
      );
      final kpi = cats[0].kpis[1]; // expense coverage
      expect(kpi.rating, Rating.scarso);
    });

    test('4 months coverage -> sufficiente', () {
      final cats = computeKpis(
        cash: 4000, investments: 0,
        annualIncome: 0, annualExpenses: 0,
        annualSavings: 0, monthlyExpenses: 1000,
        s: s, locale: locale,
      );
      final kpi = cats[0].kpis[1];
      expect(kpi.rating, Rating.sufficiente);
    });

    test('8 months coverage -> buono', () {
      final cats = computeKpis(
        cash: 8000, investments: 0,
        annualIncome: 0, annualExpenses: 0,
        annualSavings: 0, monthlyExpenses: 1000,
        s: s, locale: locale,
      );
      final kpi = cats[0].kpis[1];
      expect(kpi.rating, Rating.buono);
    });

    test('15 months coverage -> ottimo', () {
      final cats = computeKpis(
        cash: 15000, investments: 0,
        annualIncome: 0, annualExpenses: 0,
        annualSavings: 0, monthlyExpenses: 1000,
        s: s, locale: locale,
      );
      final kpi = cats[0].kpis[1];
      expect(kpi.rating, Rating.ottimo);
    });
  });

  group('Savings rate thresholds', () {
    // savingsRate = annualSavings / annualIncome * 100
    // Thresholds: scarso < 10, sufficiente [10,20), buono [20,40), ottimo >= 40

    test('5% savings rate -> scarso', () {
      final cats = computeKpis(
        cash: 0, investments: 0,
        annualIncome: 100000, annualExpenses: 95000,
        annualSavings: 5000, monthlyExpenses: 0,
        s: s, locale: locale,
      );
      final kpi = cats[0].kpis[2]; // savings rate
      expect(kpi.rating, Rating.scarso);
    });

    test('15% savings rate -> sufficiente', () {
      final cats = computeKpis(
        cash: 0, investments: 0,
        annualIncome: 100000, annualExpenses: 85000,
        annualSavings: 15000, monthlyExpenses: 0,
        s: s, locale: locale,
      );
      final kpi = cats[0].kpis[2];
      expect(kpi.rating, Rating.sufficiente);
    });

    test('25% savings rate -> buono', () {
      final cats = computeKpis(
        cash: 0, investments: 0,
        annualIncome: 100000, annualExpenses: 75000,
        annualSavings: 25000, monthlyExpenses: 0,
        s: s, locale: locale,
      );
      final kpi = cats[0].kpis[2];
      expect(kpi.rating, Rating.buono);
    });

    test('50% savings rate -> ottimo', () {
      final cats = computeKpis(
        cash: 0, investments: 0,
        annualIncome: 100000, annualExpenses: 50000,
        annualSavings: 50000, monthlyExpenses: 0,
        s: s, locale: locale,
      );
      final kpi = cats[0].kpis[2];
      expect(kpi.rating, Rating.ottimo);
    });
  });

  group('Investment weight thresholds', () {
    // investWeight = investments / (cash + investments) * 100
    // Thresholds: scarso < 20, sufficiente [20,40), buono [40,60), alto >= 60

    test('10% investment weight -> scarso', () {
      final cats = computeKpis(
        cash: 90000, investments: 10000,
        annualIncome: 0, annualExpenses: 0,
        annualSavings: 0, monthlyExpenses: 0,
        s: s, locale: locale,
      );
      final kpi = cats[1].kpis[0]; // investment weight
      expect(kpi.rating, Rating.scarso);
    });

    test('30% investment weight -> sufficiente', () {
      final cats = computeKpis(
        cash: 70000, investments: 30000,
        annualIncome: 0, annualExpenses: 0,
        annualSavings: 0, monthlyExpenses: 0,
        s: s, locale: locale,
      );
      final kpi = cats[1].kpis[0];
      expect(kpi.rating, Rating.sufficiente);
    });

    test('50% investment weight -> buono', () {
      final cats = computeKpis(
        cash: 50000, investments: 50000,
        annualIncome: 0, annualExpenses: 0,
        annualSavings: 0, monthlyExpenses: 0,
        s: s, locale: locale,
      );
      final kpi = cats[1].kpis[0];
      expect(kpi.rating, Rating.buono);
    });

    test('70% investment weight -> alto', () {
      final cats = computeKpis(
        cash: 30000, investments: 70000,
        annualIncome: 0, annualExpenses: 0,
        annualSavings: 0, monthlyExpenses: 0,
        s: s, locale: locale,
      );
      final kpi = cats[1].kpis[0];
      expect(kpi.rating, Rating.alto);
    });
  });

  group('Edge cases', () {
    test('zero income does not crash, savings rate is 0', () {
      final cats = computeKpis(
        cash: 10000, investments: 50000,
        annualIncome: 0, annualExpenses: 0,
        annualSavings: 0, monthlyExpenses: 0,
        s: s, locale: locale,
      );
      final savingsKpi = cats[0].kpis[2]; // savings rate
      expect(savingsKpi.value, 0.0);
      expect(savingsKpi.rating, Rating.scarso);
    });

    test('zero assets does not crash, all ratios are 0', () {
      final cats = computeKpis(
        cash: 0, investments: 0,
        annualIncome: 50000, annualExpenses: 40000,
        annualSavings: 10000, monthlyExpenses: 3333,
        s: s, locale: locale,
      );
      final liquidityRatio = cats[0].kpis[0];
      expect(liquidityRatio.value, 0.0);
      final investWeight = cats[1].kpis[0];
      expect(investWeight.value, 0.0);
    });

    test('all zeros does not crash', () {
      final cats = computeKpis(
        cash: 0, investments: 0,
        annualIncome: 0, annualExpenses: 0,
        annualSavings: 0, monthlyExpenses: 0,
        s: s, locale: locale,
      );
      expect(cats.length, 2);
      for (final cat in cats) {
        for (final kpi in cat.kpis) {
          expect(kpi.value, isNotNull);
        }
      }
    });
  });

  group('Rating properties', () {
    test('score values are correct', () {
      expect(Rating.ottimo.score, 100);
      expect(Rating.buono.score, 75);
      expect(Rating.alto.score, 75);
      expect(Rating.sufficiente.score, 50);
      expect(Rating.scarso.score, 25);
      expect(Rating.na.score, 0);
    });

    test('labels return localized strings', () {
      expect(Rating.ottimo.label(s), s.ratingOttimo);
      expect(Rating.scarso.label(s), s.ratingScarso);
    });
  });
}
