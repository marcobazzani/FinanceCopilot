// Pins how a KPI formula dialog renders, in and out of privacy mode: every
// text of the dialog in order (one per widget, a masked inline figure standing
// as U+FFFC in the sentence around it), which of them can be selected, and
// the style of every masked figure.
//
//  * Out of privacy mode the whole formula is one selectable text.
//  * In privacy mode the symbolic first line stays readable and selectable;
//    below it, a plain formula blurs as one block, while the Savings Rate
//    formula with its end-of-year projection blurs its figures alone — also
//    when the rate itself is N/A and only the projection follows the line.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/ui/widgets/privacy_text.dart';

import 'dashboard_harness.dart';

void main() {
  const s = AppStrings.en;
  final h = DashboardHarness();

  setUpAll(() async => initializeDateFormatting());
  setUp(h.open);
  tearDown(h.close);

  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;
  Finder inDialog(Finder f) => find.descendant(of: find.byType(AlertDialog), matching: f);

  /// The texts the dialog lets the user select, and so copy out of it.
  List<String> selectableTexts(WidgetTester tester) => [
    for (final w in tester.widgetList<SelectableText>(inDialog(find.byType(SelectableText)))) w.data ?? w.textSpan!.toPlainText(),
  ];

  /// Every masked figure of the dialog, in order, with its weight and size.
  List<String> maskedFigures(WidgetTester tester) => [
    for (final w in tester.widgetList<PrivacyText>(inDialog(find.byType(PrivacyText))))
      '${w.text} | ${w.style?.fontWeight} | ${w.style?.fontSize}',
  ];

  Future<void> account(List<(DateTime, double, double)> rows) async {
    final acct = await h.db.into(h.db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    for (final (day, amount, balance) in rows) {
      await h.db
          .into(h.db.transactions)
          .insert(
            TransactionsCompanion.insert(accountId: acct, operationDate: day, valueDate: day, amount: amount, balanceAfter: Value(balance)),
          );
    }
  }

  Future<void> salaries(int year, int months) async {
    for (var m = 1; m <= months; m++) {
      final d = DateTime(year, m, 15);
      await h.db.into(h.db.incomes).insert(IncomesCompanion.insert(date: d, valueDate: d, amount: 3000));
    }
  }

  const projectionBody =
      'End-of-year 2026 prediction\n'
      'Based on 2025 as the seasonal reference.\n'
      '\n';
  const footer =
      '\n'
      'Formula: prev year total × current year progress ÷ prev year same period\n';

  testWidgets('Savings Rate with its projection, privacy on: the symbolic line selectable, the figures masked one by one', (tester) async {
    await h.seed();
    await h.pump(tester, isPrivate: true);
    try {
      await h.openInfo(tester, s.kpiSavingsRate);
      expect(
        h.dialogText(tester),
        'Savings Rate\n'
        'Savings / Income x 100\n'
        '\uFFFC\n'
        '\n'
        '$projectionBody'
        '  Income: ~\uFFFC\n'
        '  Expenses: ~\uFFFC\n'
        '  Savings: ~\uFFFC\n'
        '  Rate%: ~0.0%\n'
        '\n'
        'How it\'s calculated:\n'
        '━ Income\n'
        '  In 2025, the full-year total was \uFFFC.\n'
        '  Over the same period (Jan–Feb) in 2025: \uFFFC.\n'
        '  In 2026 (Jan–Feb) so far: \uFFFC (100.0% vs 2025).\n'
        '  Projection: \uFFFC × \uFFFC ÷ \uFFFC = ~\uFFFC\n'
        '━ Expenses\n'
        '  In 2025, the full-year total was \uFFFC.\n'
        '  Over the same period (Jan–Feb) in 2025: \uFFFC.\n'
        '  In 2026 (Jan–Feb) so far: \uFFFC (100.0% vs 2025).\n'
        '  Projection: \uFFFC × \uFFFC ÷ \uFFFC = ~\uFFFC\n'
        '━ Savings\n'
        '  ~\uFFFC − ~\uFFFC = ~\uFFFC\n'
        '━ Rate%\n'
        '  ~\uFFFC ÷ ~\uFFFC = ~0.0%\n'
        '$footer'
        '\n'
        '0 / 6,000 x 100\n'
        '36,000.00 €\n'
        '36,000.00 €\n'
        '0.00 €\n'
        '36,000.00 €\n'
        '6,000.00 €\n'
        '6,000.00 €\n'
        '36,000.00\n'
        '6,000.00\n'
        '6,000.00\n'
        '36,000.00 €\n'
        '36,000.00 €\n'
        '6,000.00 €\n'
        '6,000.00 €\n'
        '36,000.00\n'
        '6,000.00\n'
        '6,000.00\n'
        '36,000.00 €\n'
        '36,000.00 €\n'
        '36,000.00 €\n'
        '0.00 €\n'
        '0.00\n'
        '36,000.00\n'
        'Close',
      );
      expect(selectableTexts(tester), [s.kpiFormulaSavingsRate], reason: 'only the symbolic line can be copied');
      expect(masked(inDialog(find.text(s.kpiFormulaSavingsRate))), isFalse);
      expect(masked(inDialog(find.textContaining('End-of-year 2026 prediction'))), isFalse, reason: 'the words around the figures');
      expect(maskedFigures(tester), [
        '0 / 6,000 x 100 | null | 12.0',
        '36,000.00 € | FontWeight.w700 | 12.0',
        '36,000.00 € | FontWeight.w700 | 12.0',
        '0.00 € | FontWeight.w700 | 12.0',
        for (final figure in [
          '36,000.00 €',
          '6,000.00 €',
          '6,000.00 €',
          '36,000.00',
          '6,000.00',
          '6,000.00',
          '36,000.00 €',
          '36,000.00 €',
          '6,000.00 €',
          '6,000.00 €',
          '36,000.00',
          '6,000.00',
          '6,000.00',
          '36,000.00 €',
          '36,000.00 €',
          '36,000.00 €',
          '0.00 €',
          '0.00',
          '36,000.00',
        ])
          '$figure | null | 12.0',
      ]);
      for (final figure in tester.widgetList<PrivacyText>(inDialog(find.byType(PrivacyText)))) {
        expect(
          masked(find.descendant(of: find.byWidget(figure), matching: find.text(figure.text))),
          isTrue,
          reason: figure.text,
        );
      }
      await h.tapDialogButton(tester, s.close);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('Savings Rate N/A with a projection, privacy on: the symbolic line, then the projection with its figures masked', (tester) async {
    // A salary every month of 2025; none in 2026, only 500 spent in February:
    // no savings rate this year, an expense projection all the same.
    await account([(DateTime(2024, 12, 1), 15000, 15000), (DateTime(2026, 2, 10), -500, 14500)]);
    await salaries(2025, 12);
    await h.pump(tester, isPrivate: true);
    try {
      await h.openInfo(tester, s.kpiSavingsRate);
      expect(
        h.dialogText(tester),
        'Savings Rate\n'
        'Savings / Income x 100\n'
        '\n'
        '$projectionBody'
        '  Expenses: ~\uFFFC\n'
        '\n'
        'How it\'s calculated:\n'
        '━ Expenses\n'
        '  In 2025, the full-year total was \uFFFC.\n'
        '  Over the same period (Jan–Feb) in 2025: \uFFFC.\n'
        '  In 2026 (Jan–Feb) so far: \uFFFC (8.3% vs 2025).\n'
        '  Projection: \uFFFC × \uFFFC ÷ \uFFFC = ~\uFFFC\n'
        '$footer'
        '\n'
        '3,000.00 €\n'
        '36,000.00 €\n'
        '6,000.00 €\n'
        '500.00 €\n'
        '36,000.00\n'
        '500.00\n'
        '6,000.00\n'
        '3,000.00 €\n'
        'Close',
      );
      expect(selectableTexts(tester), [s.kpiFormulaSavingsRate]);
      expect(maskedFigures(tester), [
        '3,000.00 € | FontWeight.w700 | 12.0',
        for (final figure in ['36,000.00 €', '6,000.00 €', '500.00 €', '36,000.00', '500.00', '6,000.00', '3,000.00 €']) '$figure | null | 12.0',
      ]);
      expect(masked(inDialog(find.text('3,000.00 €')).first), isTrue);
      expect(masked(inDialog(find.textContaining('(8.3% vs 2025)'))), isFalse, reason: 'a percentage');
      await h.tapDialogButton(tester, s.close);

      // A plain formula: the figures below the symbolic line blur as one block.
      await h.openInfo(tester, s.kpiLiquidityRatio);
      expect(h.dialogText(tester), 'Net Worth Liquidity Ratio\nCash / Net Worth x 100\n14,500 / 14,500 x 100\nClose');
      expect(selectableTexts(tester), ['Cash / Net Worth x 100']);
      expect(masked(inDialog(find.text('14,500 / 14,500 x 100'))), isTrue);
      expect(masked(inDialog(find.text('Cash / Net Worth x 100'))), isFalse);
      await h.tapDialogButton(tester, s.close);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('a plain formula without figures, privacy on: the symbolic line and an empty masked line', (tester) async {
    await account([(DateTime(2024, 12, 1), 15000, 15000)]);
    await h.pump(tester, isPrivate: true);
    try {
      await h.openInfo(tester, s.kpiSavingsRate);
      expect(h.dialogText(tester), 'Savings Rate\nSavings / Income x 100\n\nClose');
      expect(selectableTexts(tester), [s.kpiFormulaSavingsRate]);
      expect(masked(inDialog(find.text(''))), isTrue);
      expect(masked(inDialog(find.text(s.kpiFormulaSavingsRate))), isFalse);
      await h.tapDialogButton(tester, s.close);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('privacy off: the Savings Rate formula and its projection are one selectable text', (tester) async {
    await h.seed();
    await h.pump(tester);
    try {
      await h.openInfo(tester, s.kpiSavingsRate);
      const text =
          'Savings / Income x 100\n'
          '0 / 6,000 x 100\n'
          '\n'
          '$projectionBody'
          '  Income: ~36,000.00 €\n'
          '  Expenses: ~36,000.00 €\n'
          '  Savings: ~0.00 €\n'
          '  Rate%: ~0.0%\n'
          '\n'
          'How it\'s calculated:\n'
          '━ Income\n'
          '  In 2025, the full-year total was 36,000.00 €.\n'
          '  Over the same period (Jan–Feb) in 2025: 6,000.00 €.\n'
          '  In 2026 (Jan–Feb) so far: 6,000.00 € (100.0% vs 2025).\n'
          '  Projection: 36,000.00 × 6,000.00 ÷ 6,000.00 = ~36,000.00 €\n'
          '━ Expenses\n'
          '  In 2025, the full-year total was 36,000.00 €.\n'
          '  Over the same period (Jan–Feb) in 2025: 6,000.00 €.\n'
          '  In 2026 (Jan–Feb) so far: 6,000.00 € (100.0% vs 2025).\n'
          '  Projection: 36,000.00 × 6,000.00 ÷ 6,000.00 = ~36,000.00 €\n'
          '━ Savings\n'
          '  ~36,000.00 € − ~36,000.00 € = ~0.00 €\n'
          '━ Rate%\n'
          '  ~0.00 ÷ ~36,000.00 = ~0.0%\n'
          '$footer';
      expect(h.dialogText(tester), 'Savings Rate\n$text\nClose');
      expect(selectableTexts(tester), [text]);
      expect(find.byType(ImageFiltered), findsNothing);
      await h.tapDialogButton(tester, s.close);
    } finally {
      await h.unmount(tester);
    }
  });
}
