// The "Where the money goes" Sankey shows each spread saving plan of the year
// as a band of its own ("Saving for T-Roc"): tracked spending, not part of
// "untracked expenses". Privacy mode masks its amount, never its name or its
// share.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/spending_by_category.dart';
import 'package:finance_copilot/services/domain/adjustment_items.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show CashFlowSankeyCard, CashFlowYearTotals;

void main() {
  final cats = {
    2: const Category(id: 2, name: 'Groceries', type: CategoryType.expense, isEssential: true, isArchived: false, sortOrder: 2),
  };
  final groceries = DateTime(2024, 2, 1);
  final txs = [
    Transaction(
      id: 1,
      accountId: 1,
      operationDate: groceries,
      valueDate: groceries,
      amount: -1000,
      description: 'row 1',
      status: TransactionStatus.settled,
      categoryId: 2,
      currency: 'EUR',
      tags: '[]',
      createdAt: groceries,
    ),
  ];
  // 4 × 300 set aside for the car in 2024.
  final plan = [
    for (var m = 1; m <= 4; m++) SavingScheduleItem(eventId: 5, eventName: 'T-Roc', date: DateTime(2024, m, 26), amount: -300, currency: 'EUR'),
  ];
  // Savings 800 are already net of the 1,200 set aside: expenses 2,200 = 1,000 + 1,200.
  const Map<int, CashFlowYearTotals> years = {2024: (income: 3000, savings: 800, refunds: 0)};

  Future<void> pump(WidgetTester tester, {required bool isPrivate}) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final spending = await aggregateSpendingByCategory(
      transactions: txs,
      categories: cats,
      rate: (c, d) async => null,
      baseCurrency: 'EUR',
      now: DateTime(2025, 6, 1),
      savingItems: plan,
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
              child: CashFlowSankeyCard(spending: spending, years: years, currentYear: 2025, locale: 'en_US'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;
  Finder inNode(String id, String text) => find.descendant(of: find.byKey(ValueKey('sankeyNode:$id')), matching: find.text(text));

  testWidgets('the plan is its own band; nothing is left untracked', (tester) async {
    await pump(tester, isPrivate: false);
    expect(inNode('plan:5', 'Saving for T-Roc'), findsOneWidget);
    expect(inNode('plan:5', '€1,200'), findsOneWidget);
    expect(inNode('plan:5', ' · 40.0%'), findsOneWidget, reason: '1,200 of the 3,000 available');
    expect(inNode('out:2', '€1,000'), findsOneWidget);
    expect(inNode('saved', '€800'), findsOneWidget);
    expect(find.byKey(const ValueKey('sankeyNode:grp:untracked')), findsNothing, reason: 'the 1,200 used to be shown as untracked expenses');
    expect(find.byKey(const ValueKey('sankeyNode:untrackedIncome')), findsNothing);
  });

  testWidgets('privacy on: the amount set aside is masked, the plan name and its share stay readable', (tester) async {
    await pump(tester, isPrivate: true);
    final amount = inNode('plan:5', '€1,200');
    expect(amount, findsOneWidget);
    expect(masked(amount), isTrue, reason: 'position size');
    final name = inNode('plan:5', 'Saving for T-Roc');
    expect(name, findsOneWidget);
    expect(masked(name), isFalse);
    final share = inNode('plan:5', ' · 40.0%');
    expect(share, findsOneWidget);
    expect(masked(share), isFalse, reason: 'shape, not magnitude');
  });
}
