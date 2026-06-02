import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/ui/screens/dashboard/eoy_projection.dart';

void main() {
  // Reusable buckets:
  // - Previous year: 12 months, every month has income=3000 and expenses=2000
  //   (full-year income = 36000, full-year expenses = 24000)
  // - Current year (May, salary not yet posted): 5 months, Jan-Apr have
  //   income=3300 each, May income=0; expenses=2200 every month including May
  //   (current income total = 13200, current expenses total = 11000)
  EoyYear buildPrev() => EoyYear(
    year: 2025,
    income: 36000,
    expenses: 24000,
    months: List.generate(12, (i) => EoyMonth(month: i + 1, income: 3000, expenses: 2000)),
  );

  EoyYear buildCurrent() => EoyYear(
    year: 2026,
    income: 4 * 3300, // 13200
    expenses: 5 * 2200, // 11000
    months: [
      for (int m = 1; m <= 4; m++) EoyMonth(month: m, income: 3300, expenses: 2200),
      const EoyMonth(month: 5, income: 0, expenses: 2200),
    ],
  );

  group('computeEoyDetails', () {
    test('income projection skips the empty May to avoid underestimation (bug fix)', () {
      final prev = buildPrev();
      final current = buildCurrent();

      final inc = computeEoyDetails(current, prev);
      expect(inc, isNotNull);
      expect(inc!.months, 4);
      expect(inc.prevSame, 12000);
      expect(inc.currentTotal, 13200);
      expect(inc.value, closeTo(39600.0, 1e-6));

      const buggy = 36000.0 * 13200.0 / 15000.0;
      expect(buggy, closeTo(31680.0, 1e-6));
      expect((inc.value - buggy).abs() > 1, isTrue, reason: 'fixed projection must differ noticeably from the old buggy one');
    });

    test('expense projection still uses the full current period (May)', () {
      final exp = computeEoyDetails(buildCurrent(), buildPrev(), expenses: true);
      expect(exp, isNotNull);
      expect(exp!.months, 5);
      expect(exp.prevSame, 10000);
      expect(exp.currentTotal, 11000);
      expect(exp.value, closeTo(26400.0, 1e-6));
    });

    test('returns null when the metric has no current-year data', () {
      final current = EoyYear(
        year: 2026,
        income: 0,
        expenses: 11000,
        months: List.generate(5, (i) => EoyMonth(month: i + 1, income: 0, expenses: 2200)),
      );
      expect(computeEoyDetails(current, buildPrev()), isNull);
      expect(computeEoyDetails(current, buildPrev(), expenses: true), isNotNull);
    });

    test('returns null when the previous year has no overlap', () {
      final prev = EoyYear(year: 2025, income: 0, expenses: 0, months: const []);
      expect(computeEoyDetails(buildCurrent(), prev), isNull);
    });

    test('returns null when current year has no months', () {
      final current = const EoyYear(year: 2026, income: 0, expenses: 0, months: []);
      expect(computeEoyDetails(current, buildPrev()), isNull);
    });
  });

  group('buildEoyExplanationSpan', () {
    String plain(InlineSpan s) => s.toPlainText();

    bool hasBoldRun(InlineSpan span, String needle) {
      var found = false;
      span.visitChildren((child) {
        if (found) return false;
        if (child is TextSpan) {
          final w = child.style?.fontWeight;
          if (w == FontWeight.w700 && (child.text ?? '').contains(needle)) {
            found = true;
            return false;
          }
        }
        return true;
      });
      return found;
    }

    test('lead block has Income/Expenses/Savings/Rate predictions in bold (en)', () {
      final amtFmt = NumberFormat('#,##0.00', 'en_US');
      final pctFmt = NumberFormat('0.0%');
      final span = buildEoyExplanationSpan(
        current: buildCurrent(),
        prev: buildPrev(),
        amtFmt: amtFmt,
        pctFmt: pctFmt,
        sym: '€',
        s: AppStrings.en,
      );
      expect(span, isNotNull);

      // Predictions block contains the projected numbers as bold runs.
      expect(hasBoldRun(span!, '39,600.00'), isTrue, reason: 'income value bold');
      expect(hasBoldRun(span, '26,400.00'), isTrue, reason: 'expenses value bold');
      expect(hasBoldRun(span, '13,200.00'), isTrue, reason: 'savings value bold');
      expect(hasBoldRun(span, '33.3%'), isTrue, reason: 'rate value bold');

      final text = plain(span);
      // Lead order: Income then Expenses then Savings then Rate%, all before details.
      final iIncome = text.indexOf('Income');
      final iExpenses = text.indexOf('Expenses');
      final iSavings = text.indexOf('Savings');
      final iRate = text.indexOf('Rate%');
      final iDetails = text.indexOf("How it's calculated");
      expect(iIncome >= 0 && iExpenses > iIncome && iSavings > iExpenses && iRate > iSavings, isTrue);
      expect(iDetails > iRate, isTrue, reason: 'details section follows the predictions');

      // Details preserve per-metric month ranges.
      expect(text, contains('In 2026 (Jan–Apr) so far'));
      expect(text, contains('In 2026 (Jan–May) so far'));
      // Formula footer is present.
      expect(text, contains(AppStrings.en.eoyFormula));
    });

    test('localizes to italian', () {
      final span = buildEoyExplanationSpan(
        current: buildCurrent(),
        prev: buildPrev(),
        amtFmt: NumberFormat('#,##0.00', 'it_IT'),
        pctFmt: NumberFormat('0.0%'),
        sym: '€',
        s: AppStrings.it,
      );
      expect(span, isNotNull);
      final text = plain(span!);
      expect(text, contains('Previsione fine anno 2026'));
      expect(text, contains('Nel 2026 (Jan–Apr) finora'));
      expect(text, contains('Nel 2026 (Jan–May) finora'));
      expect(text, contains(AppStrings.it.eoyFormula));
    });

    test('returns null when current year is empty', () {
      final span = buildEoyExplanationSpan(
        current: const EoyYear(year: 2026, income: 0, expenses: 0, months: []),
        prev: buildPrev(),
        amtFmt: NumberFormat('#,##0.00', 'en_US'),
        pctFmt: NumberFormat('0.0%'),
        sym: '€',
        s: AppStrings.en,
      );
      expect(span, isNull);
    });
  });

  group('estimateSmoothedAnnualExpenses', () {
    test('returns null when prev is null', () {
      final r = estimateSmoothedAnnualExpenses(current: buildCurrent(), prev: null);
      expect(r, isNull);
    });

    test('returns null when prev has zero expenses and projection fails', () {
      final emptyPrev = EoyYear(
        year: 2025,
        income: 0,
        expenses: 0,
        months: List.generate(12, (i) => EoyMonth(month: i + 1, income: 0, expenses: 0)),
      );
      final r = estimateSmoothedAnnualExpenses(current: buildCurrent(), prev: emptyPrev);
      expect(r, isNull);
    });

    test('falls back to prev total when current has no expenses', () {
      final emptyCurrent = EoyYear(
        year: 2026,
        income: 0,
        expenses: 0,
        months: const [EoyMonth(month: 1, income: 0, expenses: 0)],
      );
      final r = estimateSmoothedAnnualExpenses(current: emptyCurrent, prev: buildPrev());
      expect(r, isNotNull);
      expect(r!.value, 24000);
      expect(r.projectedCurrent, isNull);
      expect(r.prevTotal, 24000);
    });

    test('averages EoY projection with prev full-year total', () {
      // Prev: 24000 expenses across 12 months evenly (2000/mo).
      // Current: 5 months at 2200 each = 11000.
      // prevSame (Jan-May) = 5 * 2000 = 10000.
      // Projection = prevTotal * currentTotal / prevSame
      //            = 24000 * 11000 / 10000 = 26400.
      // Smoothed = (26400 + 24000) / 2 = 25200.
      final r = estimateSmoothedAnnualExpenses(
        current: buildCurrent(),
        prev: buildPrev(),
      );
      expect(r, isNotNull);
      expect(r!.value, closeTo(25200, 0.001));
      expect(r.projectedCurrent, closeTo(26400, 0.001));
      expect(r.prevTotal, 24000);
      expect(r.projectionMonths, 5);
    });

    test('smoothed value sits between projected and prev total', () {
      final r = estimateSmoothedAnnualExpenses(
        current: buildCurrent(),
        prev: buildPrev(),
      )!;
      final lo = r.prevTotal!;
      final hi = r.projectedCurrent!;
      expect(r.value, greaterThanOrEqualTo(lo < hi ? lo : hi));
      expect(r.value, lessThanOrEqualTo(lo > hi ? lo : hi));
    });
  });
}
