// The end-of-year explanation marks each of its amounts as a
// [PositionFigureSpan], so privacy mode can mask the amounts alone: the
// labels, month ranges and percentages around them are plain spans. The text
// itself reads exactly as before (pinned in eoy_projection_test.dart and
// eoy_projection_locale_test.dart).
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

  ({List<String> figures, String readable}) parts(AppStrings s, String locale) {
    final span = buildEoyExplanationSpan(
      current: current,
      prev: prev,
      amtFmt: NumberFormat('#,##0.00', locale),
      pctFmt: NumberFormat('0.0%', locale),
      sym: '€',
      s: s,
      locale: locale,
    )!;
    final figures = <String>[];
    final readable = StringBuffer();
    span.visitChildren((child) {
      if (child is PositionFigureSpan) {
        figures.add(child.text!);
      } else if (child is TextSpan) {
        readable.write(child.text ?? '');
      }
      return true;
    });
    return (figures: figures, readable: readable.toString());
  }

  for (final (s, locale, amount) in [(AppStrings.en, 'en_US', RegExp(r'\d\.\d\d')), (AppStrings.it, 'it_IT', RegExp(r'\d,\d\d'))]) {
    test('$locale: every amount is marked, and nothing else is', () {
      final (:figures, :readable) = parts(s, locale);
      final thousands = locale == 'en_US' ? '36,000.00' : '36.000,00';
      expect(figures, contains('$thousands €'), reason: 'the previous full-year total, with its currency');
      expect(figures, contains(thousands), reason: 'the same total inside the projection formula');
      expect(figures.where((f) => f.contains('%')), isEmpty, reason: 'a percentage is shape, not magnitude');
      expect(figures.where((f) => f.contains('~') || f.contains('×') || f.contains('\n')), isEmpty, reason: 'only the figure itself is masked');
      expect(amount.hasMatch(readable), isFalse, reason: 'no amount is left unmarked in: $readable');
      expect(readable, contains(locale == 'en_US' ? '(Jan–Apr)' : '(gen–apr)'), reason: 'the months stay readable');
      expect(readable, contains(locale == 'en_US' ? '110.0%' : '110,0%'), reason: 'the percentages stay readable');
      expect(readable, contains(s.eoyHowCalculated));
    });
  }

  test('the marked amounts keep the bold of the predictions', () {
    final span = buildEoyExplanationSpan(
      current: current,
      prev: prev,
      amtFmt: NumberFormat('#,##0.00', 'en_US'),
      pctFmt: NumberFormat('0.0%', 'en_US'),
      sym: '€',
      s: AppStrings.en,
    )!;
    final bold = <String>[];
    span.visitChildren((child) {
      if (child is PositionFigureSpan && child.style?.fontWeight == FontWeight.w700) bold.add(child.text!);
      return true;
    });
    expect(bold, ['39,600.00 €', '26,400.00 €', '13,200.00 €']);
  });
}
