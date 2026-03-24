import 'package:drift/drift.dart';
import 'package:intl/intl.dart';

import '../database/database.dart';
import '../utils/logger.dart';
import 'investing_com_service.dart';

final _log = getLogger('ExchangeRateService');
final _dateFmt = DateFormat('yyyy-MM-dd');

/// Caches exchange rates in the DB.
/// Uses Investing.com for live and sync rates.
/// Historical lookups read from the DB.
class ExchangeRateService {
  final AppDatabase _db;
  final InvestingComService? _investingService;

  /// Fixed set of target currencies to download (EUR is the base).
  static const targetCurrencies = [
    'USD', 'GBP', 'CHF', 'JPY', 'SEK', 'NOK', 'DKK',
    'PLN', 'CZK', 'HUF', 'CAD', 'AUD',
  ];

  /// All supported currencies (including EUR as base).
  static const allCurrencies = ['EUR', ...targetCurrencies];

  ExchangeRateService(this._db, {InvestingComService? investingService})
      : _investingService = investingService;

  // ──────────────────────────────────────────────
  // Sync
  // ──────────────────────────────────────────────

  /// Sync exchange rates via Investing.com.
  /// Stores the latest rate for each target currency as yesterday's date.
  Future<void> syncRates() async {
    if (_investingService == null) {
      _log.warning('syncRates: no InvestingComService configured');
      return;
    }
    try {
      final lastDate = await getLastSyncDate();
      final today = DateTime.now();
      final yesterday = DateTime(today.year, today.month, today.day - 1);

      if (lastDate != null && !lastDate.isBefore(yesterday)) {
        _log.info('syncRates: already up to date (last=${_dateFmt.format(lastDate)})');
        return;
      }

      _log.info('syncRates: fetching ${targetCurrencies.length} pairs via Investing.com');

      final companions = <ExchangeRatesCompanion>[];
      for (final currency in targetCurrencies) {
        final rate = await _investingService!.getLiveFxRate('EUR', currency);
        if (rate == null) {
          _log.warning('syncRates: EUR/$currency — no rate from Investing.com');
          continue;
        }
        _log.fine('syncRates: EUR/$currency = $rate');
        companions.add(ExchangeRatesCompanion(
          fromCurrency: const Value('EUR'),
          toCurrency: Value(currency),
          date: Value(yesterday),
          rate: Value(rate),
        ));
      }

      if (companions.isNotEmpty) {
        await _db.batch((batch) {
          for (final c in companions) {
            batch.insert(_db.exchangeRates, c, onConflict: DoUpdate((_) => c));
          }
        });
        _log.info('syncRates: stored ${companions.length} rates for ${_dateFmt.format(yesterday)}');
      }
    } catch (e, stack) {
      _log.warning('syncRates: failed', e, stack);
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

  /// Get today's live rate via Investing.com. Falls back to stored DB rate.
  Future<double?> getLiveRate(String from, String to) async {
    if (from == to) return 1.0;

    if (_investingService != null) {
      final rate = await _investingService!.getLiveFxRate(from, to);
      if (rate != null) return rate;
    }

    // Fallback to latest stored rate
    return getRate(from, to, DateTime.now());
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
