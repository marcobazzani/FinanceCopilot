// Account detail actions:
//  * Edit account → Save runs once: a second tap while the first save is still
//    being written used to save again.
//  * "Mark as adjustment" on the account screen alone: it read the events
//    through a provider nobody else listened to, which Riverpod pauses, so the
//    inflow picker never opened.
import 'dart:async';

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
import 'package:finance_copilot/services/domain/account_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/accounts/account_detail_screen.dart';

/// Holds every update until the test opens [gate].
class _GatedAccountService extends AccountService {
  _GatedAccountService(super.db);

  final gate = Completer<void>();
  int updates = 0;

  @override
  Future<bool> update(int id, AccountsCompanion companion) async {
    updates++;
    await gate.future;
    return super.update(id, companion);
  }
}

void main() {
  const s = AppStrings.en;
  late AppDatabase db;
  late Account account;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final id = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main', currency: const Value('EUR')));
    account = await (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingle();
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: id,
            operationDate: DateTime(2026, 1, 10),
            valueDate: DateTime(2026, 1, 10),
            amount: -42.5,
            description: const Value('Groceries'),
          ),
        );
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpAccount(WidgetTester tester, {List overrides = const []}) async {
    tester.view.physicalSize = const Size(1200, 1000);
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
        child: MaterialApp(home: AccountDetailScreen(account: account)),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('Edit account: a second Save while the first is still running saves nothing more', (tester) async {
    final service = _GatedAccountService(db);
    await pumpAccount(tester, overrides: [accountServiceProvider.overrideWithValue(service)]);
    try {
      await tester.tap(find.byTooltip(s.tooltipEditAccount));
      await settle(tester);
      await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(TextField, s.name)), 'Checking');
      final save = find.widgetWithText(FilledButton, s.save);
      await tester.tap(save);
      await tester.pump();
      expect(tester.widget<FilledButton>(save).onPressed, isNull, reason: 'Save is off while saving');
      await tester.tap(save, warnIfMissed: false);
      await tester.pump();
      service.gate.complete();
      await settle(tester);

      expect(service.updates, 1);
      expect(find.byType(AlertDialog), findsNothing);
      expect((await (db.select(db.accounts)..where((a) => a.id.equals(account.id))).getSingle()).name, 'Checking');
    } finally {
      await unmount(tester);
    }
  });

  group('Mark as adjustment on the account screen alone', () {
    Future<void> markAsAdjustment(WidgetTester tester) async {
      await tester.tap(find.byTooltip(s.flagAsAdjustmentTooltip));
      await settle(tester);
      await tester.tap(find.text(s.flagAsAdjustmentTooltip).last);
      await settle(tester);
    }

    testWidgets('the inflow picker opens and the adjustment is recorded on the chosen inflow', (tester) async {
      final inheritance = await db
          .into(db.extraordinaryEvents)
          .insert(
            ExtraordinaryEventsCompanion.insert(
              name: 'Inheritance',
              direction: EventDirection.inflow,
              treatment: EventTreatment.instant,
              totalAmount: 10000,
              eventDate: DateTime(2025, 12, 1),
            ),
          );
      await pumpAccount(tester);
      try {
        await markAsAdjustment(tester);
        expect(find.widgetWithText(AlertDialog, s.flagAsAdjustmentTitle), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, s.add));
        await settle(tester);

        final entries = await (db.select(db.extraordinaryEventEntries)..where((e) => e.eventId.equals(inheritance))).get();
        expect(entries.map((e) => e.amount), [42.5]);
        expect(find.text(s.adjustmentFlaggedSnack), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('without inflow events the user is told there are none', (tester) async {
      await pumpAccount(tester);
      try {
        await markAsAdjustment(tester);
        expect(find.text(s.noInflowEventsAvailable), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });
  });
}
