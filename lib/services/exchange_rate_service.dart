import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';

import '../database/database.dart';
import '../utils/logger.dart';

final _log = getLogger('ExchangeRateService');
final _dateFmt = DateFormat('yyyy-MM-dd');

/// Downloads and caches historical exchange rates from the Frankfurter API (ECB data).
/// Stores EUR-based rates and derives cross-rates on the fly.
class ExchangeRateService {
  final AppDatabase _db;
  final Dio _dio;

  /// Fixed set of target currencies to download (EUR is the base).
  static const targetCurrencies = [
    'USD', 'GBP', 'CHF', 'JPY', 'SEK', 'NOK', 'DKK',
    'PLN', 'CZK', 'HUF', 'CAD', 'AUD',
  ];

  /// All supported currencies (including EUR as base).
  static const allCurrencies = ['EUR', ...targetCurrencies];

  static const _baseUrl = 'https://api.frankfurter.app';

  ExchangeRateService(this._db, {Dio? dio}) : _dio = dio ?? Dio();

  // ──────────────────────────────────────────────
  // Sync
  // ──────────────────────────────────────────────

  /// Sync exchange rates from Frankfurter API.
  /// Fetches only dates after the last stored date (incremental).
  Future<void> syncRates() async {
    try {
      final lastDate = await getLastSyncDate();
      final startDate = lastDate != null
          ? lastDate.add(const Duration(days: 1))
          : DateTime(1999, 1, 4); // ECB history start
      final today = DateTime.now();

      if (!startDate.isBefore(today)) {
        _log.info('syncRates: already up to date (last=${_dateFmt.format(lastDate!)})');
        return;
      }

      final startStr = _dateFmt.format(startDate);
      final currencies = targetCurrencies.join(',');
      final url = '$_baseUrl/$startStr..?to=$currencies';
      _log.info('syncRates: fetching from $startStr to today');

      final response = await _dio.get(url,
        options: Options(responseType: ResponseType.json),
      );
      final data = response.data as Map<String, dynamic>;
      final rates = data['rates'] as Map<String, dynamic>?;
      if (rates == null || rates.isEmpty) {
        _log.info('syncRates: no new rates returned');
        return;
      }

      // Build companions for batch insert
      final companions = <ExchangeRatesCompanion>[];
      for (final entry in rates.entries) {
        final date = DateTime.parse(entry.key);
        final dayRates = entry.value as Map<String, dynamic>;
        for (final rateEntry in dayRates.entries) {
          companions.add(ExchangeRatesCompanion(
            fromCurrency: Value('EUR'),
            toCurrency: Value(rateEntry.key),
            date: Value(date),
            rate: Value((rateEntry.value as num).toDouble()),
          ));
        }
      }

      _log.info('syncRates: inserting ${companions.length} rate entries (${rates.length} days)');
      await _db.batch((batch) {
        for (final c in companions) {
          batch.insert(_db.exchangeRates, c, onConflict: DoUpdate((_) => c));
        }
      });
      _log.info('syncRates: done');
    } on DioException catch (e) {
      _log.warning('syncRates: network error — ${e.message}');
    } catch (e, stack) {
      _log.warning('syncRates: unexpected error', e, stack);
    }
  }

  /// Get the latest date stored in the exchange_rates table.
  Future<DateTime?> getLastSyncDate() async {
    final row = await _db.customSelect(
      'SELECT MAX(date) AS max_date FROM exchange_rates',
    ).getSingleOrNull();
    return row?.readNullable<DateTime>('max_date');
  }

  // ──────────────────────────────────────────────
  // Rate lookup
  // ──────────────────────────────────────────────

  /// Get exchange rate from [from] to [to] on or before [date].
  /// Returns null if no rate data is available.
  Future<double?> getRate(String from, String to, DateTime date) async {
    if (from == to) return 1.0;

    if (from == 'EUR') {
      return _lookupEurRate(to, date);
    }
    if (to == 'EUR') {
      final r = await _lookupEurRate(from, date);
      return r != null ? 1.0 / r : null;
    }
    // Cross rate: EUR→to / EUR→from
    final rTo = await _lookupEurRate(to, date);
    final rFrom = await _lookupEurRate(from, date);
    if (rTo != null && rFrom != null && rFrom != 0) {
      return rTo / rFrom;
    }
    return null;
  }

  /// Look up EUR→[currency] rate on or before [date].
  Future<double?> _lookupEurRate(String currency, DateTime date) async {
    final epochSec = date.millisecondsSinceEpoch ~/ 1000;
    final row = await _db.customSelect(
      'SELECT rate FROM exchange_rates '
      "WHERE from_currency = 'EUR' AND to_currency = ? "
      'AND date <= ? ORDER BY date DESC LIMIT 1',
      variables: [Variable.withString(currency), Variable.withInt(epochSec)],
    ).getSingleOrNull();
    return row?.readNullable<double>('rate');
  }

  /// Convert [amount] from [from] currency to [to] currency at [date].
  /// Returns original amount if rate is unavailable.
  Future<double> convertAmount(
      double amount, String from, String to, DateTime date) async {
    if (from == to) return amount;
    final rate = await getRate(from, to, date);
    if (rate == null) return amount;
    return amount * rate;
  }

  // ──────────────────────────────────────────────
  // Live rate (today)
  // ──────────────────────────────────────────────

  /// In-memory cache for the current session's live rates (1-hour TTL).
  Map<String, double>? _liveRates;
  DateTime? _liveRatesFetchedAt;
  static const _liveRatesTtl = Duration(hours: 1);

  /// Fetch today's live rates from the API and cache them.
  /// Returns EUR→[currency] rate for today, or falls back to stored DB rate.
  Future<double?> getLiveRate(String from, String to) async {
    if (from == to) return 1.0;

    // Invalidate cache after TTL
    if (_liveRates != null &&
        _liveRatesFetchedAt != null &&
        DateTime.now().difference(_liveRatesFetchedAt!) > _liveRatesTtl) {
      _liveRates = null;
    }

    // Ensure live rates are fetched
    if (_liveRates == null) {
      _liveRates = await _fetchLiveRates();
      _liveRatesFetchedAt = DateTime.now();
    }

    double? eurToTarget(String currency) {
      if (currency == 'EUR') return 1.0;
      return _liveRates?[currency];
    }

    final rFrom = eurToTarget(from);
    final rTo = eurToTarget(to);
    if (rFrom != null && rTo != null && rFrom != 0) {
      return rTo / rFrom;
    }
    // Fallback to latest stored rate
    return getRate(from, to, DateTime.now());
  }

  Future<Map<String, double>> _fetchLiveRates() async {
    try {
      final currencies = targetCurrencies.join(',');
      final url = '$_baseUrl/latest?to=$currencies';
      _log.info('fetchLiveRates: $url');
      final response = await _dio.get(url);
      final data = response.data as Map<String, dynamic>;
      final rates = data['rates'] as Map<String, dynamic>? ?? {};
      return rates.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (e) {
      _log.warning('fetchLiveRates: failed — $e');
      return {};
    }
  }

  /// Convert [amount] using today's live rate.
  /// Falls back to stored rate if live fetch fails.
  Future<double> convertLive(double amount, String from, String to) async {
    if (from == to) return amount;
    final rate = await getLiveRate(from, to);
    if (rate == null) return amount;
    return amount * rate;
  }
}
