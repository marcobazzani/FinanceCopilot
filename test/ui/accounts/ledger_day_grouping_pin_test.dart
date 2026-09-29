// The account ledger groups rows by calendar day (local midnight), whatever the
// time of day a row carries: one day header, one day total, and pairs (a
// same-account no-op, a cross-account transfer) matched within the day.
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
  late int main;
  late int savings;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    main = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    savings = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Savings'));
  });
  tearDown(() => db.close());

  Future<void> tx(int account, DateTime at, double amount, String desc) => db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          accountId: account,
          operationDate: at,
          valueDate: at,
          amount: amount,
          description: Value(desc),
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

  testWidgets('one account: a day header and a day total per calendar day; a no-op pair within the day', (tester) async {
    await tx(main, DateTime(2026, 1, 10, 9), -20, 'Coffee');
    await tx(main, DateTime(2026, 1, 10, 18, 30), -5, 'Snack');
    await tx(main, DateTime(2026, 1, 11, 7), -7, 'Bus');
    await tx(main, DateTime(2026, 1, 12, 8), 15, 'Charge reversed');
    await tx(main, DateTime(2026, 1, 12, 21), -15, 'Charge');
    await pumpLedger(tester, await (db.select(db.accounts)..where((a) => a.id.equals(main))).getSingle());
    try {
      expect(find.text('Jan 10, 2026'), findsOneWidget, reason: 'morning and evening rows share one header');
      expect(find.text('Jan 11, 2026'), findsOneWidget);
      expect(find.text('Jan 12, 2026'), findsOneWidget);
      expect(find.text('= -EUR25.00'), findsOneWidget, reason: 'the Jan 10 total counts both of its rows');
      expect(find.text('= -EUR7.00'), findsOneWidget);
      expect(find.text('= -EUR32.00'), findsOneWidget, reason: 'the month total; the no-op pair moves no money');
      expect(find.text('No-op'), findsOneWidget);
      expect(find.text('Charge'), findsNothing, reason: 'collapsed into the no-op row');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('all accounts: a transfer is paired within its day', (tester) async {
    await tx(main, DateTime(2026, 1, 15, 9), -100, 'To savings');
    await tx(savings, DateTime(2026, 1, 15, 17), 100, 'From main');
    await tx(savings, DateTime(2026, 1, 16, 1), -100, 'Next day');
    await pumpLedger(tester, buildAllAccountsVirtual('All accounts'));
    try {
      expect(find.text('Transfer'), findsOneWidget);
      expect(find.text('To savings'), findsNothing, reason: 'collapsed into the transfer row');
      expect(find.text('Next day'), findsOneWidget, reason: 'a leg on another day is not part of the pair');
      expect(find.text('Jan 15, 2026'), findsOneWidget);
      expect(find.text('Jan 16, 2026'), findsOneWidget);
    } finally {
      await unmount(tester);
    }
  });
}
