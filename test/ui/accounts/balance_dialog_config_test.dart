// The balance dialog of an account reads the saved import config's balance
// settings with the shared tolerant reader.
//
//  * Pin: a config without a balance mode opens on the cumulative sum, the
//    mode the dialog and the import wizard pre-select for it (automatic
//    recalculations leave such an account's balances alone).
//  * A filter set stored as a JSON list, a row whose raw statement data is
//    not a JSON object, or mappings that are not JSON crashed the dialog
//    before it opened. It now opens; nothing unreadable is written back over
//    the stored config.
//  * The filter the user picks in the dialog is the one the balances are
//    recalculated with — the recalculation used to apply the previously saved
//    filter and only then save the new one.
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
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/accounts/account_detail_screen.dart';

void main() {
  late AppDatabase db;
  late Account account;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final id = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    account = await (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingle();
  });
  tearDown(() => db.close());

  Future<void> row(int day, double amount, String? raw) => db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          accountId: account.id,
          operationDate: DateTime(2026, 1, day),
          valueDate: DateTime(2026, 1, day),
          amount: amount,
          description: Value('Row $day'),
          rawMetadata: Value(raw),
        ),
      );

  Future<void> statement() async {
    await row(10, 100, '{"State":"DONE"}');
    await row(11, -30, '{"State":"FAILED"}');
    await row(12, 10, '{"State":"DONE"}');
  }

  Future<void> config(String mappingsJson) =>
      db.into(db.importConfigs).insert(ImportConfigsCompanion.insert(accountId: Value(account.id), mappingsJson: Value(mappingsJson)));

  Future<String> storedMappings() async => (await db.select(db.importConfigs).getSingle()).mappingsJson;

  Future<List<double?>> balances() async => [
    for (final t in await (db.select(db.transactions)..orderBy([(t) => OrderingTerm.asc(t.valueDate)])).get()) t.balanceAfter,
  ];

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
    expect(tester.takeException(), isNull);
    expect(find.text('Recalculate'), findsOneWidget, reason: 'the dialog is open');
  }

  Future<void> recalculate(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Recalculate'));
    await settle(tester);
    expect(tester.takeException(), isNull);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('pin: a config without a balance mode opens on the cumulative sum, which is then saved', (tester) async {
    await statement();
    await config('{"date":"Date","amount":"Amount"}');
    try {
      await openDialog(tester);
      expect(find.textContaining('Recalculated'), findsNothing);
      await recalculate(tester);
      expect(await balances(), [100, 70, 80]);
      expect(jsonDecode(await storedMappings()), {'date': 'Date', 'amount': 'Amount', '__balanceMode': 'cumulative'});
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a filter set stored as a JSON list', (tester) async {
    await statement();
    await config(
      jsonEncode({
        '__balanceMode': 'filtered',
        '__balanceFilterColumn': 'State',
        '__balanceFilterInclude': ['DONE'],
      }),
    );
    try {
      await openDialog(tester);
      await recalculate(tester);
      expect(await balances(), [100, 100, 110]);
      expect(jsonDecode(await storedMappings())['__balanceFilterInclude'], '["DONE"]');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a row whose raw statement data is not a JSON object', (tester) async {
    await statement();
    await row(13, 5, '["DONE"]');
    await config('{"__balanceMode":"cumulative"}');
    try {
      await openDialog(tester);
      await recalculate(tester);
      expect(await balances(), [100, 70, 80, 85]);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('mappings that are not JSON: nothing is recalculated, the stored text is not overwritten', (tester) async {
    await statement();
    await config('{"date": ');
    try {
      await openDialog(tester);
      await recalculate(tester);
      // A mode applied but not saved would be reverted by the next automatic
      // recalculation: the dialog does both or neither.
      expect(await balances(), [null, null, null]);
      expect(await storedMappings(), '{"date": ');
      expect(find.text(AppStrings.en.balanceSettingsUnreadable), findsOneWidget);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('column mode reads the stored statement text in the account\'s number format', (tester) async {
    await row(10, 100, '{"Saldo":"1.100,00"}');
    await row(11, -30, '{"Saldo":"1.070,00"}');
    await db
        .into(db.importConfigs)
        .insert(
          ImportConfigsCompanion.insert(
            accountId: Value(account.id),
            mappingsJson: const Value('{"balanceAfter":"Saldo","__balanceMode":"column"}'),
            numberLocale: const Value('it_IT'),
          ),
        );
    try {
      await openDialog(tester);
      await recalculate(tester);
      expect(await balances(), [1100, 1070], reason: 'anchored on the bank closing 1.070,00');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('the filter values picked in the dialog are the ones applied', (tester) async {
    await statement();
    await config(
      jsonEncode({
        '__balanceMode': 'filtered',
        '__balanceFilterColumn': 'State',
        '__balanceFilterInclude': jsonEncode(['DONE']),
      }),
    );
    try {
      await openDialog(tester);
      await tester.tap(find.widgetWithText(FilterChip, 'FAILED'));
      await settle(tester);
      await recalculate(tester);
      expect(await balances(), [100, 70, 80], reason: 'FAILED is now included');
      expect(jsonDecode(jsonDecode(await storedMappings())['__balanceFilterInclude'] as String), unorderedEquals(['DONE', 'FAILED']));
      final statuses = [for (final t in await db.select(db.transactions).get()) t.status];
      expect(statuses, everyElement(TransactionStatus.settled));
    } finally {
      await unmount(tester);
    }
  });
}
