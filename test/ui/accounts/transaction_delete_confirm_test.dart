// A transaction is deleted from two places — its edit screen's trashcan and
// the ledger row's swipe — and both ask the same confirmation: "Delete
// Transaction?", "This cannot be undone.", Cancel and a red Delete. Cancel
// keeps the row; Delete removes it through the transaction service (which
// recomputes the account's balances) and logs it. The trashcan then leaves
// the edit screen for the ledger.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:logging/logging.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/domain/transaction_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/accounts/account_detail_screen.dart';
import 'package:finance_copilot/ui/screens/events/transaction_edit_screen.dart';

/// Records the deletes it is asked for.
class _RecordingTransactionService extends TransactionService {
  _RecordingTransactionService(super.db);

  final deleted = <int>[];

  @override
  Future<int> delete(int id) {
    deleted.add(id);
    return super.delete(id);
  }
}

/// What a confirmation shows: title, message, cancel and confirm labels, and
/// the confirm button's colour.
typedef _Confirmation = (String?, String?, String?, String?, Color?);

void main() {
  const s = AppStrings.en;
  late AppDatabase db;
  late _RecordingTransactionService service;
  late Account main;
  late int coffee;
  late List<LogRecord> warnings;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = _RecordingTransactionService(db);
    final id = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    main = await (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingle();
    Future<int> tx(DateTime day, double amount, String desc) => db
        .into(db.transactions)
        .insert(TransactionsCompanion.insert(accountId: id, operationDate: day, valueDate: day, amount: amount, description: Value(desc)));
    coffee = await tx(DateTime(2026, 1, 15), -20, 'Coffee');
    await tx(DateTime(2026, 1, 16), -30, 'Lunch');
    warnings = [];
    final sub = Logger.root.onRecord.where((r) => r.level == Level.WARNING).listen(warnings.add);
    addTearDown(sub.cancel);
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpLedger(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          privacyModeProvider.overrideWith((ref) => false),
          transactionServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(home: AccountDetailScreen(account: main)),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<List<String>> descriptions() async => [for (final t in await db.select(db.transactions).get()) t.description];

  /// The UI's own delete lines (the service logs its own as well).
  List<String> uiDeleteLogs() => [
    for (final r in warnings)
      if (r.message.startsWith('deleting transaction')) r.message,
  ];

  Future<void> openEditScreen(WidgetTester tester) async {
    await tester.tap(find.text('Coffee'));
    await settle(tester);
    expect(find.byType(TransactionEditScreen), findsOneWidget);
  }

  Future<void> tapTrashcan(WidgetTester tester) async {
    await tester.tap(find.descendant(of: find.byType(TransactionEditScreen), matching: find.byIcon(Icons.delete_outline)));
    await settle(tester);
  }

  Future<void> swipeCoffee(WidgetTester tester) async {
    await tester.drag(find.text('Coffee'), const Offset(-900, 0));
    await settle(tester);
  }

  _Confirmation openConfirmation(WidgetTester tester) {
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget, reason: 'a delete asks first');
    final alert = tester.widget<AlertDialog>(dialog);
    final cancel = tester.widget<TextButton>(find.descendant(of: dialog, matching: find.byType(TextButton)));
    final confirm = tester.widget<FilledButton>(find.descendant(of: dialog, matching: find.byType(FilledButton)));
    return (
      (alert.title! as Text).data,
      (alert.content! as Text).data,
      (cancel.child! as Text).data,
      (confirm.child! as Text).data,
      confirm.style?.backgroundColor?.resolve({}),
    );
  }

  const expected = ('Delete Transaction?', 'This cannot be undone.', 'Cancel', 'Delete', Colors.red);

  Future<void> tapCancel(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextButton, s.cancel));
    await settle(tester);
  }

  Future<void> tapDelete(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, s.delete));
    await settle(tester);
  }

  group('pinned', () {
    testWidgets('the trashcan asks; Cancel keeps the row and the screen; Delete removes it, logs it and goes back to the ledger', (
      tester,
    ) async {
      await pumpLedger(tester);
      try {
        await openEditScreen(tester);
        await tapTrashcan(tester);
        expect(openConfirmation(tester), expected);
        await tapCancel(tester);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(TransactionEditScreen), findsOneWidget, reason: 'Cancel stays on the edit screen');
        expect(service.deleted, isEmpty);
        expect(await descriptions(), ['Coffee', 'Lunch']);
        expect(uiDeleteLogs(), isEmpty);

        await tapTrashcan(tester);
        await tapDelete(tester);
        expect(service.deleted, [coffee]);
        expect(await descriptions(), ['Lunch']);
        expect(uiDeleteLogs(), ['deleting transaction id=$coffee']);
        expect(find.byType(TransactionEditScreen), findsNothing, reason: 'back to the ledger');
        expect(find.text('Coffee'), findsNothing);
        expect(find.text('Lunch'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('the swipe asks; Cancel slides the row back; Delete removes it through the service', (tester) async {
      await pumpLedger(tester);
      try {
        await swipeCoffee(tester);
        expect(openConfirmation(tester), expected);
        await tapCancel(tester);
        expect(find.text('Coffee'), findsOneWidget);
        expect(service.deleted, isEmpty);

        await swipeCoffee(tester);
        await tapDelete(tester);
        expect(service.deleted, [coffee]);
        expect(await descriptions(), ['Lunch']);
        expect(find.text('Coffee'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('the Italian texts are the same from both', (tester) async {
      await pumpLedger(tester);
      final container = ProviderScope.containerOf(tester.element(find.byType(AccountDetailScreen)));
      container.read(portableLanguageProvider.notifier).state = 'it';
      await settle(tester);
      try {
        const it = AppStrings.it;
        final italian = (it.deleteTransactionTitle, it.cannotBeUndone, it.cancel, it.delete, Colors.red);
        await swipeCoffee(tester);
        expect(openConfirmation(tester), italian);
        await tester.tap(find.widgetWithText(TextButton, it.cancel));
        await settle(tester);

        await openEditScreen(tester);
        await tapTrashcan(tester);
        expect(openConfirmation(tester), italian);
        await tester.tap(find.widgetWithText(TextButton, it.cancel));
        await settle(tester);
        expect(service.deleted, isEmpty);
      } finally {
        await unmount(tester);
      }
    });
  });

  group('one confirm-and-delete', () {
    testWidgets('confirmAndDeleteTransaction: Cancel deletes nothing and says so; Delete deletes, logs and says so', (tester) async {
      final tx = await (db.select(db.transactions)..where((t) => t.id.equals(coffee))).getSingle();
      final results = <bool>[];
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            transactionServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: TextButton(
                  onPressed: () async => results.add(await confirmAndDeleteTransaction(context, ref, tx)),
                  child: const Text('ask'),
                ),
              ),
            ),
          ),
        ),
      );
      try {
        await tester.tap(find.text('ask'));
        await settle(tester);
        expect(openConfirmation(tester), expected);
        await tapCancel(tester);
        expect(results, [false]);
        expect(service.deleted, isEmpty);
        expect(uiDeleteLogs(), isEmpty);

        await tester.tap(find.text('ask'));
        await settle(tester);
        await tapDelete(tester);
        expect(results, [false, true]);
        expect(service.deleted, [coffee]);
        expect(await descriptions(), ['Lunch']);
        expect(uiDeleteLogs(), ['deleting transaction id=$coffee']);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('the swipe logs the delete as the trashcan does', (tester) async {
      await pumpLedger(tester);
      try {
        await swipeCoffee(tester);
        await tapDelete(tester);
        expect(uiDeleteLogs(), ['deleting transaction id=$coffee']);
      } finally {
        await unmount(tester);
      }
    });
  });
}
