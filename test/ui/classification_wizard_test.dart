// Widget tests for the classification wizard: shows the biggest merchant
// group first, applying creates a rule and reclassifies the ledger, skip and
// undo work, privacy masks the amount while the merchant label stays visible.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/transaction_classifier_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/classification/classification_wizard_screen.dart';

void main() {
  late AppDatabase db;
  late int acct;

  Future<int> tx(String desc, double amount, {DateTime? date}) {
    final d = date ?? DateTime(2024, 3, 10);
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
            merchantKey: Value(n.merchantKey),
            counterparty: Value(n.counterparty),
            entryKind: Value(n.entryKind),
          ),
        );
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    acct = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    await tx('Esselunga', -20);
    await tx('Esselunga', -30, date: DateTime(2024, 4, 1));
    await tx('Esselunga', -10, date: DateTime(2024, 5, 1));
    await tx('Pizzikotto', -8);
  });
  tearDown(() => db.close());

  Widget harness({bool isPrivate = false, int? accountId}) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      privacyModeProvider.overrideWith((ref) => isPrivate),
    ],
    child: MaterialApp(home: ClassificationWizardScreen(accountId: accountId)),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  // Unmount the screen and drain the drift stream-query timer so the
  // post-test "Timer is still pending" invariant doesn't trip.
  Future<void> teardownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('shows the biggest group first with progress and similar count', (tester) async {
    await tester.pumpWidget(harness());
    await settle(tester);
    // Progress is money explained (base currency), rows are secondary.
    expect(find.text('0.00 of 68.00 EUR classified (0%)'), findsOneWidget);
    expect(find.text('0 of 4 transactions'), findsOneWidget);
    expect(find.byKey(const Key('wizardCounterparty')), findsOneWidget);
    expect(find.text('Esselunga'), findsWidgets);
    expect(find.text('Merchant: ESSELUNGA'), findsOneWidget, reason: 'the computed key a merchant rule will match on');
    expect(find.text('2 other similar transactions'), findsOneWidget);
    // The money this decision explains.
    expect(find.text('You are classifying 3 transactions worth 60.00 EUR'), findsOneWidget);
    // Apply is disabled until a category is picked.
    expect(tester.widget<FilledButton>(find.byKey(const Key('wizardApply'))).onPressed, isNull);
    await teardownTree(tester);
  });

  testWidgets('skip moves to the next group; restart brings it back', (tester) async {
    await tester.pumpWidget(harness());
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('wizardSkip')));
    await tester.tap(find.byKey(const Key('wizardSkip')));
    await settle(tester);
    expect(find.text('Pizzikotto'), findsWidgets);
    expect(find.text('No other similar transactions'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('wizardSkip')));
    await tester.tap(find.byKey(const Key('wizardSkip')));
    await settle(tester);
    expect(find.text('Restart'), findsOneWidget);
    await tester.ensureVisible(find.text('Restart'));
    await tester.tap(find.text('Restart'));
    await settle(tester);
    expect(find.text('Esselunga'), findsWidgets);
    await teardownTree(tester);
  });

  testWidgets('apply creates a merchant rule, classifies all rows of the group, undo reverts', (tester) async {
    await tester.pumpWidget(harness());
    await settle(tester);

    // Pick a category via the picker sheet.
    await tester.tap(find.byKey(const Key('wizardPickCategory')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('categoryPickerSearch')), 'Grocer');
    await settle(tester);
    await tester.tap(find.text('Groceries').last);
    await settle(tester);

    await tester.ensureVisible(find.byKey(const Key('wizardApply')));
    await tester.tap(find.byKey(const Key('wizardApply')));
    await settle(tester);

    final rules = await db.select(db.autoCategorizationRules).get();
    expect(rules, hasLength(1));
    expect(rules.single.matchType, RuleMatchType.merchantKey);
    expect(rules.single.pattern, 'ESSELUNGA');
    final groceries = await (db.select(db.categories)..where((c) => c.key.equals('groceries'))).getSingle();
    expect(rules.single.categoryId, groceries.id);

    final txs = await db.select(db.transactions).get();
    expect(txs.where((t) => t.categoryId == groceries.id), hasLength(3));
    expect(find.text('60.00 of 68.00 EUR classified (88%)'), findsOneWidget);
    expect(find.text('3 of 4 transactions'), findsOneWidget);
    // Queue advanced to the next group.
    expect(find.text('Pizzikotto'), findsWidgets);
    // Recent chip now offers Groceries directly.
    expect(find.byKey(ValueKey('recentCat_${groceries.id}')), findsOneWidget);

    // Undo: rule deleted, rows uncategorized again.
    await tester.tap(find.byTooltip('Undo last'));
    await settle(tester);
    expect(await db.select(db.autoCategorizationRules).get(), isEmpty);
    expect((await db.select(db.transactions).get()).every((t) => t.categoryId == null), isTrue);
    expect(find.text('0.00 of 68.00 EUR classified (0%)'), findsOneWidget);
    await teardownTree(tester);
  });

  testWidgets('"only this transaction" sets the category without a rule', (tester) async {
    await tester.pumpWidget(harness());
    await settle(tester);
    await tester.tap(find.byKey(const Key('wizardPickCategory')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('categoryPickerSearch')), 'Grocer');
    await settle(tester);
    await tester.tap(find.text('Groceries').last);
    await settle(tester);
    await tester.ensureVisible(find.text('Only this transaction'));
    await tester.tap(find.text('Only this transaction'));
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('wizardApply')));
    await tester.tap(find.byKey(const Key('wizardApply')));
    await settle(tester);
    expect(await db.select(db.autoCategorizationRules).get(), isEmpty);
    final txs = await db.select(db.transactions).get();
    expect(txs.where((t) => t.categoryId != null), hasLength(1));
    // The newest Esselunga row (May) is the one shown and categorized.
    expect(txs.singleWhere((t) => t.categoryId != null).valueDate, DateTime(2024, 5, 1));
    expect(find.text('2 other similar transactions'), findsNothing);
    expect(find.text('1 other similar transaction'), findsOneWidget);
    await teardownTree(tester);
  });

  testWidgets('a new category can be created inline from the picker and from the "New" chip', (tester) async {
    await tester.pumpWidget(harness());
    await settle(tester);

    // Picker: search for something that does not exist → "Create "Pets"".
    await tester.tap(find.byKey(const Key('wizardPickCategory')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('categoryPickerSearch')), 'Pets');
    await settle(tester);
    expect(find.text('Create "Pets"'), findsOneWidget);
    await tester.tap(find.byKey(const Key('categoryPickerNew')));
    await settle(tester);
    expect(tester.widget<TextField>(find.byKey(const Key('categoryNameField'))).controller!.text, 'Pets');
    await tester.tap(find.byKey(const Key('categorySave')));
    await settle(tester);
    final pets = await (db.select(db.categories)..where((c) => c.name.equals('Pets'))).getSingle();
    // Created AND selected in one go.
    expect(find.text('Pets'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('wizardApply'))).onPressed, isNotNull);

    // Direct chip.
    await tester.tap(find.byKey(const Key('wizardNewCategory')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('categoryNameField')), 'Kids');
    await settle(tester);
    await tester.tap(find.byKey(const Key('categorySave')));
    await settle(tester);
    expect(find.text('Kids'), findsOneWidget);
    expect(find.text('Pets'), findsNothing, reason: 'selection moved to the newly created category');
    expect(pets.type, CategoryType.expense);
    await teardownTree(tester);
  });

  testWidgets('transfer pairs and cancelled rows are not queued and are reported as excluded', (tester) async {
    final acctB = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Card'));
    final d = DateTime(2024, 6, 1);
    await tx('To my card', -900, date: d);
    final n = TransactionClassifierService.normalize(description: 'Top-up', amount: 900);
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: acctB,
            operationDate: d,
            valueDate: d,
            amount: 900,
            description: const Value('Top-up'),
            merchantKey: Value(n.merchantKey),
            status: const Value(TransactionStatus.settled),
          ),
        );
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: acct,
            operationDate: d,
            valueDate: d,
            amount: -5000,
            description: const Value('Cancelled thing'),
            merchantKey: const Value('CANCELLEDTHING'),
            status: const Value(TransactionStatus.cancelled),
          ),
        );
    await tester.pumpWidget(harness());
    await settle(tester);
    // 4 participating rows (3 Esselunga + 1 Pizzikotto); the 3 explained rows — and their money — are out.
    expect(find.text('0.00 of 68.00 EUR classified (0%)'), findsOneWidget);
    expect(find.byKey(const Key('wizardExcludedNote')), findsOneWidget);
    expect(find.textContaining('3 entries do not take part'), findsOneWidget);
    // The biggest-by-amount transfer never shows up as a group; Esselunga still leads.
    expect(find.text('Esselunga'), findsWidgets);
    expect(find.text('To my card'), findsNothing);
    expect(find.text('Cancelled thing'), findsNothing);
    await teardownTree(tester);
  });

  testWidgets('groups are ordered by the money they explain, not by how many rows they have', (tester) async {
    // One 500 EUR row outweighs three Esselunga rows worth 60 in total.
    await tx('Dentist', -500);
    await tester.pumpWidget(harness());
    await settle(tester);
    expect(find.text('Dentist'), findsWidgets);
    expect(find.text('You are classifying 500.00 EUR'), findsOneWidget);
    expect(find.text('0.00 of 568.00 EUR classified (0%)'), findsOneWidget);
    await teardownTree(tester);
  });

  testWidgets('all-done card when nothing is uncategorized', (tester) async {
    final groceries = await (db.select(db.categories)..where((c) => c.key.equals('groceries'))).getSingle();
    await db.update(db.transactions).write(TransactionsCompanion(categoryId: Value(groceries.id)));
    await tester.pumpWidget(harness());
    await settle(tester);
    expect(find.byKey(const Key('wizardDone')), findsOneWidget);
    expect(find.text('68.00 of 68.00 EUR classified (100%)'), findsOneWidget);
    await teardownTree(tester);
  });

  testWidgets('privacy mode masks the amount but keeps merchant, counts and progress visible', (tester) async {
    await tester.pumpWidget(harness(isPrivate: true));
    await settle(tester);
    // Masked: the amount (position size).
    final amount = find.byKey(const Key('wizardAmount'));
    expect(amount, findsOneWidget);
    expect(find.descendant(of: amount, matching: find.byType(ImageFiltered)), findsOneWidget);
    // Masked too: the money progress and the group total (position size).
    expect(find.descendant(of: find.byKey(const Key('wizardProgress')), matching: find.byType(ImageFiltered)), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('wizardGroupTotal')), matching: find.byType(ImageFiltered)), findsOneWidget);
    // Visible, in the same test: merchant label, similar count, row counts.
    expect(find.text('Esselunga'), findsWidgets);
    expect(find.text('2 other similar transactions'), findsOneWidget);
    expect(find.text('0 of 4 transactions'), findsOneWidget);
    expect(find.ancestor(of: find.byKey(const Key('wizardCounterparty')), matching: find.byType(ImageFiltered)), findsNothing);
    expect(find.ancestor(of: find.byKey(const Key('wizardProgressRows')), matching: find.byType(ImageFiltered)), findsNothing);
    await teardownTree(tester);
  });
}
