import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/providers.dart';
import '../../database/tables.dart';
import '../../services/providers/providers.dart';
import 'dashboard/dashboard_screen.dart'
    show ChartSeries, allSeriesDataProvider;

/// Chart data for a single asset: invested + market value, and raw price.
class SingleAssetChartData {
  final DateTime firstDate;
  final ChartSeries investedSeries;
  final ChartSeries marketSeries;
  final ChartSeries priceSeries;
  final String baseCurrency;
  final String assetCurrency;

  const SingleAssetChartData({
    required this.firstDate,
    required this.investedSeries,
    required this.marketSeries,
    required this.priceSeries,
    required this.baseCurrency,
    required this.assetCurrency,
  });
}

/// Extracts invested + market series for a single asset from the shared
/// dashboard [allSeriesDataProvider], and adds a raw price series.
final singleAssetChartDataProvider =
    FutureProvider.family<SingleAssetChartData?, int>((ref, assetId) async {
  final allData = await ref.watch(allSeriesDataProvider.future);
  if (allData == null) return null;

  // Find this asset's invested and market series from the dashboard data
  final invMatch = allData.assetInvested
      .where((s) => s.key == 'asset_invested:$assetId');
  final mktMatch = allData.assetMarket
      .where((s) => s.key == 'asset_market:$assetId');
  if (mktMatch.isEmpty) return null;

  final marketSeries = mktMatch.first;
  final investedSeries = invMatch.isNotEmpty
      ? invMatch.first
      : ChartSeries(
          key: 'asset_invested:$assetId',
          name: marketSeries.name,
          color: Colors.orange,
          spots: const [],
          isDashed: true,
        );

  // Look up the asset for currency and instrument type
  final db = ref.watch(databaseProvider);
  final asset = await (db.select(db.assets)
        ..where((a) => a.id.equals(assetId)))
      .getSingleOrNull();
  if (asset == null) return null;

  // Build raw price series from market_prices table
  final marketPriceService = ref.watch(marketPriceServiceProvider);
  final prices = await marketPriceService.getPriceHistoryBatch([assetId]);
  final priceList = prices[assetId] ?? [];
  final bondDiv = asset.instrumentType == InstrumentType.bond ? 100.0 : 1.0;

  // Find the X offset of this asset's first data point so we can shift
  // all spots to start at x=0 (avoids empty space from global firstDate).
  final allAssetSpots = [
    ...investedSeries.spots,
    ...marketSeries.spots,
  ];
  if (allAssetSpots.isEmpty) return null;
  final xOffset = allAssetSpots.map((s) => s.x).reduce((a, b) => a < b ? a : b);

  List<FlSpot> shift(List<FlSpot> spots) =>
      spots.map((s) => FlSpot(s.x - xOffset, s.y)).toList();

  // Asset-local firstDate (shifted by xOffset days from global firstDate)
  final assetFirstDate = allData.firstDate.add(Duration(days: xOffset.toInt()));

  // Build raw price series, also shifted
  final priceSpots = <FlSpot>[];
  for (final p in priceList) {
    final x = p.key.difference(allData.firstDate).inDays.toDouble() - xOffset;
    if (x >= 0) priceSpots.add(FlSpot(x, p.value / bondDiv));
  }

  return SingleAssetChartData(
    firstDate: assetFirstDate,
    investedSeries: ChartSeries(
      key: investedSeries.key,
      name: investedSeries.name,
      color: Colors.orange,
      spots: shift(investedSeries.spots),
      isDashed: true,
    ),
    marketSeries: ChartSeries(
      key: marketSeries.key,
      name: marketSeries.name,
      color: Colors.blue,
      spots: shift(marketSeries.spots),
    ),
    priceSeries: ChartSeries(
      key: 'asset_price:$assetId',
      name: marketSeries.name,
      color: Colors.blue,
      spots: priceSpots,
    ),
    baseCurrency: allData.baseCurrency,
    assetCurrency: asset.currency,
  );
});
