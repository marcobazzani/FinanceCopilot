// Cash Flow tab:
//  * Yearly Summary: a year without income has no savings rate — "—", as the
//    Sankey leaves the rate out and the Health tab reads N/A — never "+0.0%";
//  * the month names of the monthly tables and charts, pinned before their
//    four copies of the month-name helper were folded into one;
//  * privacy mode blurs the value-axis amounts of the yearly and monthly
//    charts (PrivacyMask, as the History charts do) and keeps the years and
//    months readable;
//  * "Where the money goes" with nothing to show uses the shared empty state.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/classification/spending_by_category.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show CashFlowSankeyCard;
import 'package:finance_copilot/ui/widgets/empty_state.dart';

import 'dashboard_harness.dart';

void main() {
  final h = DashboardHarness();

  setUpAll(() async => initializeDateFormatting());
  setUp(h.open);
  tearDown(h.close);

  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  Future<void> expand(WidgetTester tester, String title) async {
    final tile = find.text(title);
    await tester.ensureVisible(tile);
    await h.settle(tester);
    await tester.tap(tile);
    await h.settle(tester);
  }

  Finder section(String title) => find.ancestor(of: find.text(title), matching: find.byType(ExpansionTile)).first;

  /// The texts of [section] in tree order.
  List<String> textsIn(WidgetTester tester, Finder section) => [
    for (final t in tester.widgetList<Text>(find.descendant(of: section, matching: find.byType(Text)))) t.data ?? '',
  ];

  /// 3,000 of the 2025 salary stays in the account: a 2025 savings rate of
  /// 3,000 / 36,000 = 8.3%.
  Future<void> depositIn2025() async {
    final acct = (await h.db.select(h.db.accounts).get()).single.id;
    await h.db
        .into(h.db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: acct,
            operationDate: DateTime(2025, 6, 15),
            valueDate: DateTime(2025, 6, 15),
            amount: 3000,
            balanceAfter: const Value(18000),
            description: const Value('Kept'),
          ),
        );
  }

  testWidgets('Yearly Summary: a year without income reads "—" in the rate column, a year with income keeps its rate', (tester) async {
    await h.seed(); // tracking opens in December 2024; the salary starts in 2025
    await depositIn2025();
    await h.pump(tester);
    try {
      await h.openTab(tester, 'Cash Flow');
      await expand(tester, 'Yearly Summary');
      final table = find.byType(DataTable);

      /// The texts laid out on the row of [year].
      List<String> row(String year) {
        final y = tester.getCenter(find.descendant(of: table, matching: find.text(year))).dy;
        return [
          for (final e in find.descendant(of: table, matching: find.byType(Text)).evaluate())
            if (((e.renderObject! as RenderBox).localToGlobal(Offset.zero).dy + (e.renderObject! as RenderBox).size.height / 2 - y).abs() < 1)
              (e.widget as Text).data ?? '',
        ];
      }

      expect(row('2024'), contains('—'), reason: 'no income in 2024: no rate to show');
      expect(row('2024'), isNot(contains('+0.0%')), reason: 'a missing rate is not a 0% one');
      expect(row('2025'), contains('+8.3%'));
    } finally {
      await h.unmount(tester);
    }
  });

  group('month names', () {
    for (final (language, locale, tab, incomeTable, yoy, incomeChart, months) in [
      (
        'en',
        'en_US',
        'Cash Flow',
        'Monthly Income by Year (table)',
        'YoY Income Changes',
        'Income by Month (per Year)',
        const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
      ),
      (
        'it',
        'it_IT',
        'Flussi di cassa',
        'Entrate Mensili per Anno (tabella)',
        'Variazione YoY Entrate',
        'Entrate per Mese (per Anno)',
        const ['gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic'],
      ),
    ]) {
      testWidgets('$locale: the monthly table, the YoY table and the monthly chart name the months alike', (tester) async {
        await h.seed();
        await h.pump(tester, language: language, locale: locale);
        try {
          await h.openTab(tester, tab);
          for (final title in [incomeTable, yoy, incomeChart]) {
            await expand(tester, title);
            expect(textsIn(tester, section(title)).where(months.contains).toList(), months, reason: title);
          }
        } finally {
          await h.unmount(tester);
        }
      });
    }
  });

  group('value axis in privacy mode', () {
    /// Amount labels (ending with the currency) and the other labels drawn by
    /// the first bar chart of [section].
    ({List<Finder> amounts, List<Finder> others}) axisOf(WidgetTester tester, Finder section) {
      final chart = find.descendant(of: section, matching: find.byType(BarChart)).first;
      final amounts = <Finder>[];
      final others = <Finder>[];
      for (final e in find.descendant(of: chart, matching: find.byType(Text)).evaluate()) {
        final text = (e.widget as Text).data ?? '';
        final finder = find.byElementPredicate((el) => el == e);
        (text.endsWith(' €') ? amounts : others).add(finder);
      }
      return (amounts: amounts, others: others);
    }

    for (final (title, label) in [('Income / Expenses / Savings per Year', '2025'), ('Income by Month (per Year)', 'Jun')]) {
      testWidgets('$title: the amounts are blurred, "$label" stays readable', (tester) async {
        await h.seed();
        await h.pump(tester, isPrivate: true);
        try {
          await h.openTab(tester, 'Cash Flow');
          if (title != 'Income / Expenses / Savings per Year') await expand(tester, title);
          final (:amounts, :others) = axisOf(tester, section(title));
          expect(amounts, isNotEmpty, reason: 'the scale is drawn, blurred, not replaced by a placeholder');
          for (final a in amounts) {
            expect(masked(a), isTrue, reason: 'an axis amount is position size');
          }
          final readable = others.where((f) => (tester.widget<Text>(f).data ?? '') == label).toList();
          expect(readable, isNotEmpty);
          expect(masked(readable.first), isFalse, reason: '"$label" carries no magnitude');
          expect(find.text('\u2022\u2022\u2022\u2022'), findsNothing);
        } finally {
          await h.unmount(tester);
        }
      });
    }

    testWidgets('without privacy nothing on the axis is blurred', (tester) async {
      await h.seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        final (:amounts, others: _) = axisOf(tester, section('Income / Expenses / Savings per Year'));
        expect(amounts, isNotEmpty);
        for (final a in amounts) {
          expect(masked(a), isFalse);
        }
      } finally {
        await h.unmount(tester);
      }
    });
  });

  testWidgets('Where the money goes: nothing to show is the shared empty state', (tester) async {
    const s = AppStrings.en;
    final spending = await aggregateSpendingByCategory(
      transactions: const [],
      categories: const {},
      rate: (c, d) async => null,
      baseCurrency: 'EUR',
      now: DateTime(2026, 3, 10),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesByIdProvider.overrideWithValue(const {}),
          allTransactionsProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CashFlowSankeyCard(spending: spending, years: const {}, currentYear: 2026, locale: 'en_US'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final empty = find.byType(EmptyState);
    expect(empty, findsOneWidget);
    expect(find.descendant(of: empty, matching: find.text(s.spendingByCategoryEmpty)), findsOneWidget);
  });
}
