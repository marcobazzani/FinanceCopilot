// The classification card and wizard:
// - a card whose group lost its entry kind when recomputed (the "this entry
//   type" scope was picked) falls back to its default scope instead of
//   crashing on the missing kind when applied;
// - when the wizard swaps the card mid-apply (the applied rule classified the
//   group away), the card still reports that it is no longer busy: the
//   wizard used to stay busy, with Undo disabled for good;
// - a failing group stream shows the localized error.
import 'dart:async';

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
import 'package:finance_copilot/ui/screens/classification/transaction_classify_card.dart';

/// Holds the second uncategorizedIds() call — the one after the rule was
/// applied — until [hold] completes, when set.
class _HeldClassifier extends TransactionClassifierService {
  _HeldClassifier(super.db);

  /// Created by the test body, so that completing it wakes the held call in
  /// the test's own (fake-async) zone.
  Completer<void>? hold;
  var _calls = 0;

  @override
  Future<Set<int>> uncategorizedIds() async {
    final held = hold;
    if (held != null && ++_calls == 2) await held.future;
    return super.uncategorizedIds();
  }
}

void main() {
  late AppDatabase db;
  late int acct;

  Future<Transaction> tx(String desc, double amount, {DateTime? date}) async {
    final d = date ?? DateTime(2024, 3, 10);
    final n = TransactionClassifierService.normalize(description: desc, amount: amount);
    final id = await db
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
    return (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    acct = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
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

  Future<void> pickGroceries(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('wizardPickCategory')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('categoryPickerSearch')), 'Grocer');
    await settle(tester);
    await tester.tap(find.text('Groceries').last);
    await settle(tester);
  }

  MerchantGroup group(Transaction t, {required BankEntryKind? entryKind}) => MerchantGroup(
    merchantKey: t.merchantKey!,
    counterparty: t.counterparty,
    entryKind: entryKind,
    count: 1,
    totalByCurrency: {t.currency: t.amount.abs()},
    firstDate: t.valueDate,
    lastDate: t.valueDate,
    accountIds: {t.accountId},
    latestTransactionId: t.id,
  );

  testWidgets('a group that lost its entry kind applies with the default scope instead of crashing', (tester) async {
    final t = await tx('Esselunga', -20);
    var g = group(t, entryKind: BankEntryKind.cardPayment);
    late StateSetter setGroup;
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  setGroup = setState;
                  return TransactionClassifyCard(key: const ValueKey('card'), group: g, samples: [t]);
                },
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    try {
      await tester.tap(find.text('This entry type'));
      await settle(tester);
      // Recomputed without the kind (same merchant, so the same card state).
      setGroup(() => g = group(t, entryKind: null));
      await settle(tester);
      expect(find.text('This entry type'), findsNothing);

      await pickGroceries(tester);
      await tester.ensureVisible(find.byKey(const Key('wizardApply')));
      await tester.tap(find.byKey(const Key('wizardApply')));
      await settle(tester);

      expect(tester.takeException(), isNull);
      final rule = (await db.select(db.autoCategorizationRules).get()).single;
      expect(rule.matchType, RuleMatchType.merchantKey);
      expect(rule.pattern, 'ESSELUNGA');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a card swapped away mid-apply still releases the wizard: Undo stays usable', (tester) async {
    await tx('Esselunga', -20);
    await tx('Esselunga', -30, date: DateTime(2024, 4, 1));
    await tx('Pizzikotto', -8);
    final classifier = _HeldClassifier(db);
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          privacyModeProvider.overrideWith((ref) => false),
          transactionClassifierServiceProvider.overrideWithValue(classifier),
        ],
        child: const MaterialApp(home: ClassificationWizardScreen()),
      ),
    );
    await settle(tester);
    try {
      expect(find.text('Merchant: ESSELUNGA'), findsOneWidget);
      await pickGroceries(tester);
      final release = classifier.hold = Completer<void>();
      await tester.ensureVisible(find.byKey(const Key('wizardApply')));
      await tester.tap(find.byKey(const Key('wizardApply')));
      await settle(tester);
      // The rule classified the Esselunga rows: the wizard moved on while the
      // card's apply is still finishing.
      expect(find.text('Merchant: PIZZIKOTTO'), findsOneWidget);

      release.complete();
      await settle(tester);
      final undo = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo));
      expect(undo.onPressed, isNotNull, reason: 'the wizard stayed busy after the card went away');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a failing group stream shows the localized error', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          privacyModeProvider.overrideWith((ref) => false),
          uncategorizedGroupsProvider.overrideWith((ref, accountId) => Stream<List<MerchantGroup>>.error(StateError('boom'))),
        ],
        child: const MaterialApp(home: ClassificationWizardScreen()),
      ),
    );
    await settle(tester);
    try {
      expect(find.text('Error: Bad state: boom'), findsOneWidget);
    } finally {
      await unmount(tester);
    }
  });
}
