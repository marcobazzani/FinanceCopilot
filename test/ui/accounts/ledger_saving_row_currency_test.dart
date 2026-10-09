// All-accounts ledger: a synthetic "Saving for X" row is in the currency of
// the spread event it comes from — the resolved row carries it. Two events
// sharing a name, a schedule and an amount but not a currency used to make
// the currency "ambiguous", and every one of their saving rows was dropped
// from the ledger and from its day totals.
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

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> spreadCar(String currency) => ExtraordinaryEventService(db).create(
    name: 'Car',
    direction: EventDirection.outflow,
    treatment: EventTreatment.spread,
    totalAmount: 1200,
    currency: currency,
    eventDate: DateTime(2026, 1, 1),
    stepFrequency: StepFrequency.monthly,
    spreadStart: DateTime(2025, 1, 1),
    spreadEnd: DateTime(2025, 12, 1),
  );

  testWidgets('two events with the same name, schedule and amount keep their saving rows, each in its own currency', (tester) async {
    final main = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: main,
            operationDate: DateTime(2026, 1, 5),
            valueDate: DateTime(2026, 1, 5),
            amount: -10,
            description: const Value('Coffee'),
          ),
        );
    await spreadCar('USD');
    await spreadCar('GBP');

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
        child: MaterialApp(home: AccountDetailScreen(account: buildAllAccountsVirtual('All accounts'))),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    try {
      final rows = find.ancestor(of: find.text('Saving for Car'), matching: find.byType(ListTile));
      expect(rows, findsWidgets, reason: 'the saving rows are shown');
      final amounts = {
        for (final row in rows.evaluate())
          for (final text in find.descendant(of: find.byWidget(row.widget), matching: find.byType(Text)).evaluate())
            if ((text.widget as Text).data?.contains('100.00') ?? false) (text.widget as Text).data,
      };
      expect(amounts, {'-USD100.00', '-GBP100.00'}, reason: 'one row per event, in its currency');
      expect(find.textContaining('EUR100.00'), findsNothing, reason: 'never shown in a currency it is not in');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}
