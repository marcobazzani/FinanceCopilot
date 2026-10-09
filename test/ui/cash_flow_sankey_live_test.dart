// The Sankey drill-down sheet is its own route and follows the ledger through
// a ValueNotifier fed by the card. The card used to feed it from
// didUpdateWidget — in the middle of the build that delivered the new data —
// so the sheet's listener was told to rebuild while another route was being
// built ("setState() or markNeedsBuild() called during build").
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/spending_by_category.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show CashFlowSankeyCard;

Transaction _tx(int id, double amount, DateTime date, {int? categoryId}) => Transaction(
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
  const cats = {2: Category(id: 2, name: 'Groceries', type: CategoryType.expense, isEssential: true, isArchived: false, sortOrder: 2)};

  testWidgets('new ledger data reaches an open drill-down sheet without rebuilding it mid-build', (tester) async {
    final before = [_tx(1, -100, DateTime(2024, 3, 1), categoryId: 2)];
    final after = [...before, _tx(2, -40, DateTime(2024, 4, 1), categoryId: 2)];
    Future<SpendingByCategoryData> aggregate(List<Transaction> txs) => aggregateSpendingByCategory(
      transactions: txs,
      categories: cats,
      rate: (c, d) async => null,
      baseCurrency: 'EUR',
      now: DateTime(2024, 12, 31),
    );
    final spendingBefore = await aggregate(before);
    final spendingAfter = await aggregate(after);
    final spending = StateProvider<SpendingByCategoryData>((ref) => spendingBefore);

    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privacyModeProvider.overrideWith((ref) => false),
          categoriesByIdProvider.overrideWithValue(cats),
          allTransactionsProvider.overrideWith((ref) => Stream.value(after)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Consumer(
                builder: (context, ref, _) => CashFlowSankeyCard(
                  spending: ref.watch(spending),
                  years: const {2024: (income: 1000, savings: 0, refunds: 0)},
                  currentYear: 2024,
                  locale: 'en_US',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sankeyNode:out:2')));
    await tester.pumpAndSettle();
    expect(find.text('Groceries · 2024 (1)'), findsOneWidget);

    final container = ProviderScope.containerOf(tester.element(find.byType(CashFlowSankeyCard)));
    container.read(spending.notifier).state = spendingAfter;
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'the sheet must not be marked dirty during the card\'s build');
    await tester.pumpAndSettle();

    expect(find.text('Groceries · 2024 (2)'), findsOneWidget, reason: 'the open sheet follows the ledger');
    expect(find.text('row 2'), findsOneWidget);
  });
}
