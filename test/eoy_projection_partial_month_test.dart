// The year-end projection with the month in progress: the previous year's
// month counts for the same share of it, never whole against a few days.
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/ui/screens/dashboard/eoy_projection.dart';

void main() {
  setUpAll(() async => initializeDateFormatting());

  // 2025: 3,000 of income and 2,000 of expenses every month.
  EoyYear prev() => EoyYear(
    year: 2025,
    income: 36000,
    expenses: 24000,
    months: [for (var m = 1; m <= 12; m++) EoyMonth(month: m, income: 3000, expenses: 2000)],
  );

  // 2026 on 5 November: January to October whole (3,300 in, 2,200 out), and
  // 5 of November's 30 days: 400 spent, the salary not in yet.
  EoyYear current() => EoyYear(
    year: 2026,
    income: 33000,
    expenses: 22400,
    months: [
      for (var m = 1; m <= 10; m++) EoyMonth(month: m, income: 3300, expenses: 2200),
      const EoyMonth(month: 11, income: 0, expenses: 400, soFar: (days: 5, of: 30)),
    ],
  );

  test('expenses: November 2025 counts for 5/30 against the first 5 days of November 2026', () {
    final d = computeEoyDetails(current(), prev(), expenses: true)!;
    const prevSame = 10 * 2000 + 2000 * 5 / 30;
    expect(d.months, 11);
    expect(d.prevSame, closeTo(prevSame, 1e-9));
    expect(d.currentTotal, 22400);
    expect(d.value, closeTo(24000 * 22400 / prevSame, 1e-6));
    expect(d.partial, (month: 11, days: 5, of: 30));
    // All of November 2025 against 5 days of November 2026 would project about a month's worth too low.
    const wholeNovember = 24000 * 22400 / 22000;
    expect(d.value - wholeNovember, closeTo(2003, 1));
  });

  test('income: November is not paid yet, so the projection stops at October, whole months', () {
    final d = computeEoyDetails(current(), prev())!;
    expect(d.months, 10);
    expect(d.prevSame, 30000);
    expect(d.partial, isNull);
  });

  group('the explanation says how the month in progress was counted', () {
    String text(AppStrings s, String locale) => buildEoyExplanationSpan(
      current: current(),
      prev: prev(),
      amtFmt: NumberFormat('#,##0.00', locale),
      pctFmt: NumberFormat('0.0%', locale),
      sym: '€',
      s: s,
      locale: locale,
    )!.toPlainText();

    test('English', () {
      expect(text(AppStrings.en, 'en_US'), contains('Nov 2026 so far: 5 of 30 days, against the same share of Nov 2025'));
    });

    test('Italian', () {
      expect(text(AppStrings.it, 'it_IT'), contains('nov 2026 finora: 5 giorni su 30, rispetto alla stessa quota di nov 2025'));
    });

    test('whole months only: no such line', () {
      final whole = buildEoyExplanationSpan(
        current: EoyYear(
          year: 2026,
          income: 33000,
          expenses: 22000,
          months: [for (var m = 1; m <= 10; m++) EoyMonth(month: m, income: 3300, expenses: 2200)],
        ),
        prev: prev(),
        amtFmt: NumberFormat('#,##0.00', 'en_US'),
        pctFmt: NumberFormat('0.0%'),
        sym: '€',
        s: AppStrings.en,
      )!.toPlainText();
      expect(whole, isNot(contains('against the same share of')));
    });
  });
}
