import 'package:drift/drift.dart';

import '../database/database.dart';
import '../utils/logger.dart';

final _log = getLogger('MarketPriceService');

/// Supported exchanges for the UI picker. Label → exchange code.
const supportedExchanges = <String, String>{
  'Borsa Italiana (Milan)': 'MIL',
  'NYSE': 'NYQ',
  'NASDAQ': 'NMS',
  'XETRA (Frankfurt)': 'XETRA',
  'London Stock Exchange': 'LON',
  'Euronext Amsterdam': 'AMS',
  'Euronext Paris': 'PAR',
  'SIX Swiss Exchange': 'SIX',
  'Toronto Stock Exchange': 'TSE',
  'Hong Kong Stock Exchange': 'HKG',
  'Tokyo Stock Exchange': 'TYO',
};

/// Abstract base for market price providers.
/// Handles all DB logic; subclasses only implement the HTTP fetch.
abstract class MarketPriceService {
  final AppDatabase db;

  MarketPriceService(this.db);

  // ──────────────────────────────────────────────
  // Abstract — override in implementations
  // ──────────────────────────────────────────────

  /// Fetch daily close prices from [from] to today for [ticker].
  Future<Map<DateTime, double>> fetchHistoricalPrices(
      String ticker, String currency, DateTime from);

  // ──────────────────────────────────────────────
  // Sync — calls abstract fetch, stores in DB
  // ──────────────────────────────────────────────

  /// Sync prices for all active assets that have a ticker.
  /// If [forceToday] is true, re-fetch today's price even if already synced.
  Future<void> syncPrices({bool forceToday = false}) async {
    try {
      final assets = await (db.select(db.assets)
            ..where((a) => a.isActive.equals(true))
            ..where((a) => a.ticker.isNotNull()))
          .get();

      _log.info('syncPrices: found ${assets.length} active assets with tickers');

      for (var i = 0; i < assets.length; i++) {
        final asset = assets[i];
        try {
          await _syncAsset(asset, forceToday: forceToday);
        } catch (e) {
          _log.warning('syncPrices: failed for ${asset.name} (${asset.ticker}): $e');
        }
        // Rate-limit: wait between requests
        if (i < assets.length - 1) {
          await Future.delayed(const Duration(milliseconds: 1500));
        }
      }

      _log.info('syncPrices: done');
    } catch (e, stack) {
      _log.warning('syncPrices: unexpected error', e, stack);
    }
  }

  Future<void> _syncAsset(Asset asset, {bool forceToday = false}) async {
    final ticker = asset.ticker;
    if (ticker == null || ticker.isEmpty) return;

    final lastDate = await getLastSyncDate(asset.id);
    final firstBuy = await getFirstBuyDate(asset.id);
    final defaultFrom = firstBuy ?? DateTime(2020, 1, 1);
    final today = DateTime.now();

    DateTime from;
    if (lastDate != null) {
      if (forceToday) {
        // On manual refresh, re-fetch from today (or last+1, whichever is later)
        final lastPlus1 = lastDate.add(const Duration(days: 1));
        from = DateTime(today.year, today.month, today.day).isAfter(lastPlus1)
            ? lastPlus1
            : DateTime(today.year, today.month, today.day);
      } else {
        from = lastDate.add(const Duration(days: 1));
      }
    } else {
      from = defaultFrom;
    }

    if (!forceToday && !from.isBefore(today)) {
      _log.fine('syncPrices: ${asset.name} already up to date');
      return;
    }

    _log.info('syncPrices: fetching $ticker from ${from.toIso8601String().substring(0, 10)}');
    final prices = await fetchHistoricalPrices(ticker, asset.currency, from);

    if (prices.isEmpty) {
      _log.info('syncPrices: no new prices for $ticker');
      return;
    }

    await db.batch((batch) {
      for (final entry in prices.entries) {
        final c = MarketPricesCompanion(
          assetId: Value(asset.id),
          date: Value(entry.key),
          closePrice: Value(entry.value),
          currency: Value(asset.currency),
        );
        batch.insert(db.marketPrices, c, onConflict: DoUpdate((_) => c));
      }
    });

    _log.info('syncPrices: inserted ${prices.length} prices for $ticker');
  }

  // ──────────────────────────────────────────────
  // DB reads
  // ──────────────────────────────────────────────

  /// Date of the first "buy" event for an asset, or null if none.
  Future<DateTime?> getFirstBuyDate(int assetId) async {
    final row = await db.customSelect(
      "SELECT MIN(date) AS min_date FROM asset_events WHERE asset_id = ? AND type = 'buy'",
      variables: [Variable.withInt(assetId)],
    ).getSingleOrNull();
    return row?.readNullable<DateTime>('min_date');
  }

  /// Earliest stored price date for an asset.
  Future<DateTime?> getFirstPriceDate(int assetId) async {
    final row = await db.customSelect(
      'SELECT MIN(date) AS min_date FROM market_prices WHERE asset_id = ?',
      variables: [Variable.withInt(assetId)],
    ).getSingleOrNull();
    return row?.readNullable<DateTime>('min_date');
  }

  /// Last stored price date for an asset.
  Future<DateTime?> getLastSyncDate(int assetId) async {
    final row = await db.customSelect(
      'SELECT MAX(date) AS max_date FROM market_prices WHERE asset_id = ?',
      variables: [Variable.withInt(assetId)],
    ).getSingleOrNull();
    return row?.readNullable<DateTime>('max_date');
  }

  /// Get close price on or before [date] for [assetId].
  Future<double?> getPrice(int assetId, DateTime date) async {
    final epochSec = date.millisecondsSinceEpoch ~/ 1000;
    final row = await db.customSelect(
      'SELECT close_price FROM market_prices '
      'WHERE asset_id = ? AND date <= ? ORDER BY date DESC LIMIT 1',
      variables: [Variable.withInt(assetId), Variable.withInt(epochSec)],
    ).getSingleOrNull();
    return row?.readNullable<double>('close_price');
  }

  /// Get all prices for an asset, sorted by date ascending.
  Future<List<MapEntry<DateTime, double>>> getPriceHistory(int assetId) async {
    final rows = await db.customSelect(
      'SELECT date, close_price FROM market_prices '
      'WHERE asset_id = ? ORDER BY date ASC',
      variables: [Variable.withInt(assetId)],
    ).get();
    return rows.map((r) => MapEntry(
      DateTime.fromMillisecondsSinceEpoch(r.read<int>('date') * 1000),
      r.read<double>('close_price'),
    )).toList();
  }
}
