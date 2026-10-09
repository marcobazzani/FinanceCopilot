// Asset detail value chart: the chart and its drag zoom share one X extent,
// the furthest the charted series reach. The chart used to take its extent
// from the invested line alone: an asset without one drew days 0–1 only,
// while the drag zoom mapped the pointer over the whole market series.
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/assets/asset_detail_charts_provider.dart';
import 'package:finance_copilot/ui/screens/assets/asset_detail_screen.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart';

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

void main() {
  setUpAll(() async => initializeDateFormatting('en'));

  final today = DateTime(2026, 3, 10);

  Future<void> pumpValueChart(WidgetTester tester, AppDatabase db, SingleAssetChartData data) async {
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    final id = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'House',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.eventDriven,
            intermediaryId: broker,
          ),
        );
    final asset = await (db.select(db.assets)..where((a) => a.id.equals(id))).getSingle();
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          nowProvider.overrideWithValue(() => today.add(const Duration(hours: 12))),
          marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          singleAssetChartDataProvider(id).overrideWith((ref) async => data),
        ],
        child: MaterialApp(home: AssetDetailScreen(asset: asset)),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.text('Asset'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  ChartSeries series(String key, List<FlSpot> spots) => ChartSeries(key: key, name: key, color: Colors.blue, spots: spots);

  testWidgets('no invested line: the chart spans the whole market series, and so does the drag zoom', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await pumpValueChart(
      tester,
      db,
      SingleAssetChartData(
        firstDate: DateTime(2025, 1, 1),
        investedSeries: series('asset_invested:1', const []),
        marketSeries: series('asset_market:1', const [FlSpot(0, 1000), FlSpot(200, 1100), FlSpot(400, 1200)]),
        priceSeries: series('asset_price:1', const []),
        baseCurrency: 'EUR',
        assetCurrency: 'EUR',
      ),
    );
    try {
      final chart = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(chart.minX, 0);
      expect(chart.maxX, 400, reason: 'the chart used to stop at day 1');
      final zoom = tester.widget<DragZoomWrapper>(find.byType(DragZoomWrapper));
      expect(zoom.xMax, 400);
      expect(zoom.totalDays, 400);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    }
  });

  testWidgets('an invested line shorter than the market series: both extents are the market series\'', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await pumpValueChart(
      tester,
      db,
      SingleAssetChartData(
        firstDate: DateTime(2025, 1, 1),
        investedSeries: series('asset_invested:1', const [FlSpot(0, 900), FlSpot(100, 900)]),
        marketSeries: series('asset_market:1', const [FlSpot(0, 1000), FlSpot(300, 1200)]),
        priceSeries: series('asset_price:1', const []),
        baseCurrency: 'EUR',
        assetCurrency: 'EUR',
      ),
    );
    try {
      expect(tester.widget<LineChart>(find.byType(LineChart)).data.maxX, 300);
      final zoom = tester.widget<DragZoomWrapper>(find.byType(DragZoomWrapper));
      expect(zoom.xMax, 300);
      expect(zoom.totalDays, 300);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}
