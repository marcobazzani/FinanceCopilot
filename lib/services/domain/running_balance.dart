/// Running balance on the app's single timeline (value date): anchored on the
/// bank's stated closing balance ([anchoredRunningBalances], column mode), or
/// from a known opening ([runningBalances], cumulative and filtered modes).
///
/// A bank's per-row balance column is a running balance **in booking order**.
/// Copying it per row is only right while value date == booking date; as soon
/// as a card payment is value-dated days before it was booked, the two
/// timelines disagree and every chart that reads "balance at day D" shows the
/// balance of a different day (spikes, phantom income/expenses). So the stored
/// `balance_after` is ALWAYS the value-date running balance, and the bank's
/// figure is used only where it is a fact: the closing balance, which fixes
/// the opening — `opening = closing − Σ amounts`. Untracked history, if any,
/// collapses into that one explicit number instead of per-row jumps.
library;

class RunningBalanceRow {
  final DateTime valueDate;

  /// Booking date (operation date): the bank's own order.
  final DateTime bookingDate;

  /// Stable tiebreak within a day (row id, file index).
  final int order;
  final double amount;

  /// The bank's stated balance after this row, when the statement has one.
  final double? statedBalance;

  const RunningBalanceRow({
    required this.valueDate,
    required this.bookingDate,
    required this.order,
    required this.amount,
    this.statedBalance,
  });
}

class AnchoredBalances {
  /// Balance after each input row, aligned to the input order.
  final List<double> balances;

  /// Balance before the first row. 0 when not anchored.
  final double opening;

  /// The bank's closing balance the series was anchored on; null when no row
  /// carries a stated balance (the series then starts from 0).
  final double? bankClosing;

  const AnchoredBalances({required this.balances, required this.opening, required this.bankClosing});
  bool get anchored => bankClosing != null;
}

/// Value-date running balance of [rows], anchored so the last balance equals
/// the bank's closing balance — the stated balance of the last row in
/// BOOKING order that has one. Integer-cent arithmetic.
AnchoredBalances anchoredRunningBalances(List<RunningBalanceRow> rows) {
  if (rows.isEmpty) return const AnchoredBalances(balances: [], opening: 0, bankClosing: null);

  // Anchor: last booked row with a stated balance.
  RunningBalanceRow? anchor;
  for (final r in rows) {
    if (r.statedBalance == null) continue;
    if (anchor == null ||
        r.bookingDate.isAfter(anchor.bookingDate) ||
        (r.bookingDate.isAtSameMomentAs(anchor.bookingDate) && r.order > anchor.order)) {
      anchor = r;
    }
  }
  final sum = rows.fold<int>(0, (s, r) => s + _cents(r.amount));
  final openingCents = anchor == null ? 0 : _cents(anchor.statedBalance!) - sum;
  return AnchoredBalances(balances: _runningFrom(openingCents, rows), opening: openingCents / 100, bankClosing: anchor?.statedBalance);
}

/// Value-date running balance of [rows] from [opening] — the cumulative and
/// filtered modes: the balance after each input row, aligned to the input
/// order. Integer-cent arithmetic. A row for which [moves] is false (filtered
/// mode: its filter value is excluded) leaves the balance where it is. Null
/// for every row when [opening] is null: what the rows continue from is
/// unknown.
List<double?> runningBalances(List<RunningBalanceRow> rows, {required double? opening, bool Function(int index)? moves}) =>
    opening == null ? List<double?>.filled(rows.length, null) : _runningFrom(_cents(opening), rows, moves: moves);

int _cents(double v) => (v * 100).round();

/// The balance after each of [rows] (aligned to the input order), walking
/// them in value-date order — ties by [RunningBalanceRow.order] — from
/// [openingCents]; a row for which [moves] is false does not move it.
List<double> _runningFrom(int openingCents, List<RunningBalanceRow> rows, {bool Function(int index)? moves}) {
  final indexed = List<int>.generate(rows.length, (i) => i)
    ..sort((a, b) {
      final c = rows[a].valueDate.compareTo(rows[b].valueDate);
      return c != 0 ? c : rows[a].order.compareTo(rows[b].order);
    });
  final out = List<double>.filled(rows.length, 0);
  var running = openingCents;
  for (final i in indexed) {
    if (moves == null || moves(i)) running += _cents(rows[i].amount);
    out[i] = running / 100;
  }
  return out;
}
