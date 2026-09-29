// Cash Flow and Health: what their figures leave out is counted next to them.
//
//  * An income record whose currency has no rate on its value date is left out
//    of the yearly Income / Expense / Savings figures (never converted 1:1);
//    the count was computed but shown nowhere — now it is on the Cash Flow tab
//    and under the Health summary.
//  * Health: a held asset without a market value today was silently left out
//    of the concentration (HHI) — counted as worth 0 — while the summary
//    counted only the assets the role charts could not value. It is now
//    counted under the summary too.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show CashFlowSankeyCard;

import 'dashboard_harness.dart';

void main() {
  const s = AppStrings.en;
  final h = DashboardHarness();

  setUpAll(() async => initializeDateFormatting());
  setUp(h.open);
  tearDown(h.close);

  /// A salary in CHF: a currency with no rate at all.
  Future<void> incomeWithoutRate() => h.db
      .into(h.db.incomes)
      .insert(
        IncomesCompanion.insert(date: DateTime(2025, 6, 15), valueDate: DateTime(2025, 6, 15), amount: 500, currency: const Value('CHF')),
      );

  group('income records without a rate', () {
    testWidgets('Cash Flow: counted next to the figures they are left out of', (tester) async {
      await h.seed();
      await incomeWithoutRate();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        expect(find.text(s.incomeFxExcluded(1)), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('Health: counted under the summary', (tester) async {
      await h.seed();
      await incomeWithoutRate();
      await h.pump(tester);
      try {
        expect(find.text(s.incomeFxExcluded(1)), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('privacy: the count stays readable, the amounts beside it are masked', (tester) async {
      await h.seed();
      await incomeWithoutRate();
      await h.pump(tester, isPrivate: true);
      bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;
      try {
        expect(masked(find.text(s.incomeFxExcluded(1))), isFalse, reason: 'a count of records: shape, not magnitude');
        await h.openTab(tester, 'Cash Flow');
        expect(masked(find.text(s.incomeFxExcluded(1))), isFalse);
        final sankey = find.byType(CashFlowSankeyCard);
        final income = find.descendant(of: sankey, matching: find.textContaining('€')).first;
        expect(masked(income), isTrue, reason: 'the yearly income is position size');
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('every income record converts: no note on either tab', (tester) async {
      await h.seed();
      await h.pump(tester);
      try {
        expect(find.textContaining('without an exchange rate'), findsNothing);
        await h.openTab(tester, 'Cash Flow');
        expect(find.textContaining('without an exchange rate'), findsNothing);
      } finally {
        await h.unmount(tester);
      }
    });
  });

  group('Health: a held asset without a market value today', () {
    testWidgets('is counted under the summary, not left out of the concentration as worth 0', (tester) async {
      await h.seed();
      // The fund's history is priced (the charts value it), today's value is not.
      await h.pump(tester, overrides: [assetMarketValuesProvider.overrideWith((ref) async => const <int, double>{})]);
      try {
        expect(find.text(s.unpricedExcludedFromTotals(1)), findsOneWidget);
        expect(
          find.descendant(of: h.kpiCard(s.hhiLabel), matching: find.text(s.ratingNa)),
          findsOneWidget,
          reason: 'nothing valued to measure',
        );
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('valued today: nothing counted', (tester) async {
      await h.seed();
      await h.pump(tester);
      try {
        expect(find.textContaining('without a price or exchange rate'), findsNothing);
      } finally {
        await h.unmount(tester);
      }
    });
  });
}
