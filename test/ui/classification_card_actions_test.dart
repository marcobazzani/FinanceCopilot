// The classification card's actions: an outlined Skip (skip icon) before a
// filled Apply (check icon), keyed wizardSkip / wizardApply. Apply is off
// until a category is picked; while it runs, its icon is a progress indicator
// and both buttons are off. The card is a wizard step: its actions sit in the
// shared wizard navbar, like the import wizard's.
import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/classification/transaction_classifier_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/classification/transaction_classify_card.dart';
import 'package:finance_copilot/ui/widgets/wizard_nav_bar.dart';

/// Holds setCategory until [hold] completes, when set.
class _HeldClassifier extends TransactionClassifierService {
  _HeldClassifier(super.db);

  /// Created by the test body, so that completing it wakes the held call in
  /// the test's own (fake-async) zone.
  Completer<void>? hold;

  @override
  Future<int> setCategory(Iterable<int> ids, int? categoryId) async {
    final held = hold;
    if (held != null) await held.future;
    return super.setCategory(ids, categoryId);
  }
}

void main() {
  const s = AppStrings.en;
  late AppDatabase db;
  late Transaction tx;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final acct = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    final n = TransactionClassifierService.normalize(description: 'Esselunga', amount: -20);
    final id = await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: acct,
            operationDate: DateTime(2024, 3, 10),
            valueDate: DateTime(2024, 3, 10),
            amount: -20,
            description: const Value('Esselunga'),
            merchantKey: Value(n.merchantKey),
            counterparty: Value(n.counterparty),
            entryKind: Value(n.entryKind),
          ),
        );
    tx = await (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  MerchantGroup group() => MerchantGroup(
    merchantKey: tx.merchantKey!,
    counterparty: tx.counterparty,
    entryKind: tx.entryKind,
    count: 1,
    totalByCurrency: {tx.currency: tx.amount.abs()},
    firstDate: tx.valueDate,
    lastDate: tx.valueDate,
    accountIds: {tx.accountId},
    latestTransactionId: tx.id,
  );

  Future<void> pumpCard(WidgetTester tester, {VoidCallback? onSkip, TransactionClassifierService? classifier}) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          privacyModeProvider.overrideWith((ref) => false),
          if (classifier != null) transactionClassifierServiceProvider.overrideWithValue(classifier),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TransactionClassifyCard(key: const ValueKey('card'), group: group(), samples: [tx], onSkip: onSkip),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> pickGroceries(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('wizardPickCategory')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('categoryPickerSearch')), 'Grocer');
    await settle(tester);
    await tester.tap(find.text('Groceries').last);
    await settle(tester);
  }

  Finder skip() => find.byKey(const Key('wizardSkip'));
  Finder apply() => find.byKey(const Key('wizardApply'));
  bool enabled(WidgetTester tester, Finder button) => tester.widget<ButtonStyleButton>(button).onPressed != null;

  testWidgets('an outlined Skip before a filled Apply; Apply comes on with a category; Skip skips', (tester) async {
    var skipped = 0;
    await pumpCard(tester, onSkip: () => skipped++);
    try {
      expect(tester.widget(skip()), isA<OutlinedButton>());
      expect(find.descendant(of: skip(), matching: find.text(s.wizardSkip)), findsOneWidget);
      expect(find.descendant(of: skip(), matching: find.byIcon(Icons.skip_next)), findsOneWidget);
      expect(tester.widget(apply()), isA<FilledButton>());
      expect(find.descendant(of: apply(), matching: find.text(s.wizardApply)), findsOneWidget);
      expect(find.descendant(of: apply(), matching: find.byIcon(Icons.check)), findsOneWidget);
      expect(tester.getTopRight(skip()).dx, lessThan(tester.getTopLeft(apply()).dx), reason: 'Skip comes first');

      expect(enabled(tester, skip()), isTrue);
      expect(enabled(tester, apply()), isFalse, reason: 'no category picked yet');
      await pickGroceries(tester);
      expect(enabled(tester, apply()), isTrue);

      await tester.tap(skip());
      await settle(tester);
      expect(skipped, 1);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('while Apply runs, its icon is a progress indicator and both buttons are off', (tester) async {
    final classifier = _HeldClassifier(db);
    await pumpCard(tester, onSkip: () {}, classifier: classifier);
    try {
      await pickGroceries(tester);
      await tester.tap(find.text(s.wizardScopeOnlyThis));
      await settle(tester);
      final release = classifier.hold = Completer<void>();
      await tester.tap(apply());
      await settle(tester);

      expect(find.descendant(of: apply(), matching: find.byType(CircularProgressIndicator)), findsOneWidget);
      expect(find.descendant(of: apply(), matching: find.byIcon(Icons.check)), findsNothing);
      expect(enabled(tester, apply()), isFalse);
      expect(enabled(tester, skip()), isFalse);

      release.complete();
      await settle(tester);
      expect(find.descendant(of: apply(), matching: find.byIcon(Icons.check)), findsOneWidget);
      expect(enabled(tester, apply()), isTrue);
      expect(enabled(tester, skip()), isTrue);
      expect((await (db.select(db.transactions)..where((t) => t.id.equals(tx.id))).getSingle()).categoryId, isNotNull);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('the actions sit in the shared wizard navbar', (tester) async {
    await pumpCard(tester, onSkip: () {});
    try {
      final bar = find.ancestor(of: apply(), matching: find.byType(WizardNavBar));
      expect(bar, findsOneWidget);
      expect(find.descendant(of: bar, matching: skip()), findsOneWidget);
    } finally {
      await unmount(tester);
    }
  });
}
