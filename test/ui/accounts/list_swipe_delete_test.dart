// Swipe-to-delete on the Accounts screen lists (accounts, an account's
// transactions, income, adjustments): a swiped row asks with the entity's own
// delete confirmation — the one its detail view's trashcan asks — Cancel keeps
// it, Delete removes it through the same service call as that trashcan.
//
// In the ledger only a plain transaction row swipes (and the legs of an
// expanded no-op pair, which are the same transaction rows): the collapsed
// pair row and the synthetic "Saving for" rows do not, and the read-only
// All-accounts view has no swipe at all.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/domain/extraordinary_event_service.dart';
import 'package:finance_copilot/services/domain/income_service.dart';
import 'package:finance_copilot/services/domain/transaction_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/accounts/account_detail_screen.dart';
import 'package:finance_copilot/ui/screens/accounts/accounts_screen.dart';
import 'package:finance_copilot/ui/screens/accounts/capex_screen.dart';
import 'package:finance_copilot/ui/screens/accounts/income_screen.dart';

/// Records the deletes it is asked for: the ledger's swipe must go through
/// the service call the transaction's own trashcan uses (it recomputes the
/// account's balances).
class _RecordingTransactionService extends TransactionService {
  _RecordingTransactionService(super.db);

  final deleted = <int>[];

  @override
  Future<int> delete(int id) {
    deleted.add(id);
    return super.delete(id);
  }
}

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

  Future<void> pump(WidgetTester tester, Widget home, {List<Override> overrides = const []}) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          privacyModeProvider.overrideWith((ref) => false),
          ...overrides,
        ],
        child: MaterialApp(home: home),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> swipe(WidgetTester tester, Finder row) async {
    await tester.drag(row, const Offset(-900, 0));
    await settle(tester);
  }

  /// The open confirmation: its title, its message and a red Delete.
  void expectConfirm(WidgetTester tester, {required String title, required String content}) {
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget, reason: 'a swipe asks first');
    final alert = tester.widget<AlertDialog>(dialog);
    expect((alert.title! as Text).data, title);
    expect((alert.content! as Text).data, content);
    final confirm = tester.widget<FilledButton>(find.descendant(of: dialog, matching: find.widgetWithText(FilledButton, s.delete)));
    expect(confirm.style?.backgroundColor?.resolve({}), Colors.red);
  }

  Future<void> cancel(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextButton, s.cancel));
    await settle(tester);
  }

  Future<void> confirmDelete(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, s.delete));
    await settle(tester);
  }

  Future<int> tx(int account, DateTime day, double amount, String desc) => db
      .into(db.transactions)
      .insert(TransactionsCompanion.insert(accountId: account, operationDate: day, valueDate: day, amount: amount, description: Value(desc)));

  Future<Account> account(int id) => (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingle();

  bool swipeable(Finder row) => find.ancestor(of: row, matching: find.byType(Dismissible)).evaluate().isNotEmpty;

  testWidgets('accounts: a swiped account asks like its trashcan; Cancel keeps it, Delete removes it with its transactions', (tester) async {
    final main = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Other'));
    await tx(main, DateTime(2026, 1, 15), -20, 'Coffee');
    await pump(tester, const AccountsScreen());
    try {
      await swipe(tester, find.text('Main'));
      expectConfirm(tester, title: s.deleteAccountTitle, content: s.deleteAccountConfirm('Main'));
      await cancel(tester);
      expect(find.text('Main'), findsOneWidget, reason: 'the row comes back');
      expect(await db.select(db.accounts).get(), hasLength(2));

      await swipe(tester, find.text('Main'));
      await confirmDelete(tester);
      expect((await db.select(db.accounts).get()).map((a) => a.name), ['Other']);
      expect(await db.select(db.transactions).get(), isEmpty, reason: 'deleted with its transactions, as from its detail view');
      expect(find.text('Main'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('accounts: a long press still starts the multi-selection', (tester) async {
    await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    await pump(tester, const AccountsScreen());
    try {
      await tester.longPress(find.text('Main'));
      await settle(tester);
      expect(find.text(s.nSelected(1)), findsOneWidget);
    } finally {
      await unmount(tester);
    }
  });

  group('ledger', () {
    testWidgets('a swiped transaction asks like its trashcan; Cancel keeps it, Delete removes it through the service', (tester) async {
      final main = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
      final coffee = await tx(main, DateTime(2026, 1, 15), -20, 'Coffee');
      await tx(main, DateTime(2026, 1, 16), -30, 'Lunch');
      final service = _RecordingTransactionService(db);
      await pump(tester, AccountDetailScreen(account: await account(main)), overrides: [transactionServiceProvider.overrideWithValue(service)]);
      try {
        await swipe(tester, find.text('Coffee'));
        expectConfirm(tester, title: s.deleteTransactionTitle, content: s.cannotBeUndone);
        await cancel(tester);
        expect(find.text('Coffee'), findsOneWidget);
        expect(service.deleted, isEmpty);

        await swipe(tester, find.text('Coffee'));
        await confirmDelete(tester);
        expect(service.deleted, [coffee]);
        expect((await db.select(db.transactions).get()).map((t) => t.description), ['Lunch']);
        expect(find.text('Coffee'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a collapsed no-op pair does not swipe; its expanded legs are transaction rows and do', (tester) async {
      final main = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
      await tx(main, DateTime(2026, 1, 15), 80, 'Reversed charge in');
      await tx(main, DateTime(2026, 1, 15), -80, 'Reversed charge out');
      await pump(tester, AccountDetailScreen(account: await account(main)));
      try {
        expect(swipeable(find.text(s.noOpLabel)), isFalse);
        await swipe(tester, find.text(s.noOpLabel));
        expect(find.byType(AlertDialog), findsNothing);

        await tester.tap(find.text(s.noOpLabel));
        await settle(tester);
        expect(swipeable(find.text('Reversed charge out')), isTrue);
        expect(swipeable(find.text('Reversed charge in')), isTrue);

        // Deleting a leg leaves the other one as a plain row.
        await swipe(tester, find.text('Reversed charge out'));
        expectConfirm(tester, title: s.deleteTransactionTitle, content: s.cannotBeUndone);
        await confirmDelete(tester);
        expect((await db.select(db.transactions).get()).map((t) => t.description), ['Reversed charge in']);
        expect(find.text(s.noOpLabel), findsNothing);
        expect(find.text('Reversed charge in'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('the read-only All-accounts view swipes nothing: plain rows, transfers or saving rows', (tester) async {
      final main = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
      final savings = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Savings'));
      await tx(main, DateTime(2026, 1, 20), -20, 'Coffee');
      await tx(main, DateTime(2026, 1, 15), -100, 'To savings');
      await tx(savings, DateTime(2026, 1, 15), 100, 'From main');
      final events = ExtraordinaryEventService(db);
      final car = await events.create(
        name: 'Car',
        direction: EventDirection.outflow,
        treatment: EventTreatment.spread,
        totalAmount: 1200,
        currency: 'EUR',
        eventDate: DateTime(2026, 1, 1),
        stepFrequency: StepFrequency.monthly,
        spreadStart: DateTime(2025, 1, 1),
        spreadEnd: DateTime(2025, 12, 1),
      );
      await events.generateScheduledEntries(car);
      await pump(tester, AccountDetailScreen(account: buildAllAccountsVirtual('All accounts')));
      try {
        expect(find.text('Coffee'), findsOneWidget);
        expect(find.text(s.transferLabel), findsOneWidget);
        expect(find.text(s.savingForLabel('Car')), findsWidgets);
        expect(find.byType(Dismissible), findsNothing);
      } finally {
        await unmount(tester);
      }
    });
  });

  group('income', () {
    testWidgets('a swiped income asks like its edit form\'s delete; Cancel keeps it, Delete removes it', (tester) async {
      await IncomeService(db).create(date: DateTime(2026, 3, 1), amount: 500, currency: 'EUR');
      await IncomeService(db).create(date: DateTime(2026, 2, 1), amount: 300, currency: 'EUR');
      await pump(tester, const IncomeScreen());
      try {
        await swipe(tester, find.textContaining('500.00'));
        final dialog = find.byType(AlertDialog);
        expect(dialog, findsOneWidget, reason: 'a swipe asks first');
        expect(find.descendant(of: dialog, matching: find.text(s.deleteIncomeTitle)), findsOneWidget);
        expect(find.descendant(of: dialog, matching: find.text(s.deleteIncomeConfirm('500.00', 'EUR', '3/1/2026'))), findsOneWidget);
        await cancel(tester);
        expect(find.textContaining('500.00'), findsOneWidget);
        expect(await db.select(db.incomes).get(), hasLength(2));

        await swipe(tester, find.textContaining('500.00'));
        await confirmDelete(tester);
        expect((await db.select(db.incomes).get()).map((i) => i.amount), [300]);
        expect(find.textContaining('500.00'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a long press still starts the multi-selection', (tester) async {
      await IncomeService(db).create(date: DateTime(2026, 3, 1), amount: 500, currency: 'EUR');
      await pump(tester, const IncomeScreen());
      try {
        await tester.longPress(find.textContaining('500.00'));
        await settle(tester);
        expect(find.text(s.nSelected(1)), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });
  });

  testWidgets('adjustments: a swiped adjustment asks like its trashcan; Cancel keeps it, Delete removes it with its entries', (tester) async {
    final events = ExtraordinaryEventService(db);
    final bonus = await events.create(
      name: 'Bonus',
      direction: EventDirection.inflow,
      treatment: EventTreatment.instant,
      totalAmount: 5000,
      currency: 'EUR',
      eventDate: DateTime(2026, 1, 5),
    );
    await events.addManualEntry(eventId: bonus, date: DateTime(2026, 1, 20), amount: 75);
    await pump(tester, const AdjustmentsView());
    try {
      await swipe(tester, find.text('Bonus'));
      expectConfirm(tester, title: s.deleteAdjustmentTitle, content: s.deleteAdjustmentConfirm('Bonus'));
      await cancel(tester);
      expect(find.text('Bonus'), findsOneWidget);
      expect(await db.select(db.extraordinaryEvents).get(), hasLength(1));

      await swipe(tester, find.text('Bonus'));
      await confirmDelete(tester);
      expect(await db.select(db.extraordinaryEvents).get(), isEmpty);
      expect(await db.select(db.extraordinaryEventEntries).get(), isEmpty);
      expect(find.text('Bonus'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await unmount(tester);
    }
  });
}
