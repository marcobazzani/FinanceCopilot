// "Where the money goes", per month: under the years, the months with
// something to show can be picked — optional, the whole year stays the
// default. A month shows that month's income, savings and expenses (the
// Cash Flow tab's monthly figures) split by that month's ledger rows, and a
// category lists that month's rows. Switching year keeps the month when that
// year has it. Privacy mode masks the amounts, never the months.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/classification/spending_by_category.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show CashFlowSankeyCard, CashFlowTotals, CashFlowYearTotals;

Transaction tx(int id, double amount, DateTime date, {int? categoryId}) => Transaction(
  id: id,
  accountId: 1,
  operationDate: date,
  valueDate: date,
  amount: amount,
  description: 'row $id',
  status: TransactionStatus.settled,
  categoryId: categoryId,
  currency: 'EUR',
  tags: '[]',
  createdAt: date,
);

void main() {
  const s = AppStrings.en;
  final cats = {
    2: const Category(id: 2, name: 'Groceries', type: CategoryType.expense, isEssential: true, isArchived: false, sortOrder: 2),
    3: const Category(id: 3, name: 'Travel', type: CategoryType.expense, isEssential: false, isArchived: false, sortOrder: 3),
  };
  final txs = [
    tx(2, -1000, DateTime(2024, 2, 1), categoryId: 2),
    tx(3, -500, DateTime(2024, 3, 1), categoryId: 3),
    tx(5, -1500, DateTime(2025, 2, 1), categoryId: 3),
    tx(7, -300, DateTime(2025, 2, 3)), // uncategorized
    tx(8, -200, DateTime(2025, 3, 4), categoryId: 2),
  ];
  const Map<int, CashFlowYearTotals> years = {
    2024: (income: 3500, savings: 1000, refunds: 0),
    2025: (income: 2000, savings: -500, refunds: 0),
  };
  const Map<(int, int), CashFlowTotals> months = {
    (2024, 1): (income: 0, savings: 0, refunds: 0), // nothing to show: not offered
    (2024, 2): (income: 1500, savings: 500, refunds: 0),
    (2024, 3): (income: 1500, savings: 500, refunds: 0),
    (2024, 12): (income: 500, savings: 0, refunds: 0),
    (2025, 2): (income: 1000, savings: -900, refunds: 0),
    (2025, 3): (income: 1000, savings: 400, refunds: 0),
  };

  setUpAll(() async => initializeDateFormatting());

  Future<void> pump(WidgetTester tester, {bool isPrivate = false, Map<(int, int), CashFlowTotals> monthly = months}) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final spending = await aggregateSpendingByCategory(
      transactions: txs,
      categories: cats,
      rate: (c, d) async => null,
      baseCurrency: 'EUR',
      now: DateTime(2025, 6, 1),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privacyModeProvider.overrideWith((ref) => isPrivate),
          categoriesByIdProvider.overrideWithValue(cats),
          allTransactionsProvider.overrideWith((ref) => Stream.value(txs)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CashFlowSankeyCard(spending: spending, years: years, months: monthly, currentYear: 2025, locale: 'en_US'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;
  Finder inNode(String id, String text) => find.descendant(of: find.byKey(ValueKey('sankeyNode:$id')), matching: find.text(text));
  Finder node(String id) => find.byKey(ValueKey('sankeyNode:$id'));
  Finder monthChip(Object month) => find.byKey(Key('sankeyMonth:$month'));
  bool selected(WidgetTester tester, Finder chip) => tester.widget<ChoiceChip>(chip).selected;

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets('the whole year until a month is picked; a month shows its own figures and rows', (tester) async {
    await pump(tester);
    expect(selected(tester, monthChip('all')), isTrue, reason: 'optional: the year is the default');
    expect(find.descendant(of: monthChip('all'), matching: find.text(s.sankeyWholeYear)), findsOneWidget);
    expect(monthChip(2), findsOneWidget);
    expect(monthChip(3), findsOneWidget);
    expect(monthChip(1), findsNothing, reason: '2025 has no January to show');
    expect(find.descendant(of: monthChip(2), matching: find.text('Feb')), findsOneWidget);
    expect(inNode('income', '€2,000'), findsOneWidget, reason: 'the year 2025');

    await tap(tester, monthChip(2));
    expect(selected(tester, monthChip(2)), isTrue);
    expect(selected(tester, monthChip('all')), isFalse);
    // February 2025: income 1,000, savings −900 → expenses 1,900.
    expect(inNode('income', '€1,000'), findsOneWidget);
    expect(inNode('fromSavings', '€900'), findsOneWidget);
    expect(inNode('out:3', '€1,500'), findsOneWidget);
    expect(inNode('grp:uncategorized', '€300'), findsOneWidget);
    expect(inNode('grp:untracked', '€100'), findsOneWidget, reason: '1,900 − (1,500 + 300)');
    expect(node('out:2'), findsNothing, reason: 'no groceries in February');
    expect(find.text('€1,900'), findsNWidgets(2), reason: 'the summary\'s expenses and the total available');

    await tap(tester, monthChip('all'));
    expect(inNode('income', '€2,000'), findsOneWidget, reason: 'back to the whole year');
    expect(inNode('out:2', '€200'), findsOneWidget);
  });

  testWidgets('a category of a month lists that month\'s rows, under the month\'s name', (tester) async {
    await pump(tester);
    await tap(tester, monthChip(3));
    await tap(tester, node('out:2'));
    expect(find.text('Groceries · Mar 2025 (1)'), findsOneWidget);
    expect(find.text('row 8'), findsOneWidget);
    expect(find.text('row 2'), findsNothing, reason: 'groceries of another year');
  });

  testWidgets('switching year keeps the month when that year has it, else shows the whole year', (tester) async {
    await pump(tester);
    await tap(tester, monthChip(3));
    await tap(tester, find.byKey(const Key('sankeyYear:2024')));
    expect(selected(tester, monthChip(3)), isTrue, reason: '2024 has a March');
    expect(inNode('income', '€1,500'), findsOneWidget, reason: 'March 2024');
    expect(inNode('out:3', '€500'), findsOneWidget);

    await tap(tester, monthChip(12));
    expect(inNode('income', '€500'), findsOneWidget, reason: 'December 2024');
    await tap(tester, find.byKey(const Key('sankeyYear:2025')));
    expect(monthChip(12), findsNothing);
    expect(selected(tester, monthChip('all')), isTrue, reason: '2025 has no December: the whole year');
    expect(inNode('income', '€2,000'), findsOneWidget);
  });

  testWidgets('privacy on: a month\'s amounts are masked, the months and the percentages are not', (tester) async {
    await pump(tester, isPrivate: true);
    await tap(tester, monthChip(2));
    final income = inNode('income', '€1,000');
    expect(income, findsOneWidget);
    expect(masked(income), isTrue, reason: 'position size');
    final month = find.descendant(of: monthChip(2), matching: find.text('Feb'));
    expect(month, findsOneWidget);
    expect(masked(month), isFalse, reason: 'a month is no amount');
    expect(masked(find.descendant(of: monthChip('all'), matching: find.text(s.sankeyWholeYear))), isFalse);
    final share = inNode('out:3', ' · 78.9%');
    expect(share, findsOneWidget, reason: '1,500 of the 1,900 available');
    expect(masked(share), isFalse);
  });

  testWidgets('without monthly figures there is no month to pick: the yearly card as before', (tester) async {
    await pump(tester, monthly: const {});
    expect(monthChip('all'), findsNothing);
    expect(monthChip(2), findsNothing);
    expect(inNode('income', '€2,000'), findsOneWidget);
  });
}
