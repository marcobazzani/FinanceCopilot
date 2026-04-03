import 'package:drift/drift.dart';

import '../database/database.dart';
import '../utils/formatters.dart' show formatYmd;
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

/// Reverse map: Investing.com exchange name → internal code.
/// Derived from `_exchangeNames` in investing_com_service.dart.
const investingExchangeToCode = <String, String>{
  'Milano': 'MIL',
  'NASDAQ': 'NMS',
  'NYSE': 'NYQ',
  'AMEX': 'ASE',
  'Xetra': 'XETRA',
  'Francoforte': 'FRA',
  'Frankfurt': 'FRA',
  'London': 'LON',
  'Londra': 'LON',
  'Amsterdam': 'AMS',
  'Parigi': 'PAR',
  'Paris': 'PAR',
  'Bruxelles': 'BRU',
  'Brussels': 'BRU',
  'Lisbona': 'LIS',
  'Lisbon': 'LIS',
  'Svizzera': 'SIX',
  'Toronto': 'TSE',
  'Hong Kong': 'HKG',
  'Tokyo': 'TYO',
};

/// Exchange code → native currency mapping.
const exchangeCodeToCurrency = <String, String>{
  'MIL': 'EUR',
  'NYQ': 'USD',
  'NMS': 'USD',
  'ASE': 'USD',
  'XETRA': 'EUR',
  'FRA': 'EUR',
  'LON': 'GBP',
  'AMS': 'EUR',
  'PAR': 'EUR',
  'BRU': 'EUR',
  'LIS': 'EUR',
  'SIX': 'CHF',
  'TSE': 'CAD',
  'HKG': 'HKD',
  'TYO': 'JPY',
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
            ..where((a) => a.ticker.isNotNull() | a.isin.isNotNull()))
          .get();

      _log.info('syncPrices: found ${assets.length} active assets with ticker/ISIN');

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

    _log.info('syncPrices: fetching $ticker from ${formatYmd(from)}');
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
  /// Falls back to revalue events: returns revalue_amount / total_quantity
  /// so the result is always a per-unit price.
  Future<double?> getPrice(int assetId, DateTime date) async {
    final epochSec = date.millisecondsSinceEpoch ~/ 1000;
    final row = await db.customSelect(
      'SELECT close_price FROM market_prices '
      'WHERE asset_id = ? AND date <= ? ORDER BY date DESC LIMIT 1',
      variables: [Variable.withInt(assetId), Variable.withInt(epochSec)],
    ).getSingleOrNull();
    if (row != null) return row.readNullable<double>('close_price');
    // Fallback: revalue amount / quantity = per-unit price
    return _revaluePrice(assetId, epochSec);
  }

  /// Derive a per-unit price from a revalue event.
  /// Returns revalue_amount / total_quantity, or revalue_amount if qty <= 0.
  Future<double?> _revaluePrice(int assetId, int epochSec) async {
    final revalue = await db.customSelect(
      "SELECT amount FROM asset_events "
      "WHERE asset_id = ? AND type = 'revalue' AND date <= ? ORDER BY date DESC LIMIT 1",
      variables: [Variable.withInt(assetId), Variable.withInt(epochSec)],
    ).getSingleOrNull();
    if (revalue == null) return null;
    final amount = revalue.read<double>('amount');
    // Get total quantity to convert total value -> per-unit price
    final qtyRow = await db.customSelect(
      "SELECT SUM(CASE WHEN type = 'buy' THEN COALESCE(quantity, 0) "
      "WHEN type = 'sell' THEN -COALESCE(quantity, 0) ELSE 0 END) AS qty "
      "FROM asset_events WHERE asset_id = ?",
      variables: [Variable.withInt(assetId)],
    ).getSingleOrNull();
    final qty = qtyRow?.readNullable<double>('qty') ?? 0;
    return qty > 0 ? amount / qty : amount;
  }

  /// Get the two most recent prices for an asset (latest and previous).
  /// Returns (latest, previous) or nulls if not enough data.
  Future<(double?, double?)> getLastTwoPrices(int assetId) async {
    final prices = await getRecentPrices(assetId, 2);
    return (
      prices.isNotEmpty ? prices[0] : null,
      prices.length >= 2 ? prices[1] : null,
    );
  }

  /// Get the [count] most recent prices for an asset, newest first.
  Future<List<double>> getRecentPrices(int assetId, int count) async {
    final rows = await db.customSelect(
      'SELECT close_price FROM market_prices '
      'WHERE asset_id = ? ORDER BY date DESC LIMIT ?',
      variables: [Variable.withInt(assetId), Variable.withInt(count)],
    ).get();
    return rows
        .map((r) => r.readNullable<double>('close_price'))
        .whereType<double>()
        .toList();
  }

  /// Get all prices for an asset, sorted by date ascending.
  /// Falls back to revalue events (converted to per-unit prices) if no market prices exist.
  Future<List<MapEntry<DateTime, double>>> getPriceHistory(int assetId) async {
    final rows = await db.customSelect(
      'SELECT date, close_price FROM market_prices '
      'WHERE asset_id = ? ORDER BY date ASC',
      variables: [Variable.withInt(assetId)],
    ).get();
    if (rows.isNotEmpty) {
      return rows.map((r) => MapEntry(
        DateTime.fromMillisecondsSinceEpoch(r.read<int>('date') * 1000),
        r.read<double>('close_price'),
      )).toList();
    }
    // Fallback: revalue events as per-unit price history
    final qtyRow = await db.customSelect(
      "SELECT SUM(CASE WHEN type = 'buy' THEN COALESCE(quantity, 0) "
      "WHEN type = 'sell' THEN -COALESCE(quantity, 0) ELSE 0 END) AS qty "
      "FROM asset_events WHERE asset_id = ?",
      variables: [Variable.withInt(assetId)],
    ).getSingleOrNull();
    final qty = qtyRow?.readNullable<double>('qty') ?? 0;
    final revalueRows = await db.customSelect(
      "SELECT date, amount FROM asset_events "
      "WHERE asset_id = ? AND type = 'revalue' ORDER BY date ASC",
      variables: [Variable.withInt(assetId)],
    ).get();
    return revalueRows.map((r) {
      final amount = r.read<double>('amount');
      return MapEntry(
        DateTime.fromMillisecondsSinceEpoch(r.read<int>('date') * 1000),
        qty > 0 ? amount / qty : amount,
      );
    }).toList();
  }

  /// Clear all cached data (market prices, exchange rates, compositions).
  Future<void> clearCache() async {
    await db.delete(db.marketPrices).go();
    await db.delete(db.exchangeRates).go();
    await db.delete(db.assetCompositions).go();
    _log.info('Cleared all cached data (prices, exchange rates, compositions)');
  }
}
