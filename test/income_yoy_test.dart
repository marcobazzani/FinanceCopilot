import 'package:finance_copilot/ui/screens/dashboard/income_yoy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('incomeYoYDiff', () {
    test('returns null when either year lacks income data for the month', () {
      expect(
        incomeYoYDiff(
          previousIncome: 1000,
          previousHasIncomeData: true,
          currentIncome: 0,
          currentHasIncomeData: false,
        ),
        isNull,
      );

      expect(
        incomeYoYDiff(
          previousIncome: 0,
          previousHasIncomeData: false,
          currentIncome: 1200,
          currentHasIncomeData: true,
        ),
        isNull,
      );
    });

    test('returns the delta when both years have income data', () {
      expect(
        incomeYoYDiff(
          previousIncome: 1000,
          previousHasIncomeData: true,
          currentIncome: 1200,
          currentHasIncomeData: true,
        ),
        200,
      );
    });
  });

  group('incomeYoYTotal', () {
    test('sums only comparable months', () {
      expect(
        incomeYoYTotal([
          (
            previousIncome: 1000.0,
            previousHasIncomeData: true,
            currentIncome: 1200.0,
            currentHasIncomeData: true,
          ),
          (
            previousIncome: 900.0,
            previousHasIncomeData: true,
            currentIncome: 0.0,
            currentHasIncomeData: false,
          ),
          (
            previousIncome: 500.0,
            previousHasIncomeData: true,
            currentIncome: 450.0,
            currentHasIncomeData: true,
          ),
        ]),
        150,
      );
    });

    test('returns null when no month is comparable', () {
      expect(
        incomeYoYTotal([
          (
            previousIncome: 1000.0,
            previousHasIncomeData: false,
            currentIncome: 1200.0,
            currentHasIncomeData: true,
          ),
          (
            previousIncome: 900.0,
            previousHasIncomeData: true,
            currentIncome: 0.0,
            currentHasIncomeData: false,
          ),
        ]),
        isNull,
      );
    });
  });
}
