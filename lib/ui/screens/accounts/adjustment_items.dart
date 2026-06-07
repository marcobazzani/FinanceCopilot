import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';

/// A synthetic "Saving for `<event>`" ledger row, materialized from a spread
/// event's scheduled amortization entry. These have NO matching real
/// transaction (they are the saving schedule, not a bank movement), so they
/// are injected as their own rows and DO count toward the All-Accounts totals
/// — mirroring how NAV distributes the CAPEX over time.
class SavingScheduleItem {
  final DateTime date;
  final double amount; // signed (negative for outflow saving)
  final String eventName;
  const SavingScheduleItem({required this.date, required this.amount, required this.eventName});
}

/// Result of resolving extraordinary events against the transaction list for
/// the read-only All-Accounts view.
class AdjustmentResolution {
  /// Transaction id → badge label. These transactions ALREADY exist (event
  /// anchor or buffer reimbursement); they are shown with the label but
  /// EXCLUDED from income/expense totals (NAV accounts for them via the
  /// adjustment mechanism, not as cashflow).
  final Map<int, String> annotatedTxIds;

  /// Synthetic saving-schedule rows (scheduled spread entries) — shown AND
  /// included in totals.
  final List<SavingScheduleItem> savingItems;

  const AdjustmentResolution({required this.annotatedTxIds, required this.savingItems});
}

/// Labels are produced by callers (localized); this helper takes the three
/// label builders so it stays UI-agnostic and unit-testable.
typedef AdjLabel = String Function(String eventName);

/// Resolve adjustments against transactions, mirroring the dashboard NAV
/// composition (see data_providers.dart §3 EXTRAORDINARY EVENTS):
///
///  • anchor: outflow → match a NEGATIVE tx; inflow → match a POSITIVE tx,
///    same day-key and |totalAmount|. Annotated, excluded from totals.
///  • buffer reimbursements (is_reimbursement): match a POSITIVE tx same
///    day-key and |amount|. Annotated, excluded from totals.
///  • scheduled spread entries: no real tx → emitted as SavingScheduleItem,
///    included in totals.
///  • ephemeral inflows (e.g. credit line): excluded entirely — the matching
///    tx, if any, is annotated (so it stays out of totals) but no saving rows.
///
/// Matching is deterministic exact membership on (dayKey, cents, sign) — no
/// phrase/regex inference. [entriesByEvent] / [reimbursementsByEvent] are
/// pre-grouped so the function does no IO.
AdjustmentResolution resolveAdjustments({
  required List<ExtraordinaryEvent> events,
  required Map<int, List<ExtraordinaryEventEntry>> entriesByEvent,
  required Map<int, List<BufferTransaction>> reimbursementsByEvent,
  required List<Transaction> transactions,
  required int Function(DateTime) dayKey,
  required AdjLabel adjustedLabel,
  required AdjLabel reimbLabel,
  required AdjLabel savingForLabel,
  required AdjLabel financedLabel,
}) {
  // Index transactions by (dayKey, cents) → list, split by sign, for exact
  // matching. Each tx may be consumed at most once.
  final consumed = <int>{};
  List<Transaction> candidates(int dk, int cents, {required bool positive}) {
    return transactions.where((t) {
      if (consumed.contains(t.id)) return false;
      if (t.amount == 0) return false;
      if (positive != (t.amount > 0)) return false;
      if (dayKey(t.valueDate) != dk) return false;
      return (t.amount.abs() * 100).round() == cents;
    }).toList()..sort((a, b) => a.id.compareTo(b.id));
  }

  final annotated = <int, String>{};
  final savings = <SavingScheduleItem>[];

  for (final e in events) {
    final isOutflow = e.direction == EventDirection.outflow;

    // Anchor → existing tx (positive for inflow, negative for outflow).
    final anchorCents = (e.totalAmount.abs() * 100).round();
    final anchorMatches = candidates(dayKey(e.eventDate), anchorCents, positive: !isOutflow);
    if (anchorMatches.isNotEmpty) {
      final t = anchorMatches.first;
      consumed.add(t.id);
      annotated[t.id] = adjustedLabel(e.name);
    }

    // Buffer reimbursements → existing positive tx (the partner paying us back).
    for (final r in reimbursementsByEvent[e.id] ?? const <BufferTransaction>[]) {
      if (!r.isReimbursement) continue;
      final rc = (r.amount.abs() * 100).round();
      final m = candidates(dayKey(r.valueDate), rc, positive: true);
      if (m.isNotEmpty) {
        final t = m.first;
        consumed.add(t.id);
        annotated[t.id] = reimbLabel(e.name);
      }
    }

    // Entries. Sign is explicit, never magnitude-only:
    //  • an ephemeral-inflow event (credit line) funds OUTFLOWS — its entries
    //    map to NEGATIVE transactions (e.g. SERRA BETON drawdowns) → annotate
    //    "Financed" and keep out of totals;
    //  • an outflow event's entries map to NEGATIVE transactions too;
    //  • an inflow (non-ephemeral) event's entries map to POSITIVE transactions;
    //  • a `scheduled` entry with no matching real tx (T-Roc's saving plan)
    //    becomes a synthetic "Saving for X" row that DOES count.
    final entryMatchesPositive = !isOutflow && !e.isEphemeral;
    for (final en in entriesByEvent[e.id] ?? const <ExtraordinaryEventEntry>[]) {
      final cents = (en.amount.abs() * 100).round();
      final m = candidates(dayKey(en.date), cents, positive: entryMatchesPositive);
      if (m.isNotEmpty) {
        final t = m.first;
        consumed.add(t.id);
        annotated[t.id] = (e.isEphemeral && !isOutflow) ? financedLabel(e.name) : adjustedLabel(e.name);
      } else if (en.entryKind == EventEntryKind.scheduled) {
        savings.add(SavingScheduleItem(date: en.date, amount: en.amount, eventName: e.name));
      }
    }
  }

  return AdjustmentResolution(annotatedTxIds: annotated, savingItems: savings);
}
