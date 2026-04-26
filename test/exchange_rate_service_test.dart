import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/exchange_rate_service.dart';

void main() {
  late AppDatabase db;
  late ExchangeRateService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = ExchangeRateService(db);
  });

  tearDown(() async => await db.close());

  /// Helper to insert a EUR-based rate directly into the database.
  Future<void> insertRate(String target, DateTime date, double rate) async {
    await db.into(db.exchangeRates).insert(ExchangeRatesCompanion.insert(
          fromCurrency: 'EUR',
          toCurrency: target,
          date: date,
          rate: rate,
        ));
  }

  group('getRate', () {
    test('EUR to USD returns stored rate', () async {
      await insertRate('USD', DateTime(2024, 1, 15), 1.08);

      final rate = await service.getRate('EUR', 'USD', DateTime(2024, 1, 15));
      expect(rate, 1.08);
    });

    test('USD to EUR returns 1/rate', () async {
      await insertRate('USD', DateTime(2024, 1, 15), 1.08);

      final rate = await service.getRate('USD', 'EUR', DateTime(2024, 1, 15));
      expect(rate, closeTo(1.0 / 1.08, 1e-10));
    });

    test('same currency returns 1.0', () async {
      final rate = await service.getRate('USD', 'USD', DateTime(2024, 1, 15));
      expect(rate, 1.0);
    });

    test('cross-rate GBP to USD = rUSD / rGBP', () async {
      await insertRate('USD', DateTime(2024, 1, 15), 1.08);
      await insertRate('GBP', DateTime(2024, 1, 15), 0.86);

      final rate = await service.getRate('GBP', 'USD', DateTime(2024, 1, 15));
      expect(rate, closeTo(1.08 / 0.86, 1e-10));
    });

    test('returns rate from closest earlier date when exact date not found', () async {
      await insertRate('USD', DateTime(2024, 1, 10), 1.08);
      await insertRate('USD', DateTime(2024, 1, 20), 1.12);

      // Query on Jan 15 — should get the Jan 10 rate (closest earlier)
      final rate = await service.getRate('EUR', 'USD', DateTime(2024, 1, 15));
      expect(rate, 1.08);

      // Query on Jan 25 — should get the Jan 20 rate
      final rate2 = await service.getRate('EUR', 'USD', DateTime(2024, 1, 25));
      expect(rate2, 1.12);
    });

    test('returns null when no rate available', () async {
      final rate = await service.getRate('EUR', 'USD', DateTime(2024, 1, 15));
      expect(rate, isNull);
    });

    test('returns null when only future rates exist', () async {
      await insertRate('USD', DateTime(2024, 6, 1), 1.10);

      final rate = await service.getRate('EUR', 'USD', DateTime(2024, 1, 1));
      expect(rate, isNull);
    });
  });

  group('convertAmount', () {
    test('converts correctly using stored rate', () async {
      await insertRate('USD', DateTime(2024, 1, 15), 1.08);

      final result = await service.convertAmount(
          100.0, 'EUR', 'USD', DateTime(2024, 1, 15));
      expect(result, closeTo(108.0, 1e-10));
    });

    test('returns original amount when same currency', () async {
      final result = await service.convertAmount(
          250.0, 'EUR', 'EUR', DateTime(2024, 1, 15));
      expect(result, 250.0);
    });

    test('returns null when rate unavailable', () async {
      // No silent fallback to the unconverted amount: callers must surface
      // missing rates instead of mixing different currencies in a total.
      final result = await service.convertAmount(
          100.0, 'EUR', 'USD', DateTime(2024, 1, 15));
      expect(result, isNull);
    });

    test('converts cross-rate correctly', () async {
      await insertRate('USD', DateTime(2024, 1, 15), 1.08);
      await insertRate('GBP', DateTime(2024, 1, 15), 0.86);

      final result = await service.convertAmount(
          100.0, 'GBP', 'USD', DateTime(2024, 1, 15));
      expect(result, closeTo(100.0 * (1.08 / 0.86), 1e-8));
    });
  });

  group('getRate - additional', () {
    test('falls back to closest prior date for cross-rate', () async {
      // Insert EUR/USD and EUR/GBP on different dates
      await insertRate('USD', DateTime(2024, 1, 5), 1.08);
      await insertRate('GBP', DateTime(2024, 1, 8), 0.86);

      // Query on Jan 10 - both should resolve to their closest prior dates
      final rate = await service.getRate('GBP', 'USD', DateTime(2024, 1, 10));
      expect(rate, closeTo(1.08 / 0.86, 1e-10));
    });

    test('returns null for cross-rate when one leg is missing', () async {
      await insertRate('USD', DateTime(2024, 1, 15), 1.08);
      // No GBP rate inserted

      final rate = await service.getRate('GBP', 'USD', DateTime(2024, 1, 15));
      expect(rate, isNull);
    });

    test('uses exact date when available even if earlier dates exist', () async {
      await insertRate('USD', DateTime(2024, 1, 10), 1.05);
      await insertRate('USD', DateTime(2024, 1, 15), 1.08);
      await insertRate('USD', DateTime(2024, 1, 20), 1.12);

      final rate = await service.getRate('EUR', 'USD', DateTime(2024, 1, 15));
      expect(rate, 1.08);
    });
  });

  group('getLiveRate', () {
    test('returns 1.0 for same currency', () async {
      final rate = await service.getLiveRate('EUR', 'EUR');
      expect(rate, 1.0);
    });

    test('returns 1.0 for same currency even for non-EUR', () async {
      final rate = await service.getLiveRate('USD', 'USD');
      expect(rate, 1.0);
    });

    test('falls back to stored rate when no investing service', () async {
      // Service has no InvestingComService, so it falls back to DB
      await insertRate('USD', DateTime.now(), 1.10);

      final rate = await service.getLiveRate('EUR', 'USD');
      expect(rate, 1.10);
    });

    test('returns null when no investing service and no stored rate', () async {
      final rate = await service.getLiveRate('EUR', 'USD');
      expect(rate, isNull);
    });
  });

  group('convertLive', () {
    test('returns same amount for same currency', () async {
      final result = await service.convertLive(500.0, 'CHF', 'CHF');
      expect(result, 500.0);
    });

    test('converts correctly using stored rate', () async {
      await insertRate('USD', DateTime.now(), 1.10);

      final result = await service.convertLive(100.0, 'EUR', 'USD');
      expect(result, closeTo(110.0, 1e-10));
    });

    test('returns null when rate missing', () async {
      // No rates in DB, no investing service. Must not silently return the
      // unconverted amount.
      final result = await service.convertLive(200.0, 'EUR', 'JPY');
      expect(result, isNull);
    });
  });

  group('CachedRateResolver', () {
    test('returns 1.0 for same currency as base', () async {
      final resolver = CachedRateResolver(service, 'EUR');
      final dayKey = DateTime(2024, 1, 15).millisecondsSinceEpoch ~/ 1000;

      final rate = await resolver.getRate('EUR', dayKey);
      expect(rate, 1.0);
    });

    test('resolves and caches rate from service', () async {
      await insertRate('USD', DateTime(2024, 1, 15), 1.08);
      final resolver = CachedRateResolver(service, 'EUR');
      final dayKey = DateTime(2024, 1, 15).millisecondsSinceEpoch ~/ 1000;

      // getRate(USD, dayKey) calls service.getRate(USD, EUR, date) = 1/1.08
      final rate1 = await resolver.getRate('USD', dayKey);
      expect(rate1, closeTo(1.0 / 1.08, 1e-10));

      // Second call should use cache (same result)
      final rate2 = await resolver.getRate('USD', dayKey);
      expect(rate2, closeTo(1.0 / 1.08, 1e-10));
    });

    test('caches different rates for different dayKeys', () async {
      await insertRate('USD', DateTime(2024, 1, 10), 1.05);
      await insertRate('USD', DateTime(2024, 1, 20), 1.12);
      final resolver = CachedRateResolver(service, 'EUR');
      final dayKey1 = DateTime(2024, 1, 10).millisecondsSinceEpoch ~/ 1000;
      final dayKey2 = DateTime(2024, 1, 20).millisecondsSinceEpoch ~/ 1000;

      final rate1 = await resolver.getRate('USD', dayKey1);
      final rate2 = await resolver.getRate('USD', dayKey2);

      expect(rate1, closeTo(1.0 / 1.05, 1e-10));
      expect(rate2, closeTo(1.0 / 1.12, 1e-10));
    });

    test('returns null when rate is missing', () async {
      // No rates in DB. Must surface as null instead of silently using 1.0,
      // which would treat the foreign currency as if it were the base.
      final resolver = CachedRateResolver(service, 'EUR');
      final dayKey = DateTime(2024, 1, 15).millisecondsSinceEpoch ~/ 1000;

      final rate = await resolver.getRate('USD', dayKey);
      expect(rate, isNull);
    });

    test('caches the null result so subsequent calls do not re-query', () async {
      final resolver = CachedRateResolver(service, 'EUR');
      final dayKey = DateTime(2024, 1, 15).millisecondsSinceEpoch ~/ 1000;

      // Both calls return null without re-hitting the DB.
      final rate1 = await resolver.getRate('USD', dayKey);
      final rate2 = await resolver.getRate('USD', dayKey);
      expect(rate1, isNull);
      expect(rate2, isNull);
    });

    test('works with non-EUR base currency', () async {
      await insertRate('USD', DateTime(2024, 1, 15), 1.08);
      await insertRate('GBP', DateTime(2024, 1, 15), 0.86);
      final resolver = CachedRateResolver(service, 'USD');
      final dayKey = DateTime(2024, 1, 15).millisecondsSinceEpoch ~/ 1000;

      // GBP -> USD cross-rate via EUR: rUSD / rGBP = 1.08 / 0.86
      final rate = await resolver.getRate('GBP', dayKey);
      expect(rate, closeTo(1.08 / 0.86, 1e-10));
    });
  });

  group('syncRates vs _persistFxRate race', () {
    // Regression: two code paths wrote conflicting FX values to the same row.
    // syncRates uses DoUpdate (always wins), _persistFxRate uses DoNothing
    // (yields to existing). The data provider returns slightly different numbers
    // for EUR/USD (1.17200) vs 1/USDEUR (1.17192) due to bid/ask spread.
    // Regardless of execution order, syncRates' value must prevail.

    final day = DateTime(2024, 6, 15);
    const syncRatesValue = 1.17200005054474; // EUR/USD from syncRates
    const persistValue = 1.17192081194759; // 1/USDEUR from _persistFxRate

    Future<double?> readEurUsd() async {
      final row = await db.customSelect(
        'SELECT rate FROM exchange_rates '
        "WHERE from_currency = 'EUR' AND to_currency = 'USD' AND date = ?",
        variables: [Variable.withInt(day.millisecondsSinceEpoch ~/ 1000)],
      ).getSingleOrNull();
      return row?.readNullable<double>('rate');
    }

    /// Simulates syncRates: inserts with DoUpdate (upsert, always overwrites).
    Future<void> writeSyncRates(double rate) async {
      final c = ExchangeRatesCompanion(
        fromCurrency: const Value('EUR'),
        toCurrency: const Value('USD'),
        date: Value(day),
        rate: Value(rate),
      );
      await db.into(db.exchangeRates).insert(c, onConflict: DoUpdate((_) => c));
    }

    /// Simulates _persistFxRate: inserts with DoNothing (insert-if-absent).
    Future<void> writePersistFxRate(double rate) async {
      await db.into(db.exchangeRates).insert(
        ExchangeRatesCompanion(
          fromCurrency: const Value('EUR'),
          toCurrency: const Value('USD'),
          date: Value(day),
          rate: Value(rate),
        ),
        onConflict: DoNothing(),
      );
    }

    test('syncRates first, then _persistFxRate: syncRates value preserved', () async {
      await writeSyncRates(syncRatesValue);
      await writePersistFxRate(persistValue);

      final stored = await readEurUsd();
      expect(stored, syncRatesValue,
          reason: '_persistFxRate (DoNothing) must not overwrite syncRates');
    });

    test('_persistFxRate first, then syncRates: syncRates value wins', () async {
      await writePersistFxRate(persistValue);
      await writeSyncRates(syncRatesValue);

      final stored = await readEurUsd();
      expect(stored, syncRatesValue,
          reason: 'syncRates (DoUpdate) must overwrite _persistFxRate');
    });

    test('_persistFxRate alone fills gap when syncRates has not run', () async {
      await writePersistFxRate(persistValue);

      final stored = await readEurUsd();
      expect(stored, persistValue,
          reason: '_persistFxRate should fill an empty slot');
    });
  });

  group('allCurrencies', () {
    test('is not empty', () {
      expect(ExchangeRateService.allCurrencies, isNotEmpty);
    });

    test('contains EUR', () {
      expect(ExchangeRateService.allCurrencies, contains('EUR'));
    });

    test('contains USD', () {
      expect(ExchangeRateService.allCurrencies, contains('USD'));
    });

    test('EUR is the first element (base currency)', () {
      expect(ExchangeRateService.allCurrencies.first, 'EUR');
    });

    test('contains all targetCurrencies plus EUR', () {
      expect(
        ExchangeRateService.allCurrencies.length,
        ExchangeRateService.targetCurrencies.length + 1,
      );
      for (final c in ExchangeRateService.targetCurrencies) {
        expect(ExchangeRateService.allCurrencies, contains(c));
      }
    });
  });
}
