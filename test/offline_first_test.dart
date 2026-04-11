import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/exchange_rate_service.dart';
import 'package:finance_copilot/services/investing_com_service.dart';
import 'package:finance_copilot/services/market_price_service.dart';

void main() {
  late AppDatabase db;
  late InvestingComService priceService;
  late ExchangeRateService rateService;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    priceService = InvestingComService(db);
    rateService = ExchangeRateService(db);
  });

  tearDown(() async => await db.close());

  /// Helper to insert a market price.
  Future<void> insertPrice(int assetId, DateTime date, double price) async {
    await db.into(db.marketPrices).insert(MarketPricesCompanion.insert(
      assetId: assetId,
      date: date,
      closePrice: price,
      currency: 'EUR',
    ));
  }

  /// Helper to insert an FX rate (both directions).
  Future<void> insertRate(String from, String to, DateTime date, double rate) async {
    await db.into(db.exchangeRates).insert(ExchangeRatesCompanion.insert(
      fromCurrency: from,
      toCurrency: to,
      date: date,
      rate: rate,
    ));
    await db.into(db.exchangeRates).insert(ExchangeRatesCompanion.insert(
      fromCurrency: to,
      toCurrency: from,
      date: date,
      rate: 1.0 / rate,
    ));
  }

  /// Helper to create an asset with a ticker.
  Future<int> createAsset(String name, {String? ticker, String currency = 'EUR'}) async {
    return db.into(db.assets).insert(AssetsCompanion.insert(
      name: name,
      assetType: AssetType.stockEtf,
      valuationMethod: ValuationMethod.marketPrice,
      ticker: Value(ticker),
      currency: Value(currency),
    ));
  }

  group('getPrice - offline price retrieval', () {
    test('returns stored price for today', () async {
      final assetId = await createAsset('ETF A');
      final today = DateTime(2024, 6, 15);
      await insertPrice(assetId, today, 112.50);

      final price = await priceService.getPrice(assetId, today);
      expect(price, 112.50);
    });

    test('returns most recent price when today has no entry', () async {
      final assetId = await createAsset('ETF A');
      await insertPrice(assetId, DateTime(2024, 6, 13), 110.0);
      await insertPrice(assetId, DateTime(2024, 6, 14), 111.0);

      // Saturday query - no price for June 15
      final price = await priceService.getPrice(assetId, DateTime(2024, 6, 15));
      expect(price, 111.0);
    });

    test('returns null when no prices exist', () async {
      final assetId = await createAsset('ETF A');
      final price = await priceService.getPrice(assetId, DateTime(2024, 6, 15));
      expect(price, isNull);
    });

    test('does not return future prices', () async {
      final assetId = await createAsset('ETF A');
      await insertPrice(assetId, DateTime(2024, 6, 20), 120.0);

      final price = await priceService.getPrice(assetId, DateTime(2024, 6, 15));
      expect(price, isNull);
    });
  });

  group('getRate - offline rate retrieval', () {
    test('returns stored rate for today', () async {
      final today = DateTime(2024, 6, 15);
      await insertRate('EUR', 'USD', today, 1.08);

      final rate = await rateService.getRate('EUR', 'USD', today);
      expect(rate, 1.08);
    });

    test('returns most recent rate when today has no entry', () async {
      await insertRate('EUR', 'USD', DateTime(2024, 6, 13), 1.07);
      await insertRate('EUR', 'USD', DateTime(2024, 6, 14), 1.08);

      // Weekend query - no rate for June 15
      final rate = await rateService.getRate('EUR', 'USD', DateTime(2024, 6, 15));
      expect(rate, 1.08);
    });

    test('getLiveRate falls back to stored rate without InvestingComService', () async {
      final today = DateTime.now();
      final storeDate = DateTime(today.year, today.month, today.day);
      await insertRate('EUR', 'USD', storeDate, 1.10);

      final rate = await rateService.getLiveRate('EUR', 'USD');
      expect(rate, 1.10);
    });
  });

  group('onTodayPriceSynced - live cache population during sync', () {
    test('populates _livePriceCache so isMarketOpen returns true', () async {
      final assetId = await createAsset('ETF A');
      final today = DateTime.now();
      final todayKey = DateTime(today.year, today.month, today.day);

      // Before sync, market is not open
      expect(priceService.isMarketOpen(assetId), false);

      // Simulate what syncPrices does after storing today's price
      priceService.onTodayPriceSynced(assetId, 100.0, todayKey);

      // Now market should be considered open
      expect(priceService.isMarketOpen(assetId), true);
    });
  });

  group('syncRates stores today date', () {
    test('rates stored with today date are found by getRate for today', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await insertRate('EUR', 'USD', today, 1.15);

      final rate = await rateService.getRate('EUR', 'USD', now);
      expect(rate, 1.15);
    });

    test('today rate differs from yesterday rate', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      await insertRate('EUR', 'USD', yesterday, 1.10);
      await insertRate('EUR', 'USD', today, 1.15);

      final todayRate = await rateService.getRate('EUR', 'USD', now);
      final yesterdayRate = await rateService.getRate('EUR', 'USD', yesterday);

      expect(todayRate, 1.15);
      expect(yesterdayRate, 1.10);
      expect(todayRate, isNot(equals(yesterdayRate)));
    });
  });

  group('price history includes today', () {
    test('getPriceHistoryBatch returns today price when stored', () async {
      final assetId = await createAsset('ETF A');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      await insertPrice(assetId, yesterday, 100.0);
      await insertPrice(assetId, today, 101.0);

      final histories = await priceService.getPriceHistoryBatch([assetId]);
      final prices = histories[assetId]!;

      expect(prices.length, 2);
      // Last entry should be today's price
      expect(prices.last.value, 101.0);
    });
  });

  group('DB merge column intersection', () {
    test('schema version is 26 with ghost column migration', () async {
      // Verify the DB opens at schema version 26
      // (which includes the migration to drop bank_account_id, bank_session_id)
      final rows = await db.customSelect('PRAGMA user_version').get();
      final version = rows.first.read<int>('user_version');
      expect(version, 26);
    });

    test('accounts table has no ghost columns', () async {
      final cols = await db.customSelect('PRAGMA table_info(accounts)').get();
      final colNames = cols.map((r) => r.read<String>('name')).toSet();

      expect(colNames.contains('bank_account_id'), false);
      expect(colNames.contains('bank_session_id'), false);
      // Verify expected columns are present
      expect(colNames.contains('id'), true);
      expect(colNames.contains('name'), true);
      expect(colNames.contains('currency'), true);
      expect(colNames.contains('intermediary_id'), true);
    });
  });

  group('offline market values computation', () {
    test('market value can be computed from stored price and rate', () async {
      // Simulate what assetMarketValuesProvider does: qty * price / bondDiv * fxRate
      final assetId = await createAsset('US Stock', ticker: 'AMZN', currency: 'USD');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Store price and rate in DB (as background sync would)
      await insertPrice(assetId, today, 180.0);
      await insertRate('EUR', 'USD', today, 1.08);

      // Read back (what providers do offline)
      final price = await priceService.getPrice(assetId, now);
      final fxRate = await rateService.getRate('USD', 'EUR', now);

      expect(price, isNotNull);
      expect(fxRate, isNotNull);

      // Compute market value: 10 shares * 180 USD * (1/1.08) EUR/USD
      const quantity = 10.0;
      final marketValue = quantity * price! * fxRate!;
      expect(marketValue, closeTo(10 * 180.0 / 1.08, 1e-6));
    });

    test('market value works with only yesterday prices (weekend scenario)', () async {
      final assetId = await createAsset('EU ETF', ticker: 'SWDA');
      final friday = DateTime(2024, 6, 14);
      final saturday = DateTime(2024, 6, 15);

      await insertPrice(assetId, friday, 112.0);

      // On Saturday, getPrice falls back to Friday's close
      final price = await priceService.getPrice(assetId, saturday);
      expect(price, 112.0);
    });
  });

  group('daily change computation offline', () {
    test('price change is zero when today and reference have same price', () async {
      final assetId = await createAsset('ETF A');
      final friday = DateTime(2024, 6, 14);
      final saturday = DateTime(2024, 6, 15);

      // Only Friday's close stored
      await insertPrice(assetId, friday, 100.0);

      final todayPrice = await priceService.getPrice(assetId, saturday);
      final refPrice = await priceService.getPrice(assetId, friday);

      expect(todayPrice, 100.0);
      expect(refPrice, 100.0);
      expect(todayPrice! - refPrice!, 0.0);
    });

    test('FX-driven value delta shows when rates differ', () async {
      final assetId = await createAsset('US Stock', currency: 'USD');
      final friday = DateTime(2024, 6, 14);
      final today = DateTime(2024, 6, 15);

      await insertPrice(assetId, friday, 200.0);
      await insertRate('USD', 'EUR', friday, 0.925);
      await insertRate('USD', 'EUR', today, 0.930);

      final price = await priceService.getPrice(assetId, today);
      final todayFx = await rateService.getRate('USD', 'EUR', today);
      final prevFx = await rateService.getRate('USD', 'EUR', friday);

      // Same price, different FX -> value delta is non-zero
      const qty = 10.0;
      final valueDiff = (price! * qty * todayFx!) - (price * qty * prevFx!);
      expect(valueDiff, isNot(0.0));
      expect(valueDiff, closeTo(10 * 200.0 * (0.930 - 0.925), 1e-6));
    });
  });
}
