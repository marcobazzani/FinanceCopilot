// The All-accounts ledger's synthetic "Saving for X" rows answer the search
// like every other row: the search box and the "Doesn't contain" filter
// match them over what they show (their label and amount). They used to be
// listed whatever was typed.
//
// A search only narrows the ledger: which rows are adjustments — and so which
// scheduled entries show as saving rows — is decided on the whole ledger,
// never on the rows the search kept. And when nothing matches, the ledger
// says so, even when it holds saving rows only.
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
  late int main;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    main = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
  });
  tearDown(() => db.close());

  /// A 1,200 car saved for over Jan–Mar 2025: three scheduled entries of
  /// −400 on the 1st of each month.
  Future<void> spreadCar() => ExtraordinaryEventService(db).create(
    name: 'Car',
    direction: EventDirection.outflow,
    treatment: EventTreatment.spread,
    totalAmount: 1200,
    currency: 'EUR',
    eventDate: DateTime(2026, 1, 1),
    stepFrequency: StepFrequency.monthly,
    spreadStart: DateTime(2025, 1, 1),
    spreadEnd: DateTime(2025, 3, 1),
  );

  Future<int> tx(DateTime day, double amount, String desc) => db
      .into(db.transactions)
      .insert(TransactionsCompanion.insert(accountId: main, operationDate: day, valueDate: day, amount: amount, description: Value(desc)));

  Future<void> coffee() => tx(DateTime(2026, 1, 5), -10, 'Coffee');

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpAllAccounts(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(home: AccountDetailScreen(account: buildAllAccountsVirtual('All accounts'))),
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

  Future<void> excludeText(WidgetTester tester, String text) async {
    await tester.tap(find.byKey(const Key('ledgerFilterButton')));
    await settle(tester);
    final field = find.widgetWithText(TextField, s.filterTextExcludes);
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    await tester.tap(find.widgetWithText(FilledButton, s.filterApply));
    await settle(tester);
  }

  final savingRows = find.text(s.savingForLabel('Car'));

  testWidgets('a search hides the saving rows it does not match', (tester) async {
    await spreadCar();
    await coffee();
    await pumpAllAccounts(tester);
    try {
      expect(savingRows, findsNWidgets(3));
      await search(tester, 'coffee');
      expect(find.text('Coffee'), findsOneWidget);
      expect(savingRows, findsNothing, reason: 'no saving row says "coffee"');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a search finds the saving rows by their label or amount', (tester) async {
    await spreadCar();
    await coffee();
    await pumpAllAccounts(tester);
    try {
      await search(tester, 'saving');
      expect(savingRows, findsNWidgets(3));
      expect(find.text('Coffee'), findsNothing);

      await search(tester, 'car');
      expect(savingRows, findsNWidgets(3), reason: 'the label names the event');
      expect(find.text('Coffee'), findsNothing);

      await search(tester, '-400');
      expect(savingRows, findsNWidgets(3), reason: 'the amount is searchable, as on a transaction row');
      expect(find.text('Coffee'), findsNothing);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('"Doesn\'t contain" hides the saving rows it matches', (tester) async {
    await spreadCar();
    await coffee();
    await pumpAllAccounts(tester);
    try {
      await excludeText(tester, 'saving');
      expect(find.text('Coffee'), findsOneWidget);
      expect(savingRows, findsNothing);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a search never adds saving rows: an entry a hidden transaction accounts for stays out', (tester) async {
    await spreadCar();
    // February's saving is a real bank movement: that entry is not a
    // synthetic row, the transaction carries the adjustment badge instead.
    await tx(DateTime(2025, 2, 1), -400, 'Bank transfer');
    await pumpAllAccounts(tester);
    try {
      expect(savingRows, findsNWidgets(2));
      expect(find.text(s.adjustedForLabel('Car')), findsOneWidget);

      await search(tester, 'saving');
      expect(find.text('Bank transfer'), findsNothing);
      expect(savingRows, findsNWidgets(2), reason: 'hiding the transfer does not turn its entry into a saving row');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a search keeps the adjustment badge on the transaction the event matched', (tester) async {
    await spreadCar();
    // Two identical movements: February's entry is the first one's.
    await tx(DateTime(2025, 2, 1), -400, 'Transfer A');
    await tx(DateTime(2025, 2, 1), -400, 'Transfer B');
    await pumpAllAccounts(tester);
    try {
      expect(find.text(s.adjustedForLabel('Car')), findsOneWidget);

      await search(tester, 'transfer b');
      expect(find.text('Transfer B'), findsOneWidget);
      expect(find.text('Transfer A'), findsNothing);
      expect(find.text(s.adjustedForLabel('Car')), findsNothing, reason: 'B was not the adjustment before the search');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('saving rows only: a search that matches none says no match, not "no transactions"', (tester) async {
    await spreadCar();
    await pumpAllAccounts(tester);
    try {
      expect(savingRows, findsNWidgets(3));
      await search(tester, 'zzz');
      expect(savingRows, findsNothing);
      expect(find.descendant(of: find.byType(EmptyState), matching: find.text(s.noMatchingTransactions)), findsOneWidget);
      expect(find.text(s.noTransactionsImport), findsNothing);
    } finally {
      await unmount(tester);
    }
  });
}
