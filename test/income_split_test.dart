import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/utils/income_split.dart';

// Pins the money math behind "Flag as Income" splitting one bank inflow across
// Income / Refund / Pension contribution. The invariant that matters
// financially: a plan is valid ONLY when the slices add up to the transaction
// amount to the cent — never rounded, never padded with a default.
void main() {
  group('planIncomeSplit', () {
    test('single type covering the whole amount is valid', () {
      final plan = planIncomeSplit(
        total: 1500.0,
        parts: {IncomeType.income: 1500.0},
      );
      expect(plan.isValid, isTrue);
      expect(plan.remainderCents, 0);
      expect(plan.entries, [const IncomeSplitEntry(IncomeType.income, 1500.0)]);
    });

    test('three-way split is valid and keeps every slice', () {
      final plan = planIncomeSplit(
        total: 2000.0,
        parts: {
          IncomeType.income: 1500.0,
          IncomeType.refund: 200.0,
          IncomeType.pensionContribution: 300.0,
        },
      );
      expect(plan.isValid, isTrue);
      expect(plan.entries, const [
        IncomeSplitEntry(IncomeType.income, 1500.0),
        IncomeSplitEntry(IncomeType.refund, 200.0),
        IncomeSplitEntry(IncomeType.pensionContribution, 300.0),
      ]);
    });

    test('entries are ordered by IncomeType.values regardless of input order', () {
      final plan = planIncomeSplit(
        total: 100.0,
        parts: {
          IncomeType.pensionContribution: 60.0,
          IncomeType.income: 40.0,
        },
      );
      expect(plan.entries.map((e) => e.type).toList(), [
        IncomeType.income,
        IncomeType.pensionContribution,
      ]);
    });

    test('zero and null slices are dropped, not persisted', () {
      final plan = planIncomeSplit(
        total: 100.0,
        parts: {
          IncomeType.income: 100.0,
          IncomeType.refund: 0.0,
          IncomeType.pensionContribution: null,
        },
      );
      expect(plan.isValid, isTrue);
      expect(plan.entries.length, 1);
      expect(plan.entries.single.type, IncomeType.income);
    });

    test('cent-level split that doubles cannot represent exactly is still balanced', () {
      // 33.33 + 33.33 + 33.34 == 100.00 in cents but NOT in binary doubles.
      final plan = planIncomeSplit(
        total: 100.0,
        parts: {
          IncomeType.income: 33.33,
          IncomeType.refund: 33.33,
          IncomeType.pensionContribution: 33.34,
        },
      );
      expect(plan.error, IncomeSplitError.none);
      expect(plan.remainderCents, 0);
    });

    test('under-allocation is a mismatch with a positive remainder', () {
      final plan = planIncomeSplit(
        total: 1000.0,
        parts: {IncomeType.income: 900.0},
      );
      expect(plan.isValid, isFalse);
      expect(plan.error, IncomeSplitError.mismatch);
      expect(plan.remainder, closeTo(100.0, 1e-9));
      expect(plan.isBalanced, isFalse);
    });

    test('over-allocation is a mismatch with a negative remainder', () {
      final plan = planIncomeSplit(
        total: 1000.0,
        parts: {IncomeType.income: 900.0, IncomeType.refund: 200.0},
      );
      expect(plan.error, IncomeSplitError.mismatch);
      expect(plan.remainder, closeTo(-100.0, 1e-9));
    });

    test('a one-cent gap is a mismatch — never silently absorbed', () {
      final plan = planIncomeSplit(
        total: 100.0,
        parts: {IncomeType.income: 99.99},
      );
      expect(plan.error, IncomeSplitError.mismatch);
      expect(plan.remainderCents, 1);
    });

    test('all-empty allocation is empty, not valid', () {
      final plan = planIncomeSplit(
        total: 100.0,
        parts: {IncomeType.income: null, IncomeType.refund: 0.0},
      );
      expect(plan.error, IncomeSplitError.empty);
      expect(plan.entries, isEmpty);
    });

    test('negative slice is rejected even when the sum matches', () {
      final plan = planIncomeSplit(
        total: 100.0,
        parts: {IncomeType.income: 150.0, IncomeType.refund: -50.0},
      );
      expect(plan.error, IncomeSplitError.negative);
      expect(plan.isValid, isFalse);
    });

    test('sub-cent input is rounded to cents on both sides of the comparison', () {
      final plan = planIncomeSplit(
        total: 1234.567,
        parts: {IncomeType.income: 1234.567},
      );
      expect(plan.isValid, isTrue);
      expect(plan.entries.single.amount, closeTo(1234.57, 1e-9));
    });
  });

  group('incomeCents', () {
    test('rounds to the nearest cent', () {
      expect(incomeCents(12.34), 1234);
      expect(incomeCents(0.1), 10);
      expect(incomeCents(1234.567), 123457);
      expect(incomeCents(1.004), 100);
      expect(incomeCents(1.006), 101);
      expect(incomeCents(-5.5), -550);
      expect(incomeCents(0), 0);
    });
  });
}
