// Widget tests for Settings → Categories & rules and the transaction edit
// screen's category field.
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
import 'package:finance_copilot/ui/screens/classification/categories_rules_screen.dart';
import 'package:finance_copilot/ui/screens/events/transaction_edit_screen.dart';
import 'package:finance_copilot/ui/widgets/category_ui.dart';

void main() {
  late AppDatabase db;
  late Account account;
  late int groceries;

  Future<int> tx(String desc, double amount) {
    final d = DateTime(2024, 3, 10);
    final n = TransactionClassifierService.normalize(description: desc, amount: amount);
    return db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: account.id,
            operationDate: d,
            valueDate: d,
            amount: amount,
            description: Value(desc),
            merchantKey: Value(n.merchantKey),
            counterparty: Value(n.counterparty),
            entryKind: Value(n.entryKind),
          ),
        );
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final id = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    account = await (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingle();
    groceries = (await (db.select(db.categories)..where((c) => c.key.equals('groceries'))).getSingle()).id;
    await tx('Esselunga', -20);
    await tx('Esselunga', -30);
    await tx('Bar Sport', -3);
  });
  tearDown(() => db.close());

  Widget scope(Widget home, {bool isPrivate = false}) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      privacyModeProvider.overrideWith((ref) => isPrivate),
    ],
    child: MaterialApp(home: home),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> teardownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('CategoriesRulesScreen', () {
    testWidgets('empty rules state, wizard shortcut with count, both classifier buttons', (tester) async {
      await tester.pumpWidget(scope(const CategoriesRulesScreen()));
      await settle(tester);
      expect(find.textContaining('No rules yet'), findsOneWidget);
      expect(find.byKey(const Key('classifyUncategorized')), findsOneWidget);
      expect(find.byKey(const Key('reclassifyEverything')), findsOneWidget);
      expect(find.text('Classify 3 uncategorized'), findsOneWidget);
      expect(find.byKey(const Key('rulesDirtyBanner')), findsNothing);
      await teardownTree(tester);
    });

    testWidgets('rule list shows rules; toggling active marks dirty; classify clears it and applies', (tester) async {
      await RuleService(db).create(matchType: RuleMatchType.merchantKey, pattern: 'ESSELUNGA', categoryId: groceries);
      await tester.pumpWidget(scope(const CategoriesRulesScreen()));
      await settle(tester);
      expect(find.textContaining('ESSELUNGA', findRichText: true), findsOneWidget);
      expect(find.text('Groceries'), findsWidgets);

      await tester.tap(find.byType(Switch).first);
      await settle(tester);
      expect(find.byKey(const Key('rulesDirtyBanner')), findsOneWidget);
      await tester.tap(find.byType(Switch).first);
      await settle(tester);

      await tester.tap(find.byKey(const Key('classifyUncategorized')));
      await settle(tester);
      expect(find.byKey(const Key('rulesDirtyBanner')), findsNothing);
      expect(find.text('Classified 2 transactions, 1 uncategorized'), findsOneWidget);
      final txs = await db.select(db.transactions).get();
      expect(txs.where((t) => t.categoryId == groceries), hasLength(2));
      await teardownTree(tester);
    });

    testWidgets('new rule dialog validates, previews matches and saves', (tester) async {
      await tester.pumpWidget(scope(const CategoriesRulesScreen()));
      await settle(tester);
      await tester.tap(find.byTooltip('New rule'));
      await settle(tester);

      // Save disabled: no pattern / no category yet.
      expect(tester.widget<FilledButton>(find.byKey(const Key('ruleSave'))).onPressed, isNull);

      // Switch to "contains" and type a pattern → live preview.
      await tester.tap(find.byKey(const Key('ruleMatchType')));
      await settle(tester);
      await tester.tap(find.text('Description contains').last);
      await settle(tester);
      await tester.enterText(find.byKey(const Key('rulePattern')), 'esselunga');
      await settle(tester);
      expect(find.text('Matches 2 transactions (2 uncategorized)'), findsOneWidget);

      // Pick a category.
      await tester.tap(find.byType(CategoryField));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('categoryPickerSearch')), 'Grocer');
      await settle(tester);
      await tester.tap(find.text('Groceries').last);
      await settle(tester);

      await tester.tap(find.byKey(const Key('ruleSave')));
      await settle(tester);
      final rules = await db.select(db.autoCategorizationRules).get();
      expect(rules, hasLength(1));
      expect(rules.single.matchType, RuleMatchType.contains);
      expect(rules.single.pattern, 'esselunga');
      expect(find.byKey(const Key('rulesDirtyBanner')), findsOneWidget, reason: 'new rule not applied yet');
      await teardownTree(tester);
    });

    testWidgets('categories tab lists seeded categories and creates a custom one', (tester) async {
      await tester.pumpWidget(scope(const CategoriesRulesScreen()));
      await settle(tester);
      await tester.tap(find.byKey(const Key('tabCategories')));
      await settle(tester);
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Transfers'), findsOneWidget);

      await tester.tap(find.byTooltip('New category'));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('categoryNameField')), 'Pets');
      await settle(tester);
      await tester.tap(find.byKey(const Key('categorySave')));
      await settle(tester);
      final pets = await (db.select(db.categories)..where((c) => c.name.equals('Pets'))).getSingle();
      expect(pets.type, CategoryType.expense);
      expect(pets.key, isNull);
      expect(find.text('Pets'), findsOneWidget);
      await teardownTree(tester);
    });
  });

  group('TransactionEditScreen category field', () {
    testWidgets('shows merchant helper, picks a category and optionally creates a merchant rule', (tester) async {
      final t = (await db.select(db.transactions).get()).first;
      await tester.pumpWidget(scope(TransactionEditScreen(transaction: t, account: account)));
      await settle(tester);
      // The category field sits below the fold of the lazily-built ListView.
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await settle(tester);
      expect(find.text('Uncategorized'), findsOneWidget);
      expect(find.textContaining('Merchant: Esselunga'), findsOneWidget);
      // Rule checkbox only appears once a category is chosen.
      expect(find.text('Create a rule for this merchant'), findsNothing);

      await tester.tap(find.byType(CategoryField));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('categoryPickerSearch')), 'Grocer');
      await settle(tester);
      await tester.tap(find.text('Groceries').last);
      await settle(tester);
      expect(find.text('Create a rule for this merchant'), findsOneWidget);
      expect(find.textContaining('"Esselunga" (1)'), findsOneWidget, reason: 'one other uncategorized row shares the merchant');

      await tester.tap(find.byType(CheckboxListTile));
      await settle(tester);
      for (var i = 0; i < 8 && find.text('Save Changes').evaluate().isEmpty; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await settle(tester);
      }
      await tester.ensureVisible(find.text('Save Changes'));
      await settle(tester);
      await tester.tap(find.text('Save Changes'));
      await settle(tester);

      final saved = await (db.select(db.transactions)..where((x) => x.id.equals(t.id))).getSingle();
      expect(saved.categoryId, groceries);
      final rules = await db.select(db.autoCategorizationRules).get();
      expect(rules.single.pattern, 'ESSELUNGA');
      expect(rules.single.categoryId, groceries);
      await teardownTree(tester);
    });
  });
}
