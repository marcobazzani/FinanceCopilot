// The Accounts view hosts the single classification entry point: the
// full-screen Categories & rules view (wizard, rule runs, rules, categories).
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/rule_service.dart';
import 'package:finance_copilot/services/classification/transaction_classifier_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/accounts/accounts_screen.dart';
import 'package:finance_copilot/ui/screens/classification/categories_rules_screen.dart';

void main() {
  late AppDatabase db;
  late int groceries;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final acct = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    groceries = (await (db.select(db.categories)..where((c) => c.key.equals('groceries'))).getSingle()).id;
    final n = TransactionClassifierService.normalize(description: 'Esselunga', amount: -20);
    for (var i = 0; i < 2; i++) {
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              accountId: acct,
              operationDate: DateTime(2024, 3, 10 + i),
              valueDate: DateTime(2024, 3, 10 + i),
              amount: -20,
              description: const Value('Esselunga'),
              merchantKey: Value(n.merchantKey),
            ),
          );
    }
    await RuleService(db).create(matchType: RuleMatchType.merchantKey, pattern: 'ESSELUNGA', categoryId: groceries);
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> teardownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Widget harness() => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db), privacyModeProvider.overrideWith((ref) => false)],
    child: const MaterialApp(home: AccountsScreen()),
  );

  testWidgets('wand opens the full-screen Categories & rules view with the classifier controls', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness());
    await settle(tester);

    await tester.tap(find.byTooltip('Classify 2 uncategorized'));
    await settle(tester);
    expect(find.byType(CategoriesRulesScreen), findsOneWidget);
    expect(find.byKey(const Key('openWizard')), findsOneWidget);

    await tester.tap(find.byKey(const Key('classifyUncategorized')));
    await settle(tester);
    expect(find.text('Classified 2 transactions, 0 uncategorized'), findsOneWidget);
    final txs = await db.select(db.transactions).get();
    expect(txs.every((t) => t.categoryId == groceries), isTrue);
    await teardownTree(tester);
  });
}
