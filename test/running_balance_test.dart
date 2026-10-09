// The stored running balance lives on the value-date timeline and is anchored
// on the bank's closing balance — never a per-row copy of the bank's
// booking-order figure.
import 'package:finance_copilot/services/domain/running_balance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RunningBalanceRow row(int order, DateTime value, DateTime booked, double amount, [double? stated]) =>
      RunningBalanceRow(valueDate: value, bookingDate: booked, order: order, amount: amount, statedBalance: stated);

  test('rows booked later than their value date: balance follows the value date, closing matches the bank', () {
    // The card-statement shape: a payment made on the 8th is booked on the 10th.
    // Bank balances are in booking order: 20134.33 → 17634.33 (3 transfers on the 9th) ... → 2634.33 after the card payment.
    final rows = [
      row(1, DateTime(2022, 5, 9), DateTime(2022, 5, 9), -5000, 15134.33),
      row(2, DateTime(2022, 5, 9), DateTime(2022, 5, 9), -5000, 10134.33),
      row(3, DateTime(2022, 5, 9), DateTime(2022, 5, 9), -5000, 5134.33),
      row(4, DateTime(2022, 5, 8), DateTime(2022, 5, 10), -2500, 2634.33), // value-dated BEFORE the transfers
      row(5, DateTime(2022, 5, 9), DateTime(2022, 5, 11), -2500, 134.33),
      row(6, DateTime(2022, 5, 10), DateTime(2022, 5, 11), -134.33, 0),
    ];
    final r = anchoredRunningBalances(rows);
    expect(r.anchored, isTrue);
    expect(r.bankClosing, 0);
    expect(r.opening, closeTo(20134.33, 1e-9), reason: 'closing 0 − Σ(−20134.33)');
    // Value-date order: row4 (8th) first, then rows 1,2,3,5 (9th) by order, then row6.
    expect(r.balances[3], closeTo(17634.33, 1e-9), reason: 'balance on the 8th after the card payment, NOT the bank figure 2634.33');
    expect(r.balances[0], closeTo(12634.33, 1e-9));
    expect(r.balances[1], closeTo(7634.33, 1e-9));
    expect(r.balances[2], closeTo(2634.33, 1e-9));
    expect(r.balances[4], closeTo(134.33, 1e-9));
    expect(r.balances[5], closeTo(0, 1e-9), reason: 'last balance == bank closing');
  });

  test('the anchor is the last BOOKED row with a stated balance, not the last value-dated one', () {
    final rows = [
      row(1, DateTime(2024, 1, 5), DateTime(2024, 1, 5), 100, 1100),
      row(2, DateTime(2024, 1, 3), DateTime(2024, 1, 6), -20, 1080), // booked last, value-dated first
    ];
    final r = anchoredRunningBalances(rows);
    expect(r.bankClosing, 1080);
    expect(r.opening, 1000);
    expect(r.balances, [1080, 980]);
  });

  test('no stated balance anywhere: not anchored, series starts from 0', () {
    final r = anchoredRunningBalances([
      row(1, DateTime(2024, 1, 1), DateTime(2024, 1, 1), 50),
      row(2, DateTime(2024, 1, 2), DateTime(2024, 1, 2), -20),
    ]);
    expect(r.anchored, isFalse);
    expect(r.opening, 0);
    expect(r.balances, [50, 30]);
  });

  test('rows without a stated balance (hand-entered) still get a running balance and count toward the anchor', () {
    final rows = [
      row(1, DateTime(2024, 1, 1), DateTime(2024, 1, 1), 100, 100),
      row(2, DateTime(2024, 1, 2), DateTime(2024, 1, 2), -30), // manual, no bank figure
      row(3, DateTime(2024, 1, 3), DateTime(2024, 1, 3), -10, 60),
    ];
    final r = anchoredRunningBalances(rows);
    expect(r.opening, 0);
    expect(r.balances, [100, 70, 60]);
  });

  test('same-day rows are ordered by the tiebreak; cents arithmetic has no float drift', () {
    final d = DateTime(2024, 3, 1);
    final rows = [row(2, d, d, -0.1, 0.2), row(1, d, d, -0.2, 0.3), row(3, d, d, -0.2, 0)];
    final r = anchoredRunningBalances(rows);
    expect(r.opening, closeTo(0.5, 1e-12));
    expect(r.balances, [0.2, 0.3, 0.0]);
  });

  test('empty input', () {
    final r = anchoredRunningBalances(const []);
    expect(r.balances, isEmpty);
    expect(r.anchored, isFalse);
  });
}
