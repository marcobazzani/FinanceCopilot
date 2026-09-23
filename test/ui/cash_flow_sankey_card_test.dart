import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/spending_by_category.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show CashFlowSankeyCard, CashFlowYearTotals;

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
  final baseTxs = [
    tx(2, -1000, DateTime(2024, 2, 1), categoryId: 2),
    tx(3, -500, DateTime(2024, 3, 1), categoryId: 3),
    tx(5, -1500, DateTime(2025, 2, 1), categoryId: 3),
    tx(6, 99999, DateTime(2025, 2, 2)), // ledger inflow: never the income figure
    tx(7, -300, DateTime(2025, 2, 3)), // uncategorized spending
  ];
  // The yearly Income/Expense/Savings figures (expenses = income − savings).
  const Map<int, CashFlowYearTotals> years = {
    2024: (income: 3000, savings: 1000), // expenses 2000
    2025: (income: 2000, savings: -500), // expenses 2500
  };

  Future<void> pump(
    WidgetTester tester, {
    required bool isPrivate,
    Map<int, CashFlowYearTotals> totals = years,
    List<Transaction>? ledger,
  }) async {
    final txs = ledger ?? baseTxs;
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
              child: CashFlowSankeyCard(spending: spending, years: totals, currentYear: 2025, locale: 'en_US'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;
  Finder inNode(String id, String text) => find.descendant(of: find.byKey(ValueKey('sankeyNode:$id')), matching: find.text(text));

  testWidgets('shows the yearly chart figures; the ledger only splits expenses; privacy masks amounts, not percentages', (tester) async {
    await pump(tester, isPrivate: true);
    // 2025 YTD: income 2000, savings −500 → expenses 2500 (not the ledger's 99,999 inflow).
    expect(inNode('income', '€2,000'), findsOneWidget);
    expect(inNode('fromSavings', '€500'), findsOneWidget);
    expect(inNode('out:3', '€1,500'), findsOneWidget);
    expect(inNode('grp:uncategorized', '€300'), findsOneWidget, reason: 'tracked, just not classified');
    expect(inNode('grp:uncategorized', 'Uncategorized'), findsOneWidget);
    expect(inNode('grp:untracked', '€700'), findsOneWidget, reason: 'expenses 2500 − ledger (1500 + 300)');
    expect(find.byKey(const ValueKey('sankeyNode:saved')), findsNothing);

    final travelShare = inNode('out:3', ' · 60.0%');
    expect(travelShare, findsOneWidget);
    expect(masked(inNode('out:3', '€1,500')), isTrue, reason: 'position size');
    expect(masked(travelShare), isFalse, reason: 'shape, not magnitude');
    expect(masked(find.byKey(const Key('sankeySavingsRate'))), isFalse);
  });

  testWidgets('switching year rebuilds the flows from that year\'s figures', (tester) async {
    await pump(tester, isPrivate: false);
    await tester.tap(find.byKey(const Key('sankeyYear:2024')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sankeyNode:fromSavings')), findsNothing);
    expect(inNode('saved', '€1,000'), findsOneWidget);
    expect(inNode('saved', ' · 33.3%'), findsOneWidget);
    expect(find.byKey(const ValueKey('sankeyNode:grp:essential')), findsOneWidget);
    expect(find.byKey(const ValueKey('sankeyNode:grp:untracked')), findsOneWidget, reason: '2000 − 1500');
  });

  testWidgets('categorized spending above the yearly expenses is balanced by untracked income, no warning', (tester) async {
    // 2025: ledger 1500 + 300, expenses 1000 − 500 = 500 → 1300 untracked income.
    await pump(tester, isPrivate: false, totals: const {2025: (income: 1000, savings: 500)});
    expect(find.byKey(const Key('cashFlowSankey')), findsOneWidget);
    expect(inNode('untrackedIncome', '€1,300'), findsOneWidget);
    expect(inNode('untrackedIncome', 'Untracked income'), findsOneWidget);
    expect(inNode('out:3', '€1,500'), findsOneWidget, reason: 'categories never shrunk');
    expect(find.byKey(const ValueKey('sankeyNode:grp:untracked')), findsNothing);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });

  testWidgets('transfer outflows are not spending but their amount is shown (masked); refund-category outflows count', (tester) async {
    const moves = Category(id: 9, name: 'Investments', type: CategoryType.transfer, isEssential: false, isArchived: false, sortOrder: 9);
    const back = Category(id: 8, name: 'Refunds', type: CategoryType.reimbursement, isEssential: false, isArchived: false, sortOrder: 8);
    cats[9] = moves;
    cats[8] = back;
    addTearDown(
      () => cats
        ..remove(9)
        ..remove(8),
    );
    await pump(
      tester,
      isPrivate: true,
      ledger: [...baseTxs, tx(20, -4000, DateTime(2025, 3, 1), categoryId: 9), tx(21, -200, DateTime(2025, 3, 2), categoryId: 8)],
    );
    final line = find.byKey(const Key('sankeyTransfersExcluded'));
    final text = find.descendant(of: line, matching: find.text('Transfers and investments not counted as expenses: €4,000'));
    expect(text, findsOneWidget);
    expect(masked(text), isTrue, reason: 'money moved: position size');
    expect(masked(find.byKey(const Key('spendingFootnote'))), isFalse, reason: 'explanations and counts stay readable');
    expect(find.byKey(const ValueKey('sankeyNode:out:9')), findsNothing);
    expect(inNode('out:8', '€200'), findsOneWidget, reason: 'an outflow in a refund category is money that left');
  });

  testWidgets('tapping a category lists exactly the transactions summed into it', (tester) async {
    await pump(tester, isPrivate: false);
    await tester.tap(find.byKey(const Key('sankeyYear:2024')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sankeyNode:out:2')));
    await tester.pumpAndSettle();
    expect(find.text('Groceries · 2024 (1)'), findsOneWidget);
    expect(find.text('row 2'), findsOneWidget);
    expect(find.text('row 3'), findsNothing);
  });

  testWidgets('tapping a node lists its rows by absolute amount, biggest first', (tester) async {
    await pump(
      tester,
      isPrivate: false,
      ledger: [
        ...baseTxs,
        tx(8, -40, DateTime(2025, 5, 3)), // newer but smaller
        tx(9, -900, DateTime(2025, 1, 3)), // older but bigger
      ],
    );
    await tester.tap(find.byKey(const ValueKey('sankeyNode:grp:uncategorized')));
    await tester.pumpAndSettle();
    expect(find.text('Uncategorized · 2025 (3)'), findsOneWidget);
    final order = ['row 9', 'row 7', 'row 8'].map((t) => tester.getTopLeft(find.text(t)).dy).toList();
    expect(order, [...order]..sort(), reason: 'ordered by |amount| descending, not by date');
  });
}
