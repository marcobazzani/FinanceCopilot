// Health KPIs speak the user's language all the way down: the formula shown in
// each KPI's info dialog, the months unit and the description chosen by the
// rating. The rating stays an enum until it is put into words, so a
// description can no longer drift from its rating through a mistyped token.
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/pillars/financial_health_service.dart';

void main() {
  List<KpiCategory> kpis(
    AppStrings s, {
    double cash = 10000,
    double investments = 100000,
    double liquidInvestments = 0,
    double annualIncome = 0,
    double? rollingIncome,
    double annualSavings = 0,
    double monthlyExpenses = 0,
    String locale = 'en_US',
  }) => computeKpis(
    cash: cash,
    investments: investments,
    liquidInvestments: liquidInvestments,
    annualIncome: annualIncome,
    rollingIncome: rollingIncome,
    annualExpenses: annualIncome - annualSavings,
    annualSavings: annualSavings,
    monthlyExpenses: monthlyExpenses,
    s: s,
    locale: locale,
  );

  HealthKpi liquidity(List<KpiCategory> c) => c[0].kpis[0];
  HealthKpi coverage(List<KpiCategory> c) => c[0].kpis[1];
  HealthKpi savings(List<KpiCategory> c) => c[0].kpis[2];
  HealthKpi investWeight(List<KpiCategory> c) => c[1].kpis[0];
  HealthKpi liquidAsset(List<KpiCategory> c) => c[1].kpis[1];
  HealthKpi incomeToWealth(List<KpiCategory> c) => c[1].kpis[2];

  group('descriptions follow the rating', () {
    const liquidityTexts = {
      Rating.ottimo: (
        'Excellent liquidity! You have a good emergency cushion.',
        'Ottima liquidità! Hai un buon cuscinetto per le emergenze.',
      ),
      Rating.buono: ('Good liquidity, you are in a solid position.', 'Buona liquidità, sei in una posizione solida.'),
      Rating.sufficiente: (
        'Liquidity is fair, but watch out for unexpected expenses.',
        'La tua liquidità è sufficiente, ma fai attenzione a spese impreviste.',
      ),
      Rating.scarso: (
        'Low liquidity. Consider building up emergency reserves.',
        'Liquidità bassa. Valuta di aumentare le riserve di emergenza.',
      ),
    };
    // cash share of net worth: 30%, 20%, 12%, 5%.
    const liquidityCash = {Rating.ottimo: 30000.0, Rating.buono: 20000.0, Rating.sufficiente: 12000.0, Rating.scarso: 5000.0};

    for (final rating in liquidityTexts.keys) {
      test('liquidity ratio, ${rating.name}', () {
        final cash = liquidityCash[rating]!;
        for (final (s, text) in [(AppStrings.en, liquidityTexts[rating]!.$1), (AppStrings.it, liquidityTexts[rating]!.$2)]) {
          final kpi = liquidity(kpis(s, cash: cash, investments: 100000 - cash));
          expect(kpi.rating, rating);
          expect(kpi.description, text);
        }
      });
    }

    const savingsTexts = {
      Rating.ottimo: (
        'Excellent! You can focus on other aspects of your financial life.',
        'Sei in un\'ottima situazione! Puoi dedicarti ad altri aspetti della tua vita finanziaria.',
      ),
      Rating.buono: ('Good savings rate, keep it up!', 'Buon tasso di risparmio, continua così!'),
      Rating.sufficiente: ('Average savings rate, try to improve it.', 'Tasso di risparmio nella media, cerca di migliorarlo.'),
      Rating.scarso: (
        'Low savings rate. Try reducing non-essential expenses.',
        'Tasso di risparmio basso. Cerca di ridurre le spese non essenziali.',
      ),
    };
    const savingsAmount = {Rating.ottimo: 50000.0, Rating.buono: 25000.0, Rating.sufficiente: 15000.0, Rating.scarso: 5000.0};

    for (final rating in savingsTexts.keys) {
      test('savings rate, ${rating.name}', () {
        for (final (s, text) in [(AppStrings.en, savingsTexts[rating]!.$1), (AppStrings.it, savingsTexts[rating]!.$2)]) {
          final kpi = savings(kpis(s, annualIncome: 100000, annualSavings: savingsAmount[rating]!));
          expect(kpi.rating, rating);
          expect(kpi.description, text);
        }
      });
    }

    test('investment weight has one text whatever the rating', () {
      for (final investments in [10000.0, 50000.0, 90000.0]) {
        expect(
          investWeight(kpis(AppStrings.en, cash: 100000 - investments, investments: investments)).description,
          'Your financial investments have the right weight in your overall wealth.',
        );
        expect(
          investWeight(kpis(AppStrings.it, cash: 100000 - investments, investments: investments)).description,
          'I tuoi investimenti finanziari hanno il giusto spazio nel tuo patrimonio complessivo.',
        );
      }
    });

    test('liquid asset ratio: excellent and good read as mostly liquid, the rest as not', () {
      const good = (
        'Most of your wealth is quickly convertible to cash: unexpected expenses are manageable.',
        'Gran parte del tuo patrimonio è liquidabile in breve tempo: le spese impreviste non sono un problema.',
      );
      const low = (
        'A significant portion of your wealth is not easily convertible to cash.',
        'Una parte significativa del tuo patrimonio non è facilmente liquidabile.',
      );
      // (cash + liquid) / gross with cash 10k, investments 100k: 90.9%, 72.7%, 63.6%, 9.1%.
      final cases = {
        90000.0: (Rating.ottimo, good),
        70000.0: (Rating.buono, good),
        60000.0: (Rating.sufficiente, low),
        0.0: (Rating.scarso, low),
      };
      for (final MapEntry(key: liquid, value: (rating, texts)) in cases.entries) {
        for (final (s, text) in [(AppStrings.en, texts.$1), (AppStrings.it, texts.$2)]) {
          final kpi = liquidAsset(kpis(s, liquidInvestments: liquid));
          expect(kpi.rating, rating);
          expect(kpi.description, text);
        }
      }
    });

    test('income-to-wealth: excellent and good read as proportionate, the rest as too low', () {
      const good = ('Your income is proportional to your wealth.', 'Le tue entrate sono proporzionate al tuo patrimonio.');
      const low = (
        'Your income is too low relative to your wealth. Pay attention to your investments.',
        'Le tue entrate sono troppo basse rispetto al tuo patrimonio. Fai attenzione ai tuoi investimenti.',
      );
      // Rolling income over a 110k net worth: 45.5%, 10.9%, 7.3%, 0.9%.
      final cases = {
        50000.0: (Rating.ottimo, good),
        12000.0: (Rating.buono, good),
        8000.0: (Rating.sufficiente, low),
        1000.0: (Rating.scarso, low),
      };
      for (final MapEntry(key: income, value: (rating, texts)) in cases.entries) {
        for (final (s, text) in [(AppStrings.en, texts.$1), (AppStrings.it, texts.$2)]) {
          final kpi = incomeToWealth(kpis(s, rollingIncome: income));
          expect(kpi.rating, rating);
          expect(kpi.description, text);
        }
      }
    });
  });

  group('months unit', () {
    test('follows the language', () {
      expect(coverage(kpis(AppStrings.en, monthlyExpenses: 1000)).unit, ' months');
      expect(coverage(kpis(AppStrings.it, monthlyExpenses: 1000)).unit, ' mesi');
    });
  });

  group('FI target progress description', () {
    test('one text per rating, in both languages', () {
      expect(fireDescription(rateFire(120), AppStrings.en), 'Your net worth fully covers the estimated FI target.');
      expect(fireDescription(rateFire(60), AppStrings.en), 'Your net worth covers a good portion of the estimated FI target.');
      expect(fireDescription(rateFire(30), AppStrings.en), 'Your net worth covers only part of the estimated FI target.');
      expect(fireDescription(rateFire(10), AppStrings.en), 'Your net worth is still far from the estimated FI target.');
      expect(fireDescription(rateFire(120), AppStrings.it), 'Il tuo patrimonio copre completamente il target FI stimato.');
      expect(fireDescription(rateFire(60), AppStrings.it), 'Il tuo patrimonio copre una buona parte del target FI stimato.');
      expect(fireDescription(rateFire(30), AppStrings.it), 'Il tuo patrimonio copre solo in parte il target FI stimato.');
      expect(fireDescription(rateFire(10), AppStrings.it), 'Il tuo patrimonio è ancora lontano dal target FI stimato.');
    });
  });

  group('formulas', () {
    List<String> firstLines(List<KpiCategory> c) => [
      for (final kpi in [...c[0].kpis, ...c[1].kpis]) kpi.formula.split('\n').first,
    ];

    test('English: symbolic formula, then the figures in the display locale', () {
      final c = kpis(
        AppStrings.en,
        cash: 15000,
        investments: 85000,
        liquidInvestments: 60000,
        annualIncome: 40000,
        rollingIncome: 42000,
        annualSavings: 10000,
        monthlyExpenses: 2500,
      );
      expect(firstLines(c), [
        'Cash / Net Worth x 100',
        'Cash / Monthly Expenses',
        'Savings / Income x 100',
        'Investments / Gross Assets x 100',
        '(Cash + Liquid Investments) / Gross Assets x 100',
        'Income (12m) / Net Worth x 100',
      ]);
      expect(liquidity(c).formula, 'Cash / Net Worth x 100\n15,000 / 100,000 x 100');
      expect(liquidAsset(c).formula, '(Cash + Liquid Investments) / Gross Assets x 100\n(15,000 + 60,000) / 100,000 x 100');
    });

    test('Italian: the formulas are Italian too, the figures use the Italian grouping', () {
      final c = kpis(
        AppStrings.it,
        cash: 15000,
        investments: 85000,
        liquidInvestments: 60000,
        annualIncome: 40000,
        rollingIncome: 42000,
        annualSavings: 10000,
        monthlyExpenses: 2500,
        locale: 'it_IT',
      );
      expect(firstLines(c), [
        'Liquidità / Patrimonio netto x 100',
        'Liquidità / Spese mensili',
        'Risparmi / Entrate x 100',
        'Investimenti / Patrimonio lordo x 100',
        '(Liquidità + Investimenti liquidi) / Patrimonio lordo x 100',
        'Entrate (12 mesi) / Patrimonio netto x 100',
      ]);
      expect(liquidity(c).formula, 'Liquidità / Patrimonio netto x 100\n15.000 / 100.000 x 100');
      expect(incomeToWealth(c).formula, 'Entrate (12 mesi) / Patrimonio netto x 100\n42.000 / 100.000 x 100');
    });
  });
}
