// The New Account dialog on the Accounts screen.
//
// Pinned bug: Enter in the name field and the Create button both submitted,
// with no in-flight guard, so a quick second submit created a duplicate
// account. The dialog now owns its controller (disposed with the dialog) and
// submits once.
import 'dart:async';

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
import 'package:finance_copilot/ui/screens/accounts/accounts_screen.dart';

/// Holds every create until the test opens [gate].
class _GatedAccountService extends AccountService {
  _GatedAccountService(super.db);

  final gate = Completer<void>();
  final created = <String>[];

  @override
  Future<int> create({required String name, required String currency, String institution = ''}) async {
    created.add(name);
    await gate.future;
    return super.create(name: name, currency: currency, institution: institution);
  }
}

void main() {
  const s = AppStrings.en;
  late AppDatabase db;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // An intermediary keeps the list (and its add button) on screen.
    await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    await db.into(db.appConfigs).insertOnConflictUpdate(AppConfigsCompanion.insert(key: 'BASE_CURRENCY', value: 'USD'));
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> openCreateDialog(WidgetTester tester, {List overrides = const []}) async {
    tester.view.physicalSize = const Size(1200, 900);
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

  Future<List<Account>> accounts() => db.select(db.accounts).get();

  testWidgets('Enter in the name field creates the account in the base currency', (tester) async {
    await openCreateDialog(tester);
    try {
      await tester.enterText(nameField(), '  Fineco  ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      final account = (await accounts()).single;
      expect(account.name, 'Fineco');
      expect(account.currency, 'USD');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('Create with the field still focused creates the account', (tester) async {
    await openCreateDialog(tester);
    try {
      await tester.enterText(nameField(), 'Fineco');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, s.create));
      await settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect((await accounts()).map((a) => a.name), ['Fineco']);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('Cancel with the field still focused creates nothing', (tester) async {
    await openCreateDialog(tester);
    try {
      await tester.enterText(nameField(), 'Fineco');
      await tester.tap(find.widgetWithText(TextButton, s.cancel));
      await settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(await accounts(), isEmpty);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('an empty name cannot be submitted', (tester) async {
    await openCreateDialog(tester);
    try {
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, s.create)).onPressed, isNull);
      await tester.enterText(nameField(), '  ');
      await tester.pump();
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, s.create)).onPressed, isNull);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(await accounts(), isEmpty);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('Enter then Create while the first create is still running creates one account', (tester) async {
    final service = _GatedAccountService(db);
    await openCreateDialog(tester, overrides: [accountServiceProvider.overrideWithValue(service)]);
    try {
      await tester.enterText(nameField(), 'Fineco');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, s.create));
      await tester.pump();
      service.gate.complete();
      await settle(tester);

      expect(service.created, ['Fineco']);
      expect(find.byType(AlertDialog), findsNothing);
      expect(await accounts(), hasLength(1));
    } finally {
      await unmount(tester);
    }
  });
}
