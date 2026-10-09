// The end-of-year projection in the Savings Rate KPI dialog is worded by
// AppStrings and dated by the display locale: an Italian user reads Italian
// sentences with Italian month names and decimal commas, never "Jan–Apr".
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/ui/screens/dashboard/eoy_projection.dart';

void main() {
  setUpAll(() async => initializeDateFormatting());

  // Previous year: 3000 income / 2000 expenses every month. Current year: four
  // months of 3300 income (May's salary not posted yet), five of 2200 expenses.
  final prev = EoyYear(
    year: 2025,
    income: 36000,
    expenses: 24000,
    months: List.generate(12, (i) => EoyMonth(month: i + 1, income: 3000, expenses: 2000)),
  );
  final current = EoyYear(
    year: 2026,
    income: 13200,
    expenses: 11000,
    months: [
      for (int m = 1; m <= 4; m++) EoyMonth(month: m, income: 3300, expenses: 2200),
      const EoyMonth(month: 5, income: 0, expenses: 2200),
    ],
  );

  String explain(AppStrings s, String locale, {EoyYear? currentYear}) => buildEoyExplanationSpan(
    current: currentYear ?? current,
    prev: prev,
    amtFmt: NumberFormat('#,##0.00', locale),
    pctFmt: NumberFormat('0.0%', locale),
    sym: '€',
    s: s,
    locale: locale,
  )!.toPlainText();

  test('Italian: Italian sentences, Italian month names, decimal commas', () {
    final text = explain(AppStrings.it, 'it_IT');
    expect(text, contains('Previsione fine anno 2026'));
    expect(text, contains('Basata sull\'andamento del 2025 come riferimento stagionale.'));
    expect(text, contains('Dettagli del calcolo:'));
    expect(text, contains('Nel 2025, il totale annuo è stato 36.000,00 €.'));
    expect(text, contains('Nello stesso periodo (gen–apr) del 2025: 12.000,00 €.'));
    expect(text, contains('Nel 2026 (gen–apr) finora: 13.200,00 € (110,0% rispetto al 2025).'));
    expect(text, contains('Nel 2026 (gen–mag) finora: 11.000,00 € (110,0% rispetto al 2025).'));
    expect(text, contains('Proiezione: 36.000,00 × 13.200,00 ÷ 12.000,00 = ~39.600,00 €'));
    expect(text, contains(AppStrings.it.eoyFormula));
    for (final english in ['Jan', 'Apr', 'May', 'Projection', 'so far', 'full-year', 'How it']) {
      expect(text, isNot(contains(english)), reason: '"$english" is English');
    }
  });

  test('English reads as before', () {
    final text = explain(AppStrings.en, 'en_US');
    expect(text, contains('End-of-year 2026 prediction'));
    expect(text, contains('Based on 2025 as the seasonal reference.'));
    expect(text, contains("How it's calculated:"));
    expect(text, contains('In 2025, the full-year total was 36,000.00 €.'));
    expect(text, contains('Over the same period (Jan–Apr) in 2025: 12,000.00 €.'));
    expect(text, contains('In 2026 (Jan–Apr) so far: 13,200.00 € (110.0% vs 2025).'));
    expect(text, contains('In 2026 (Jan–May) so far: 11,000.00 € (110.0% vs 2025).'));
    expect(text, contains('Projection: 36,000.00 × 13,200.00 ÷ 12,000.00 = ~39,600.00 €'));
  });

  test('a one-month period names just that month', () {
    final january = EoyYear(year: 2026, income: 3300, expenses: 2200, months: const [EoyMonth(month: 1, income: 3300, expenses: 2200)]);
    expect(explain(AppStrings.it, 'it_IT', currentYear: january), contains('Nel 2026 (gen) finora'));
    expect(explain(AppStrings.en, 'en_US', currentYear: january), contains('In 2026 (Jan) so far'));
  });

  test('the predictions stay bold', () {
    final span = buildEoyExplanationSpan(
      current: current,
      prev: prev,
      amtFmt: NumberFormat('#,##0.00', 'it_IT'),
      pctFmt: NumberFormat('0.0%', 'it_IT'),
      sym: '€',
      s: AppStrings.it,
      locale: 'it_IT',
    )!;
    final bold = <String>[];
    span.visitChildren((child) {
      if (child is TextSpan && child.style?.fontWeight == FontWeight.w700) bold.add(child.text ?? '');
      return true;
    });
    expect(bold, contains('~33,3%\n'));
  });
}
