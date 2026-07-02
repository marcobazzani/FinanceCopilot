// All-Accounts entry pairing — pure logic tests.
//
// Pins two passes:
//   1. cross-account transfers (different account), and
//   2. same-account no-ops (+X/-X same day, same account) — excluded from
//      totals, cancelled rows never paired.
// Transfers are matched FIRST so a genuine transfer is never mis-collapsed
// as a same-account no-op.

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/ui/screens/accounts/entry_pairing.dart';

void main() {
  late AppDatabase db;
  late int accA;
  late int accB;

  int dayKey(DateTime d) => DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    accA = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'A'));
    accB = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'B'));
  });

  tearDown(() async => db.close());

  Future<Transaction> tx({
    required int account,
    required double amount,
    required DateTime date,
    String desc = '',
    TransactionStatus status = TransactionStatus.settled,
  }) async {
    final id = await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: account,
            operationDate: date,
            valueDate: date,
            amount: amount,
            description: Value(desc),
            status: Value(status),
          ),
        );
    return (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();
  }

  test('same-account +X/-X same day collapses into a no-op (no transfer)', () async {
    final pos = await tx(account: accA, amount: 507.68, date: DateTime(2025, 1, 16), desc: 'refund');
    final neg = await tx(account: accA, amount: -507.68, date: DateTime(2025, 1, 16), desc: 'charge');

    final r = pairTransactions([pos, neg], dayKey);
    expect(r.transfers, isEmpty);
    expect(r.noOps, hasLength(1));
    expect(r.noOps.single.inflowId, pos.id);
    expect(r.noOps.single.outflowId, neg.id);
  });

  test('cross-account +X/-X is a transfer, NOT a no-op', () async {
    final pos = await tx(account: accB, amount: 100.0, date: DateTime(2025, 1, 10));
    final neg = await tx(account: accA, amount: -100.0, date: DateTime(2025, 1, 10));

    final r = pairTransactions([pos, neg], dayKey);
    expect(r.noOps, isEmpty);
    expect(r.transfers, hasLength(1));
  });

  test('transfer pass wins: cross-account pair consumed before same-account', () async {
    // One -100 on A; two +100 same day: one on B (transfer), one on A (no-op).
    final negA = await tx(account: accA, amount: -100.0, date: DateTime(2025, 2, 1));
    final posB = await tx(account: accB, amount: 100.0, date: DateTime(2025, 2, 1));
    final posA = await tx(account: accA, amount: 100.0, date: DateTime(2025, 2, 1));

    final r = pairTransactions([negA, posB, posA], dayKey);
    // The -100 on A pairs with +100 on B as a transfer (different account first).
    expect(r.transfers, hasLength(1));
    expect(r.transfers.single.inflowId, posB.id);
    expect(r.transfers.single.outflowId, negA.id);
    // The leftover +100 on A has no same-account negative left → not a no-op.
    expect(r.noOps, isEmpty);
  });

  test('cancelled rows are never paired as no-ops', () async {
    final pos = await tx(account: accA, amount: 50.0, date: DateTime(2025, 3, 3), status: TransactionStatus.cancelled);
    final neg = await tx(account: accA, amount: -50.0, date: DateTime(2025, 3, 3));

    final r = pairTransactions([pos, neg], dayKey);
    expect(r.noOps, isEmpty);
    expect(r.transfers, isEmpty);
  });

  test('different day does not pair', () async {
    final pos = await tx(account: accA, amount: 30.0, date: DateTime(2025, 4, 1));
    final neg = await tx(account: accA, amount: -30.0, date: DateTime(2025, 4, 2));

    final r = pairTransactions([pos, neg], dayKey);
    expect(r.noOps, isEmpty);
  });

  test('different amount does not pair', () async {
    final pos = await tx(account: accA, amount: 30.0, date: DateTime(2025, 4, 1));
    final neg = await tx(account: accA, amount: -31.0, date: DateTime(2025, 4, 1));

    final r = pairTransactions([pos, neg], dayKey);
    expect(r.noOps, isEmpty);
  });

  test('odd leftover stays unpaired (two -X, one +X same account/day)', () async {
    final neg1 = await tx(account: accA, amount: -20.0, date: DateTime(2025, 5, 5));
    final neg2 = await tx(account: accA, amount: -20.0, date: DateTime(2025, 5, 5));
    final pos = await tx(account: accA, amount: 20.0, date: DateTime(2025, 5, 5));

    final r = pairTransactions([neg1, neg2, pos], dayKey);
    expect(r.noOps, hasLength(1)); // exactly one +/- pair collapses
    expect(r.transfers, isEmpty);
  });

  test('deterministic: pairing is stable regardless of input order', () async {
    final pos = await tx(account: accA, amount: 75.0, date: DateTime(2025, 6, 1));
    final neg = await tx(account: accA, amount: -75.0, date: DateTime(2025, 6, 1));

    final r1 = pairTransactions([pos, neg], dayKey);
    final r2 = pairTransactions([neg, pos], dayKey);
    expect(r1.noOps, equals(r2.noOps));
  });
}
