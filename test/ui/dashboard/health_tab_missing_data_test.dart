// Health tab with missing data: every input is loaded before a KPI is shown,
// a failed load says so, and a KPI whose inputs are missing reads "-" and
// N/A instead of being computed — and rated — from placeholder zeros (no
// income read as a 0% savings rate rated Poor, no expenses as 0 months of
// coverage rated Poor, no holdings as a largest position of 0% rated
// Excellent, no investing history as a 0.00% yearly return).
import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/market/exchange_rate_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show allSeriesDataProvider;

import 'dashboard_harness.dart';

/// Holds every USD lookup until [gate] opens.
class _GatedRates extends ExchangeRateService {
  _GatedRates(super.db);

  final gate = Completer<void>();

  @override
  Future<double?> getRate(String from, String to, DateTime date) async {
    if (from == 'USD') await gate.future;
    return super.getRate(from, to, date);
  }
}

void main() {
  const s = AppStrings.en;
  final h = DashboardHarness();

  setUpAll(() async => initializeDateFormatting());
  setUp(h.open);
  tearDown(h.close);

  Finder inKpi(String kpi, String text) => find.descendant(of: h.kpiCard(kpi), matching: find.text(text));

  void expectNa(String kpi) {
    expect(inKpi(kpi, '-'), findsOneWidget, reason: '$kpi has no value');
    expect(inKpi(kpi, s.ratingNa), findsOneWidget, reason: '$kpi is not rated');
  }

  Future<void> seedCashOnly() async {
    final acct = await h.db.into(h.db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    await h.db
        .into(h.db.transactions)
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
  }

  testWidgets('under a year of investing history: the yearly return reads "-" and N/A with the reason, never a rate for a few months', (
    tester,
  ) async {
    final acct = await h.db.into(h.db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    await h.db
        .into(h.db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: acct,
            operationDate: DateTime(2025, 11, 1),
            valueDate: DateTime(2025, 11, 1),
            amount: 15000,
            balanceAfter: const Value(15000),
          ),
        );
    final broker = await h.db.into(h.db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    final fund = await h.db
        .into(h.db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'Fund',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: broker,
          ),
        );
    await h.db
        .into(h.db.assetEvents)
        .insert(
          AssetEventsCompanion.insert(
            assetId: fund,
            date: DateTime(2025, 12, 1),
            valueDate: DateTime(2025, 12, 1),
            type: EventType.buy,
            amount: 1000,
            quantity: const Value(10),
            price: const Value(100),
          ),
        );
    for (final (date, close) in [(DateTime(2025, 12, 1), 100.0), (DateTime(2026, 3, 10), 110.0)]) {
      await h.db.into(h.db.marketPrices).insert(MarketPricesCompanion.insert(assetId: fund, date: date, closePrice: close, currency: 'EUR'));
    }
    await h.pump(tester);
    try {
      expectNa(s.kpiAnnualizedReturn);
      expect(inKpi(s.kpiAnnualizedReturn, '10.00%'), findsNothing, reason: 'a 10% gain in three months is not a yearly rate');
      final details = find.descendant(of: h.kpiCard(s.kpiAnnualizedReturn), matching: find.text(s.healthDetails));
      await tester.ensureVisible(details);
      await h.settle(tester);
      await tester.tap(details);
      await h.settle(tester);
      expect(inKpi(s.kpiAnnualizedReturn, s.kpiAnnualizedReturnNeedsYear), findsOneWidget);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('cash only: KPIs without income, expenses or holdings are N/A; the ones with data keep their value', (tester) async {
    await seedCashOnly();
    await h.pump(tester);
    try {
      for (final kpi in [
        s.kpiSavingsRate,
        s.kpiExpenseCoverage,
        s.kpiIncomeToWealth,
        s.kpiLargestPosition,
        s.kpiAnnualizedReturn,
        s.kpiFireNumber,
        s.kpiCreditLineUsage,
      ]) {
        expectNa(kpi);
      }
      expect(inKpi(s.kpiExpenseCoverage, '0${s.kpiUnitMonths}'), findsNothing, reason: 'no expenses is not 0 months of coverage');
      expect(inKpi(s.kpiLargestPosition, '0.00%'), findsNothing, reason: 'no holdings is not a perfectly diversified portfolio');
      // All of it is cash: the liquidity ratio is known, and nothing is owed.
      expect(inKpi(s.kpiLiquidityRatio, '100.00%'), findsOneWidget);
      expect(inKpi(s.kpiLiquidityRatio, s.ratingOttimo), findsOneWidget);
      expect(inKpi(s.kpiDebtToAssets, '0.00%'), findsOneWidget);
      expect(inKpi(s.kpiDebtToAssets, s.ratingOttimo), findsOneWidget);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('nothing at all: no KPI is rated and the overall score is not "0 · Poor"', (tester) async {
    await h.pump(tester);
    try {
      final summary = find.ancestor(of: find.text(s.healthSummary), matching: find.byType(Card)).first;
      expect(find.descendant(of: summary, matching: find.text('-')), findsOneWidget);
      expect(find.descendant(of: summary, matching: find.text(s.ratingScarso)), findsNothing);
      expectNa(s.kpiLiquidityRatio);
      expectNa(s.kpiInvestmentWeight);
      expectNa(s.kpiDebtToAssets);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('a failed load shows the error instead of KPIs computed without it', (tester) async {
    await h.seed();
    await h.pump(tester, overrides: [allSeriesDataProvider.overrideWith((ref) async => throw StateError('boom'))]);
    try {
      expect(find.text(s.error(StateError('boom'))), findsWidgets);
      expect(find.text(s.kpiSavingsRate), findsNothing);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('the tab waits for the income and expense data before showing a KPI', (tester) async {
    await h.seed();
    // A USD income: converting it keeps the income/expense data loading
    // until the gate opens, while every other input is ready.
    await h.db
        .into(h.db.incomes)
        .insert(
          IncomesCompanion.insert(date: DateTime(2026, 2, 20), valueDate: DateTime(2026, 2, 20), amount: 100, currency: const Value('USD')),
        );
    final rates = _GatedRates(h.db);
    await h.pump(tester, overrides: [exchangeRateServiceProvider.overrideWithValue(rates)]);
    try {
      expect(find.text(s.kpiSavingsRate), findsNothing, reason: 'no savings rate from income that has not loaded');
      rates.gate.complete();
      await h.settle(tester);
      expect(find.text(s.kpiSavingsRate), findsOneWidget);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('an asset without a price is counted under the KPIs it is left out of', (tester) async {
    await h.seed();
    final broker = await h.db.into(h.db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Other broker'));
    final asset = await h.db
        .into(h.db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'Unpriced',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: broker,
          ),
        );
    await h.db
        .into(h.db.assetEvents)
        .insert(
          AssetEventsCompanion.insert(
            assetId: asset,
            date: DateTime(2025, 2, 3),
            valueDate: DateTime(2025, 2, 3),
            type: EventType.buy,
            amount: 1000,
            quantity: const Value(10),
          ),
        );
    await h.pump(tester);
    try {
      expect(find.text(s.unpricedExcludedFromTotals(1)), findsOneWidget);
    } finally {
      await h.unmount(tester);
    }
  });
}
