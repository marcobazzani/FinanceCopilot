import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';

/// The kind of ledger row, used by the account-detail filter chips.
///
/// A single row maps to exactly one [EntryKind]. The classification is pure
/// (no UI) so it can be unit-tested and reused by both the single-account and
/// merged All-Accounts views.
enum EntryKind {
  /// A settled transaction with amount > 0 (money in).
  inflow,

  /// A settled transaction with amount < 0 (money out).
  outflow,

  /// A same-account +X/-X same-day pair that nets to zero, OR a settled
  /// transaction with amount == 0. Moved no net money.
  noOp,

  /// A transaction whose status is cancelled (never moved money).
  cancelled,

  /// A cross-account transfer (two opposing legs on different accounts).
  /// Only ever produced in the merged All-Accounts view.
  transfer,

  /// A synthetic adjustment row (e.g. "Saving for X") or a transaction
  /// annotated as an extraordinary-event anchor/reimbursement. Only ever
  /// produced in the merged All-Accounts view.
  adjustment,
}

/// Classifies a single, standalone [Transaction] (one that did NOT collapse
/// into a transfer/no-op pair) into its set of [EntryKind]s.
///
/// A row can carry several kinds at once:
///   * sign drives [EntryKind.inflow] / [EntryKind.outflow] (amount 0 → noOp);
///   * a cancelled row additionally carries [EntryKind.cancelled] (it is still
///     an inflow/outflow row, just struck through and out of totals).
/// Adjustment annotation is layered on by the caller (it needs the resolved
/// annotation map), so it is NOT added here.
Set<EntryKind> classifyTransactionKinds(Transaction tx) {
  final kinds = <EntryKind>{};
  if (tx.status == TransactionStatus.cancelled) kinds.add(EntryKind.cancelled);
  if (tx.amount > 0) {
    kinds.add(EntryKind.inflow);
  } else if (tx.amount < 0) {
    kinds.add(EntryKind.outflow);
  } else {
    kinds.add(EntryKind.noOp);
  }
  return kinds;
}

/// An inclusive date-range bound on a row's value date. Either end may be
/// null (open-ended). Comparison is done on the calendar day, so the upper
/// bound includes the entire [end] day.
class DateRangeFilter {
  final DateTime? start;
  final DateTime? end;
  const DateRangeFilter({this.start, this.end});

  bool get isEmpty => start == null && end == null;

  /// True when [date]'s calendar day is within [start]..[end] inclusive.
  bool contains(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    if (start != null) {
      final s = DateTime(start!.year, start!.month, start!.day);
      if (d.isBefore(s)) return false;
    }
    if (end != null) {
      final e = DateTime(end!.year, end!.month, end!.day);
      if (d.isAfter(e)) return false;
    }
    return true;
  }
}

/// Direction scope for the amount filter: apply the magnitude bound to
/// inflows only, outflows only, or either sign.
enum AmountDirection { both, inflow, outflow }

/// An inclusive numeric bound on a row's representative amount. The bound is
/// compared against the row's *absolute* amount (magnitude), so the same
/// threshold works for inflows and outflows. [direction] optionally scopes the
/// bound to one sign. Either end may be null (open-ended).
class AmountRangeFilter {
  final double? min;
  final double? max;
  final AmountDirection direction;

  /// When true the magnitude bound is inverted: a row matches when its
  /// |amount| falls OUTSIDE [min]..[max] (below min or above max) rather than
  /// inside it. Only meaningful when at least one bound is set; with no bound
  /// it has no effect.
  final bool outside;

  const AmountRangeFilter({this.min, this.max, this.direction = AmountDirection.both, this.outside = false});

  bool get isEmpty => min == null && max == null && direction == AmountDirection.both;

  /// True when [amount] passes the direction scope AND its magnitude is within
  /// (or, when [outside], beyond) [min]..[max] inclusive.
  bool contains(double amount) {
    switch (direction) {
      case AmountDirection.inflow:
        if (amount < 0) return false;
      case AmountDirection.outflow:
        if (amount > 0) return false;
      case AmountDirection.both:
        break;
    }
    // Direction-only filter (no magnitude bound): the sign check above is the
    // whole test; `outside` has nothing to invert.
    if (min == null && max == null) return true;
    final a = amount.abs();
    final inRange = (min == null || a >= min!) && (max == null || a <= max!);
    return outside ? !inRange : inRange;
  }
}

/// Per-kind selection state in the filter sheet's Type section: a kind can be
/// neutral (no constraint), explicitly shown, or explicitly hidden.
enum KindSel { neutral, include, exclude }

/// Pure, immutable filter applied to the account-detail ledger.
///
/// Semantics (confirmed product decision):
///   * [includeKinds] — "show only": a row passes the kind test if its kind-set
///     intersects this set. Empty = no positive restriction (show all kinds).
///   * [excludeKinds] — "hide": a row is rejected if its kind-set intersects
///     this set. Exclusion wins over inclusion. A kind is never in both sets.
///   * [dateRange] further restricts with AND.
///   * [amountRange] further restricts with AND, on the |amount|.
///   * [containsText] / [excludesText] are case-insensitive text constraints
///     applied to the raw transactions (before pairing/collapsing), AND-ed
///     with the rest. [containsText] is bound to the ledger search box.
class TransactionFilter {
  final Set<EntryKind> includeKinds;
  final Set<EntryKind> excludeKinds;
  final DateRangeFilter dateRange;
  final AmountRangeFilter amountRange;
  final String containsText;
  final String excludesText;

  const TransactionFilter({
    this.includeKinds = const {},
    this.excludeKinds = const {},
    this.dateRange = const DateRangeFilter(),
    this.amountRange = const AmountRangeFilter(),
    this.containsText = '',
    this.excludesText = '',
  });

  static const TransactionFilter none = TransactionFilter();

  /// True when a per-row (kind/date/amount, i.e. non-text) restriction is set.
  /// Text is matched separately, pre-collapse, over the raw transactions.
  bool get hasRowFilter => includeKinds.isNotEmpty || excludeKinds.isNotEmpty || !dateRange.isEmpty || !amountRange.isEmpty;

  bool get hasTextFilter => containsText.isNotEmpty || excludesText.isNotEmpty;

  bool get isActive => hasRowFilter || hasTextFilter;

  /// Count of independent active dimensions, for the "Filters (N)" badge: each
  /// shown/hidden kind counts once; date, amount, and each text term once.
  int get activeCount =>
      includeKinds.length +
      excludeKinds.length +
      (dateRange.isEmpty ? 0 : 1) +
      (amountRange.isEmpty ? 0 : 1) +
      (containsText.isEmpty ? 0 : 1) +
      (excludesText.isEmpty ? 0 : 1);

  TransactionFilter copyWith({
    Set<EntryKind>? includeKinds,
    Set<EntryKind>? excludeKinds,
    DateRangeFilter? dateRange,
    AmountRangeFilter? amountRange,
    String? containsText,
    String? excludesText,
  }) {
    return TransactionFilter(
      includeKinds: includeKinds ?? this.includeKinds,
      excludeKinds: excludeKinds ?? this.excludeKinds,
      dateRange: dateRange ?? this.dateRange,
      amountRange: amountRange ?? this.amountRange,
      containsText: containsText ?? this.containsText,
      excludesText: excludesText ?? this.excludesText,
    );
  }

  KindSel kindSel(EntryKind kind) {
    if (includeKinds.contains(kind)) return KindSel.include;
    if (excludeKinds.contains(kind)) return KindSel.exclude;
    return KindSel.neutral;
  }

  /// Sets [kind] to [sel], keeping include/exclude mutually exclusive.
  TransactionFilter withKindSel(EntryKind kind, KindSel sel) {
    final inc = Set<EntryKind>.of(includeKinds)..remove(kind);
    final exc = Set<EntryKind>.of(excludeKinds)..remove(kind);
    switch (sel) {
      case KindSel.include:
        inc.add(kind);
      case KindSel.exclude:
        exc.add(kind);
      case KindSel.neutral:
        break;
    }
    return copyWith(includeKinds: inc, excludeKinds: exc);
  }

  /// Case-insensitive text test over a row's searchable [haystack]
  /// (description + full description + amount). Passes when it contains
  /// [containsText] (if set) and does NOT contain [excludesText] (if set).
  bool textMatches(String haystack) {
    final h = haystack.toLowerCase();
    if (containsText.isNotEmpty && !h.contains(containsText.toLowerCase())) return false;
    if (excludesText.isNotEmpty && h.contains(excludesText.toLowerCase())) return false;
    return true;
  }

  /// Per-row kind/date/amount test. A row may carry several kinds at once —
  /// e.g. an adjustment-annotated outflow is both outflow AND adjustment — so
  /// the include test passes if ANY selected kind intersects, and the exclude
  /// test rejects if ANY hidden kind intersects.
  bool matches(Set<EntryKind> kinds, DateTime valueDate, double amount) {
    if (includeKinds.isNotEmpty && includeKinds.intersection(kinds).isEmpty) return false;
    if (excludeKinds.isNotEmpty && excludeKinds.intersection(kinds).isNotEmpty) return false;
    if (!dateRange.contains(valueDate)) return false;
    if (!amountRange.contains(amount)) return false;
    return true;
  }
}
