// Pillar detail overview: the chart legend and the over-assignment message
// speak the display language (the message without the quantities, which are
// position size); a failed load says so instead of spinning forever; a load
// that lands mid-drag cannot move the slider under the finger; an asset
// without a price or exchange rate is left out of the pillar value and the
// weights, with a count of what was left out.
import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/pillars/pillar_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show AllSeriesData, ChartSeries, allSeriesDataProvider;
import 'package:finance_copilot/ui/screens/pillars/pillar_detail_screen.dart';

/// Answers the first `quantitiesForPillar` right away; every later call waits
/// for [release], so a test decides when a reload lands.
class _GatedPillarService extends PillarService {
  _GatedPillarService(super.db);

  int calls = 0;
  final _pending = <Completer<void>>[];

  void release() {
    for (final c in _pending) {
      c.complete();
    }
    _pending.clear();
  }

  @override
  Future<Map<int, PillarAssetQuantities>> quantitiesForPillar(String pillarId, Iterable<int> assetIds) async {
    final ids = assetIds.toList();
    final answer = await super.quantitiesForPillar(pillarId, ids);
    if (calls++ > 0) {
      final gate = Completer<void>();
      _pending.add(gate);
      await gate.future;
    }
    return answer;
  }
}

/// Fails every quantity read, as a closed database would.
class _FailingPillarService extends PillarService {
  _FailingPillarService(super.db);

  @override
  Future<Map<int, PillarAssetQuantities>> quantitiesForPillar(String pillarId, Iterable<int> assetIds) async =>
      throw StateError('database closed');
}

void main() {
  late AppDatabase db;

  setUpAll(() async => initializeDateFormatting());
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> seedAsset({required String ticker, required double qty, String? isin}) async {
    final interId = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker $ticker'));
    final id = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: '$ticker fund',
            ticker: Value(ticker),
            isin: Value(isin),
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: interId,
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
            amount: qty * 10,
            quantity: Value(qty),
            price: const Value(10),
          ),
        );
    return id;
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    required String pillarId,
    required Map<int, double> marketValues,
    String language = 'en',
    AllSeriesData? allData,
    AsyncValue<List<Asset>>? activeAssets,
    List<Pillar>? pillars,
    Stream<List<PillarAsset>>? assignments,
    PillarService? service,
    List<PortfolioModelItem> modelItems = const [],
  }) async {
    final allPillars = pillars ?? await PillarService(db).getAll();
    final assets = await db.select(db.assets).get();
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          portableLanguageProvider.overrideWith((ref) => language),
          appLocaleProvider.overrideWith((ref) => Stream.value(language == 'it' ? 'it_IT' : 'en_US')),
          baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
          pillarsProvider.overrideWithValue(AsyncData(allPillars)),
          standardPillarsProvider.overrideWithValue(AsyncData(allPillars)),
          virtualPortfoliosProvider.overrideWithValue(const AsyncData([])),
          activeAssetsProvider.overrideWithValue(activeAssets ?? AsyncData(assets)),
          assetsProvider.overrideWithValue(AsyncData(assets)),
          if (assignments == null)
            pillarAssetsProvider.overrideWithValue(const AsyncData([]))
          else
            pillarAssetsProvider.overrideWith((ref) => assignments),
          assetMarketValuesProvider.overrideWithValue(AsyncData(marketValues)),
          unassignedFractionProvider.overrideWithValue(const AsyncData({})),
          allSeriesDataProvider.overrideWithValue(AsyncData<AllSeriesData?>(allData)),
          pillarPerformanceSnapshotsProvider.overrideWithValue(const AsyncData({})),
          if (service != null) pillarServiceProvider.overrideWithValue(service),
          if (modelItems.isNotEmpty) portfolioModelItemsProvider.overrideWith((ref, modelId) => Stream.value(modelItems)),
        ],
        child: MaterialApp(home: PillarDetailScreen(pillarId: pillarId)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('chart legend: Invested and Value in the display language', (tester) async {
    final id = await seedAsset(ticker: 'EM', qty: 10);
    final pillarId = await PillarService(db).create(name: 'Pensione');
    await PillarService(db).assign(pillarId: pillarId, assetId: id, qty: 10);
    ChartSeries series(String key, double y) =>
        ChartSeries(key: key, name: key, color: Colors.blue, spots: [const FlSpot(0, 100), FlSpot(30, y)]);
    final allData = AllSeriesData(
      firstDate: DateTime(2025, 1, 1),
      accounts: const [],
      assetInvested: [series('asset_invested:$id', 100)],
      assetMarket: [series('asset_market:$id', 120)],
      assetGain: const [],
      assetNet: const [],
      adjustments: const [],
      incomeAdjustments: const [],
      ephemeralInflows: const [],
      baseCurrency: 'EUR',
    );

    await pumpScreen(tester, pillarId: pillarId, marketValues: {id: 120}, language: 'it', allData: allData);

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('Investito'), findsOneWidget);
    expect(find.text('Valore'), findsOneWidget);
    expect(find.text('Invested'), findsNothing);
    expect(find.text('Value'), findsNothing);
  });

  testWidgets('an over-assignment is explained in the display language, without the quantities', (tester) async {
    final id = await seedAsset(ticker: 'EM', qty: 129);
    final pillarId = await PillarService(db).create(name: 'Lombard');
    final other = await PillarService(db).create(name: 'FIRE');
    await pumpScreen(tester, pillarId: pillarId, marketValues: {id: 12900}, language: 'it');

    // Another window assigns part of the holding meanwhile: this screen still
    // offers all 129 units.
    await PillarService(db).assign(pillarId: other, assetId: id, qty: 3.87);
    await tester.tap(find.byTooltip('100%'));
    await tester.pumpAndSettle();

    expect(find.text('Non puoi assegnare a questo pilastro più unità di EM fund di quelle disponibili.'), findsOneWidget);
    expect(find.textContaining('over-assign'), findsNothing);
    expect(find.textContaining('125.13'), findsNothing, reason: 'the units still available are position size');
    expect(await PillarService(db).qtyFor(pillarId, id), 0, reason: 'nothing was assigned');
  });

  testWidgets('a load that fails shows the error instead of an endless spinner', (tester) async {
    final pillarId = await PillarService(db).create(name: 'Retirement');
    // The load reads through the services (never a provider nobody else
    // listens to): make the pillar's read fail.
    await pumpScreen(tester, pillarId: pillarId, marketValues: const {}, service: _FailingPillarService(db));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Error: Bad state: database closed'), findsOneWidget);
  });

  testWidgets('a reload that lands mid-drag does not move the slider under the finger', (tester) async {
    final id = await seedAsset(ticker: 'EM', qty: 100);
    final pillarId = await PillarService(db).create(name: 'Retirement');
    final gated = _GatedPillarService(db);
    final assignments = StreamController<List<PillarAsset>>.broadcast();
    addTearDown(assignments.close);
    await pumpScreen(tester, pillarId: pillarId, marketValues: {id: 1000}, service: gated, assignments: assignments.stream);
    expect(gated.calls, 1);

    // Something else changes the assignments: a reload starts and waits.
    assignments.add(const []);
    await tester.pump();
    await tester.pump();
    expect(gated.calls, 2);

    // The user grabs the slider and drags it right, finger still down.
    final slider = find.byType(Slider);
    final gesture = await tester.startGesture(tester.getTopLeft(slider) + const Offset(30, 24));
    await gesture.moveBy(const Offset(200, 0));
    await tester.pump();
    final dragged = tester.widget<Slider>(slider).value;
    expect(dragged, greaterThan(0));

    // The stale reload lands now, with the assignment it read before the drag.
    gated.release();
    await tester.pump();
    await tester.pump();
    expect(tester.widget<Slider>(slider).value, dragged, reason: 'a load started before the drag must not overwrite it');

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('model ISINs match held ISINs whatever their case and padding', (tester) async {
    final em = await seedAsset(ticker: 'EM', qty: 10, isin: 'IE00BKM4GZ66');
    final gold = await seedAsset(ticker: 'GOLD', qty: 5, isin: 'ie00b4nd3602');
    final pillarId = await PillarService(db).create(name: 'Retirement');
    await PillarService(db).assign(pillarId: pillarId, assetId: em, qty: 10);
    await PillarService(db).assign(pillarId: pillarId, assetId: gold, qty: 5);
    final pillar = (await PillarService(db).getById(pillarId))!.copyWith(portfolioModelId: const Value('model-1'));
    final targets = [
      PortfolioModelItem(id: 1, modelId: 'model-1', isin: ' ie00bkm4gz66 ', targetWeight: 60, description: 'EM', sortOrder: 0),
      PortfolioModelItem(id: 2, modelId: 'model-1', isin: 'IE00B3RBWM25', targetWeight: 40, description: 'World', sortOrder: 1),
    ];

    await pumpScreen(tester, pillarId: pillarId, marketValues: {em: 7500, gold: 2500}, pillars: [pillar], modelItems: targets);

    expect(find.text('Target: 60.00% · Current: 75.00% · Divergence: 15.00%'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Unmatched model rows'), 200, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    // Held but not in the model: listed under its ISIN as stored.
    expect(find.widgetWithText(ListTile, 'GOLD fund'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'ie00b4nd3602'), findsOneWidget);
    // In the model but not held: listed under the normalised ISIN.
    expect(find.widgetWithText(ListTile, 'IE00B3RBWM25'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Target: 40.00%'), findsOneWidget);
    expect(find.textContaining('IE00BKM4GZ66'), findsNothing, reason: 'the held EM row matched its target');
  });

  group('an asset without a price or exchange rate', () {
    testWidgets('is left out of the value and the weights, and the exclusion is counted', (tester) async {
      final priced = await seedAsset(ticker: 'EM', qty: 10, isin: 'IE00BKM4GZ66');
      final unpriced = await seedAsset(ticker: 'GOLD', qty: 5, isin: 'IE00B4ND3602');
      final pillarId = await PillarService(db).create(name: 'Retirement', targetValue: 20000);
      await PillarService(db).assign(pillarId: pillarId, assetId: priced, qty: 10);
      await PillarService(db).assign(pillarId: pillarId, assetId: unpriced, qty: 5);

      await pumpScreen(tester, pillarId: pillarId, marketValues: {priced: 10000});

      expect(find.text('Value: 10,000.00 EUR'), findsOneWidget);
      expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, 0.5);
      expect(find.text('1 asset without a price or exchange rate excluded from the value'), findsOneWidget);
      expect(find.text('0.00 EUR'), findsNothing, reason: 'a missing value is never shown as zero');
      final unpricedRow = find.byKey(ValueKey('pillar-row-$unpriced'));
      expect(
        find.descendant(of: unpricedRow, matching: find.text('—')),
        findsOneWidget,
        reason: 'the unpriced asset shows a dash for its value',
      );
      expect(find.descendant(of: unpricedRow, matching: find.textContaining('5 of 5 units · —')), findsOneWidget);
      expect(find.textContaining('10 of 10 units · 10,000.00 EUR'), findsOneWidget);
    });

    testWidgets('has no current weight against its model target', (tester) async {
      final priced = await seedAsset(ticker: 'EM', qty: 10, isin: 'IE00BKM4GZ66');
      final unpriced = await seedAsset(ticker: 'GOLD', qty: 5, isin: 'IE00B4ND3602');
      final pillarId = await PillarService(db).create(name: 'Retirement');
      await PillarService(db).assign(pillarId: pillarId, assetId: priced, qty: 10);
      await PillarService(db).assign(pillarId: pillarId, assetId: unpriced, qty: 5);
      final pillar = (await PillarService(db).getById(pillarId))!.copyWith(portfolioModelId: const Value('model-1'));
      final targets = [
        PortfolioModelItem(id: 1, modelId: 'model-1', isin: 'IE00BKM4GZ66', targetWeight: 60, description: 'EM', sortOrder: 0),
        PortfolioModelItem(id: 2, modelId: 'model-1', isin: 'ie00b4nd3602 ', targetWeight: 40, description: 'Gold', sortOrder: 1),
      ];

      await pumpScreen(tester, pillarId: pillarId, marketValues: {priced: 10000}, pillars: [pillar], modelItems: targets);

      // ISINs match whatever their case and padding.
      expect(find.text('Target: 60.00% · Current: 100.00% · Divergence: 40.00%'), findsOneWidget);
      expect(find.text('Target: 40.00% · Current: — · Divergence: —'), findsOneWidget);
      expect(find.textContaining('Current: 0.00%'), findsNothing, reason: 'an unvalued asset is not a 0% weight');
    });
  });
}
