import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/ledger_roles.dart';
import 'package:finance_copilot/services/domain/adjustment_items.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction tx(int id, int acct, double amount, DateTime date, {TransactionStatus status = TransactionStatus.settled, BankEntryKind? kind}) =>
    Transaction(
      id: id,
      accountId: acct,
      operationDate: date,
      valueDate: date,
      amount: amount,
      description: 'tx $id',
      status: status,
      currency: 'EUR',
      tags: '[]',
      createdAt: date,
      entryKind: kind,
    );

void main() {
  final d = DateTime(2024, 5, 2);

  test('transfer pairs, no-op pairs, cancelled and adjustment anchors get a role; everything else none', () {
    final event = ExtraordinaryEvent(
      id: 1,
      name: 'Dental',
      direction: EventDirection.outflow,
      treatment: EventTreatment.instant,
      totalAmount: 3000,
      currency: 'EUR',
      eventDate: d,
      isEphemeral: false,
      isActive: true,
      createdAt: d,
      updatedAt: d,
    );
    final roles = resolveLedgerRoles(
      transactions: [
        tx(1, 1, -500, d), // transfer out
        tx(2, 2, 500, d), // transfer in
        tx(3, 1, -30, d), // no-op leg
        tx(4, 1, 30, d), // no-op leg
        tx(5, 1, -12, d, status: TransactionStatus.cancelled),
        tx(6, 1, -3000, d), // adjustment anchor
        tx(7, 1, -8, d), // plain spending
        tx(8, 1, -500, DateTime(2024, 5, 9)), // unpaired: no role
      ],
      adjustments: AdjustmentInputs(events: [event], entriesByEvent: const {}, reimbursementsByEvent: const {}),
    );
    expect(roles[1], LedgerRole.transfer);
    expect(roles[2], LedgerRole.transfer);
    expect(roles[3], LedgerRole.noOp);
    expect(roles[4], LedgerRole.noOp);
    expect(roles[5], LedgerRole.cancelled);
    expect(roles[6], LedgerRole.adjustment);
    expect(roles.containsKey(7), isFalse);
    expect(roles.containsKey(8), isFalse);
  });

  test('cancelled wins over any pairing role', () {
    final roles = resolveLedgerRoles(
      transactions: [
        tx(1, 1, -500, d, status: TransactionStatus.cancelled),
        tx(2, 2, 500, d),
      ],
      adjustments: AdjustmentInputs.empty,
    );
    expect(roles[1], LedgerRole.cancelled);
    expect(roles[2], LedgerRole.transfer);
  });

  test('bank-declared card top-ups and FX exchanges are transfers even without a visible other leg', () {
    final roles = resolveLedgerRoles(
      transactions: [
        tx(1, 1, 150, d, kind: BankEntryKind.cardTopUp),
        tx(2, 1, -20, d, kind: BankEntryKind.fxExchange),
        tx(3, 1, -20, d, kind: BankEntryKind.cardPayment),
        tx(4, 1, 500, d, kind: BankEntryKind.transfer), // a declared bank transfer is NOT excluded: it may be salary/rent
        tx(5, 1, 150, d, kind: BankEntryKind.cardTopUp, status: TransactionStatus.cancelled),
      ],
      adjustments: AdjustmentInputs.empty,
    );
    expect(roles[1], LedgerRole.transfer);
    expect(roles[2], LedgerRole.transfer);
    expect(roles.containsKey(3), isFalse);
    expect(roles.containsKey(4), isFalse);
    expect(roles[5], LedgerRole.cancelled);
  });

  test('a top-up pairs only by exact day: a same-amount outflow days apart stays unexplained spending', () {
    final roles = resolveLedgerRoles(
      transactions: [
        tx(1, 2, 150, DateTime(2024, 5, 10), kind: BankEntryKind.cardTopUp), // e-money account credited
        tx(2, 1, -150, DateTime(2024, 5, 12), kind: BankEntryKind.cardPayment), // booked 2 days later: not paired
        tx(3, 2, 100, DateTime(2024, 5, 20), kind: BankEntryKind.cardTopUp),
        tx(4, 1, -100, DateTime(2024, 5, 20), kind: BankEntryKind.cardPayment), // same day: paired
      ],
      adjustments: AdjustmentInputs.empty,
    );
    expect(roles[1], LedgerRole.transfer, reason: 'bank-declared top-up is a transfer on its own');
    expect(roles.containsKey(2), isFalse);
    expect(roles[3], LedgerRole.transfer);
    expect(roles[4], LedgerRole.transfer);
  });

  test('empty ledger', () {
    expect(resolveLedgerRoles(transactions: const [], adjustments: AdjustmentInputs.empty), isEmpty);
  });
}
