// The New Account dialog creates the account in the stored base currency.
//
// Pinned bug: before the base currency had loaded, Create (and Enter) made the
// account in 'EUR' whatever the stored base currency was.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/accounts/accounts_screen.dart';

void main() {
  const s = AppStrings.en;
  late AppDatabase db;
  late StreamController<String> baseCurrency;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // An intermediary keeps the list (and its add button) on screen.
    await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    baseCurrency = StreamController<String>();
  });
  tearDown(() async {
    await baseCurrency.close();
    await db.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> openCreateDialog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          privacyModeProvider.overrideWith((ref) => false),
          baseCurrencyProvider.overrideWith((ref) => baseCurrency.stream),
        ],
        child: const MaterialApp(home: AccountsScreen()),
      ),
    );
    await settle(tester);
    await tester.tap(find.byWidgetPredicate((w) => w is FloatingActionButton && w.heroTag == 'add_account'));
    await settle(tester);
    expect(find.widgetWithText(AlertDialog, s.newAccountTitle), findsOneWidget);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder nameField() => find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
  Finder createButton() => find.widgetWithText(FilledButton, s.create);

  testWidgets('nothing is created before the base currency is known; then it is created in it', (tester) async {
    await openCreateDialog(tester);
    try {
      await tester.enterText(nameField(), 'Fineco');
      await tester.pump();
      expect(tester.widget<FilledButton>(createButton()).onPressed, isNull);
      await tester.tap(createButton());
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(await db.select(db.accounts).get(), isEmpty, reason: 'no account in a guessed currency');
      expect(find.byType(AlertDialog), findsOneWidget);

      baseCurrency.add('CHF');
      await settle(tester);
      await tester.tap(createButton());
      await settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      final account = (await db.select(db.accounts).get()).single;
      expect(account.name, 'Fineco');
      expect(account.currency, 'CHF');
    } finally {
      await unmount(tester);
    }
  });
}
