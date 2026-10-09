// The balance dialog applies what it saves, and only that:
//
//  * When the account's saved import settings cannot be read, it used to
//    recalculate in the newly picked mode but skip saving it — the next
//    automatic recalculation (after a delete, an import) then reverted to the
//    saved mode. It now does neither and says why.
//  * The screen can go away while the recalculation runs: the new mode is
//    still saved (it used `ref` after the await, on a disposed screen).
import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/domain/transaction_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/accounts/account_detail_screen.dart';

import '../import_wizard_harness.dart' show Gate;

/// Holds the dialog's recalculation on [gate].
class _GatedTransactionService extends TransactionService {
  _GatedTransactionService(super.db);

  final gate = Gate();

  @override
  Future<BalanceRecalcResult> recalculateBalancesDetailed(
    int accountId, {
    required String balanceMode,
    Map<String, dynamic> savedMappings = const {},
    String? numberLocale,
  }) async {
    await gate.wait;
    return super.recalculateBalancesDetailed(accountId, balanceMode: balanceMode, savedMappings: savedMappings, numberLocale: numberLocale);
  }
}

void main() {
  const s = AppStrings.en;
  late AppDatabase db;
  late Account account;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final id = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    account = await (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingle();
    for (final (day, amount, state) in [(10, 100.0, 'DONE'), (11, -30.0, 'FAILED'), (12, 10.0, 'DONE')]) {
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              accountId: id,
              operationDate: DateTime(2026, 1, day),
              valueDate: DateTime(2026, 1, day),
              amount: amount,
              description: Value('Row $day'),
              rawMetadata: Value(jsonEncode({'State': state})),
            ),
          );
    }
  });
  tearDown(() => db.close());

  Future<void> config(String mappingsJson, {String formulaJson = '[]'}) => db
      .into(db.importConfigs)
      .insert(ImportConfigsCompanion.insert(accountId: Value(account.id), mappingsJson: Value(mappingsJson), formulaJson: Value(formulaJson)));

  Future<ImportConfig> stored() => db.select(db.importConfigs).getSingle();

  Future<List<double?>> balances() async => [
    for (final t in await (db.select(db.transactions)..orderBy([(t) => OrderingTerm.asc(t.valueDate)])).get()) t.balanceAfter,
  ];

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> openDialog(WidgetTester tester, {TransactionService? transactions}) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          privacyModeProvider.overrideWith((ref) => false),
          if (transactions != null) transactionServiceProvider.overrideWithValue(transactions),
        ],
        child: MaterialApp(home: AccountDetailScreen(account: account)),
      ),
    );
    await settle(tester);
    await tester.tap(find.byTooltip(s.tooltipRecalcBalance));
    await settle(tester);
    expect(find.widgetWithText(FilledButton, s.recalculate), findsOneWidget, reason: 'the dialog is open');
  }

  /// Picks the filtered sum on State with FAILED left out.
  Future<void> pickFilteredDone(WidgetTester tester) async {
    await tester.tap(find.text(s.recalcFiltered));
    await settle(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await settle(tester);
    await tester.tap(find.text('State').last);
    await settle(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'FAILED'));
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('unreadable saved settings: nothing is recalculated nor saved, and the user is told', (tester) async {
    // Readable mappings, but an amount formula that is not a list of terms.
    await config('{"date":"Date","amount":"Amount","__balanceMode":"cumulative"}', formulaJson: '{"operator":"+"}');
    try {
      await openDialog(tester);
      await pickFilteredDone(tester);
      await tester.tap(find.widgetWithText(FilledButton, s.recalculate));
      await settle(tester);
      expect(tester.takeException(), isNull);

      expect(await balances(), [null, null, null], reason: 'no balance in a mode the account does not keep');
      expect((await stored()).mappingsJson, '{"date":"Date","amount":"Amount","__balanceMode":"cumulative"}');
      expect((await stored()).formulaJson, '{"operator":"+"}', reason: 'unreadable settings are not rewritten');
      expect(find.descendant(of: find.byType(SnackBar), matching: find.text(s.balanceSettingsUnreadable)), findsOneWidget);

      // What an automatic recalculation does with the saved settings is what
      // the account shows: the dialog did not leave a mode it would revert.
      await TransactionService(db).recalcFromImportConfig(account.id);
      expect(await balances(), [100, 70, 80]);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('pin: readable settings: the picked mode is applied and saved', (tester) async {
    await config('{"date":"Date","amount":"Amount","__balanceMode":"cumulative"}');
    try {
      await openDialog(tester);
      await pickFilteredDone(tester);
      await tester.tap(find.widgetWithText(FilledButton, s.recalculate));
      await settle(tester);
      expect(await balances(), [100, 100, 110]);
      final saved = jsonDecode((await stored()).mappingsJson) as Map<String, dynamic>;
      expect((saved['__balanceMode'], saved['__balanceFilterColumn']), ('filtered', 'State'));
      await TransactionService(db).recalcFromImportConfig(account.id);
      expect(await balances(), [100, 100, 110], reason: 'the automatic recalculation keeps the saved mode');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('the screen goes away while the recalculation runs: the mode is still saved', (tester) async {
    await config('{"date":"Date","amount":"Amount","__balanceMode":"cumulative"}');
    final transactions = _GatedTransactionService(db);
    await openDialog(tester, transactions: transactions);
    await pickFilteredDone(tester);
    await tester.tap(find.widgetWithText(FilledButton, s.recalculate));
    await settle(tester);
    await unmount(tester);

    transactions.gate.open();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(await balances(), [100, 100, 110]);
    expect((jsonDecode((await stored()).mappingsJson) as Map<String, dynamic>)['__balanceMode'], 'filtered');
  });
}
