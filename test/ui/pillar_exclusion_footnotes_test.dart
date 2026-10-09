// Pillars: what a figure leaves out is counted where the figure is shown, and a
// figure with nothing behind it is a dash, never 0.
//
//  * Assets Overview tab: a held asset without a value is counted under the
//    charts (the count was computed but never passed on).
//  * Pillar detail: the assets the performance leaves out are counted under
//    it; a pillar whose every asset is unpriced has no value ("Value: 0.00
//    EUR" before) and no progress; an unpriced asset is not ranked as if it
//    were worth 0.
//  * Pillar list: the card's value and performance leave out the assets
//    without a value while its asset count includes them — now counted under
//    the card; with every asset left out the value is a dash, not 0.00 EUR.
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
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show AllSeriesData, ChartSeries, allSeriesDataProvider;
import 'package:finance_copilot/ui/screens/pillars/pillar_detail_screen.dart';
import 'package:finance_copilot/ui/screens/pillars/pillars_screen.dart';

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

void main() {
  const s = AppStrings.en;
  final today = DateTime(2026, 3, 10);
  late AppDatabase db;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<int> seedHeldAsset(String ticker, {InstrumentType type = InstrumentType.etf}) async {
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker $ticker'));
    final id = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: '$ticker fund',
            ticker: Value(ticker),
            assetType: AssetType.stockEtf,
            instrumentType: Value(type),
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

  Future<Pillar> seedPillar({double? target}) async {
    final id = await PillarService(db).create(name: 'Retirement', targetValue: target);
    return (await PillarService(db).getById(id))!;
  }

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    required List<Pillar> pillars,
    List<Override> overrides = const [],
    bool isPrivate = false,
  }) async {
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
          pillarsProvider.overrideWithValue(AsyncData(pillars)),
          standardPillarsProvider.overrideWithValue(AsyncData(pillars)),
          virtualPortfoliosProvider.overrideWithValue(const AsyncData([])),
          activeAssetsProvider.overrideWithValue(AsyncData(assets)),
          assetsProvider.overrideWithValue(AsyncData(assets)),
          unassignedFractionProvider.overrideWithValue(const AsyncData({})),
          assetCompositionsProvider.overrideWithValue(const AsyncData({})),
          privacyModeProvider.overrideWith((ref) => isPrivate),
          ...overrides,
        ],
        child: MaterialApp(home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  ChartSeries series(String key, List<FlSpot> spots) => ChartSeries(key: key, name: key, color: Colors.blue, spots: spots);

  AllSeriesData seriesData({required List<ChartSeries> invested, required List<ChartSeries> market}) => AllSeriesData(
    firstDate: DateTime(2025, 1, 1),
    accounts: const [],
    assetInvested: invested,
    assetMarket: market,
    assetGain: const [],
    assetNet: const [],
    adjustments: const [],
    incomeAdjustments: const [],
    ephemeralInflows: const [],
    baseCurrency: 'EUR',
  );

  group('pillar detail', () {
    List<Override> detailOverrides(Map<int, double> marketValues, {AllSeriesData? allData}) => [
      pillarAssetsProvider.overrideWithValue(const AsyncData([])),
      assetMarketValuesProvider.overrideWithValue(AsyncData(marketValues)),
      allSeriesDataProvider.overrideWithValue(AsyncData<AllSeriesData?>(allData)),
      pillarPerformanceSnapshotsProvider.overrideWithValue(const AsyncData({})),
    ];

    testWidgets('Assets Overview: a held asset without a value is counted under the charts', (tester) async {
      final priced = await seedHeldAsset('EM');
      final pillar = await seedPillar();
      final asset = await (db.select(db.assets)..where((a) => a.id.equals(priced))).getSingle();
      await pump(
        tester,
        PillarDetailScreen(pillarId: pillar.id),
        pillars: [pillar],
        overrides: [
          ...detailOverrides({priced: 1000}),
          pillarAllocationDataProvider(pillar.id).overrideWith(
            (ref) async => PillarAllocationData(assets: [asset], marketValues: {priced: 1000}, baseCurrency: 'EUR', unvaluedAssetCount: 1),
          ),
        ],
      );
      try {
        await tester.tap(find.widgetWithText(Tab, s.dashTabAssetsOverview));
        await tester.pumpAndSettle();
        expect(find.text(s.unpricedExcludedFromTotal(1)), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('the assets the performance leaves out are counted under it', (tester) async {
      final priced = await seedHeldAsset('EM');
      final unpriced = await seedHeldAsset('GOLD');
      final pillar = await seedPillar();
      for (final id in [priced, unpriced]) {
        await PillarService(db).assign(pillarId: pillar.id, assetId: id, qty: 10);
      }
      final allData = seriesData(
        invested: [
          series('asset_invested:$priced', const [FlSpot(0, 1000), FlSpot(30, 1000)]),
          series('asset_invested:$unpriced', const [FlSpot(0, 500), FlSpot(30, 500)]),
        ],
        market: [
          series('asset_market:$priced', const [FlSpot(0, 1000), FlSpot(30, 1200)]),
          series('asset_market:$unpriced', const []),
        ],
      );
      await pump(
        tester,
        PillarDetailScreen(pillarId: pillar.id),
        pillars: [pillar],
        overrides: detailOverrides({priced: 1200}, allData: allData),
      );
      try {
        final objective = find.ancestor(of: find.text(s.pillarObjective), matching: find.byType(Card));
        expect(find.descendant(of: objective, matching: find.text(s.pillarPerformanceExcluded(1))), findsOneWidget);
        expect(
          find.descendant(of: objective, matching: find.text(s.pillarUnpricedExcluded(1))),
          findsOneWidget,
          reason: 'and the value',
        );
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('nothing left out of the performance: no footnote', (tester) async {
      final priced = await seedHeldAsset('EM');
      final pillar = await seedPillar();
      await PillarService(db).assign(pillarId: pillar.id, assetId: priced, qty: 10);
      final allData = seriesData(
        invested: [
          series('asset_invested:$priced', const [FlSpot(0, 1000), FlSpot(30, 1000)]),
        ],
        market: [
          series('asset_market:$priced', const [FlSpot(0, 1000), FlSpot(30, 1200)]),
        ],
      );
      await pump(
        tester,
        PillarDetailScreen(pillarId: pillar.id),
        pillars: [pillar],
        overrides: detailOverrides({priced: 1200}, allData: allData),
      );
      try {
        expect(find.textContaining('excluded'), findsNothing);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('every asset unpriced: the value is a dash and there is no progress, never 0.00 EUR', (tester) async {
      final unpriced = await seedHeldAsset('GOLD');
      final pillar = await seedPillar(target: 12345);
      await PillarService(db).assign(pillarId: pillar.id, assetId: unpriced, qty: 10);
      await pump(
        tester,
        PillarDetailScreen(pillarId: pillar.id),
        pillars: [pillar],
        overrides: detailOverrides(const {}),
      );
      try {
        expect(find.text(s.pillarValue('—')), findsOneWidget);
        expect(find.textContaining('0.00 EUR'), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsNothing, reason: 'no progress toward the target from an unknown value');
        expect(find.text(s.pillarUnpricedExcluded(1)), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('an empty pillar is worth 0', (tester) async {
      final pillar = await seedPillar();
      await pump(
        tester,
        PillarDetailScreen(pillarId: pillar.id),
        pillars: [pillar],
        overrides: detailOverrides(const {}),
      );
      try {
        expect(find.text(s.pillarValue('0.00 EUR')), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('privacy: the value is masked; the counts of what is left out stay readable', (tester) async {
      final priced = await seedHeldAsset('EM');
      final unpriced = await seedHeldAsset('GOLD');
      final pillar = await seedPillar();
      for (final id in [priced, unpriced]) {
        await PillarService(db).assign(pillarId: pillar.id, assetId: id, qty: 10);
      }
      final allData = seriesData(
        invested: [
          series('asset_invested:$priced', const [FlSpot(0, 1000), FlSpot(30, 1000)]),
          series('asset_invested:$unpriced', const [FlSpot(0, 500), FlSpot(30, 500)]),
        ],
        market: [
          series('asset_market:$priced', const [FlSpot(0, 1000), FlSpot(30, 1200)]),
          series('asset_market:$unpriced', const []),
        ],
      );
      await pump(
        tester,
        PillarDetailScreen(pillarId: pillar.id),
        pillars: [pillar],
        overrides: detailOverrides({priced: 1200}, allData: allData),
        isPrivate: true,
      );
      try {
        expect(masked(find.text(s.pillarValue('1,200.00 EUR'))), isTrue, reason: 'the value is position size');
        expect(masked(find.text(s.pillarUnpricedExcluded(1))), isFalse, reason: 'a count of assets');
        expect(masked(find.text(s.pillarPerformanceExcluded(1))), isFalse, reason: 'a count of assets');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('privacy: an unknown value is a readable dash; the target stays masked', (tester) async {
      final unpriced = await seedHeldAsset('GOLD');
      final pillar = await seedPillar(target: 12345);
      await PillarService(db).assign(pillarId: pillar.id, assetId: unpriced, qty: 10);
      await pump(
        tester,
        PillarDetailScreen(pillarId: pillar.id),
        pillars: [pillar],
        overrides: detailOverrides(const {}),
        isPrivate: true,
      );
      try {
        expect(masked(find.text(s.pillarValue('—'))), isFalse, reason: 'a dash carries no magnitude');
        expect(masked(find.text(s.pillarTarget('12,345.00 EUR'))), isTrue);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('an unpriced asset is ranked after every valued one, even one worth less than nothing', (tester) async {
      final unpriced = await seedHeldAsset('GOLD');
      final loan = await seedHeldAsset('LOAN', type: InstrumentType.liability);
      final pillar = await seedPillar();
      for (final id in [unpriced, loan]) {
        await PillarService(db).assign(pillarId: pillar.id, assetId: id, qty: 10);
      }
      await pump(
        tester,
        PillarDetailScreen(pillarId: pillar.id),
        pillars: [pillar],
        overrides: detailOverrides({loan: -5000}),
      );
      try {
        double top(String ticker) => tester.getTopLeft(find.textContaining('$ticker  ·  ').first).dy;
        expect(top('LOAN'), lessThan(top('GOLD')), reason: 'GOLD has no value to rank by, it is not worth 0');
      } finally {
        await unmount(tester);
      }
    });
  });

  group('pillar list', () {
    PillarPerformanceSnapshot snapshot({required double marketValue, required double netInvested, int excluded = 0}) =>
        PillarPerformanceSnapshot(
          asOfDate: today,
          marketValue: marketValue,
          netInvested: netInvested,
          absoluteReturnAmount: marketValue - netInvested,
          absoluteReturnPct: marketValue / netInvested - 1,
          twrr: null,
          cagr: null,
          hasSufficientHistory: false,
          excludedAssetCount: excluded,
        );

    Future<void> pumpList(WidgetTester tester, Pillar pillar, PillarPerformanceSnapshot performance, {bool isPrivate = false}) => pump(
      tester,
      const PillarsScreen(),
      pillars: [pillar],
      isPrivate: isPrivate,
      overrides: [
        pillarAssetsProvider.overrideWithValue(
          AsyncData([PillarAsset(pillarId: pillar.id, assetId: 1, quantity: 10), PillarAsset(pillarId: pillar.id, assetId: 2, quantity: 5)]),
        ),
        assetMarketValuesProvider.overrideWithValue(const AsyncData({})),
        allSeriesDataProvider.overrideWithValue(const AsyncData<AllSeriesData?>(null)),
        pillarPerformanceSnapshotsProvider.overrideWithValue(AsyncData({pillar.id: performance})),
      ],
    );

    Finder inCard(Finder f) => find.descendant(
      of: find.ancestor(of: find.text('Retirement'), matching: find.byType(Card)),
      matching: f,
    );

    testWidgets('the card counts the assets its value and performance leave out', (tester) async {
      final pillar = await seedPillar();
      await pumpList(tester, pillar, snapshot(marketValue: 1200, netInvested: 1000, excluded: 1));
      try {
        expect(inCard(find.text('1,200.00 EUR')), findsOneWidget);
        expect(inCard(find.text(' · ${s.pillarAssetCount(2)}')), findsOneWidget, reason: 'the count includes the one left out');
        expect(inCard(find.text(s.pillarValueAndPerformanceExcluded(1))), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('nothing left out: no footnote', (tester) async {
      final pillar = await seedPillar();
      await pumpList(tester, pillar, snapshot(marketValue: 1200, netInvested: 1000));
      try {
        expect(find.textContaining('excluded'), findsNothing);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('privacy: the value is masked, the count of what is left out stays readable', (tester) async {
      final pillar = await seedPillar();
      await pumpList(tester, pillar, snapshot(marketValue: 1200, netInvested: 1000, excluded: 1), isPrivate: true);
      try {
        expect(masked(inCard(find.text('1,200.00 EUR'))), isTrue);
        expect(masked(inCard(find.text(s.pillarValueAndPerformanceExcluded(1)))), isFalse);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('every asset left out: the value is a dash, not 0.00 EUR', (tester) async {
      final pillar = await seedPillar(target: 10000);
      await pumpList(tester, pillar, PillarPerformanceSnapshot.empty(today, excludedAssetCount: 2));
      try {
        expect(find.textContaining('0.00 EUR'), findsNothing);
        expect(inCard(find.text('—')), findsWidgets);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(inCard(find.text(s.pillarValueAndPerformanceExcluded(2))), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });
  });
}
