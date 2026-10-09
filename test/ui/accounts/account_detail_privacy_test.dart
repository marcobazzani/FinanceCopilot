// Account detail: privacy mode masks the money (amounts, balances) and leaves
// the words and counts around it readable — in the summary bar, in the
// confirmation dialogs that quote an amount, and in the snackbar that reports
// a balance recalculation.
//
// Every test asserts a masked figure and a readable one in the same place, so
// a fix that simply blurred the whole dialog or message would fail too.
import 'dart:convert';

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
import 'package:finance_copilot/services/import/import_config_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/accounts/account_detail_screen.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late Account account;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final id = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    account = await (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingle();
    // Two imported rows WITHOUT a stored running balance; the statement's
    // balance column says 1,100.00 after the last one.
    for (final (day, amount, stated) in [(10, 220.5, '1220.50'), (12, -120.5, '1100.00')]) {
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              accountId: id,
              operationDate: DateTime(2026, 1, day),
              valueDate: DateTime(2026, 1, day),
              amount: amount,
              description: Value('Row $day'),
              rawMetadata: Value(jsonEncode({'Saldo': stated})),
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
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The test font draws every glyph a full em wide: at 1.0 the row menu's
    // "Mark as adjustment" entry overflows the 280-px popup menu.
    tester.platformDispatcher.textScaleFactorTestValue = 0.8;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final screen = AccountDetailScreen(account: account);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(home: screen),
      ),
    );
    container = ProviderScope.containerOf(tester.element(find.byWidget(screen)));
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> setPrivate(WidgetTester tester, bool value) async {
    container.read(privacyModeProvider.notifier).state = value;
    await settle(tester);
  }

  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  bool everyMasked(Finder f) => f.evaluate().every(
    (e) => find.ancestor(of: find.byElementPredicate((x) => x == e), matching: find.byType(ImageFiltered)).evaluate().isNotEmpty,
  );

  testWidgets('summary bar without a balance: the record count stays readable while amounts stay masked', (tester) async {
    await pumpAccount(tester);
    try {
      await setPrivate(tester, true);
      expect(find.text('2 records'), findsOneWidget);
      expect(masked(find.text('2 records')), isFalse, reason: 'a count of records is shape, not magnitude');
      final amount = find.textContaining('120.50');
      expect(amount, findsWidgets);
      expect(everyMasked(amount), isTrue, reason: 'a transaction amount is position size');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('balance recalculation snackbar: opening and bank closing are masked, the rest of the message is readable', (tester) async {
    await ImportConfigService(db).save(
      accountId: account.id,
      skipRows: 0,
      mappings: {'date': 'Date', 'amount': 'Amount', 'balanceAfter': 'Saldo', '__balanceMode': 'column'},
      formula: const [],
      hashColumns: const [],
      numberLocale: 'en_US',
    );
    await pumpAccount(tester);
    try {
      await setPrivate(tester, true);
      await tester.tap(find.byTooltip('Recalculate Balance'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Recalculate'));
      await settle(tester);

      final snack = find.byType(SnackBar);
      expect(snack, findsOneWidget);
      Finder inSnack(String text) => find.descendant(of: snack, matching: find.textContaining(text));
      // 1,100.00 closing − (220.50 − 120.50) of history in the app = 1,000.00 opening.
      expect(inSnack('1,000.00'), findsOneWidget);
      expect(masked(inSnack('1,000.00')), isTrue, reason: 'the implied opening balance is position size');
      expect(masked(inSnack('1,100.00')), isTrue, reason: 'the bank closing balance is position size');
      expect(inSnack('Recalculated 2 balances.'), findsOneWidget);
      expect(masked(inSnack('Recalculated 2 balances.')), isFalse, reason: 'the explanation and the count stay readable');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('mark as adjustment: the amount is masked in the confirmation and in the duplicate warning, the words are not', (tester) async {
    await ExtraordinaryEventService(db).create(
      name: 'Bonus',
      direction: EventDirection.inflow,
      treatment: EventTreatment.instant,
      totalAmount: 5000,
      currency: 'EUR',
      eventDate: DateTime(2026, 1, 5),
    );
    await pumpAccount(tester);
    // In the app the shell keeps the events stream listened (dashboard charts,
    // Adjustments tab); an unlistened stream provider is paused and the
    // action's `ref.read(extraordinaryEventsProvider.future)` would never
    // resolve on this lone screen.
    final keepAlive = container.listen(extraordinaryEventsProvider, (_, _) {});
    addTearDown(keepAlive.close);
    try {
      await setPrivate(tester, true);
      Finder inDialog(String text) => find.descendant(of: find.byType(AlertDialog), matching: find.textContaining(text));

      Future<void> flagOutflow() async {
        await tester.tap(find.byTooltip('Mark as adjustment'));
        await settle(tester);
        await tester.tap(find.text('Mark as adjustment').last);
        await settle(tester);
      }

      await flagOutflow();
      expect(inDialog('120.50'), findsOneWidget);
      expect(masked(inDialog('120.50')), isTrue, reason: 'the adjustment amount is position size');
      expect(masked(inDialog('adjustment will be added to the selected inflow')), isFalse, reason: 'the explanation stays readable');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await settle(tester);

      // Same day, same amount again: the duplicate warning quotes the amount.
      await flagOutflow();
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await settle(tester);
      expect(find.text('Adjustment already exists'), findsOneWidget);
      expect(inDialog('120.50'), findsOneWidget);
      expect(masked(inDialog('120.50')), isTrue, reason: 'the adjustment amount is position size');
      expect(masked(inDialog('already exists on this date for this inflow')), isFalse, reason: 'the warning stays readable');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await settle(tester);
    } finally {
      await unmount(tester);
    }
  });
}
