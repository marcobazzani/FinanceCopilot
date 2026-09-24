// Sankey drill-down → classification: tapping a transaction in a node's list
// shows the wizard's own card inside the same sheet (no dialog on top),
// applying re-classifies and returns to the list, which follows the ledger.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/category_service.dart';
import 'package:finance_copilot/services/classification/rule_service.dart';
import 'package:finance_copilot/services/classification/spending_by_category.dart';
import 'package:finance_copilot/services/classification/transaction_classifier_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/classification/transaction_classify_card.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show CashFlowSankeyCard;

void main() {
  late AppDatabase db;
  late int acct, groceries, restaurants;

  Future<int> tx(String desc, double amount, DateTime d, {int? categoryId}) {
    final n = TransactionClassifierService.normalize(description: desc, amount: amount);
    return db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: acct,
            operationDate: d,
            valueDate: d,
            amount: amount,
            description: Value(desc),
            categoryId: Value(categoryId),
            merchantKey: Value(n.merchantKey),
            counterparty: Value(n.counterparty),
            entryKind: Value(n.entryKind),
          ),
        );
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    acct = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    groceries = (await CategoryService(db).getByKey('groceries'))!.id;
    restaurants = (await CategoryService(db).getByKey('restaurantsBars'))!.id;
  });
  tearDown(() => db.close());

  // Spending recomputed from the live ledger, like the dashboard provider.
  final spendingProvider = FutureProvider<SpendingByCategoryData>((ref) async {
    final txs = await ref.watch(allTransactionsProvider.future);
    final cats = await ref.watch(allCategoriesProvider.future);
    return aggregateSpendingByCategory(
      transactions: txs,
      categories: {for (final c in cats) c.id: c},
      rate: (c, d) async => null,
      baseCurrency: 'EUR',
      now: DateTime(2024, 12, 31),
    );
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          baseCurrencyProvider.overrideWith((ref) => Stream.value('EUR')),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Consumer(
                builder: (context, ref, _) {
                  final d = ref.watch(spendingProvider).value;
                  if (d == null) return const SizedBox.shrink();
                  return CashFlowSankeyCard(
                    spending: d,
                    years: const {2024: (income: 1000, savings: 0, refunds: 0)},
                    currentYear: 2024,
                    locale: 'en_US',
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> teardownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('tapping a transaction shows the wizard card in the same sheet; Skip goes back to the list', (tester) async {
    await tx('Esselunga', -20, DateTime(2024, 3, 1), categoryId: groceries);
    await pump(tester);
    await tester.tap(find.byKey(ValueKey('sankeyNode:out:$groceries')));
    await settle(tester);
    await tester.tap(find.text('Esselunga').last);
    await settle(tester);

    expect(find.byType(TransactionClassifyCard), findsOneWidget);
    expect(find.byKey(const Key('wizardCounterparty')), findsOneWidget);
    expect(find.byKey(const Key('wizardApply')), findsOneWidget);
    expect(find.byType(Dialog), findsNothing, reason: 'no popup over the sheet');
    expect(find.byType(BottomSheet), findsOneWidget);

    await tester.tap(find.byKey(const Key('wizardSkip')));
    await settle(tester);
    expect(find.byType(TransactionClassifyCard), findsNothing);
    expect(find.textContaining('(1)'), findsOneWidget, reason: 'back on the node list');
    await teardownTree(tester);
  });

  testWidgets('re-classifying a categorized row by merchant moves its siblings too, and the list follows', (tester) async {
    final a = await tx('Esselunga', -20, DateTime(2024, 3, 1), categoryId: groceries);
    final b = await tx('Esselunga', -30, DateTime(2024, 4, 1), categoryId: groceries);
    final other = await tx('Pizzikotto', -8, DateTime(2024, 5, 1), categoryId: groceries);
    // Restaurants used once (by a rule) → offered among the card's chips.
    await RuleService(db).create(matchType: RuleMatchType.contains, pattern: 'never-matches-anything', categoryId: restaurants);
    await pump(tester);
    await tester.tap(find.byKey(ValueKey('sankeyNode:out:$groceries')));
    await settle(tester);
    expect(find.textContaining('· 2024 (3)'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('sankeyTx:$a')));
    await settle(tester);
    expect(find.text('1 other similar transaction'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('recentCat_$restaurants')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('wizardApply')));
    await settle(tester);

    Future<int?> cat(int id) async => (await (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle()).categoryId;
    expect(await cat(a), restaurants);
    expect(await cat(b), restaurants, reason: 'same merchant, same old category');
    expect(await cat(other), groceries, reason: 'another merchant is untouched');
    expect(find.byType(TransactionClassifyCard), findsNothing, reason: 'back to the list');
    expect(find.textContaining('· 2024 (1)'), findsOneWidget, reason: 'the moved rows left the node');
    await teardownTree(tester);
  });
}
