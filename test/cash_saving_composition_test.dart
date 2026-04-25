import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart'
    show AllSeriesData, ChartSeries, buildTotalSpots;

// Fixture: a small AllSeriesData with two accounts, one invested asset,
// one spread adjustment, one income adjustment.
AllSeriesData _fixture() {
  return AllSeriesData(
    firstDate: DateTime(2024, 1, 1),
    accounts: [
      ChartSeries(
        key: 'account:1',
        name: 'Checking',
        color: Colors.blue,
        spots: const [FlSpot(0, 1000), FlSpot(10, 1200)],
      ),
      ChartSeries(
        key: 'account:2',
        name: 'Savings',
        color: Colors.green,
        spots: const [FlSpot(0, 500), FlSpot(5, 600), FlSpot(10, 650)],
      ),
    ],
    assetInvested: [
      ChartSeries(
        key: 'asset_invested:1',
        name: 'VWCE cost',
        color: Colors.orange,
        spots: const [FlSpot(3, 2000), FlSpot(10, 3000)],
      ),
    ],
    assetMarket: const [],
    assetGain: const [],
    adjustments: [
      ChartSeries(
        key: 'adjustment:1',
        name: 'Tax provision',
        color: Colors.purple,
        spots: const [FlSpot(2, -100), FlSpot(10, -400)],
      ),
    ],
    ephemeralInflows: const [],
    incomeAdjustments: [
      ChartSeries(
        key: 'income_adj:1',
        name: 'Bonus inflow',
        color: Colors.teal,
        spots: const [FlSpot(7, 500)],
      ),
    ],
    baseCurrency: 'EUR',
  );
}

void main() {
  group('AllSeriesData cash/saving getters — pinning pre-refactor composition',
      () {
    test('cashSpots matches the old inline accounts+adjustments composition',
        () {
      final d = _fixture();

      // Old inline composition from cashflow_tab.dart/totals_table.dart/
      // dashboard_screen.dart.
      final oldCashSpots = buildTotalSpots([
        ...d.accounts.map((s) => s.spots),
        ...d.adjustments.map((s) => s.spots),
      ]);

      expect(d.cashSpots.length, oldCashSpots.length);
      for (var i = 0; i < oldCashSpots.length; i++) {
        expect(d.cashSpots[i].x, oldCashSpots[i].x);
        expect(d.cashSpots[i].y, oldCashSpots[i].y);
      }
    });

    test(
        'savingSpots matches the old inline accounts+invested+adjustments+incomeAdj composition',
        () {
      final d = _fixture();

      final oldSavingSpots = buildTotalSpots([
        ...d.accounts.map((s) => s.spots),
        ...d.assetInvested.map((s) => s.spots),
        ...d.adjustments.map((s) => s.spots),
        ...d.incomeAdjustments.map((s) => s.spots),
      ]);

      expect(d.savingSpots.length, oldSavingSpots.length);
      for (var i = 0; i < oldSavingSpots.length; i++) {
        expect(d.savingSpots[i].x, oldSavingSpots[i].x);
        expect(d.savingSpots[i].y, oldSavingSpots[i].y);
      }
    });

    test('cashSeries has expected order: accounts then adjustments', () {
      final d = _fixture();
      final keys = d.cashSeries.map((s) => s.key).toList();
      expect(keys, ['account:1', 'account:2', 'adjustment:1']);
    });

    test(
        'savingSeries has expected order: accounts + invested + adjustments + incomeAdj',
        () {
      final d = _fixture();
      final keys = d.savingSeries.map((s) => s.key).toList();
      expect(keys, [
        'account:1',
        'account:2',
        'asset_invested:1',
        'adjustment:1',
        'income_adj:1',
      ]);
    });

    test('cashSpots is a hand-computed carry-forward total', () {
      final d = _fixture();
      // X keys across cash series: 0, 2, 5, 10.
      // account:1:       x=0 -> 1000, x=10 -> 1200
      // account:2:       x=0 -> 500,  x=5 -> 600,  x=10 -> 650
      // adjustment:1:    x=2 -> -100, x=10 -> -400
      // Carry-forward totals:
      //   x=0:  1000 + 500 + 0      = 1500
      //   x=2:  1000 + 500 + -100   = 1400
      //   x=5:  1000 + 600 + -100   = 1500
      //   x=10: 1200 + 650 + -400   = 1450
      final got = d.cashSpots;
      expect(got.map((s) => s.x).toList(), [0, 2, 5, 10]);
      expect(got.map((s) => s.y).toList(), [1500, 1400, 1500, 1450]);
    });

    test('savingSpots is a hand-computed carry-forward total', () {
      final d = _fixture();
      // X keys across saving series: 0, 2, 3, 5, 7, 10.
      // account:1:        x=0 -> 1000, x=10 -> 1200
      // account:2:        x=0 -> 500,  x=5 -> 600,  x=10 -> 650
      // asset_invested:1: x=3 -> 2000, x=10 -> 3000
      // adjustment:1:     x=2 -> -100, x=10 -> -400
      // income_adj:1:     x=7 -> 500
      // Carry-forward totals:
      //   x=0:  1000 + 500 + 0    + 0    + 0   = 1500
      //   x=2:  1000 + 500 + 0    + -100 + 0   = 1400
      //   x=3:  1000 + 500 + 2000 + -100 + 0   = 3400
      //   x=5:  1000 + 600 + 2000 + -100 + 0   = 3500
      //   x=7:  1000 + 600 + 2000 + -100 + 500 = 4000
      //   x=10: 1200 + 650 + 3000 + -400 + 500 = 4950
      final got = d.savingSpots;
      expect(got.map((s) => s.x).toList(), [0, 2, 3, 5, 7, 10]);
      expect(got.map((s) => s.y).toList(), [1500, 1400, 3400, 3500, 4000, 4950]);
    });

    test('ephemeral inflows raise Cash but never enter Saving', () {
      final d = AllSeriesData(
        firstDate: DateTime(2024, 1, 1),
        accounts: [
          ChartSeries(
            key: 'account:1',
            name: 'Checking',
            color: Colors.blue,
            spots: const [FlSpot(0, 1000), FlSpot(10, 1000)],
          ),
        ],
        assetInvested: const [],
        assetMarket: const [],
        assetGain: const [],
        adjustments: const [],
        incomeAdjustments: const [],
        ephemeralInflows: [
          ChartSeries(
            key: 'ephemeral_inflow_value:5',
            name: 'Line of credit',
            color: Colors.amber,
            // Stored negative (inflow anchor convention) — the cash getter
            // negates it so the absolute value adds to Cash.
            spots: const [FlSpot(2, -500)],
          ),
        ],
        baseCurrency: 'EUR',
      );
      // Cash should include +500 from x=2 onward (negation of -500).
      final cash = {for (final s in d.cashSpots) s.x: s.y};
      expect(cash[2], 1500); // 1000 + 500
      // Saving must not include the ephemeral series at all.
      expect(d.savingSpots.every((p) => p.y == 1000), isTrue);
    });

    test('all-empty AllSeriesData yields empty cash/saving spots', () {
      final empty = AllSeriesData(
        firstDate: DateTime(2024, 1, 1),
        accounts: const [],
        assetInvested: const [],
        assetMarket: const [],
        assetGain: const [],
        adjustments: const [],
        incomeAdjustments: const [],
        ephemeralInflows: const [],
        baseCurrency: 'EUR',
      );
      expect(empty.cashSeries, isEmpty);
      expect(empty.savingSeries, isEmpty);
      expect(empty.cashSpots, isEmpty);
      expect(empty.savingSpots, isEmpty);
    });
  });
}
