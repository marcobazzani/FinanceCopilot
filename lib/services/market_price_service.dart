import 'package:drift/drift.dart';

import '../database/database.dart';
import '../utils/formatters.dart' show formatYmd;
import '../utils/logger.dart';
import 'asset_event_service.dart';

final _log = getLogger('MarketPriceService');

/// Canonical exchange names — the values stored in `assets.exchange` and
/// in the cache-key suffix. We use the provider's English name; the search
/// service accepts language synonyms (Italian variants etc.) via its
/// internal name list, but we never store synonyms.
const supportedExchanges = <String>[
  'Milan',
  'NYSE',
  'NASDAQ',
  'AMEX',
  'Xetra',
  'Frankfurt',
  'London',
  'Amsterdam',
  'Paris',
  'Brussels',
  'Lisbon',
  'Switzerland',
  'Toronto',
  'Hong Kong',
  'Tokyo',
];

/// Native currency for each canonical exchange name.
const exchangeCurrency = <String, String>{
  'Milan': 'EUR',
  'NYSE': 'USD',
  'NASDAQ': 'USD',
  'AMEX': 'USD',
  'Xetra': 'EUR',
  'Frankfurt': 'EUR',
  'London': 'GBP',
  'Amsterdam': 'EUR',
  'Paris': 'EUR',
  'Brussels': 'EUR',
  'Lisbon': 'EUR',
  'Switzerland': 'CHF',
  'Toronto': 'CAD',
  'Hong Kong': 'HKD',
  'Tokyo': 'JPY',
};

/// Synonym → canonical exchange name (e.g. `'Milano' → 'Milan'`,
/// `'Londra' → 'London'`). Used to recognise listings the provider
/// returns under a localised name and resolve them back to the canonical
/// English name we store. Canonical names map to themselves.
const exchangeSynonyms = <String, String>{
  // Canonical names (identity).
  'Milan': 'Milan',
  'NYSE': 'NYSE',
  'NASDAQ': 'NASDAQ',
  'AMEX': 'AMEX',
  'Xetra': 'Xetra',
  'Frankfurt': 'Frankfurt',
  'London': 'London',
  'Amsterdam': 'Amsterdam',
  'Paris': 'Paris',
  'Brussels': 'Brussels',
  'Lisbon': 'Lisbon',
  'Switzerland': 'Switzerland',
  'Toronto': 'Toronto',
  'Hong Kong': 'Hong Kong',
  'Tokyo': 'Tokyo',
  // Synonyms.
  'Milano': 'Milan',
  'Londra': 'London',
  'Francoforte': 'Frankfurt',
  'Parigi': 'Paris',
  'Bruxelles': 'Brussels',
  'Lisbona': 'Lisbon',
  'Svizzera': 'Switzerland',
};

/// True when [name] is a canonical exchange name OR a recognised synonym.
bool isKnownExchange(String name) => exchangeSynonyms.containsKey(name);

/// One-shot map from legacy short-codes / synonyms to the canonical name.
/// Used by migration v40 to heal pre-existing rows; no live code path
/// should rely on this. Kept as a public const so the migration can
/// consume it without duplicating the table.
const legacyExchangeAliases = <String, String>{
  // Codes
  'MIL': 'Milan',
  'NYQ': 'NYSE',
  'NMS': 'NASDAQ',
  'NYS': 'NYSE',
  'ASE': 'AMEX',
  'XETRA': 'Xetra',
  'FRA': 'Frankfurt',
  'LON': 'London',
  'AMS': 'Amsterdam',
  'PAR': 'Paris',
  'BRU': 'Brussels',
  'LIS': 'Lisbon',
  'SIX': 'Switzerland',
  'TSE': 'Toronto',
  'HKG': 'Hong Kong',
  'TYO': 'Tokyo',
  // Italian synonyms
  'Milano': 'Milan',
  'Londra': 'London',
  'Francoforte': 'Frankfurt',
  'Parigi': 'Paris',
  'Bruxelles': 'Brussels',
  'Lisbona': 'Lisbon',
  'Svizzera': 'Switzerland',
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
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from);

  // ──────────────────────────────────────────────
  // Sync — calls abstract fetch, stores in DB
  // ──────────────────────────────────────────────

  /// Sync prices for all active assets that have a ticker.
  /// If [forceToday] is true, re-fetch today's price even if already synced.
  Future<void> syncPrices({bool forceToday = false}) async {
    try {
      final assets =
          await (db.select(db.assets)
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
        from = DateTime(today.year, today.month, today.day).isAfter(lastPlus1) ? lastPlus1 : DateTime(today.year, today.month, today.day);
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

    // Notify subclass about today's price so it can populate in-memory caches
    final todayKey = DateTime(today.year, today.month, today.day);
    final todayPrice = prices[todayKey];
    if (todayPrice != null) {
      onTodayPriceSynced(asset.id, todayPrice, todayKey);
    }
  }

  /// Hook for subclasses to cache today's price in memory after sync.
  void onTodayPriceSynced(int assetId, double price, DateTime date) {}

  // ──────────────────────────────────────────────
  // DB reads
  // ──────────────────────────────────────────────

  /// Date of the first "buy" event for an asset, or null if none.
  /// Uses value_date per CLAUDE.md (canonical "money moved" date) so the
  /// price-history fetch window starts no later than the actual investment.
  Future<DateTime?> getFirstBuyDate(int assetId) async {
    final row = await db
        .customSelect(
          "SELECT MIN(value_date) AS min_date FROM asset_events WHERE asset_id = ? AND type = 'buy'",
          variables: [Variable.withInt(assetId)],
        )
        .getSingleOrNull();
    return row?.readNullable<DateTime>('min_date');
  }

  /// Earliest stored price date for an asset.
  Future<DateTime?> getFirstPriceDate(int assetId) async {
    final row = await db
        .customSelect(
          'SELECT MIN(date) AS min_date FROM market_prices WHERE asset_id = ?',
          variables: [Variable.withInt(assetId)],
        )
        .getSingleOrNull();
    return row?.readNullable<DateTime>('min_date');
  }

  /// Last stored price date for an asset.
  Future<DateTime?> getLastSyncDate(int assetId) async {
    final row = await db
        .customSelect(
          'SELECT MAX(date) AS max_date FROM market_prices WHERE asset_id = ?',
          variables: [Variable.withInt(assetId)],
        )
        .getSingleOrNull();
    return row?.readNullable<DateTime>('max_date');
  }

  /// Get close price on or before [date] for [assetId].
  /// Revalue events are materialised into market_prices rows by
  /// [AssetEventService.resyncRevaluePricesForAsset], so they're picked up
  /// here automatically. Falls back to the last buy event's price for assets
  /// that have neither market_prices rows nor revalues.
  Future<double?> getPrice(int assetId, DateTime date) async {
    final endExclusive = DateTime(
      date.year,
      date.month,
      date.day,
    ).add(const Duration(days: 1));
    final epochSec = endExclusive.millisecondsSinceEpoch ~/ 1000;
    final row = await db
        .customSelect(
          'SELECT close_price FROM market_prices '
          'WHERE asset_id = ? AND date < ? ORDER BY date DESC LIMIT 1',
          variables: [Variable.withInt(assetId), Variable.withInt(epochSec)],
        )
        .getSingleOrNull();
    if (row != null) return row.readNullable<double>('close_price');
    // Last-buy-price fallback for assets with no market_prices and no
    // revalues materialised yet.
    final buyRow = await db
        .customSelect(
          "SELECT price FROM asset_events "
          "WHERE asset_id = ? AND type = 'buy' AND price IS NOT NULL AND value_date < ? "
          "ORDER BY value_date DESC, id DESC LIMIT 1",
          variables: [Variable.withInt(assetId), Variable.withInt(epochSec)],
        )
        .getSingleOrNull();
    return buyRow?.readNullable<double>('price');
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
    final rows = await db
        .customSelect(
          'SELECT close_price FROM market_prices '
          'WHERE asset_id = ? ORDER BY date DESC LIMIT ?',
          variables: [Variable.withInt(assetId), Variable.withInt(count)],
        )
        .get();
    return rows.map((r) => r.readNullable<double>('close_price')).whereType<double>().toList();
  }

  /// Get all prices for an asset, sorted by date ascending.
  /// Revalue events are materialised into market_prices rows so they appear
  /// here without a separate fallback path.
  Future<List<MapEntry<DateTime, double>>> getPriceHistory(int assetId) async {
    final rows = await db
        .customSelect(
          'SELECT date, close_price FROM market_prices '
          'WHERE asset_id = ? ORDER BY date ASC',
          variables: [Variable.withInt(assetId)],
        )
        .get();

    return rows
        .map(
          (r) => MapEntry(
            DateTime.fromMillisecondsSinceEpoch(r.read<int>('date') * 1000),
            r.read<double>('close_price'),
          ),
        )
        .toList();
  }

  /// Get all prices for multiple assets in a single query, sorted by date ascending.
  /// Falls back to buy-event prices for assets with no market_prices rows, mirroring
  /// the [getPrice] single-point fallback so the dashboard history chart is consistent
  /// with the portfolio screen's current-value display.
  Future<Map<int, List<MapEntry<DateTime, double>>>> getPriceHistoryBatch(List<int> assetIds) async {
    if (assetIds.isEmpty) return {};
    final placeholders = assetIds.map((_) => '?').join(',');
    final rows = await db
        .customSelect(
          'SELECT asset_id, date, close_price FROM market_prices '
          'WHERE asset_id IN ($placeholders) ORDER BY asset_id, date ASC',
          variables: assetIds.map((id) => Variable.withInt(id)).toList(),
        )
        .get();

    final result = <int, List<MapEntry<DateTime, double>>>{};
    for (final r in rows) {
      final assetId = r.read<int>('asset_id');
      result
          .putIfAbsent(assetId, () => [])
          .add(
            MapEntry(
              DateTime.fromMillisecondsSinceEpoch(r.read<int>('date') * 1000),
              r.read<double>('close_price'),
            ),
          );
    }

    // For assets with no market_prices rows at all, fall back to buy-event
    // prices so the history chart is consistent with the portfolio screen's
    // current-value display (which uses getPrice()'s buy-price fallback).
    final missingIds = assetIds.where((id) => !result.containsKey(id)).toList();
    if (missingIds.isNotEmpty) {
      final missingPlaceholders = missingIds.map((_) => '?').join(',');
      final buyRows = await db
          .customSelect(
            // id ASC tiebreak makes the last-in-list (last-write-wins after the
            // day-keyed collapse in the chart) the highest-id same-day buy,
            // matching getPrice()'s `value_date DESC, id DESC LIMIT 1`.
            "SELECT asset_id, value_date, price FROM asset_events "
            "WHERE asset_id IN ($missingPlaceholders) AND type = 'buy' "
            "AND price IS NOT NULL ORDER BY asset_id, value_date ASC, id ASC",
            variables: missingIds.map((id) => Variable.withInt(id)).toList(),
          )
          .get();
      for (final r in buyRows) {
        final assetId = r.read<int>('asset_id');
        final price = r.readNullable<double>('price');
        if (price == null) continue;
        result
            .putIfAbsent(assetId, () => [])
            .add(
              MapEntry(
                DateTime.fromMillisecondsSinceEpoch(r.read<int>('value_date') * 1000),
                price,
              ),
            );
      }
    }

    return result;
  }

  /// Clear all cached data (market prices, exchange rates, compositions).
  /// Revalue-derived prices are immediately re-materialised so manual assets
  /// keep rendering correctly after a cache wipe.
  Future<void> clearCache() async {
    await db.delete(db.marketPrices).go();
    await db.delete(db.exchangeRates).go();
    await db.delete(db.assetCompositions).go();
    _log.info('Cleared all cached data (prices, exchange rates, compositions)');
    // Rematerialise revalue events into market_prices.
    final eventService = AssetEventService(db);
    final assetIdRows = await db
        .customSelect(
          "SELECT DISTINCT asset_id FROM asset_events WHERE type = 'revalue'",
        )
        .get();
    for (final row in assetIdRows) {
      await eventService.resyncRevaluePricesForAsset(row.read<int>('asset_id'));
    }
  }
}
