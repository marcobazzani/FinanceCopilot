// Transaction and record counts on the Accounts screens read right for one
// ("1 transaction", not "1 transactions").
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
import 'package:finance_copilot/ui/screens/accounts/accounts_screen.dart';

void main() {
  late AppDatabase db;
  late Account account;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final id = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main', currency: const Value('EUR')));
    account = await (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingle();
  });
  tearDown(() => db.close());

  Future<void> addTransactions(int n) async {
    for (var i = 0; i < n; i++) {
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              accountId: account.id,
              operationDate: DateTime(2026, 1, 10 + i),
              valueDate: DateTime(2026, 1, 10 + i),
              amount: -10.0 - i,
              description: Value('Row $i'),
            ),
          );
    }
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pump(WidgetTester tester, Widget home) async {
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
        child: MaterialApp(home: home),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('account detail summary', () {
    testWidgets('one row: "1 transaction", "1 record"', (tester) async {
      await addTransactions(1);
      await pump(tester, AccountDetailScreen(account: account));
      try {
        expect(find.text('1 transaction'), findsOneWidget);
        expect(find.text('1 record'), findsOneWidget, reason: 'no balance yet: the record count stands in');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('two rows: "2 transactions", "2 records"', (tester) async {
      await addTransactions(2);
      await pump(tester, AccountDetailScreen(account: account));
      try {
        expect(find.text('2 transactions'), findsOneWidget);
        expect(find.text('2 records'), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('all accounts: the count reads right for one and for many', (tester) async {
      await addTransactions(1);
      await pump(tester, AccountDetailScreen(account: buildAllAccountsVirtual('All accounts')));
      try {
        expect(find.text('1 transaction'), findsOneWidget);
      } finally {
        await unmount(tester);
      }

      await addTransactions(1);
      await pump(tester, AccountDetailScreen(account: buildAllAccountsVirtual('All accounts')));
      try {
        expect(find.text('2 transactions'), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });
  });

  group('accounts list', () {
    Finder statsLine(String count) => find.textContaining(RegExp('^$count(?!s)'), findRichText: true);

    testWidgets('an account with one transaction', (tester) async {
      await addTransactions(1);
      await pump(tester, const AccountsScreen());
      try {
        expect(statsLine('1 transaction'), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('an account with two transactions', (tester) async {
      await addTransactions(2);
      await pump(tester, const AccountsScreen());
      try {
        expect(statsLine('2 transactions'), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });
  });
}
