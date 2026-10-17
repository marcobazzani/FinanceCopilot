// `TransactionService.planOpeningBalance`: what adding an opening-balance
// transaction would create, for a bank export that doesn't start at the
// account's inception. Read-only — it never writes; the caller creates the
// transaction itself via `create`, the same path "Add transaction" uses, so
// nothing downstream (categorization, spending, the ledger, Cash Flow) has
// to treat it specially.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/domain/transaction_service.dart';
import 'package:finance_copilot/services/import/stored_import_data.dart';

void main() {
  late AppDatabase db;
  late TransactionService service;
  late int acct;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = TransactionService(db);
    acct = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
  });
  tearDown(() => db.close());

  Future<int> row(DateTime value, double amount, double balance, {DateTime? booking}) => db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          accountId: acct,
          operationDate: booking ?? value,
          valueDate: value,
          amount: amount,
          balanceAfter: Value(balance),
        ),
      );

  group('cumulative', () {
    test('the amount that brings the account to the actual balance, dated the day before the earliest row', () async {
      await row(DateTime(2026, 3, 1), 100, 100);
      await row(DateTime(2026, 3, 5), -40, 60);
      final plan = await service.planOpeningBalance(accountId: acct, balanceMode: BalanceMode.cumulative, actualBalance: 560);
      expect(plan, isNotNull);
      expect(plan!.amount, 500, reason: '560 actual − 60 the app shows');
      expect(plan.anchorDate, DateTime(2026, 2, 28), reason: 'the day before the earliest row');
    });

    test('a negative difference (the app overstates the balance)', () async {
      await row(DateTime(2026, 3, 1), 100, 100);
      final plan = await service.planOpeningBalance(accountId: acct, balanceMode: BalanceMode.cumulative, actualBalance: 70);
      expect(plan!.amount, -30);
    });

    test('null when the balances already match', () async {
      await row(DateTime(2026, 3, 1), 100, 100);
      final plan = await service.planOpeningBalance(accountId: acct, balanceMode: BalanceMode.cumulative, actualBalance: 100);
      expect(plan, isNull);
    });

    test('null when the account has no transactions', () async {
      final plan = await service.planOpeningBalance(accountId: acct, balanceMode: BalanceMode.cumulative, actualBalance: 100);
      expect(plan, isNull);
    });

    test('null when no row has a computed balance yet (not recalculated)', () async {
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(accountId: acct, operationDate: DateTime(2026, 3, 1), valueDate: DateTime(2026, 3, 1), amount: 100),
          );
      final plan = await service.planOpeningBalance(accountId: acct, balanceMode: BalanceMode.cumulative, actualBalance: 999);
      expect(plan, isNull);
    });

    test('cents, not float: no drift', () async {
      await row(DateTime(2026, 3, 1), 10.1, 10.1);
      final plan = await service.planOpeningBalance(accountId: acct, balanceMode: BalanceMode.cumulative, actualBalance: 1245.65);
      expect(plan!.amount, 1235.55);
    });

    test('anchored before the earliest VALUE date, even if a later row was booked earlier', () async {
      // Row booked 3-10 but value-dated 3-12 (a card payment settling late);
      // row booked 3-11 but value-dated 3-9 (settling early). The earliest
      // date on EITHER timeline must be respected, so a later import cannot
      // land after this one on either axis.
      await row(DateTime(2026, 3, 12), 100, 70, booking: DateTime(2026, 3, 10));
      await row(DateTime(2026, 3, 9), -30, -30, booking: DateTime(2026, 3, 11));
      final plan = await service.planOpeningBalance(accountId: acct, balanceMode: BalanceMode.cumulative, actualBalance: 170);
      expect(plan!.anchorDate, DateTime(2026, 3, 8), reason: 'the day before 3-9, the earliest date on either timeline');
    });
  });

  group('filtered', () {
    test('works the same way: the latest row carries a balance even when excluded', () async {
      await row(DateTime(2026, 1, 1), 100, 100);
      final plan = await service.planOpeningBalance(accountId: acct, balanceMode: BalanceMode.filtered, actualBalance: 150);
      expect(plan!.amount, 50);
    });
  });

  group('unsupported modes: refused, nothing guessed', () {
    for (final mode in [BalanceMode.column, BalanceMode.none]) {
      test('${mode.name} mode: null even with a real difference', () async {
        await row(DateTime(2026, 1, 1), 100, 100);
        final plan = await service.planOpeningBalance(accountId: acct, balanceMode: mode, actualBalance: 99999);
        expect(plan, isNull);
      });
    }
  });
}
