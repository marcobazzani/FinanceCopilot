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

    test('returns original amount when rate unavailable', () async {
      final result = await service.convertAmount(
          100.0, 'EUR', 'USD', DateTime(2024, 1, 15));
      expect(result, 100.0);
    });

    test('converts cross-rate correctly', () async {
      await insertRate('USD', DateTime(2024, 1, 15), 1.08);
      await insertRate('GBP', DateTime(2024, 1, 15), 0.86);

      final result = await service.convertAmount(
          100.0, 'GBP', 'USD', DateTime(2024, 1, 15));
      expect(result, closeTo(100.0 * (1.08 / 0.86), 1e-8));
    });
  });
}
