// The classification card in privacy mode masks the money of a merchant group
// — the group total — but not the count of transactions it stands for: the
// whole "You are classifying N transactions worth X" sentence used to be
// blurred, count included.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/services/classification/transaction_classifier_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/classification/classification_wizard_screen.dart';

void main() {
  late AppDatabase db;
  late int acct;

  Future<int> tx(String desc, double amount, DateTime d) {
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
    await tx('Esselunga', -20, DateTime(2024, 3, 10));
    await tx('Esselunga', -30, DateTime(2024, 4, 1));
    await tx('Esselunga', -10, DateTime(2024, 5, 1));
  });
  tearDown(() => db.close());

  Future<void> pumpWizard(WidgetTester tester, {required bool isPrivate}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          privacyModeProvider.overrideWith((ref) => isPrivate),
        ],
        child: const MaterialApp(home: ClassificationWizardScreen()),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  testWidgets('privacy mode: the group total is masked, the count of transactions is not', (tester) async {
    await pumpWizard(tester, isPrivate: true);
    try {
      final total = find.byKey(const Key('wizardGroupTotal'));
      final amount = find.descendant(of: total, matching: find.text('60.00 EUR'));
      expect(amount, findsOneWidget);
      expect(masked(amount), isTrue, reason: 'the money of the group is a position size');
      final count = find.descendant(of: total, matching: find.textContaining('You are classifying 3 transactions worth ', findRichText: true));
      expect(count, findsOneWidget);
      expect(masked(count), isFalse, reason: 'a count of transactions is shape, not size');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('privacy off: the sentence reads in the clear', (tester) async {
    await pumpWizard(tester, isPrivate: false);
    try {
      expect(find.text('You are classifying 3 transactions worth 60.00 EUR'), findsOneWidget);
      expect(masked(find.text('You are classifying 3 transactions worth 60.00 EUR')), isFalse);
    } finally {
      await unmount(tester);
    }
  });
}
