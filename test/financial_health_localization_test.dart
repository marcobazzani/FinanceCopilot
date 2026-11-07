// Health KPIs speak the user's language all the way down: the formula shown in
// each KPI's info dialog, the months unit and the description chosen by the
// rating. The rating stays an enum until it is put into words, so a
// description can no longer drift from its rating through a mistyped token.
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/pillars/financial_health_service.dart';
import 'package:finance_copilot/services/pillars/health_balance_sheet.dart';
import 'package:finance_copilot/services/pillars/pillar_performance.dart';
import 'package:finance_copilot/utils/privacy_slots.dart';

void main() {
  setUpAll(() async => initializeDateFormatting());

  /// [cash] in the accounts and [investments] in the portfolio: a net worth of
  /// both, nothing owed. [creditLines] and [drawn] are the lines of credit and
  /// the part of them drawn on overdrawn accounts.
  List<KpiCategory> kpis(
    AppStrings s, {
    double cash = 10000,
    double investments = 100000,
    double liquidInvestments = 0,
    double annualIncome = 0,
    double rollingIncome = 0,
    double annualSavings = 0,
    double? estimatedAnnualExpenses,
    double creditLines = 0,
    double owed = 0,
    String locale = 'en_US',
  }) => computeKpis(
    sheet: HealthBalanceSheet(
      bankBalances: cash - owed,
      positiveBankBalances: cash,
      overdrawnAccounts: owed,
      netWorth: cash + investments - owed,
      investments: investments,
      liquidInvestments: liquidInvestments,
      creditLines: creditLines,
    ),
    annualIncome: annualIncome,
    annualSavings: annualSavings,
    rollingIncome: rollingIncome,
    estimatedAnnualExpenses: estimatedAnnualExpenses,
    thisYearMonthlyExpenses: 0,
    s: s,
    locale: locale,
  );

  HealthKpi liquidity(List<KpiCategory> c) => c[0].kpis[0];
  HealthKpi coverage(List<KpiCategory> c) => c[0].kpis[1];
  HealthKpi savings(List<KpiCategory> c) => c[0].kpis[2];
  HealthKpi investWeight(List<KpiCategory> c) => c[1].kpis[0];
  HealthKpi liquidAsset(List<KpiCategory> c) => c[1].kpis[1];
  HealthKpi incomeToWealth(List<KpiCategory> c) => c[1].kpis[2];
  HealthKpi debtToAssets(List<KpiCategory> c) => c[2].kpis[0];
  HealthKpi creditUsage(List<KpiCategory> c) => c[2].kpis[1];

  const languages = [AppStrings.en, AppStrings.it];

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

    test('investment weight: one text per rating, in both languages', () {
      const texts = {
        Rating.ottimo: (
          'Most of what you own is invested in the financial markets.',
          'Gran parte di ciò che possiedi è investito sui mercati finanziari.',
        ),
        Rating.buono: (
          'A good part of what you own is invested: you could put more of it to work.',
          'Una buona parte di ciò che possiedi è investita: potresti metterne al lavoro di più.',
        ),
        Rating.sufficiente: (
          'Only part of what you own is invested: idle money loses value to inflation.',
          'Solo una parte di ciò che possiedi è investita: il denaro fermo perde valore con l\'inflazione.',
        ),
        Rating.scarso: (
          'Almost nothing of what you own is invested: consider putting your savings to work.',
          'Quasi nulla di ciò che possiedi è investito: valuta di mettere al lavoro i tuoi risparmi.',
        ),
      };
      // 90%, 50%, 30%, 10% of a net worth of 100,000.
      const invested = {Rating.ottimo: 90000.0, Rating.buono: 50000.0, Rating.sufficiente: 30000.0, Rating.scarso: 10000.0};
      for (final MapEntry(key: rating, value: (en, it)) in texts.entries) {
        for (final (s, text) in [(AppStrings.en, en), (AppStrings.it, it)]) {
          final kpi = investWeight(kpis(s, cash: 100000 - invested[rating]!, investments: invested[rating]!));
          expect(kpi.rating, rating);
          expect(kpi.description, text);
        }
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
      // (accounts above zero + liquid) / gross with 10k in the accounts, 100k invested: 90.9%, 72.7%, 63.6%, 9.1%.
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

    test('debt-to-assets: one text per rating, in both languages', () {
      const texts = {
        Rating.ottimo: ('Debt is a negligible part of what you own.', 'I debiti sono una parte trascurabile di ciò che possiedi.'),
        Rating.buono: ('Debt is a manageable part of what you own.', 'I debiti sono una parte gestibile di ciò che possiedi.'),
        Rating.sufficiente: (
          'A large part of what you own is financed by debt.',
          'Una parte consistente di ciò che possiedi è finanziata a debito.',
        ),
        Rating.scarso: (
          'Debt weighs heavily on what you own. Consider paying it down.',
          'I debiti pesano molto su ciò che possiedi. Valuta di ridurli.',
        ),
      };
      // Owing 5%, 20%, 40% and 60% of the 100,000 owned: nothing is invested or in cash, the debt is all that varies.
      const owed = {Rating.ottimo: 5000.0, Rating.buono: 20000.0, Rating.sufficiente: 40000.0, Rating.scarso: 60000.0};
      for (final MapEntry(key: rating, value: (en, it)) in texts.entries) {
        for (final (s, text) in [(AppStrings.en, en), (AppStrings.it, it)]) {
          final kpi = debtToAssets(kpis(s, cash: 0, investments: 100000, owed: owed[rating]!));
          expect(kpi.rating, rating);
          expect(kpi.description, text);
        }
      }
    });

    test('credit-line usage: one text per rating, and a text for no lines at all', () {
      const texts = {
        Rating.ottimo: ('You use only a small part of your credit lines.', 'Usi solo una piccola parte dei tuoi fidi.'),
        Rating.buono: ('You use a moderate part of your credit lines.', 'Usi una parte moderata dei tuoi fidi.'),
        Rating.sufficiente: (
          'You use a large part of your credit lines: little room is left.',
          'Usi gran parte dei tuoi fidi: resta poco margine.',
        ),
        Rating.scarso: ('Your credit lines are almost used up.', 'I tuoi fidi sono quasi esauriti.'),
      };
      // 10%, 30%, 60% and 80% of credit lines of 100,000.
      const drawn = {Rating.ottimo: 10000.0, Rating.buono: 30000.0, Rating.sufficiente: 60000.0, Rating.scarso: 80000.0};
      for (final MapEntry(key: rating, value: (en, it)) in texts.entries) {
        for (final (s, text) in [(AppStrings.en, en), (AppStrings.it, it)]) {
          final kpi = creditUsage(kpis(s, cash: 0, owed: drawn[rating]!, creditLines: 100000));
          expect(kpi.rating, rating);
          expect(kpi.description, text);
        }
      }
      expect(creditUsage(kpis(AppStrings.en)).description, 'You have no credit lines: nothing to measure.');
      expect(creditUsage(kpis(AppStrings.it)).description, 'Non hai fidi: niente da misurare.');
    });

    test('expense coverage: months, and a text of its own when the cash is negative', () {
      expect(coverage(kpis(AppStrings.en, estimatedAnnualExpenses: 12000)).description, 'Your cash covers your expenses for 10 months.');
      expect(coverage(kpis(AppStrings.it, estimatedAnnualExpenses: 12000)).description, 'La tua liquidità copre le tue spese per 10 mesi.');
      expect(
        coverage(kpis(AppStrings.en, cash: 0, owed: 5000, estimatedAnnualExpenses: 12000)).description,
        'You have no cash to cover your expenses: your overdrawn accounts outweigh your money-market funds.',
      );
      expect(
        coverage(kpis(AppStrings.it, cash: 0, owed: 5000, estimatedAnnualExpenses: 12000)).description,
        'Non hai liquidità per coprire le spese: i conti scoperti superano i fondi monetari.',
      );
    });

    test('largest position: one text per rating, in both languages', () {
      const texts = {
        Rating.ottimo: (
          'No single stock or crypto weighs much in your portfolio.',
          'Nessuna singola azione o cripto pesa molto sul tuo portafoglio.',
        ),
        Rating.buono: (
          'Your largest single stock or crypto is a moderate part of your portfolio.',
          'La tua azione o cripto maggiore è una parte moderata del portafoglio.',
        ),
        Rating.sufficiente: (
          'One stock or crypto is a large part of your portfolio.',
          'Un\'azione o cripto è una parte consistente del tuo portafoglio.',
        ),
        Rating.scarso: ('One stock or crypto dominates your portfolio.', 'Un\'azione o cripto domina il tuo portafoglio.'),
      };
      const share = {Rating.ottimo: 3.0, Rating.buono: 8.0, Rating.sufficiente: 15.0, Rating.scarso: 40.0};
      for (final MapEntry(key: rating, value: (en, it)) in texts.entries) {
        for (final (s, text) in [(AppStrings.en, en), (AppStrings.it, it)]) {
          final kpi = largestPositionKpi(
            position: LargestPosition(name: 'ACME', value: share[rating]!, total: 100),
            s: s,
            locale: 'en_US',
          );
          expect(kpi.rating, rating);
          expect(kpi.description, text);
        }
      }
    });

    test('annualized return: one text per rating, and what is needed to annualize', () {
      const texts = {
        Rating.ottimo: ('Your investments grow at a strong yearly rate.', 'I tuoi investimenti crescono a un ritmo annuo molto buono.'),
        Rating.buono: ('Your investments grow at a healthy yearly rate.', 'I tuoi investimenti crescono a un buon ritmo annuo.'),
        Rating.sufficiente: (
          'Your investments grow slowly: about as fast as inflation or less.',
          'I tuoi investimenti crescono lentamente: poco sopra l\'inflazione o meno.',
        ),
        Rating.scarso: ('Your investments have lost value over the period.', 'I tuoi investimenti hanno perso valore nel periodo.'),
      };
      const yearly = {Rating.ottimo: 0.08, Rating.buono: 0.03, Rating.sufficiente: 0.01, Rating.scarso: -0.02};
      PillarPerformanceSnapshot snapshot(double cagr) => PillarPerformanceSnapshot(
        asOfDate: DateTime(2026, 10, 31),
        inceptionDate: DateTime(2020, 1, 1),
        marketValue: 1000,
        netInvested: 900,
        absoluteReturnAmount: 100,
        absoluteReturnPct: 0.1,
        twrr: 0.3,
        cagr: cagr,
        hasSufficientHistory: true,
      );
      for (final MapEntry(key: rating, value: (en, it)) in texts.entries) {
        for (final (s, text, locale) in [(AppStrings.en, en, 'en_US'), (AppStrings.it, it, 'it_IT')]) {
          final kpi = annualizedReturnKpi(snapshot: snapshot(yearly[rating]!), s: s, locale: locale);
          expect(kpi.rating, rating);
          expect(kpi.description, text);
        }
      }
      expect(
        annualizedReturnKpi(snapshot: null, s: AppStrings.en, locale: 'en_US').description,
        'At least a year of investing history is needed to annualize the return.',
      );
      expect(
        annualizedReturnKpi(snapshot: null, s: AppStrings.it, locale: 'it_IT').description,
        'Servono almeno un anno di storico degli investimenti per annualizzare il rendimento.',
      );
    });
  });

  group('months unit', () {
    test('follows the language', () {
      expect(coverage(kpis(AppStrings.en, estimatedAnnualExpenses: 12000)).unit, ' months');
      expect(coverage(kpis(AppStrings.it, estimatedAnnualExpenses: 12000)).unit, ' mesi');
    });
  });

  group('FIRE number', () {
    test('one description per rating, in both languages', () {
      expect(fireDescription(rateFire(120), AppStrings.en), 'Your investable net worth fully covers the FIRE number.');
      expect(fireDescription(rateFire(60), AppStrings.en), 'Your investable net worth covers a good portion of the FIRE number.');
      expect(fireDescription(rateFire(30), AppStrings.en), 'Your investable net worth covers only part of the FIRE number.');
      expect(fireDescription(rateFire(10), AppStrings.en), 'Your investable net worth is still far from the FIRE number.');
      expect(fireDescription(rateFire(120), AppStrings.it), 'Il tuo patrimonio investibile copre completamente il numero FIRE.');
      expect(fireDescription(rateFire(60), AppStrings.it), 'Il tuo patrimonio investibile copre una buona parte del numero FIRE.');
      expect(fireDescription(rateFire(30), AppStrings.it), 'Il tuo patrimonio investibile copre solo in parte il numero FIRE.');
      expect(fireDescription(rateFire(10), AppStrings.it), 'Il tuo patrimonio investibile è ancora lontano dal numero FIRE.');
    });

    test('the card is named and subtitled in the display language', () {
      final fire = computeFire(netWorth: 500000, annualExpenses: 30000, swrPct: 2.75);
      for (final (s, name, target) in [(AppStrings.en, 'FIRE number', 'Target: '), (AppStrings.it, 'Numero FIRE', 'Obiettivo: ')]) {
        final kpi = fireKpi(fire: fire, s: s, money: (v) => '${v.round()} €');
        expect(kpi.name, name);
        expect(kpi.subtitle, '$target${privacySlot(0)}');
        expect(kpi.subtitleFigures, ['1090909 €']);
      }
    });

    test('without expenses, the reason is in the display language too', () {
      final fire = computeFire(netWorth: 500000, annualExpenses: 0, swrPct: 2.75);
      expect(
        fireKpi(fire: fire, s: AppStrings.en, money: (v) => '').description,
        'Annual expenses are required to estimate the FIRE number.',
      );
      expect(
        fireKpi(fire: fire, s: AppStrings.it, money: (v) => '').description,
        'Servono spese annuali registrate per stimare il numero FIRE.',
      );
    });
  });

  group('formulas', () {
    List<String> firstLines(List<KpiCategory> c) => [
      for (final kpi in [...c[0].kpis, ...c[1].kpis, ...c[2].kpis]) kpi.formula.split('\n').first,
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
        estimatedAnnualExpenses: 30000,
      );
      expect(firstLines(c), [
        'Cash / Net Worth x 100',
        'Cash / Monthly Expenses',
        'Savings / Income x 100',
        'Investments / Gross Assets x 100',
        '(Accounts above zero + Liquid Investments) / Gross Assets x 100',
        'Income (12m) / Net Worth x 100',
        'Owed / Gross Assets x 100',
        'Overdrawn Accounts / Credit Lines x 100',
      ]);
      expect(
        liquidity(c).formula,
        'Cash / Net Worth x 100\n15,000 / 100,000 x 100\nCash = Accounts + Money Market: 15,000 + 0\nNet Worth = Total Assets chart',
      );
      expect(
        liquidAsset(c).formula,
        '(Accounts above zero + Liquid Investments) / Gross Assets x 100\n(15,000 + 60,000) / 100,000 x 100\nGross Assets = Net Worth + Owed: 100,000 + 0',
      );
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
        estimatedAnnualExpenses: 30000,
        locale: 'it_IT',
      );
      expect(firstLines(c), [
        'Liquidità / Patrimonio netto x 100',
        'Liquidità / Spese mensili',
        'Risparmi / Entrate x 100',
        'Investimenti / Patrimonio lordo x 100',
        '(Conti in positivo + Investimenti liquidi) / Patrimonio lordo x 100',
        'Entrate (12 mesi) / Patrimonio netto x 100',
        'Debiti / Patrimonio lordo x 100',
        'Conti scoperti / Fidi x 100',
      ]);
      expect(
        liquidity(c).formula,
        'Liquidità / Patrimonio netto x 100\n15.000 / 100.000 x 100\nLiquidità = Conti + Monetario: 15.000 + 0\nPatrimonio netto = grafico Total Assets',
      );
      expect(
        incomeToWealth(c).formula,
        'Entrate (12 mesi) / Patrimonio netto x 100\n42.000 / 100.000 x 100\nPatrimonio netto = grafico Total Assets',
      );
    });

    test('the definitions behind a figure are spelled in both languages', () {
      for (final (s, locale, defs) in [
        (
          AppStrings.en,
          'en_US',
          [
            'Monthly Expenses = estimated annual expenses / 12: 30,000 / 12',
            'Unused Credit Lines: 70,000 (about 28 more months, not counted)',
            'Owed = overdrawn Accounts + Liabilities: 30,000 + 0',
            'Gross Assets = Net Worth + Owed: 95,000 + 30,000',
          ],
        ),
        (
          AppStrings.it,
          'it_IT',
          [
            'Spese mensili = spese annue stimate / 12: 30.000 / 12',
            'Fidi non usati: 70.000 (circa 28 mesi in più, non conteggiati)',
            'Debiti = Conti scoperti + Passività: 30.000 + 0',
            'Patrimonio lordo = Patrimonio netto + Debiti: 95.000 + 30.000',
          ],
        ),
      ]) {
        final c = kpis(s, cash: 15000, investments: 110000, owed: 30000, creditLines: 100000, estimatedAnnualExpenses: 30000, locale: locale);
        final lines = [...coverage(c).formula.split('\n'), ...debtToAssets(c).formula.split('\n')];
        for (final def in defs) {
          expect(lines, contains(def), reason: def);
        }
      }
    });

    test('without a previous year, the monthly expenses say they are this year\'s average', () {
      for (final (s, line) in [
        (AppStrings.en, 'Monthly Expenses = this year\'s average (no previous year yet)'),
        (AppStrings.it, 'Spese mensili = media di quest\'anno (ancora nessun anno precedente)'),
      ]) {
        final c = computeKpis(
          sheet: const HealthBalanceSheet(bankBalances: 10000, positiveBankBalances: 10000, netWorth: 10000),
          annualIncome: 0,
          annualSavings: 0,
          rollingIncome: 0,
          estimatedAnnualExpenses: null,
          thisYearMonthlyExpenses: 1000,
          s: s,
          locale: 'en_US',
        );
        expect(coverage(c).formula.split('\n'), contains(line));
      }
    });

    test('the largest position and the annualized return name their figures in the display language', () {
      const position = LargestPosition(name: 'ACME', value: 12500, total: 100000);
      for (final (s, first, none) in [
        (AppStrings.en, 'Largest Stock or Crypto / Portfolio value x 100', 'No single stock or crypto held'),
        (AppStrings.it, 'Maggiore azione o cripto / Valore del portafoglio x 100', 'Nessuna azione o cripto in portafoglio'),
      ]) {
        expect(largestPositionKpi(position: position, s: s, locale: 'en_US').formula, '$first\nACME: 12,500 / 100,000 x 100');
        expect(
          largestPositionKpi(position: const LargestPosition(name: null, value: 0, total: 100000), s: s, locale: 'en_US').formula,
          '$first\n$none',
        );
      }
      final snapshot = PillarPerformanceSnapshot(
        asOfDate: DateTime(2026, 10, 31),
        inceptionDate: DateTime(2018, 2, 15),
        marketValue: 1000,
        netInvested: 500,
        absoluteReturnAmount: 500,
        absoluteReturnPct: 1.0,
        twrr: 1.951,
        cagr: 0.1322,
        hasSufficientHistory: true,
      );
      expect(
        annualizedReturnKpi(snapshot: snapshot, s: AppStrings.en, locale: 'en_US').formula,
        [
          'Time-weighted return, per year',
          'Since Feb 15, 2018: +195.1%',
          'Per year: 13.22%',
        ].join('\n'),
      );
      expect(
        annualizedReturnKpi(snapshot: snapshot, s: AppStrings.it, locale: 'it_IT').formula,
        [
          'Rendimento ponderato nel tempo, all\'anno',
          'Dal 15 feb 2018: +195,1%',
          'All\'anno: 13,22%',
        ].join('\n'),
      );
    });
  });

  test('every language names the same categories and indicators', () {
    for (final s in languages) {
      final c = kpis(s, estimatedAnnualExpenses: 12000, creditLines: 1, owed: 1);
      expect(c.map((cat) => cat.name).toSet().length, 3);
      for (final kpi in c.expand((cat) => cat.kpis)) {
        expect(kpi.name, isNotEmpty);
        expect(kpi.description, isNotEmpty, reason: kpi.name);
      }
    }
  });
}
