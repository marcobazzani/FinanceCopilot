// History tab, with an asset that has no price: the Totals table shows a dash
// for a total it cannot compute and for the asset in the drill-down (never
// +€0.00), counts the asset it left out under the table; the Price Changes
// total counts the asset it left out as well.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';

import 'dashboard_harness.dart';

void main() {
  const s = AppStrings.en;
  final h = DashboardHarness();

  setUpAll(() async => initializeDateFormatting());
  setUp(h.open);
  tearDown(h.close);

  /// 15,000 cash and 10 units of "Unpriced" bought for 1,000 without a unit
  /// price, with no close on record: nothing to value them with.
  Future<void> seedCashAndUnpriced() async {
    final db = h.db;
    final acct = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: acct,
            operationDate: DateTime(2024, 12, 1),
            valueDate: DateTime(2024, 12, 1),
            amount: 15000,
            balanceAfter: const Value(15000),
            description: const Value('Opening'),
          ),
        );
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Other broker'));
    final asset = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'Unpriced',
            ticker: const Value('UNPR'),
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: broker,
          ),
        );
    await db
        .into(db.assetEvents)
        .insert(
          AssetEventsCompanion.insert(
            assetId: asset,
            date: DateTime(2024, 12, 3),
            valueDate: DateTime(2024, 12, 3),
            type: EventType.buy,
            amount: 1000,
            quantity: const Value(10),
          ),
        );
  }

  Finder totalsCard() => find.ancestor(of: find.text(s.vsATH), matching: find.byType(Card)).first;
  Finder rowOf(String label) => find
      .ancestor(
        of: find.descendant(of: totalsCard(), matching: find.text(label)),
        matching: find.byType(Row),
      )
      .first;

  testWidgets('Totals: a total with nothing to add up is a dash, the unpriced asset is a dash in the drill-down and is counted', (tester) async {
    await seedCashAndUnpriced();
    await h.pump(tester);
    try {
      await h.openTab(tester, 'History');
      await tester.ensureVisible(find.text(s.vsATH));
      await h.settle(tester);

      // Portfolio / Liquid Investments / Performance hold only the unpriced
      // asset: no total, not a zero one.
      for (final label in ['Portfolio', 'Liquid Investments', 'Performance']) {
        expect(
          find.descendant(of: rowOf(label), matching: find.text('—')),
          findsOneWidget,
          reason: label,
        );
        expect(
          find.descendant(of: rowOf(label), matching: find.textContaining('0.00')),
          findsNothing,
          reason: label,
        );
      }
      // Total Assets = the cash; the asset is left out, not valued at cost.
      expect(find.descendant(of: rowOf('Total Assets'), matching: find.text('+€15,000.00')), findsOneWidget);
      expect(find.descendant(of: totalsCard(), matching: find.text(s.unpricedExcludedFromTotals(1))), findsOneWidget);

      await tester.tap(find.descendant(of: totalsCard(), matching: find.text('Portfolio')));
      await h.settle(tester);
      final drill = find
          .ancestor(
            of: find.descendant(of: totalsCard(), matching: find.text('UNPR')),
            matching: find.byType(Row),
          )
          .first;
      expect(
        find.descendant(of: drill, matching: find.text('—')),
        findsOneWidget,
        reason: 'no value, not +€0.00',
      );
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('priced assets only: no dash and no footnote', (tester) async {
    await h.seed();
    await h.pump(tester);
    try {
      await h.openTab(tester, 'History');
      await tester.ensureVisible(find.text(s.vsATH));
      await h.settle(tester);
      expect(find.descendant(of: rowOf('Portfolio'), matching: find.text('+€1,210.00')), findsOneWidget);
      expect(find.descendant(of: totalsCard(), matching: find.text('—')), findsNothing);
      expect(find.textContaining('excluded from the total'), findsNothing);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('Price Changes and Totals: the asset left out of each total is counted under it', (tester) async {
    await h.seed(); // a priced fund, 10 units closing at 121 today
    await seedCashAndUnpriced();
    await h.pump(tester);
    try {
      await h.openTab(tester, 'History');
      final changes = find.ancestor(of: find.text(s.dashPriceChanges), matching: find.byType(Card)).first;
      final note = find.descendant(of: changes, matching: find.text(s.unpricedExcludedFromTotal(1)));
      for (var i = 0; i < 100 && note.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(note, findsOneWidget);
      expect(
        find.descendant(of: changes, matching: find.text('Fund')),
        findsOneWidget,
        reason: 'the priced fund is listed',
      );

      await tester.ensureVisible(find.text(s.vsATH));
      await h.settle(tester);
      expect(find.descendant(of: rowOf('Portfolio'), matching: find.text('+€1,210.00')), findsOneWidget);
      expect(find.descendant(of: totalsCard(), matching: find.text(s.unpricedExcludedFromTotals(1))), findsOneWidget);
    } finally {
      await h.unmount(tester);
    }
  });
}
