import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';

/// A matched pair of transactions (inflow id + outflow id) produced by
/// [pairTransactions]. Pure data — UI layers map these to display entries.
class TxPair {
  final int inflowId;
  final int outflowId;
  const TxPair(this.inflowId, this.outflowId);

  @override
  bool operator ==(Object other) => other is TxPair && other.inflowId == inflowId && other.outflowId == outflowId;
  @override
  int get hashCode => Object.hash(inflowId, outflowId);
  @override
  String toString() => 'TxPair(+$inflowId / -$outflowId)';
}

/// Result of pairing transactions in the All-Accounts view.
class TxPairing {
  /// Cross-account transfers: same day/currency/|amount|, opposite sign,
  /// DIFFERENT account.
  final List<TxPair> transfers;

  /// Same-account no-ops: same day/currency/|amount|, opposite sign, SAME
  /// account — net to zero (charge reversed / round-trip). Cancelled rows are
  /// never paired here.
  final List<TxPair> noOps;

  const TxPairing({required this.transfers, required this.noOps});
}

/// Deterministic pairing used by the read-only All-Accounts ledger.
///
/// Two passes over buckets keyed by (dayKey, currency, |amount in cents|):
///   1. cross-account transfers (different account) — runs first so a genuine
///      transfer is never mis-collapsed as a same-account no-op;
///   2. same-account no-ops (same account) among rows not already paired,
///      excluding cancelled rows.
/// Greedy 1:1, ordered by transaction id for stable, reproducible results.
TxPairing pairTransactions(List<Transaction> txs, int Function(DateTime) dayKey) {
  final buckets = <String, ({List<Transaction> pos, List<Transaction> neg})>{};
  for (final t in txs) {
    if (t.amount == 0) continue;
    final cents = (t.amount.abs() * 100).round();
    final k = '${dayKey(t.valueDate)}|${t.currency}|$cents';
    final bucket = buckets[k] ?? (pos: <Transaction>[], neg: <Transaction>[]);
    if (t.amount > 0) {
      bucket.pos.add(t);
    } else {
      bucket.neg.add(t);
    }
    buckets[k] = bucket;
  }

  // Sort each bucket leg by id for determinism.
  for (final b in buckets.values) {
    b.pos.sort((a, c) => a.id.compareTo(c.id));
    b.neg.sort((a, c) => a.id.compareTo(c.id));
  }

  final paired = <int>{};
  final transfers = <TxPair>[];
  final noOps = <TxPair>[];

  // Pass 1 — cross-account transfers.
  for (final b in buckets.values) {
    if (b.pos.isEmpty || b.neg.isEmpty) continue;
    final consumed = <int>{};
    for (final p in b.pos) {
      for (final n in b.neg) {
        if (consumed.contains(n.id) || n.accountId == p.accountId) continue;
        consumed.add(n.id);
        paired
          ..add(p.id)
          ..add(n.id);
        transfers.add(TxPair(p.id, n.id));
        break;
      }
    }
  }

  // Pass 2 — same-account no-ops (exclude cancelled, exclude already paired).
  bool eligible(Transaction t) => !paired.contains(t.id) && t.status != TransactionStatus.cancelled;
  for (final b in buckets.values) {
    final pos = b.pos.where(eligible).toList();
    final neg = b.neg.where(eligible).toList();
    if (pos.isEmpty || neg.isEmpty) continue;
    final consumed = <int>{};
    for (final p in pos) {
      for (final n in neg) {
        if (consumed.contains(n.id) || n.accountId != p.accountId) continue;
        consumed.add(n.id);
        paired
          ..add(p.id)
          ..add(n.id);
        noOps.add(TxPair(p.id, n.id));
        break;
      }
    }
  }

  return TxPairing(transfers: transfers, noOps: noOps);
}
