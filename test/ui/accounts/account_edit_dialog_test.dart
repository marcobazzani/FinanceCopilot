// Account detail → Edit account:
// - the dialog owns its text controllers: closing it with a field focused
//   used to dispose them while the closing animation still rebuilt the
//   fields ("A TextEditingController was used after being disposed");
// - the screen follows the live account row: after an edit the title and the
//   amounts' currency are the saved ones, and reopening the dialog starts from
//   them — it used to start from the row the screen was opened with, so a
//   second save silently reverted the first edit.
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

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final id = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main', currency: const Value('EUR')));
    account = await (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingle();
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: id,
            operationDate: DateTime(2026, 1, 10),
            valueDate: DateTime(2026, 1, 10),
            amount: -42.5,
            description: const Value('Groceries'),
          ),
        );
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpAccount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
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

  Finder dialogField(String label) => find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(TextField, label));

  String fieldText(WidgetTester tester, String label) => tester.widget<TextField>(dialogField(label)).controller!.text;

  Future<void> openEdit(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Edit Account'));
    await settle(tester);
    expect(find.widgetWithText(AlertDialog, 'Edit Account'), findsOneWidget);
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
  }

  Future<Account> reload() => (db.select(db.accounts)..where((a) => a.id.equals(account.id))).getSingle();

  testWidgets('saving with a focused field closes the dialog cleanly', (tester) async {
    await pumpAccount(tester);
    try {
      await openEdit(tester);
      await tester.enterText(dialogField('Name'), 'Checking');
      await tapSave(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect((await reload()).name, 'Checking');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('cancelling with a focused field closes the dialog cleanly and saves nothing', (tester) async {
    await pumpAccount(tester);
    try {
      await openEdit(tester);
      await tester.enterText(dialogField('Institution'), 'Bank');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect((await reload()).institution, '');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('after an edit the title shows the saved name and reopening edit starts from it', (tester) async {
    await pumpAccount(tester);
    try {
      await openEdit(tester);
      await tester.enterText(dialogField('Name'), 'Checking');
      await tapSave(tester);

      expect(find.descendant(of: find.byType(AppBar), matching: find.text('Checking')), findsOneWidget);
      expect(find.descendant(of: find.byType(AppBar), matching: find.text('Main')), findsNothing);

      await openEdit(tester);
      expect(fieldText(tester, 'Name'), 'Checking', reason: 'the dialog starts from the saved row, not the opened one');
      await tapSave(tester);
      expect((await reload()).name, 'Checking', reason: 'saving again must not revert the first edit');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a currency change reaches the amounts and the next edit', (tester) async {
    await pumpAccount(tester);
    try {
      Finder rowAmount(String text) => find.descendant(of: find.widgetWithText(ListTile, 'Groceries'), matching: find.text(text));
      expect(rowAmount('-EUR42.50'), findsOneWidget);
      await openEdit(tester);
      await tester.enterText(dialogField('Currency'), 'USD');
      await tapSave(tester);

      expect(rowAmount('-USD42.50'), findsOneWidget, reason: 'amounts are formatted in the saved currency');
      await openEdit(tester);
      expect(fieldText(tester, 'Currency'), 'USD');
    } finally {
      await unmount(tester);
    }
  });
}
