// Account ledger empty states:
// - an account without transactions, and a search that matches nothing, say
//   so through the app's one EmptyState (the texts are pinned: moving them
//   onto the shared widget cannot change them);
// - the All-accounts ledger shows its synthetic "Saving for X" rows even when
//   no account holds a transaction yet. It used to say "No transactions yet"
//   and hide them.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/domain/extraordinary_event_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/accounts/account_detail_screen.dart';
import 'package:finance_copilot/ui/widgets/empty_state.dart';

void main() {
  const s = AppStrings.en;
  late AppDatabase db;
  late Account main;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final id = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    main = await (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingle();
  });
  tearDown(() => db.close());

  Future<void> spreadCar() => ExtraordinaryEventService(db).create(
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

  Future<void> coffee() => db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          accountId: main.id,
          operationDate: DateTime(2026, 1, 5),
          valueDate: DateTime(2026, 1, 5),
          amount: -10,
          description: const Value('Coffee'),
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

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.widgetWithText(TextField, s.searchTransactions), text);
    await settle(tester);
  }

  Finder inEmptyState(String message) => find.descendant(of: find.byType(EmptyState), matching: find.text(message));

  group('pinned texts', () {
    testWidgets('an account without transactions says so', (tester) async {
      await pumpLedger(tester, main);
      try {
        expect(find.text(s.noTransactionsImport), findsOneWidget);
        expect(find.text(s.noMatchingTransactions), findsNothing);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a search that matches nothing says so', (tester) async {
      await coffee();
      await pumpLedger(tester, main);
      try {
        expect(find.text('Coffee'), findsOneWidget);
        await search(tester, 'zzz');
        expect(find.text(s.noMatchingTransactions), findsOneWidget);
        expect(find.text(s.noTransactionsImport), findsNothing);
        expect(find.text('Coffee'), findsNothing);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('All accounts with nothing at all says there are no transactions', (tester) async {
      await pumpLedger(tester, buildAllAccountsVirtual('All accounts'));
      try {
        expect(find.text(s.noTransactionsImport), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });
  });

  group('shared EmptyState', () {
    testWidgets('no transactions: the shared empty state', (tester) async {
      await pumpLedger(tester, main);
      try {
        expect(inEmptyState(s.noTransactionsImport), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('no match: the shared empty state', (tester) async {
      await coffee();
      await pumpLedger(tester, main);
      try {
        await search(tester, 'zzz');
        expect(inEmptyState(s.noMatchingTransactions), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });
  });

  group('All accounts', () {
    testWidgets('the saving rows show when no account holds a transaction yet', (tester) async {
      await spreadCar();
      await pumpLedger(tester, buildAllAccountsVirtual('All accounts'));
      try {
        expect(find.text(s.noTransactionsImport), findsNothing, reason: 'the ledger is not empty: it has the saving rows');
        expect(find.byType(EmptyState), findsNothing);
        expect(find.text(s.savingForLabel('Car')), findsWidgets, reason: 'one row per month of the spread');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('with transactions too, the saving rows and the transactions show together', (tester) async {
      await spreadCar();
      await coffee();
      await pumpLedger(tester, buildAllAccountsVirtual('All accounts'));
      try {
        expect(find.text('Coffee'), findsOneWidget);
        expect(find.text(s.savingForLabel('Car')), findsWidgets);
      } finally {
        await unmount(tester);
      }
    });
  });
}
