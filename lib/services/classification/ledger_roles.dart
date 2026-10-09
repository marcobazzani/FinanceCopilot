import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/adjustment_items.dart';
import 'package:finance_copilot/services/domain/entry_pairing.dart';

/// Structural role the ledger already assigns to a row. Rows with a role are
/// explained by the ledger itself (a pair, an adjustment, a cancelled line)
/// and therefore NEVER take part in categorization: no rule is applied to
/// them, they are not queued in the wizard, and they are excluded from
/// progress counts and from spending charts.
enum LedgerRole {
  /// Cross-account pair (same day, currency, |amount|, opposite sign), or a
  /// movement the bank itself declares as one — a card top-up or an FX
  /// exchange — whose other leg may live outside the ledger or settle on a
  /// later day.
  transfer,

  /// Same-account pair netting to zero (charge + reversal).
  noOp,

  /// Anchor / entry / reimbursement of an extraordinary event.
  adjustment,

  /// `status == cancelled`.
  cancelled,
}

/// Bank-declared entry kinds that are money moving between the user's own
/// instruments, never spending or income — a transfer even when the other
/// leg lives in an account that was never imported.
const _declaredTransferKinds = {BankEntryKind.cardTopUp, BankEntryKind.fxExchange};

int ledgerDayKey(DateTime d) => DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;

/// Resolve the [LedgerRole] of every structurally-explained row, using the
/// exact same deterministic logic as the All-Accounts ledger view
/// ([pairTransactions] + [resolveAdjustments]). Pure: no IO.
Map<int, LedgerRole> resolveLedgerRoles({required List<Transaction> transactions, required AdjustmentInputs adjustments}) {
  final roles = <int, LedgerRole>{};

  for (final t in transactions) {
    if (t.status == TransactionStatus.cancelled) {
      roles[t.id] = LedgerRole.cancelled;
    } else if (_declaredTransferKinds.contains(t.entryKind)) {
      roles[t.id] = LedgerRole.transfer;
    }
  }

  final pairing = pairTransactions(transactions, ledgerDayKey);
  for (final p in pairing.transfers) {
    roles.putIfAbsent(p.inflowId, () => LedgerRole.transfer);
    roles.putIfAbsent(p.outflowId, () => LedgerRole.transfer);
  }
  for (final p in pairing.noOps) {
    roles.putIfAbsent(p.inflowId, () => LedgerRole.noOp);
    roles.putIfAbsent(p.outflowId, () => LedgerRole.noOp);
  }

  if (adjustments.events.isNotEmpty) {
    String same(String n) => n;
    final adj = resolveAdjustments(
      events: adjustments.events,
      entriesByEvent: adjustments.entriesByEvent,
      reimbursementsByEvent: adjustments.reimbursementsByEvent,
      transactions: transactions,
      dayKey: ledgerDayKey,
      adjustedLabel: same,
      reimbLabel: same,
      savingForLabel: same,
      financedLabel: same,
    );
    for (final id in adj.annotatedTxIds.keys) {
      roles.putIfAbsent(id, () => LedgerRole.adjustment);
    }
  }
  return roles;
}
