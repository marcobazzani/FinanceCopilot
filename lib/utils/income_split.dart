/// Pure money math for splitting ONE inflow across several [IncomeType]s.
///
/// A bank inflow is frequently a mix: part salary/income, part expense refund,
/// part pension contribution. Instead of forcing 100% of the transaction under
/// a single type, the user allocates each slice and one `Income` row is created
/// per non-zero slice.
///
/// All comparisons happen in integer cents so `33.33 + 33.33 + 33.34` exactly
/// matches a `100.00` total (binary doubles do not). Per the project's
/// financial-accuracy rule the plan NEVER silently absorbs a difference: an
/// unbalanced split is reported as [IncomeSplitError.mismatch] with the signed
/// remainder so the UI can block the save and show what is missing.
library;

import 'package:finance_copilot/database/tables.dart';

/// One allocated slice of an inflow.
class IncomeSplitEntry {
  const IncomeSplitEntry(this.type, this.amount);

  final IncomeType type;
  final double amount;

  @override
  bool operator ==(Object other) => other is IncomeSplitEntry && other.type == type && incomeCents(other.amount) == incomeCents(amount);

  @override
  int get hashCode => Object.hash(type, incomeCents(amount));

  @override
  String toString() => 'IncomeSplitEntry(${type.name}, $amount)';
}

/// Why a split cannot be saved. [none] means the plan is valid.
enum IncomeSplitError {
  none,

  /// Every slice is empty or zero — nothing to record.
  empty,

  /// At least one slice is negative. Inflow slices are always positive.
  negative,

  /// The slices do not add up to the total (see [IncomeSplitPlan.remainder]).
  mismatch,
}

/// Round a monetary amount to integer cents.
int incomeCents(double value) => (value * 100).round();

/// The outcome of validating a proposed split.
class IncomeSplitPlan {
  const IncomeSplitPlan({
    required this.entries,
    required this.remainderCents,
    required this.error,
  });

  /// Non-zero slices, ordered by [IncomeType.values].
  final List<IncomeSplitEntry> entries;

  /// `total - sum(slices)` in cents. Positive = under-allocated,
  /// negative = over-allocated, zero = balanced.
  final int remainderCents;

  final IncomeSplitError error;

  bool get isValid => error == IncomeSplitError.none;

  bool get isBalanced => remainderCents == 0;

  double get remainder => remainderCents / 100;
}

/// Validate [parts] against [total].
///
/// `null` (or absent) parts mean "not allocated" and are treated as zero. A
/// plan is valid only when at least one slice is non-zero, no slice is
/// negative, and the slices add up to [total] to the cent.
IncomeSplitPlan planIncomeSplit({
  required double total,
  required Map<IncomeType, double?> parts,
}) {
  final totalCents = incomeCents(total);
  var sumCents = 0;
  var hasNegative = false;
  final entries = <IncomeSplitEntry>[];

  for (final type in IncomeType.values) {
    final value = parts[type];
    if (value == null) continue;
    final cents = incomeCents(value);
    if (cents < 0) hasNegative = true;
    sumCents += cents;
    if (cents != 0) entries.add(IncomeSplitEntry(type, cents / 100));
  }

  final remainderCents = totalCents - sumCents;
  final IncomeSplitError error;
  if (hasNegative) {
    error = IncomeSplitError.negative;
  } else if (entries.isEmpty) {
    error = IncomeSplitError.empty;
  } else if (remainderCents != 0) {
    error = IncomeSplitError.mismatch;
  } else {
    error = IncomeSplitError.none;
  }

  return IncomeSplitPlan(entries: entries, remainderCents: remainderCents, error: error);
}
