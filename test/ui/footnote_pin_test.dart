// Pins the footnote under a figure — the line saying what the figure leaves
// out — everywhere one is shown: small muted text (bodySmall in
// onSurfaceVariant), with no alignment or line settings of its own. It carries
// counts, not amounts, so privacy mode leaves it readable while the figures
// beside it are masked.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/pillars/pillar_performance.dart';
import 'package:finance_copilot/services/pillars/pillar_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/allocation/allocation_tab.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show AllSeriesData, ChartSeries, allSeriesDataProvider;
import 'package:finance_copilot/ui/screens/pillars/pillar_detail_screen.dart';
import 'package:finance_copilot/ui/screens/pillars/pillars_screen.dart';

import 'dashboard/dashboard_harness.dart';

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

void main() {
  const s = AppStrings.en;

  setUpAll(() async => initializeDateFormatting('en'));

  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  /// Every widget [f] finds is a footnote: the muted small text, readable.
  void expectFootnotes(Finder f, {int? count}) {
    final found = f.evaluate().toList();
    expect(found, count == null ? isNotEmpty : hasLength(count), reason: '$f');
    for (final element in found) {
      final text = element.widget as Text;
      final theme = Theme.of(element);
      expect(text.style, theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.onSurfaceVariant), reason: text.data);
      expect(text.textAlign, isNull, reason: text.data);
      expect(text.maxLines, isNull, reason: text.data);
      expect(text.overflow, isNull, reason: text.data);
      expect(masked(find.byElementPredicate((e) => e == element)), isFalse, reason: '${text.data}: a count, not an amount');
    }
  }

  group('dashboard', () {
    final h = DashboardHarness();
    setUp(h.open);
    tearDown(h.close);

    testWidgets('Health, History and Cash Flow footnotes', (tester) async {
      await h.seed();
      // 10 units held, no price on record at all.
      final broker = await h.db.into(h.db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Other broker'));
      final unpriced = await h.db
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
              assetId: unpriced,
              date: DateTime(2025, 2, 3),
              valueDate: DateTime(2025, 2, 3),
              type: EventType.buy,
              amount: 1000,
              quantity: const Value(10),
            ),
          );
      // A salary in CHF: a currency with no rate at all.
      await h.db
          .into(h.db.incomes)
          .insert(
            IncomesCompanion.insert(date: DateTime(2025, 6, 15), valueDate: DateTime(2025, 6, 15), amount: 500, currency: const Value('CHF')),
          );
      await h.pump(tester, isPrivate: true);
      try {
        // Health: under the summary, and under each price-change KPI.
        expectFootnotes(find.text(s.unpricedExcludedFromTotals(1)), count: 1);
        expectFootnotes(find.text(s.incomeFxExcluded(1)), count: 1);
        expectFootnotes(find.text(s.unpricedExcludedFromTotal(1)), count: 3);

        // History: under the Totals table, the Price Changes total and the
        // header total of the charts adding the unpriced asset up.
        await h.openTab(tester, 'History');
        await tester.ensureVisible(find.text(s.vsATH));
        await h.settle(tester);
        final totals = find.ancestor(of: find.text(s.vsATH), matching: find.byType(Card)).first;
        expectFootnotes(find.descendant(of: totals, matching: find.text(s.unpricedExcludedFromTotals(1))), count: 1);
        final priceChanges = find.ancestor(of: find.text(s.dashPriceChanges), matching: find.byType(Card)).first;
        expectFootnotes(find.descendant(of: priceChanges, matching: find.text(s.unpricedExcludedFromTotal(1))), count: 1);
        expectFootnotes(find.text(s.unpricedExcludedFromTotal(1)));
        final cash = find.descendant(
          of: find
              .ancestor(
                of: find.descendant(of: totals, matching: find.text('Cash')),
                matching: find.byType(Row),
              )
              .first,
          matching: find.text('+€15,000.00'),
        );
        expect(masked(cash), isTrue, reason: 'a balance is position size');

        // Cash Flow: above the yearly figures.
        await h.openTab(tester, 'Cash Flow');
        expectFootnotes(find.text(s.incomeFxExcluded(1)), count: 1);
        expect(
          find.descendant(of: find.byKey(const Key('incomeFxFootnote')), matching: find.text(s.incomeFxExcluded(1)), matchRoot: true),
          findsOneWidget,
        );
      } finally {
        await h.unmount(tester);
      }
    });
  });

  testWidgets('Assets Overview: the unvalued assets above the charts, the funds without a TER below the costs', (tester) async {
    final now = DateTime(2025, 1, 1);
    Asset asset(int id, String name, double? ter) => Asset(
      id: id,
      name: name,
      ticker: name,
      assetType: AssetType.stockEtf,
      instrumentType: InstrumentType.etf,
      assetClass: AssetClass.equity,
      intermediaryId: 1,
      assetGroup: '',
      currency: 'EUR',
      valuationMethod: ValuationMethod.marketPrice,
      ter: ter,
      isActive: true,
      includeInSavings: true,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    );
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          privacyModeProvider.overrideWith((ref) => true),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AllocationOverviewBody(
              assets: [asset(1, 'EMKT', 0.2), asset(2, 'MYST', null)],
              marketValues: const {1: 6000, 2: 4000},
              baseCurrency: 'EUR',
              compositions: const {},
              unvaluedCount: 1,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expectFootnotes(find.text(s.unpricedExcludedFromTotal(1)), count: 1);
    expectFootnotes(find.text(s.terUnknownExcluded(1)), count: 1);
    expect(masked(find.text('€10,000').first), isTrue, reason: 'the portfolio value is position size');
  });

  group('pillars', () {
    final today = DateTime(2026, 3, 10);
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<int> seedHeldAsset(String ticker) async {
      final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker $ticker'));
      final id = await db
          .into(db.assets)
          .insert(
            AssetsCompanion.insert(
              name: '$ticker fund',
              ticker: Value(ticker),
              assetType: AssetType.stockEtf,
              valuationMethod: ValuationMethod.marketPrice,
              intermediaryId: broker,
            ),
          );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: id,
              date: DateTime(2025, 1, 1),
              valueDate: DateTime(2025, 1, 1),
              type: EventType.buy,
              amount: 100,
              quantity: const Value(10),
              price: const Value(10),
            ),
          );
      return id;
    }

    Future<void> pump(WidgetTester tester, Widget home, {required Pillar pillar, required List<Override> overrides}) async {
      final assets = await db.select(db.assets).get();
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            databaseProvider.overrideWithValue(db),
            nowProvider.overrideWithValue(() => today.add(const Duration(hours: 12))),
            marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
            appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
            baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
            pillarsProvider.overrideWithValue(AsyncData([pillar])),
            standardPillarsProvider.overrideWithValue(AsyncData([pillar])),
            virtualPortfoliosProvider.overrideWithValue(const AsyncData([])),
            activeAssetsProvider.overrideWithValue(AsyncData(assets)),
            assetsProvider.overrideWithValue(AsyncData(assets)),
            assetCompositionsProvider.overrideWithValue(const AsyncData({})),
            privacyModeProvider.overrideWith((ref) => true),
            ...overrides,
          ],
          child: MaterialApp(home: home),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('list: under the pillar card and the Unassigned card', (tester) async {
      final unassigned = await seedHeldAsset('GOLD');
      final pillar = (await PillarService(db).getById(await PillarService(db).create(name: 'Retirement')))!;
      await pump(
        tester,
        const PillarsScreen(),
        pillar: pillar,
        overrides: [
          pillarAssetsProvider.overrideWithValue(AsyncData([PillarAsset(pillarId: pillar.id, assetId: 99, quantity: 10)])),
          unassignedFractionProvider.overrideWithValue(AsyncData({unassigned: 1.0})),
          assetMarketValuesProvider.overrideWithValue(const AsyncData({})),
          allSeriesDataProvider.overrideWithValue(const AsyncData<AllSeriesData?>(null)),
          pillarPerformanceSnapshotsProvider.overrideWithValue(
            AsyncData({
              pillar.id: PillarPerformanceSnapshot(
                asOfDate: today,
                marketValue: 1200,
                netInvested: 1000,
                absoluteReturnAmount: 200,
                absoluteReturnPct: 0.2,
                twrr: null,
                cagr: null,
                hasSufficientHistory: false,
                excludedAssetCount: 1,
              ),
            }),
          ),
        ],
      );
      try {
        expectFootnotes(find.text(s.pillarValueAndPerformanceExcluded(1)), count: 1);
        expectFootnotes(find.text(s.pillarUnpricedExcluded(1)), count: 1);
        expect(masked(find.text('1,200.00 EUR')), isTrue, reason: 'the pillar value is position size');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('detail: under the value and under the performance', (tester) async {
      final priced = await seedHeldAsset('EM');
      final unpriced = await seedHeldAsset('GOLD');
      final pillar = (await PillarService(db).getById(await PillarService(db).create(name: 'Retirement')))!;
      for (final id in [priced, unpriced]) {
        await PillarService(db).assign(pillarId: pillar.id, assetId: id, qty: 10);
      }
      ChartSeries series(String key, List<FlSpot> spots) => ChartSeries(key: key, name: key, color: Colors.blue, spots: spots);
      final allData = AllSeriesData(
        firstDate: DateTime(2025, 1, 1),
        accounts: const [],
        assetInvested: [
          series('asset_invested:$priced', const [FlSpot(0, 1000), FlSpot(30, 1000)]),
          series('asset_invested:$unpriced', const [FlSpot(0, 500), FlSpot(30, 500)]),
        ],
        assetMarket: [
          series('asset_market:$priced', const [FlSpot(0, 1000), FlSpot(30, 1200)]),
          series('asset_market:$unpriced', const []),
        ],
        assetGain: const [],
        assetNet: const [],
        adjustments: const [],
        incomeAdjustments: const [],
        ephemeralInflows: const [],
        baseCurrency: 'EUR',
      );
      await pump(
        tester,
        PillarDetailScreen(pillarId: pillar.id),
        pillar: pillar,
        overrides: [
          pillarAssetsProvider.overrideWithValue(const AsyncData([])),
          unassignedFractionProvider.overrideWithValue(const AsyncData({})),
          assetMarketValuesProvider.overrideWithValue(AsyncData({priced: 1200})),
          allSeriesDataProvider.overrideWithValue(AsyncData<AllSeriesData?>(allData)),
          pillarPerformanceSnapshotsProvider.overrideWithValue(const AsyncData({})),
        ],
      );
      try {
        final objective = find.ancestor(of: find.text(s.pillarObjective), matching: find.byType(Card));
        expectFootnotes(find.descendant(of: objective, matching: find.text(s.pillarUnpricedExcluded(1))), count: 1);
        expectFootnotes(find.descendant(of: objective, matching: find.text(s.pillarPerformanceExcluded(1))), count: 1);
        expect(masked(find.text(s.pillarValue('1,200.00 EUR'))), isTrue, reason: 'the value is position size');
      } finally {
        await unmount(tester);
      }
    });
  });
}
