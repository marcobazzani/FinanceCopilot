// Drag-to-zoom maps the pointer to chart values through the Y range the
// wrapper is handed; the chart draws its own. UnifiedChart fits Y to the data
// inside the VISIBLE X window, while the dashboard card, the full-screen view
// and the asset detail charts used to hand the wrapper a range fitted to the
// WHOLE series. With an X window and no Y zoom — every Cash Flow chart opens on
// the last 365 days — an old out-of-view spike made a drag zoom onto values
// nowhere near the pointer.
//
// Each drag test reads the values under the pointer from what fl_chart paints
// (the drawn minY/maxY over the drawing rectangle), then checks the zoom the
// drag applies.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/models/dashboard_chart.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/assets/asset_detail_screen.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart';
import 'package:finance_copilot/ui/screens/dashboard/fullscreen_chart_screen.dart';

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

void main() {
  setUpAll(() async => initializeDateFormatting('en'));

  final firstDate = DateTime(2026, 1, 1);

  // An early spike far above the rest: in view it dominates the range, out of
  // view it must not squeeze the recent data.
  const spiked = [FlSpot(0, 10000), FlSpot(100, 1000), FlSpot(200, 1100), FlSpot(300, 1200), FlSpot(400, 1300)];
  ChartSeries series(String key, List<FlSpot> spots, {bool rightAxis = false}) =>
      ChartSeries(key: key, name: key, color: const Color(0xFF2196F3), spots: spots, rightAxis: rightAxis);

  Finder leafOf(Finder lineChart) =>
      find.descendant(of: lineChart, matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == 'LineChartLeaf'));

  /// The Y range fl_chart draws.
  ({double minY, double maxY}) drawnY(WidgetTester tester, Finder lineChart) {
    final data = tester.widget<LineChart>(lineChart).data;
    return (minY: data.minY, maxY: data.maxY);
  }

  /// The chart value painted at global pixel row [dy] of [lineChart].
  double valueAtRow(WidgetTester tester, Finder lineChart, double dy) {
    final drawn = drawnY(tester, lineChart);
    final leaf = tester.renderObject<RenderBox>(leafOf(lineChart));
    final fraction = (dy - leaf.localToGlobal(Offset.zero).dy) / leaf.size.height;
    return drawn.maxY - fraction * (drawn.maxY - drawn.minY);
  }

  /// The global pixel column where [lineChart] paints chart X [x].
  double columnOfX(WidgetTester tester, Finder lineChart, double x) {
    final data = tester.widget<LineChart>(lineChart).data;
    final leaf = tester.renderObject<RenderBox>(leafOf(lineChart));
    return leaf.localToGlobal(Offset.zero).dx + (x - data.minX) / (data.maxX - data.minX) * leaf.size.width;
  }

  Future<void> mouseDrag(WidgetTester tester, Offset from, Offset to) async {
    final gesture = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
    await gesture.moveTo(to);
    await tester.pump();
    await gesture.up();
    // Let the double-tap / long-press recognizers' timers run out.
    await tester.pump(const Duration(seconds: 1));
  }

  /// The values a drag between [from] and [to] should zoom onto: the ones
  /// painted under the pointer, low to high.
  ({double lo, double hi}) valuesUnder(WidgetTester tester, Finder lineChart, Offset from, Offset to) {
    final a = valueAtRow(tester, lineChart, from.dy);
    final b = valueAtRow(tester, lineChart, to.dy);
    return (lo: a < b ? a : b, hi: a < b ? b : a);
  }

  group('UnifiedChart draws a Y range fitted to the visible X window', () {
    Future<({double minY, double maxY})> pumpChart(
      WidgetTester tester, {
      required List<ChartSeries> visible,
      required List<FlSpot> totalSpots,
      bool showTotal = true,
      double? zoomMinX,
      double? zoomMaxX,
      double? zoomMinY,
      double? zoomMaxY,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 400,
              child: UnifiedChart(
                firstDate: firstDate,
                visible: visible,
                totalSpots: totalSpots,
                showTotal: showTotal,
                baseCurrency: 'EUR',
                locale: 'en_US',
                language: 'en_US',
                zoomMinX: zoomMinX,
                zoomMaxX: zoomMaxX,
                zoomMinY: zoomMinY,
                zoomMaxY: zoomMaxY,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final drawn = drawnY(tester, find.byType(LineChart));
      expect(tester.widget<UnifiedChart>(find.byType(UnifiedChart)).drawnYRange, drawn, reason: 'the range callers hand the drag zoom');
      return drawn;
    }

    testWidgets('no X window: the whole series, padded by 5%', (tester) async {
      final y = await pumpChart(tester, visible: [series('asset_market:1', spiked)], totalSpots: spiked);
      expect(y.minY, closeTo(1000 - 9000 * 0.05, 1e-9));
      expect(y.maxY, closeTo(10000 + 9000 * 0.05, 1e-9));
    });

    testWidgets('an X window leaves an out-of-view spike out', (tester) async {
      final y = await pumpChart(tester, visible: [series('asset_market:1', spiked)], totalSpots: spiked, zoomMinX: 150, zoomMaxX: 400);
      // In view: 1100, 1200, 1300 plus the sample straddling the left edge (1000).
      expect(y.minY, closeTo(1000 - 300 * 0.05, 1e-9));
      expect(y.maxY, closeTo(1300 + 300 * 0.05, 1e-9));
    });

    testWidgets('an explicit Y zoom wins over the fit', (tester) async {
      final y = await pumpChart(
        tester,
        visible: [series('asset_market:1', spiked)],
        totalSpots: spiked,
        zoomMinX: 150,
        zoomMaxX: 400,
        zoomMinY: 1111,
        zoomMaxY: 1222,
      );
      expect(y, (minY: 1111.0, maxY: 1222.0));
    });

    testWidgets('a right-axis series and a hidden Total do not stretch the left range', (tester) async {
      const left = [FlSpot(0, 100), FlSpot(10, 200)];
      final y = await pumpChart(
        tester,
        visible: [
          series('cf:saving', left),
          series('cf:diff', const [FlSpot(0, -5000), FlSpot(10, 5000)], rightAxis: true),
        ],
        totalSpots: const [FlSpot(0, 99999), FlSpot(10, 99999)],
        showTotal: false,
      );
      expect(y.minY, closeTo(100 - 100 * 0.05, 1e-9));
      expect(y.maxY, closeTo(200 + 100 * 0.05, 1e-9));
    });

    testWidgets('a flat line gets a fixed margin of 100 either side', (tester) async {
      const flat = [FlSpot(0, 500), FlSpot(10, 500)];
      final y = await pumpChart(tester, visible: [series('account:1', flat)], totalSpots: flat);
      expect(y, (minY: 400.0, maxY: 600.0));
    });
  });

  testWidgets('dashboard card with an X window: a drag zooms Y onto the values under the pointer', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final shown = [series('asset_market:1', spiked)];
    double? zoomMinY, zoomMaxY;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ChartCard(
              chart: DashboardChart(id: 1, title: 'Portfolio', widgetType: 'chart', sortOrder: 0, seriesJson: '[]', createdAt: firstDate),
              series: shown,
              allData: AllSeriesData(
                firstDate: firstDate,
                accounts: const [],
                assetInvested: const [],
                assetMarket: shown,
                assetGain: const [],
                assetNet: const [],
                adjustments: const [],
                incomeAdjustments: const [],
                ephemeralInflows: const [],
                baseCurrency: 'EUR',
              ),
              hidden: const {},
              locale: 'en_US',
              language: 'en_US',
              chartHeight: 420,
              // The window a Cash Flow chart opens on: the latest stretch only.
              zoomMinX: 150,
              zoomMaxX: 400,
              onToggle: (_) {},
              onToggleGroup: (_) {},
              onToggleHideComponents: () {},
              onZoom: (_, _, minY, maxY) {
                zoomMinY = minY;
                zoomMaxY = maxY;
              },
              onHeightChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final chart = find.byType(LineChart);
    final center = tester.getCenter(chart);
    final from = center - const Offset(100, 60);
    final to = center + const Offset(100, 60);
    final expected = valuesUnder(tester, chart, from, to);
    await mouseDrag(tester, from, to);

    expect(zoomMinY, closeTo(expected.lo, 0.01), reason: 'the drawn range is ${drawnY(tester, chart)}');
    expect(zoomMaxY, closeTo(expected.hi, 0.01));
  });

  testWidgets('full-screen chart: after an X-only zoom, a drag zooms Y onto the values under the pointer', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
        ],
        child: MaterialApp(
          home: FullscreenChartScreen(
            title: 'Portfolio',
            series: [series('asset_market:1', spiked)],
            totalSpots: spiked,
            showTotal: true,
            firstDate: firstDate,
            baseCurrency: 'EUR',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final chart = find.byType(LineChart);

    // A flat horizontal drag past the spike: an X window, no Y zoom.
    final row = tester.getCenter(chart).dy;
    await mouseDrag(tester, Offset(columnOfX(tester, chart, 150), row), Offset(columnOfX(tester, chart, 390), row + 1));
    final afterX = tester.widget<UnifiedChart>(find.byType(UnifiedChart));
    expect(afterX.zoomMinX, isNotNull);
    expect(afterX.zoomMinY, isNull, reason: 'the first drag only narrows X');
    expect(drawnY(tester, chart).maxY, lessThan(2000), reason: 'the out-of-view spike no longer sets the range');

    final center = tester.getCenter(chart);
    final from = center - const Offset(100, 60);
    final to = center + const Offset(100, 60);
    final expected = valuesUnder(tester, chart, from, to);
    await mouseDrag(tester, from, to);

    final zoomed = tester.widget<UnifiedChart>(find.byType(UnifiedChart));
    expect(zoomed.zoomMinY, closeTo(expected.lo, 0.01));
    expect(zoomed.zoomMaxY, closeTo(expected.hi, 0.01));
  });

  testWidgets('asset detail price chart: after an X-only zoom, a drag zooms Y onto the values under the pointer', (tester) async {
    final today = DateTime(2026, 3, 10);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    final id = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'Fund',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: broker,
          ),
        );
    final closes = [
      (DateTime(2025, 1, 10), 500.0), // the spike, at the first buy
      (DateTime(2025, 2, 10), 100.0),
      (DateTime(2025, 6, 2), 110.0),
      (DateTime(2025, 10, 1), 115.0),
      (today, 121.0),
    ];
    await db
        .into(db.assetEvents)
        .insert(
          AssetEventsCompanion.insert(
            assetId: id,
            date: closes.first.$1,
            valueDate: closes.first.$1,
            type: EventType.buy,
            amount: 5000,
            quantity: const Value(10),
            price: const Value(500),
          ),
        );
    for (final (date, close) in closes) {
      await db.into(db.marketPrices).insert(MarketPricesCompanion.insert(assetId: id, date: date, closePrice: close, currency: 'EUR'));
    }
    final fund = await (db.select(db.assets)..where((a) => a.id.equals(id))).getSingle();

    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final screen = AssetDetailScreen(asset: fund);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          nowProvider.overrideWithValue(() => today.add(const Duration(hours: 12))),
          marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
        ],
        child: MaterialApp(home: screen),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    try {
      await settle();
      await tester.tap(find.text('Price'));
      await settle();
      final chart = find.descendant(
        of: find.ancestor(of: find.text('Price'), matching: find.byType(Card)).first,
        matching: find.byType(LineChart),
      );
      expect(chart, findsOneWidget);

      // A flat horizontal drag past the spike: an X window, no Y zoom.
      final row = tester.getCenter(chart).dy;
      await mouseDrag(tester, Offset(columnOfX(tester, chart, 160), row), Offset(columnOfX(tester, chart, 400), row + 1));
      await settle();
      final unified = find.descendant(
        of: find.ancestor(of: chart, matching: find.byType(Card)).first,
        matching: find.byType(UnifiedChart),
      );
      expect(tester.widget<UnifiedChart>(unified).zoomMinX, isNotNull);
      expect(tester.widget<UnifiedChart>(unified).zoomMinY, isNull, reason: 'the first drag only narrows X');
      expect(drawnY(tester, chart).maxY, lessThan(200), reason: 'the out-of-view spike no longer sets the range');

      final center = tester.getCenter(chart);
      final from = center - const Offset(100, 40);
      final to = center + const Offset(100, 40);
      final expected = valuesUnder(tester, chart, from, to);
      await mouseDrag(tester, from, to);
      await settle();

      final zoomed = tester.widget<UnifiedChart>(unified);
      expect(zoomed.zoomMinY, closeTo(expected.lo, 0.01));
      expect(zoomed.zoomMaxY, closeTo(expected.hi, 0.01));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}
