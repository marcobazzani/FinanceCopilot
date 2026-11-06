// Cash Flow tab:
//  * Year by year, as a table: a year without income has no savings rate —
//    "—", as the Sankey leaves the rate out and the Health tab reads N/A —
//    never "+0.0%";
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

  testWidgets('Year by year table: a year without income reads "—" in the rate column, a year with income keeps its rate', (tester) async {
    await h.seed(); // tracking opens in December 2024; the salary starts in 2025
    await depositIn2025();
    await h.pump(tester);
    try {
      await h.openTab(tester, 'Cash Flow');
      await h.cashFlowSection(tester, 'cfYearByYearTile', pick: [AppStrings.en.cfViewTable]);
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
    for (final (language, locale, tab, months) in [
      ('en', 'en_US', 'Cash Flow', const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']),
      ('it', 'it_IT', 'Flussi di cassa', const ['gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic']),
    ]) {
      testWidgets('$locale: the monthly table, the YoY table and the monthly chart name the months alike', (tester) async {
        final s = AppStrings.of(language);
        await h.seed();
        await h.pump(tester, language: language, locale: locale);
        try {
          await h.openTab(tester, tab);
          // Month by month, income: as a table, year over year, as a chart.
          for (final view in [s.cfViewTable, s.cfViewYoY, s.cfViewChart]) {
            final section = await h.cashFlowSection(tester, 'cfMonthByMonthTile', pick: [view]);
            expect(textsIn(tester, section).where(months.contains).toList(), months, reason: view);
          }
        } finally {
          await h.unmount(tester);
        }
      });
    }
  });

  group('value axis in privacy mode', () {
    /// Amount labels (ending with the currency) and the other labels drawn by
    /// the first chart of [section].
    ({List<Finder> amounts, List<Finder> others}) axisOf(WidgetTester tester, Finder section) {
      final chart = find.descendant(of: section, matching: find.byWidgetPredicate((w) => w is BarChart || w is LineChart)).first;
      final amounts = <Finder>[];
      final others = <Finder>[];
      for (final e in find.descendant(of: chart, matching: find.byType(Text)).evaluate()) {
        final text = (e.widget as Text).data ?? '';
        final finder = find.byElementPredicate((el) => el == e);
        (text.endsWith(' €') ? amounts : others).add(finder);
      }
      return (amounts: amounts, others: others);
    }

    for (final (title, key, label) in [('Year by year', 'cfYearByYearTile', '2025'), ('Month by month', 'cfMonthByMonthTile', 'Jun')]) {
      testWidgets('$title: the amounts are blurred, "$label" stays readable', (tester) async {
        await h.seed();
        await h.pump(tester, isPrivate: true);
        try {
          await h.openTab(tester, 'Cash Flow');
          final (:amounts, :others) = axisOf(tester, await h.cashFlowSection(tester, key));
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
        final (:amounts, others: _) = axisOf(tester, await h.cashFlowSection(tester, 'cfYearByYearTile'));
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
              child: CashFlowSankeyCard(
                spending: spending,
                periods: const {},
                totals: (income: 0, savings: 0, refunds: 0),
                periodLabel: '2026',
                locale: 'en_US',
              ),
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
