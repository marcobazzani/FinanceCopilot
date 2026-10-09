// An account's delete asks one confirmation wherever it starts: the detail
// view's trashcan (pinned here) and the accounts list's swipe
// (list_swipe_delete_test.dart). The message names the account as it is now,
// not as the screen was opened with; Delete is red. Cancel keeps the account;
// Delete removes it with its transactions, and the trashcan then leaves the
// deleted account's screen.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/accounts/account_detail_screen.dart';

void main() {
  const s = AppStrings.en;
  late AppDatabase db;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// An account 'Main' with one transaction, renamed 'Main renamed' once
  /// [opened] was read: the detail screen is opened with a stale snapshot.
  Future<Account> seedRenamedAccount() async {
    final id = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: id,
            operationDate: DateTime(2026, 1, 15),
            valueDate: DateTime(2026, 1, 15),
            amount: -20,
            description: const Value('Coffee'),
          ),
        );
    final opened = await (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingle();
    await (db.update(db.accounts)..where((a) => a.id.equals(id))).write(const AccountsCompanion(name: Value('Main renamed')));
    return opened;
  }

  Future<void> openDetail(WidgetTester tester, Account opened) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => AccountDetailScreen(account: opened))),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    expect(find.byType(AccountDetailScreen), findsOneWidget);
  }

  Future<void> tapTrashcan(WidgetTester tester) async {
    await tester.tap(find.byTooltip(s.tooltipDeleteAccount));
    await settle(tester);
  }

  void expectConfirm(WidgetTester tester, {required String content}) {
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget, reason: 'the trashcan asks first');
    final alert = tester.widget<AlertDialog>(dialog);
    expect((alert.title! as Text).data, s.deleteAccountTitle);
    expect((alert.content! as Text).data, content);
    final confirm = tester.widget<FilledButton>(find.descendant(of: dialog, matching: find.widgetWithText(FilledButton, s.delete)));
    expect(confirm.style?.backgroundColor?.resolve({}), Colors.red);
    expect(find.descendant(of: dialog, matching: find.widgetWithText(TextButton, s.cancel)), findsOneWidget);
  }

  testWidgets('the trashcan asks with the account\'s current name; Cancel keeps it and stays on its screen', (tester) async {
    final opened = await seedRenamedAccount();
    await openDetail(tester, opened);
    try {
      await tapTrashcan(tester);
      expectConfirm(tester, content: s.deleteAccountConfirm('Main renamed'));

      await tester.tap(find.widgetWithText(TextButton, s.cancel));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(AccountDetailScreen), findsOneWidget);
      expect(await db.select(db.accounts).get(), hasLength(1));
      expect(await db.select(db.transactions).get(), hasLength(1));
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('Delete removes the account with its transactions and leaves its screen', (tester) async {
    final opened = await seedRenamedAccount();
    await openDetail(tester, opened);
    try {
      await tapTrashcan(tester);
      await tester.tap(find.widgetWithText(FilledButton, s.delete));
      await settle(tester);

      expect(await db.select(db.accounts).get(), isEmpty);
      expect(await db.select(db.transactions).get(), isEmpty);
      expect(find.byType(AccountDetailScreen), findsNothing, reason: 'the deleted account\'s screen is left');
      expect(find.text('open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await unmount(tester);
    }
  });
}
