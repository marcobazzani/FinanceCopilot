// Saving a row (create or edit) re-runs the account's running balance. The
// contract the edit form relies on:
//
//  (a) that recalculation never changes the STATUS of the row just saved:
//      in filtered mode a row the user set to Settled was flipped back to
//      Cancelled at once (a hand-entered row has no statement data, so the
//      filter excluded it). Every other row is recalculated as before.
//  (b) `balance_after` stays derived in an account whose saved config
//      computes balances (cumulative / column / filtered); without such a
//      config (none, the `{}` number-format placeholder, an explicit none, a
//      config that stores no mode) a typed balance stays exactly as typed. An
//      edit of the balance alone used to skip the recalculation, so a typed
//      figure survived in a computing account.
//  (c) the write and its recalculation are one DB transaction: a failed
//      recalculation used to leave the new row inserted (a second Save then
//      duplicated it) or the edit written.
import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/transaction_service.dart';

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

  Future<void> config(Map<String, Object?> mappings, {int? account}) => db
      .into(db.importConfigs)
      .insert(
        ImportConfigsCompanion.insert(
          accountId: Value(account ?? acct),
          mappingsJson: Value(jsonEncode(mappings)),
          numberLocale: const Value('en_US'),
        ),
      );

  const filtered = {
    '__balanceMode': 'filtered',
    '__balanceFilterColumn': 'State',
    '__balanceFilterInclude': '["DONE"]',
  };

  /// A row as an import stores it: statement cells, balance, status.
  Future<int> imported(int day, double amount, String state, {TransactionStatus status = TransactionStatus.settled, int? account}) => db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          accountId: account ?? acct,
          operationDate: DateTime(2025, 1, day),
          valueDate: DateTime(2025, 1, day),
          amount: amount,
          description: Value('Day $day'),
          status: Value(status),
          rawMetadata: Value(jsonEncode({'State': state})),
        ),
      );

  Future<Transaction> row(int id) => (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();

  Future<int> count() async => (await db.select(db.transactions).get()).length;

  group('(a) the saved row keeps the status the user gave it', () {
    test('create in filtered mode: a Settled hand-entered row stays Settled; other rows are recalculated as before', () async {
      await config(filtered);
      await imported(1, 100, 'DONE');
      // Stale: excluded by the filter but still settled — the recalculation
      // cancels it, as it always did.
      final stale = await imported(2, -30, 'FAILED');

      final id = await service.create(
        accountId: acct,
        operationDate: DateTime(2025, 1, 3),
        amount: -10,
        currency: 'EUR',
        description: 'cash',
      );

      expect((await row(id)).status, TransactionStatus.settled);
      expect((await row(stale)).status, TransactionStatus.cancelled, reason: 'other rows as before');
    });

    test('create in filtered mode: a Pending row stays Pending', () async {
      await config(filtered);
      await imported(1, 100, 'DONE');
      final id = await service.create(
        accountId: acct,
        operationDate: DateTime(2025, 1, 3),
        amount: -10,
        currency: 'EUR',
        status: TransactionStatus.pending,
      );
      expect((await row(id)).status, TransactionStatus.pending);
    });

    test('edit in filtered mode: an excluded row the user sets to Settled stays Settled', () async {
      await config(filtered);
      await imported(1, 100, 'DONE');
      final failed = await imported(2, -30, 'FAILED', status: TransactionStatus.cancelled);

      expect(await service.update(failed, const TransactionsCompanion(status: Value(TransactionStatus.settled))), isTrue);
      expect((await row(failed)).status, TransactionStatus.settled);
    });

    test('edit that moves a row into a filtered account keeps its status there', () async {
      final other = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Other'));
      await config(filtered, account: other);
      await imported(1, 100, 'DONE', account: other);
      final moved = await imported(2, -30, 'FAILED');

      await service.update(moved, TransactionsCompanion(accountId: Value(other), amount: const Value(-31)));
      expect((await row(moved)).status, TransactionStatus.settled);
    });

    test('the row still does not move a filtered balance its filter value excludes', () async {
      await config(filtered);
      final done = await imported(1, 100, 'DONE');
      final id = await service.create(accountId: acct, operationDate: DateTime(2025, 1, 3), amount: -10, currency: 'EUR');
      expect((await row(done)).balanceAfter, 100);
      expect((await row(id)).balanceAfter, 100);
    });
  });

  group('(b) balance_after: derived in a computing account, as typed elsewhere', () {
    test('create in a cumulative account: a typed balance is replaced by the running balance', () async {
      await config({'__balanceMode': 'cumulative'});
      await imported(1, 100, 'DONE');
      final id = await service.create(accountId: acct, operationDate: DateTime(2025, 1, 3), amount: -10, balanceAfter: 500, currency: 'EUR');
      expect((await row(id)).balanceAfter, 90);
    });

    for (final (what, mappings) in [
      ('no import config', null),
      ('the number-format placeholder', <String, Object?>{}),
      ('an explicit none', {'__balanceMode': 'none'}),
    ]) {
      test('create with $what: the typed balance stays exactly as typed', () async {
        if (mappings != null) await config(mappings);
        final id = await service.create(
          accountId: acct,
          operationDate: DateTime(2025, 1, 3),
          amount: -99.99,
          balanceAfter: 500,
          currency: 'EUR',
        );
        expect((await row(id)).balanceAfter, 500);
      });

      test('edit of the balance alone with $what: stays exactly as typed', () async {
        if (mappings != null) await config(mappings);
        final id = await imported(1, 100, 'DONE');
        await service.update(id, const TransactionsCompanion(balanceAfter: Value(1234.56)));
        expect((await row(id)).balanceAfter, 1234.56);
      });
    }

    test('edit of the balance alone in a cumulative account: re-derived', () async {
      await config({'__balanceMode': 'cumulative'});
      final first = await imported(1, 100, 'DONE');
      final second = await imported(2, -30, 'DONE');
      await service.recalculateBalances(acct, balanceMode: 'cumulative');

      await service.update(second, const TransactionsCompanion(balanceAfter: Value(500)));
      expect((await row(first)).balanceAfter, 100);
      expect((await row(second)).balanceAfter, 70);
    });

    group('computesBalances: the accounts whose balance is derived', () {
      for (final (what, mappings, computes) in [
        ('no import config', null, false),
        ('the number-format placeholder', <String, Object?>{}, false),
        ('an explicit none', {'__balanceMode': 'none'}, false),
        ('unreadable settings', {'__balanceMode': 'cumulativ'}, false),
        ('a config that stores no mode', {'date': 'Date'}, false),
        ('cumulative', {'__balanceMode': 'cumulative'}, true),
        ('column', {'__balanceMode': 'column', 'balanceAfter': 'Balance'}, true),
        ('filtered', filtered, true),
      ]) {
        test('$what: $computes', () async {
          if (mappings != null) await config(mappings);
          expect(await service.computesBalances(acct), computes);
        });
      }
    });
  });

  group('(c) the write and its recalculation are one transaction', () {
    /// The recalculation's balance write fails from now on; the row's own
    /// write (insert, or an update that does not set the balance) does not.
    Future<void> failBalanceWrites() => db.customStatement(
      "CREATE TEMP TRIGGER fail_balance BEFORE UPDATE OF balance_after ON transactions BEGIN SELECT RAISE(ABORT, 'injected failure'); END",
    );

    test('create: a failed recalculation inserts nothing, so saving again cannot duplicate the row', () async {
      await config({'__balanceMode': 'cumulative'});
      await imported(1, 100, 'DONE');
      await service.recalculateBalances(acct, balanceMode: 'cumulative');
      await failBalanceWrites();

      await expectLater(
        service.create(accountId: acct, operationDate: DateTime(2025, 1, 3), amount: -10, currency: 'EUR', description: 'cash'),
        throwsA(anything),
      );
      expect(await count(), 1, reason: 'nothing inserted');
    });

    test('edit: a failed recalculation leaves the row as it was', () async {
      await config({'__balanceMode': 'cumulative'});
      final id = await imported(1, 100, 'DONE');
      await service.recalculateBalances(acct, balanceMode: 'cumulative');
      await failBalanceWrites();

      await expectLater(service.update(id, const TransactionsCompanion(amount: Value(120))), throwsA(anything));
      final after = await row(id);
      expect(after.amount, 100, reason: 'the edit is rolled back with its recalculation');
      expect(after.balanceAfter, 100);
    });

    test('baseline: without a failure the row and its balance are written', () async {
      await config({'__balanceMode': 'cumulative'});
      await imported(1, 100, 'DONE');
      final id = await service.create(accountId: acct, operationDate: DateTime(2025, 1, 3), amount: -10, currency: 'EUR');
      expect(await count(), 2);
      expect((await row(id)).balanceAfter, 90);
    });
  });
}
