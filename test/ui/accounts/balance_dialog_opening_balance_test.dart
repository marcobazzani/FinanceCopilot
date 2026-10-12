// The Recalculate Balance dialog's "Actual balance" field (opening balance —
// see TransactionService.planOpeningBalance), for accounts already
// imported. Shown for cumulative and filtered; column mode already derives
// its opening from the bank's own balance column, so it's absent there.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/category_service.dart';
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
  });
  tearDown(() => db.close());

  Future<void> row(int day, double amount, {String? raw}) => db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          accountId: account.id,
          operationDate: DateTime(2026, 3, day),
          valueDate: DateTime(2026, 3, day),
          amount: amount,
          description: Value('Row $day'),
          rawMetadata: Value(raw),
        ),
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> openDialog(WidgetTester tester) async {
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
    await tester.tap(find.byTooltip('Recalculate Balance'));
    await settle(tester);
    expect(find.text('Recalculate'), findsOneWidget, reason: 'the dialog is open');
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('cumulative (the default selection): the field shows; column: it is absent', (tester) async {
    await row(1, 100);
    await openDialog(tester);
    try {
      expect(find.byKey(const Key('actualBalanceField')), findsOneWidget, reason: 'cumulative is pre-selected');

      await tester.tap(find.text('Column'));
      await settle(tester);
      expect(find.byKey(const Key('actualBalanceField')), findsNothing);

      await tester.tap(find.text('Filtered sum'));
      await settle(tester);
      expect(find.byKey(const Key('actualBalanceField')), findsOneWidget);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('typing the bank balance adds an "Opening balance" transaction for the difference', (tester) async {
    await row(1, 100);
    await row(5, -40);
    await openDialog(tester);
    try {
      await tester.enterText(find.byKey(const Key('actualBalanceField')), '560');
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Recalculate'));
      await settle(tester);

      expect(find.textContaining('Opening balance added'), findsOneWidget);

      final rows = await (db.select(db.transactions)..orderBy([(t) => OrderingTerm.asc(t.valueDate)])).get();
      final opening = rows.firstWhere((t) => t.description == 'Opening balance');
      expect(opening.amount, 500);
      expect(opening.operationDate, DateTime(2026, 2, 28));
      expect(opening.currency, 'EUR');
      expect(opening.status, TransactionStatus.settled);
      final cat = await CategoryService(db).getByKey(CategoryService.openingBalanceIncomeKey);
      expect(opening.categoryId, cat!.id);
      expect(rows.last.balanceAfter, 560);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('left empty: nothing added, as before', (tester) async {
    await row(1, 100);
    await openDialog(tester);
    try {
      await tester.tap(find.widgetWithText(FilledButton, 'Recalculate'));
      await settle(tester);

      expect(find.textContaining('Opening balance'), findsNothing);
      final rows = await db.select(db.transactions).get();
      expect(rows, hasLength(1));
    } finally {
      await unmount(tester);
    }
  });
}
