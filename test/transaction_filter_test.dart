// Pure unit tests for the account-detail TransactionFilter model.
//
// Pins the confirmed product semantics:
//   * includeKinds = "show only" (OR); excludeKinds = "hide" (rejects on
//     intersection); a kind is never in both; exclude wins.
//   * date range and amount range further restrict with AND,
//   * amount bound is on the |amount| (sign-agnostic), with an inside/outside
//     (negated) mode,
//   * text: contains AND not-excludes, case-insensitive,
//   * classifyTransactionKinds: a row carries its sign kind plus cancelled;
//     adjustment is layered on by the caller (multi-kind rows).

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/ui/screens/accounts/transaction_filter.dart';

void main() {
  group('classifyTransactionKinds', () {
    late AppDatabase db;
    late int acc;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      acc = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'A'));
    });
    tearDown(() async => db.close());

    Future<Transaction> tx({
      required double amount,
      TransactionStatus status = TransactionStatus.settled,
    }) async {
      final id = await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              accountId: acc,
              operationDate: DateTime(2025, 1, 1),
              valueDate: DateTime(2025, 1, 1),
              amount: amount,
              status: Value(status),
            ),
          );
      return (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();
    }

    test('positive settled => {inflow}', () async {
      expect(classifyTransactionKinds(await tx(amount: 10)), {EntryKind.inflow});
    });
    test('negative settled => {outflow}', () async {
      expect(classifyTransactionKinds(await tx(amount: -10)), {EntryKind.outflow});
    });
    test('zero settled => {noOp}', () async {
      expect(classifyTransactionKinds(await tx(amount: 0)), {EntryKind.noOp});
    });
    test('cancelled positive => {cancelled, inflow} (still an inflow row)', () async {
      expect(
        classifyTransactionKinds(await tx(amount: 10, status: TransactionStatus.cancelled)),
        {EntryKind.cancelled, EntryKind.inflow},
      );
    });
    test('cancelled negative => {cancelled, outflow}', () async {
      expect(
        classifyTransactionKinds(await tx(amount: -10, status: TransactionStatus.cancelled)),
        {EntryKind.cancelled, EntryKind.outflow},
      );
    });
  });

  group('DateRangeFilter', () {
    test('empty range contains everything', () {
      const f = DateRangeFilter();
      expect(f.isEmpty, isTrue);
      expect(f.contains(DateTime(1999, 1, 1)), isTrue);
    });
    test('inclusive bounds, day-granular', () {
      final f = DateRangeFilter(start: DateTime(2025, 1, 10), end: DateTime(2025, 1, 20));
      expect(f.contains(DateTime(2025, 1, 9, 23)), isFalse);
      expect(f.contains(DateTime(2025, 1, 10)), isTrue);
      expect(f.contains(DateTime(2025, 1, 20, 23, 59)), isTrue); // whole end day
      expect(f.contains(DateTime(2025, 1, 21)), isFalse);
    });
    test('open-ended start', () {
      final f = DateRangeFilter(end: DateTime(2025, 1, 20));
      expect(f.contains(DateTime(1990, 1, 1)), isTrue);
      expect(f.contains(DateTime(2025, 1, 21)), isFalse);
    });
    test('open-ended end', () {
      final f = DateRangeFilter(start: DateTime(2025, 1, 10));
      expect(f.contains(DateTime(2025, 1, 9)), isFalse);
      expect(f.contains(DateTime(2999, 1, 1)), isTrue);
    });
  });

  group('AmountRangeFilter (sign-agnostic on |amount|)', () {
    test('empty contains everything', () {
      const f = AmountRangeFilter();
      expect(f.isEmpty, isTrue);
      expect(f.contains(-99999), isTrue);
    });
    test('min only catches both signs', () {
      const f = AmountRangeFilter(min: 100);
      expect(f.contains(150), isTrue);
      expect(f.contains(-150), isTrue);
      expect(f.contains(50), isFalse);
      expect(f.contains(-50), isFalse);
      expect(f.contains(100), isTrue); // inclusive
    });
    test('max only', () {
      const f = AmountRangeFilter(max: 100);
      expect(f.contains(100), isTrue); // inclusive
      expect(f.contains(-100), isTrue);
      expect(f.contains(101), isFalse);
    });
    test('min..max window', () {
      const f = AmountRangeFilter(min: 50, max: 100);
      expect(f.contains(-75), isTrue);
      expect(f.contains(49.99), isFalse);
      expect(f.contains(100.01), isFalse);
    });
    test('direction=inflow scopes to positive amounts', () {
      const f = AmountRangeFilter(min: 100, direction: AmountDirection.inflow);
      expect(f.isEmpty, isFalse);
      expect(f.contains(150), isTrue);
      expect(f.contains(-150), isFalse, reason: 'outflow excluded by direction');
    });
    test('direction=outflow scopes to negative amounts', () {
      const f = AmountRangeFilter(min: 100, direction: AmountDirection.outflow);
      expect(f.contains(-150), isTrue);
      expect(f.contains(150), isFalse, reason: 'inflow excluded by direction');
    });
    test('direction alone (no bounds) is still active', () {
      const f = AmountRangeFilter(direction: AmountDirection.outflow);
      expect(f.isEmpty, isFalse);
      expect(f.contains(-1), isTrue);
      expect(f.contains(1), isFalse);
    });

    group('outside (negated) range', () {
      test('outside min..max keeps the extremes, drops the middle', () {
        const f = AmountRangeFilter(min: 50, max: 100, outside: true);
        expect(f.contains(49.99), isTrue, reason: 'below the window');
        expect(f.contains(100.01), isTrue, reason: 'above the window');
        expect(f.contains(75), isFalse, reason: 'inside the window is excluded');
        expect(f.contains(50), isFalse, reason: 'boundary is inside');
        expect(f.contains(100), isFalse, reason: 'boundary is inside');
        expect(f.contains(-75), isFalse, reason: 'sign-agnostic: |-75| is inside');
        expect(f.contains(-200), isTrue);
      });
      test('outside with only min = magnitude strictly below min', () {
        const f = AmountRangeFilter(min: 100, outside: true);
        expect(f.contains(50), isTrue);
        expect(f.contains(-50), isTrue);
        expect(f.contains(100), isFalse, reason: 'at/above min is inside');
        expect(f.contains(150), isFalse);
      });
      test('outside respects direction scope', () {
        const f = AmountRangeFilter(min: 50, max: 100, outside: true, direction: AmountDirection.outflow);
        expect(f.contains(-200), isTrue, reason: 'outflow beyond the window');
        expect(f.contains(200), isFalse, reason: 'inflow excluded by direction even though beyond window');
      });
      test('outside with no bounds is a no-op (direction=both => empty)', () {
        const f = AmountRangeFilter(outside: true);
        expect(f.isEmpty, isTrue);
        expect(f.contains(123), isTrue);
      });
    });
  });

  group('TransactionFilter — include/exclude kinds', () {
    final d = DateTime(2025, 6, 15);

    test('none matches everything', () {
      expect(TransactionFilter.none.isActive, isFalse);
      for (final k in EntryKind.values) {
        expect(TransactionFilter.none.matches({k}, d, 123), isTrue);
      }
    });

    test('empty include = no positive restriction', () {
      const f = TransactionFilter();
      expect(f.matches({EntryKind.transfer}, d, 1), isTrue);
      expect(f.matches({EntryKind.adjustment}, d, 1), isTrue);
    });

    test('includeKinds combine with OR', () {
      const f = TransactionFilter(includeKinds: {EntryKind.inflow, EntryKind.transfer});
      expect(f.matches({EntryKind.inflow}, d, 1), isTrue);
      expect(f.matches({EntryKind.transfer}, d, 1), isTrue);
      expect(f.matches({EntryKind.outflow}, d, 1), isFalse);
      expect(f.matches({EntryKind.noOp}, d, 1), isFalse);
    });

    test('excludeKinds hide matching rows (negative filter)', () {
      const f = TransactionFilter(excludeKinds: {EntryKind.outflow});
      expect(f.matches({EntryKind.inflow}, d, 1), isTrue);
      expect(f.matches({EntryKind.noOp}, d, 0), isTrue);
      expect(f.matches({EntryKind.outflow}, d, -1), isFalse, reason: 'hidden kind rejected');
    });

    test('exclude rejects even a multi-kind row that also matches include', () {
      // Hide transfers, show inflows: a row that is BOTH (shouldn\'t happen, but
      // proves exclusion wins) is rejected.
      const f = TransactionFilter(includeKinds: {EntryKind.inflow}, excludeKinds: {EntryKind.transfer});
      expect(f.matches({EntryKind.inflow}, d, 1), isTrue);
      expect(f.matches({EntryKind.inflow, EntryKind.transfer}, d, 1), isFalse, reason: 'exclude wins over include');
    });

    test('a row carrying multiple kinds matches include if ANY intersects', () {
      const both = {EntryKind.outflow, EntryKind.adjustment};
      expect(const TransactionFilter(includeKinds: {EntryKind.outflow}).matches(both, d, -50), isTrue);
      expect(const TransactionFilter(includeKinds: {EntryKind.adjustment}).matches(both, d, -50), isTrue);
      expect(const TransactionFilter(includeKinds: {EntryKind.inflow}).matches(both, d, -50), isFalse);
    });

    test('kindSel reports the per-kind state', () {
      const f = TransactionFilter(includeKinds: {EntryKind.inflow}, excludeKinds: {EntryKind.outflow});
      expect(f.kindSel(EntryKind.inflow), KindSel.include);
      expect(f.kindSel(EntryKind.outflow), KindSel.exclude);
      expect(f.kindSel(EntryKind.noOp), KindSel.neutral);
    });

    test('withKindSel keeps include/exclude mutually exclusive', () {
      var f = TransactionFilter.none;
      f = f.withKindSel(EntryKind.inflow, KindSel.include);
      expect(f.includeKinds, {EntryKind.inflow});
      expect(f.excludeKinds, isEmpty);
      // Flip the same kind to exclude: it leaves include and enters exclude.
      f = f.withKindSel(EntryKind.inflow, KindSel.exclude);
      expect(f.includeKinds, isEmpty);
      expect(f.excludeKinds, {EntryKind.inflow});
      // Back to neutral.
      f = f.withKindSel(EntryKind.inflow, KindSel.neutral);
      expect(f.includeKinds, isEmpty);
      expect(f.excludeKinds, isEmpty);
    });
  });

  group('TransactionFilter — text', () {
    test('contains is case-insensitive', () {
      const f = TransactionFilter(containsText: 'Salary');
      expect(f.textMatches('Monthly SALARY payment'), isTrue);
      expect(f.textMatches('rent'), isFalse);
    });
    test('excludes (doesn\'t contain) rejects matching haystacks', () {
      const f = TransactionFilter(excludesText: 'fee');
      expect(f.textMatches('grocery'), isTrue);
      expect(f.textMatches('Bank FEE'), isFalse);
    });
    test('contains AND not-excludes combine', () {
      const f = TransactionFilter(containsText: 'card', excludesText: 'fee');
      expect(f.textMatches('card payment'), isTrue);
      expect(f.textMatches('card fee'), isFalse, reason: 'excluded term wins');
      expect(f.textMatches('cash payment'), isFalse, reason: 'missing required term');
    });
    test('text is independent of the per-row (kind/date/amount) filter', () {
      const f = TransactionFilter(excludesText: 'fee');
      expect(f.hasRowFilter, isFalse);
      expect(f.hasTextFilter, isTrue);
      expect(f.isActive, isTrue);
    });
  });

  group('TransactionFilter — composition & flags', () {
    final d = DateTime(2025, 6, 15);

    test('kind AND date AND amount', () {
      final f = TransactionFilter(
        includeKinds: const {EntryKind.inflow},
        dateRange: DateRangeFilter(start: DateTime(2025, 6, 1), end: DateTime(2025, 6, 30)),
        amountRange: const AmountRangeFilter(min: 100),
      );
      expect(f.matches({EntryKind.inflow}, DateTime(2025, 6, 15), 250), isTrue);
      expect(f.matches({EntryKind.inflow}, DateTime(2025, 7, 1), 250), isFalse, reason: 'out of date range');
      expect(f.matches({EntryKind.inflow}, DateTime(2025, 6, 15), 50), isFalse, reason: 'below min');
      expect(f.matches({EntryKind.outflow}, DateTime(2025, 6, 15), 250), isFalse, reason: 'wrong kind');
    });

    test('isActive / hasRowFilter / hasTextFilter', () {
      expect(const TransactionFilter(includeKinds: {EntryKind.inflow}).hasRowFilter, isTrue);
      expect(const TransactionFilter(excludeKinds: {EntryKind.transfer}).hasRowFilter, isTrue);
      expect(TransactionFilter(dateRange: DateRangeFilter(start: DateTime(2025, 1, 1))).hasRowFilter, isTrue);
      expect(const TransactionFilter(amountRange: AmountRangeFilter(max: 10)).hasRowFilter, isTrue);
      expect(const TransactionFilter(containsText: 'x').hasRowFilter, isFalse);
      expect(const TransactionFilter(containsText: 'x').isActive, isTrue);
    });

    test('activeCount tallies each dimension', () {
      final f = TransactionFilter(
        includeKinds: const {EntryKind.inflow, EntryKind.noOp},
        excludeKinds: const {EntryKind.transfer},
        dateRange: DateRangeFilter(start: DateTime(2025, 1, 1)),
        amountRange: const AmountRangeFilter(min: 10),
        containsText: 'a',
        excludesText: 'b',
      );
      // 2 include + 1 exclude + 1 date + 1 amount + 1 contains + 1 excludes
      expect(f.activeCount, 7);
      expect(TransactionFilter.none.activeCount, 0);
    });

    test('matches ignores text (text is applied pre-collapse, not here)', () {
      const f = TransactionFilter(containsText: 'salary');
      // matches() only checks kind/date/amount; a text-only filter passes here.
      expect(f.matches({EntryKind.outflow}, d, -5), isTrue);
    });
  });
}
