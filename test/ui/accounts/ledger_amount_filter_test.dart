// Account ledger → Filters → Amount: the bounds are read in the active
// locale, strictly. Under it_IT "1.000" is one thousand (it used to be read
// as 1.0 by the separator-guessing parser), and text the locale cannot read
// is flagged on its field instead of being applied as some other number.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/accounts/account_detail_screen.dart';

void main() {
  late AppDatabase db;
  late Account account;

  setUpAll(() async => initializeDateFormatting());
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final id = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    account = await (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingle();
    for (final (day, amount, desc) in [(5, 2000.0, 'Salary'), (10, -1500.0, 'Rent'), (12, -20.0, 'Coffee')]) {
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              accountId: id,
              operationDate: DateTime(2026, 1, day),
              valueDate: DateTime(2026, 1, day),
              amount: amount,
              description: Value(desc),
            ),
          );
    }
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpAccount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('it_IT')),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(home: AccountDetailScreen(account: account)),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openAmountDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('ledgerFilterButton')));
    await settle(tester);
    await tester.ensureVisible(find.text('Any amount'));
    await tester.tap(find.text('Any amount'));
    await settle(tester);
    expect(find.widgetWithText(AlertDialog, 'Amount'), findsOneWidget);
  }

  Finder boundField(String label) => find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(TextField, label));

  Future<void> applyDialog(WidgetTester tester) async {
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Apply')));
    await settle(tester);
  }

  testWidgets('"1.000" under it_IT is a thousand', (tester) async {
    await pumpAccount(tester);
    try {
      await openAmountDialog(tester);
      await tester.enterText(boundField('Min'), '1.000');
      await applyDialog(tester);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await settle(tester);

      expect(find.text('Rent'), findsOneWidget);
      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('Coffee'), findsNothing, reason: '20 is below a minimum of 1.000 (it used to be read as 1)');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a bound the locale cannot read is flagged and the dialog stays open', (tester) async {
    await pumpAccount(tester);
    try {
      await openAmountDialog(tester);
      await tester.enterText(boundField('Max'), '1.5');
      await applyDialog(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Invalid number'), findsOneWidget);

      await tester.enterText(boundField('Max'), '100');
      await applyDialog(tester);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await settle(tester);
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('Rent'), findsNothing);
    } finally {
      await unmount(tester);
    }
  });
}
