// The account ledger's collapsed rows:
// - a cross-account transfer (All-accounts view) and a same-account no-op
//   pair render as one expandable row each — swap_horiz / sync_alt icon,
//   label, date (and "from to" for a transfer), the pair amount (struck
//   through for a no-op), both legs on tap;
// - an expanded row stays with its pair: after a search moves another pair
//   into its place, that pair is collapsed (the expanded state used to stay
//   with the list position);
// - a synthetic "Saving for X" row, and the day total it counts in, are in
//   its spread event's currency (they used to be labelled EUR whatever the
//   event's currency).
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/extraordinary_event_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/accounts/account_detail_screen.dart';

void main() {
  late AppDatabase db;
  late int main;
  late int savings;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    main = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    savings = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Savings'));
  });
  tearDown(() => db.close());

  Future<void> tx(int account, DateTime day, double amount, String desc, {String currency = 'EUR'}) => db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          accountId: account,
          operationDate: day,
          valueDate: day,
          amount: amount,
          description: Value(desc),
          currency: Value(currency),
        ),
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpLedger(WidgetTester tester, Account account) async {
    tester.view.physicalSize = const Size(1200, 1600);
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

  Future<Account> account(int id) => (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingle();

  TextStyle? styleOf(WidgetTester tester, Finder text) => tester.widget<Text>(text).style;

  group('collapsed pair rows', () {
    testWidgets('a transfer: icon, label, date, from and to, amount; tap shows both legs', (tester) async {
      await tx(main, DateTime(2026, 1, 15), -100, 'To savings');
      await tx(savings, DateTime(2026, 1, 15), 100, 'From main');
      await pumpLedger(tester, buildAllAccountsVirtual('All accounts'));
      try {
        final row = find.ancestor(of: find.text('Transfer'), matching: find.byType(ListTile));
        expect(find.descendant(of: row, matching: find.byIcon(Icons.swap_horiz)), findsOneWidget);
        expect(find.descendant(of: row, matching: find.text('1/15/2026')), findsOneWidget);
        expect(find.descendant(of: row, matching: find.text('Main to Savings')), findsOneWidget);
        final amount = find.descendant(of: row, matching: find.text('EUR100.00'));
        expect(amount, findsOneWidget);
        expect(styleOf(tester, amount)?.decoration, isNot(TextDecoration.lineThrough));
        expect(find.descendant(of: row, matching: find.byIcon(Icons.expand_more)), findsOneWidget);
        expect(find.text('To savings'), findsNothing, reason: 'collapsed');

        await tester.tap(find.byIcon(Icons.swap_horiz));
        await settle(tester);
        expect(find.text('To savings'), findsOneWidget);
        expect(find.text('From main'), findsOneWidget);
        expect(find.byIcon(Icons.expand_less), findsOneWidget);

        await tester.tap(find.byIcon(Icons.swap_horiz));
        await settle(tester);
        expect(find.text('To savings'), findsNothing);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a no-op: icon, label, date, struck-through amount; tap shows both legs', (tester) async {
      await tx(main, DateTime(2026, 1, 15), 80, 'Reversed charge in');
      await tx(main, DateTime(2026, 1, 15), -80, 'Reversed charge out');
      await pumpLedger(tester, await account(main));
      try {
        final row = find.ancestor(of: find.text('No-op'), matching: find.byType(ListTile));
        expect(find.descendant(of: row, matching: find.byIcon(Icons.sync_alt)), findsOneWidget);
        expect(find.descendant(of: row, matching: find.text('1/15/2026')), findsOneWidget);
        final amount = find.descendant(of: row, matching: find.text('EUR80.00'));
        expect(amount, findsOneWidget);
        expect(styleOf(tester, amount)?.decoration, TextDecoration.lineThrough, reason: 'a no-op moved no money');
        expect(find.text('Reversed charge out'), findsNothing, reason: 'collapsed');

        await tester.tap(find.text('No-op'));
        await settle(tester);
        expect(find.text('Reversed charge out'), findsOneWidget);
        expect(find.text('Reversed charge in'), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });
  });

  testWidgets('an expanded transfer stays with its pair when a search moves another pair into its place', (tester) async {
    await tx(main, DateTime(2026, 1, 20), -100, 'Savings move out');
    await tx(savings, DateTime(2026, 1, 20), 100, 'Savings move in');
    await tx(main, DateTime(2026, 1, 15), -250, 'Holiday fund out');
    await tx(savings, DateTime(2026, 1, 15), 250, 'Holiday fund in');
    await pumpLedger(tester, buildAllAccountsVirtual('All accounts'));
    try {
      await tester.tap(find.byIcon(Icons.swap_horiz).first);
      await settle(tester);
      expect(find.text('Savings move out'), findsOneWidget, reason: 'the newest pair is expanded');
      expect(find.text('Holiday fund out'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'Holiday');
      await settle(tester);

      expect(find.text('EUR250.00'), findsWidgets, reason: 'the other pair is now the first row');
      expect(find.text('Holiday fund out'), findsNothing, reason: 'it was never expanded');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a saving row and its day total are in the spread event\'s currency', (tester) async {
    await tx(main, DateTime(2026, 1, 5), -10, 'Coffee');
    await ExtraordinaryEventService(db).create(
      name: 'Car',
      direction: EventDirection.outflow,
      treatment: EventTreatment.spread,
      totalAmount: 1200,
      currency: 'USD',
      eventDate: DateTime(2026, 1, 1),
      stepFrequency: StepFrequency.monthly,
      spreadStart: DateTime(2025, 1, 1),
      spreadEnd: DateTime(2025, 12, 1),
    );
    await pumpLedger(tester, buildAllAccountsVirtual('All accounts'));
    try {
      final row = find.ancestor(of: find.text('Saving for Car'), matching: find.byType(ListTile)).first;
      expect(find.descendant(of: row, matching: find.text('Adjustment')), findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('-USD100.00')), findsOneWidget);
      expect(find.textContaining('EUR100.00'), findsNothing, reason: 'the event is in USD');
      expect(find.text('-EUR10.00'), findsWidgets, reason: 'the coffee is in EUR');
    } finally {
      await unmount(tester);
    }
  });
}
