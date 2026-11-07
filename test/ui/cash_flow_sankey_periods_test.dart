// "Where the money goes" shows the periods the Cash Flow tab picked: a whole
// year, one month, or months of different years summed. A month shows that
// month's income, savings and expenses (the tab's monthly figures) split by
// that month's ledger rows, and a category lists that month's rows. Privacy
// mode masks the amounts, never the percentages.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/spending_by_category.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show CashFlowSankeyCard, CashFlowTotals;

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
  // The monthly figures; a year's add up to it (2024: 3,500 and 1,000 saved;
  // 2025: 2,000 and 500 taken from savings).
  const Map<(int, int), CashFlowTotals> months = {
    (2024, 1): (income: 0, savings: 0, refunds: 0),
    (2024, 2): (income: 1500, savings: 500, refunds: 0),
    (2024, 3): (income: 1500, savings: 500, refunds: 0),
    (2024, 12): (income: 500, savings: 0, refunds: 0),
    (2025, 2): (income: 1000, savings: -900, refunds: 0),
    (2025, 3): (income: 1000, savings: 400, refunds: 0),
  };

  setUpAll(() async => initializeDateFormatting());

  Set<(int, int)> yearOf(int year) => {for (var m = 1; m <= 12; m++) (year, m)};

  // The tab's figures for [periods]: their months', summed.
  CashFlowTotals totalsOf(Set<(int, int)> periods) {
    var (income, savings, refunds) = (0.0, 0.0, 0.0);
    for (final p in periods) {
      final t = months[p];
      if (t == null) continue;
      income += t.income;
      savings += t.savings;
      refunds += t.refunds;
    }
    return (income: income, savings: savings, refunds: refunds);
  }

  Future<void> pump(WidgetTester tester, {required Set<(int, int)> periods, required String label, bool isPrivate = false}) async {
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
              child: CashFlowSankeyCard(spending: spending, periods: periods, totals: totalsOf(periods), periodLabel: label, locale: 'en_US'),
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

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets('a year shows the year\'s figures; a month its own figures and rows', (tester) async {
    await pump(tester, periods: yearOf(2025), label: '2025');
    expect(inNode('income', '€2,000.00'), findsOneWidget, reason: 'the year 2025');

    await pump(tester, periods: {(2025, 2)}, label: 'Feb 2025');
    // February 2025: income 1,000, savings −900 → expenses 1,900.
    expect(inNode('income', '€1,000.00'), findsOneWidget);
    expect(inNode('fromSavings', '€900.00'), findsOneWidget);
    expect(inNode('out:3', '€1,500.00'), findsOneWidget);
    expect(inNode('grp:uncategorized', '€300.00'), findsOneWidget);
    expect(inNode('grp:untracked', '€100.00'), findsOneWidget, reason: '1,900 − (1,500 + 300)');
    expect(node('out:2'), findsNothing, reason: 'no groceries in February');
    expect(find.text('€1,900.00'), findsOneWidget, reason: 'the total available');

    await pump(tester, periods: yearOf(2025), label: '2025');
    expect(inNode('income', '€2,000.00'), findsOneWidget, reason: 'back to the whole year');
    expect(inNode('out:2', '€200.00'), findsOneWidget);
  });

  testWidgets('a category of a month lists that month\'s rows, under the month\'s name', (tester) async {
    await pump(tester, periods: {(2025, 3)}, label: 'Mar 2025');
    await tap(tester, node('out:2'));
    expect(find.text('Groceries · Mar 2025 (1)'), findsOneWidget);
    expect(find.text('row 8'), findsOneWidget);
    expect(find.text('row 2'), findsNothing, reason: 'groceries of another year');
  });

  testWidgets('each month shows its own figures, whichever year it is in', (tester) async {
    await pump(tester, periods: {(2024, 3)}, label: 'Mar 2024');
    expect(inNode('income', '€1,500.00'), findsOneWidget, reason: 'March 2024');
    expect(inNode('out:3', '€500.00'), findsOneWidget);

    await pump(tester, periods: {(2024, 12)}, label: 'Dec 2024');
    expect(inNode('income', '€500.00'), findsOneWidget, reason: 'December 2024');
  });

  testWidgets('months of two years are summed, their figures and their rows', (tester) async {
    await pump(tester, periods: {(2024, 12), (2025, 2)}, label: 'Dec 2024 · Feb 2025');
    // 500 + 1,000 of income, 900 taken from savings: 2,400 of expenses, 1,800 in the ledger.
    expect(inNode('income', '€1,500.00'), findsOneWidget);
    expect(inNode('fromSavings', '€900.00'), findsOneWidget);
    expect(inNode('out:3', '€1,500.00'), findsOneWidget);
    expect(inNode('grp:untracked', '€600.00'), findsOneWidget, reason: '2,400 − (1,500 + 300)');
  });

  testWidgets('privacy on: a month\'s amounts are masked, the percentages are not', (tester) async {
    await pump(tester, periods: {(2025, 2)}, label: 'Feb 2025', isPrivate: true);
    final income = inNode('income', '€1,000.00');
    expect(income, findsOneWidget);
    expect(masked(income), isTrue, reason: 'position size');
    final share = inNode('out:3', ' · 78.9%');
    expect(share, findsOneWidget, reason: '1,500 of the 1,900 available');
    expect(masked(share), isFalse);
  });
}
