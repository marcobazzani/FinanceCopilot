// The account detail's summary bar shows the account's balance by the same
// rule as the accounts list (AccountService): the latest row that HAS a
// balance. A hand-entered row without one on the latest day used to make the
// detail show "N records" while the list showed the balance.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/domain/account_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/accounts/account_detail_screen.dart';
import 'package:finance_copilot/utils/formatters.dart' as fmt;

void main() {
  const s = AppStrings.en;
  late AppDatabase db;
  late Account account;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final id = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    account = await (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingle();
  });
  tearDown(() => db.close());

  Future<void> row(int day, double amount, double? balance) => db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          accountId: account.id,
          operationDate: DateTime(2026, 1, day),
          valueDate: DateTime(2026, 1, day),
          amount: amount,
          description: Value('Row $day'),
          balanceAfter: Value(balance),
        ),
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpDetail(WidgetTester tester) async {
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

  String balanceLine(double balance) => '${s.balance}: +${fmt.currencyFormat('en_US', account.currency).format(balance)}';

  testWidgets('a latest row without a balance: the latest balance is still shown, as in the accounts list', (tester) async {
    await row(10, 100, 100);
    await row(12, -30, 70);
    await row(14, 5, null); // hand-entered, no balance
    expect((await AccountService(db).getStatsForAll())[account.id]!.balance, 70, reason: 'the accounts list rule');
    await pumpDetail(tester);
    try {
      expect(find.text(balanceLine(70)), findsOneWidget);
      expect(find.text(s.recordCount(3)), findsNothing);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('pin: the balance of the latest row, by value date then id', (tester) async {
    await row(12, -30, 70);
    await row(10, 100, 100);
    await row(12, 5, 75);
    await pumpDetail(tester);
    try {
      expect(find.text(balanceLine(75)), findsOneWidget);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('pin: no row with a balance: the record count stands in', (tester) async {
    await row(10, 100, null);
    await row(12, -30, null);
    await pumpDetail(tester);
    try {
      expect(find.text(s.recordCount(2)), findsOneWidget);
      expect(find.textContaining('${s.balance}: '), findsNothing);
    } finally {
      await unmount(tester);
    }
  });
}
