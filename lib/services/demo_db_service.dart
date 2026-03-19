import 'dart:math';

import 'package:drift/drift.dart';

import '../database/database.dart';
import '../database/tables.dart';
import '../utils/logger.dart';

final _log = getLogger('DemoDbService');

/// Generates a demo database with realistic, anonymized financial data.
class DemoDbService {
  DemoDbService._();

  static Future<void> generateDemoDb(String path) async {
    _log.info('Generating demo DB at $path');
    final db = AppDatabase.withPath(path);

    try {
      // Wait for DB to be fully initialized (migration runs on first access)
      await db.customSelect('SELECT 1').get();

      await _insertAccounts(db);
      await _insertCategories(db);
      await _insertTransactions(db);
      await _insertAssets(db);
      await _insertAssetEvents(db);
      await _insertBuffer(db);
      await _insertDepreciation(db);
      await _insertExchangeRates(db);

      _log.info('Demo DB generation complete');
    } finally {
      await db.close();
    }
  }

  static Future<void> _insertAccounts(AppDatabase db) async {
    final accounts = [
      ('Checking Plus', AccountType.bank, 'EUR', 'National Bank', 1),
      ('Savings Pro', AccountType.bank, 'EUR', 'National Bank', 2),
      ('Digital Bank', AccountType.bank, 'EUR', 'FinTech Bank', 3),
      ('Reserve Fund', AccountType.bank, 'EUR', 'Credit Union', 4),
    ];
    for (final (name, type, currency, institution, order) in accounts) {
      await db.into(db.accounts).insert(AccountsCompanion.insert(
        name: name,
        type: Value(type),
        currency: Value(currency),
        institution: Value(institution),
        sortOrder: Value(order),
      ));
    }
  }

  static Future<void> _insertCategories(AppDatabase db) async {
    final categories = [
      ('Salary', CategoryType.income, true),
      ('Freelance', CategoryType.income, false),
      ('Rent', CategoryType.expense, true),
      ('Groceries', CategoryType.expense, true),
      ('Utilities', CategoryType.expense, true),
      ('Transport', CategoryType.expense, false),
      ('Subscriptions', CategoryType.expense, false),
      ('Dining Out', CategoryType.expense, false),
      ('Healthcare', CategoryType.expense, true),
      ('Transfer', CategoryType.transfer, false),
    ];
    for (final (name, type, essential) in categories) {
      await db.into(db.categories).insert(CategoriesCompanion.insert(
        name: name,
        type: type,
        isEssential: Value(essential),
      ));
    }
  }

  static Future<void> _insertTransactions(AppDatabase db) async {
    final rng = Random(42);
    final now = DateTime.now();
    var balanceChecking = 0.0;
    var balanceSavings = 15000.0;

    // Insert initial savings balance as a single transaction
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
      accountId: 2,
      operationDate: DateTime(2023, 1, 1),
      valueDate: DateTime(2023, 1, 1),
      amount: balanceSavings,
      balanceAfter: Value(balanceSavings),
      description: Value('Opening balance'),
      categoryId: const Value(1),
    ));

    // Monthly transactions for ~24 months on Checking Plus (account 1)
    for (var m = 0; m < 24; m++) {
      final year = 2024 + m ~/ 12;
      final month = 1 + m % 12;
      if (DateTime(year, month, 1).isAfter(now)) break;

      // Salary: 27th of prior month or 1st
      final salaryDay = min(27, DateTime(year, month + 1, 0).day);
      final salaryDate = DateTime(year, month, salaryDay);
      final salary = 3200.0 + rng.nextInt(200).toDouble();
      balanceChecking += salary;
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
        accountId: 1,
        operationDate: salaryDate,
        valueDate: salaryDate,
        amount: salary,
        balanceAfter: Value(balanceChecking),
        description: Value('Monthly salary'),
        categoryId: const Value(1), // Salary
      ));

      // Rent: 1st of month
      final rentDate = DateTime(year, month, 1);
      const rent = -950.0;
      balanceChecking += rent;
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
        accountId: 1,
        operationDate: rentDate,
        valueDate: rentDate,
        amount: rent,
        balanceAfter: Value(balanceChecking),
        description: Value('Rent payment'),
        categoryId: const Value(3), // Rent
      ));

      // Groceries: 3-4 transactions per month
      final groceryCount = 3 + rng.nextInt(2);
      for (var g = 0; g < groceryCount; g++) {
        final day = 3 + rng.nextInt(25);
        final groceryDate = DateTime(year, month, min(day, 28));
        final amount = -(40.0 + rng.nextInt(80).toDouble());
        balanceChecking += amount;
        await db.into(db.transactions).insert(TransactionsCompanion.insert(
          accountId: 1,
          operationDate: groceryDate,
          valueDate: groceryDate,
          amount: amount,
          balanceAfter: Value(balanceChecking),
          description: Value('Supermarket'),
          categoryId: const Value(4), // Groceries
        ));
      }

      // Utilities: once per month
      final utilDate = DateTime(year, month, 15);
      final util = -(80.0 + rng.nextInt(40).toDouble());
      balanceChecking += util;
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
        accountId: 1,
        operationDate: utilDate,
        valueDate: utilDate,
        amount: util,
        balanceAfter: Value(balanceChecking),
        description: Value('Electricity & gas'),
        categoryId: const Value(5), // Utilities
      ));

      // Subscription: ~15€
      final subDate = DateTime(year, month, 10);
      const sub = -14.99;
      balanceChecking += sub;
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
        accountId: 1,
        operationDate: subDate,
        valueDate: subDate,
        amount: sub,
        balanceAfter: Value(balanceChecking),
        description: Value('Streaming subscription'),
        categoryId: const Value(7), // Subscriptions
      ));
    }
  }

  static Future<void> _insertAssets(AppDatabase db) async {
    final assets = [
      ('GLMK', 'Global Markets ETF', AssetType.stockEtf, 'EUR', 'MIL', 'GLMK.MI', 'global'),
      ('EGB3', 'Euro Gov Bond 1-3Y', AssetType.bondEtf, 'EUR', 'MIL', 'EGB3.MI', 'bonds'),
      ('EMKT', 'Emerging Markets ETF', AssetType.stockEtf, 'EUR', 'MIL', 'EMKT.MI', 'emerging'),
      ('EU60', 'Europe 600 ETF', AssetType.stockEtf, 'EUR', 'MIL', 'EU60.MI', 'europe'),
      ('GLDX', 'Gold ETC', AssetType.goldEtc, 'EUR', 'MIL', 'GLDX.MI', 'commodities'),
      ('USTK', 'US Tech Leaders', AssetType.stockEtf, 'USD', 'NYQ', 'USTK', 'us-tech'),
    ];
    for (var i = 0; i < assets.length; i++) {
      final (ticker, name, type, currency, exchange, yahoo, group) = assets[i];
      await db.into(db.assets).insert(AssetsCompanion.insert(
        name: name,
        ticker: Value(ticker),
        assetType: type,
        assetGroup: Value(group),
        currency: Value(currency),
        exchange: Value(exchange),
        yahooTicker: Value(yahoo),
        valuationMethod: ValuationMethod.marketPrice,
        sortOrder: Value(i + 1),
      ));
    }
  }

  static Future<void> _insertAssetEvents(AppDatabase db) async {
    final rng = Random(42);

    // (assetId, basePrices per year from 2021-2025, qty range)
    final buyPlans = [
      (1, [68.0, 72.0, 65.0, 78.0, 82.0], 5, 15),   // GLMK
      (2, [102.0, 100.0, 98.0, 103.0, 105.0], 3, 8), // EGB3
      (3, [25.0, 28.0, 22.0, 30.0, 33.0], 10, 25),   // EMKT
      (4, [45.0, 48.0, 42.0, 52.0, 55.0], 5, 15),    // EU60
      (5, [150.0, 165.0, 170.0, 180.0, 195.0], 1, 5), // GLDX
      (6, [85.0, 95.0, 75.0, 105.0, 120.0], 3, 10),  // USTK (USD)
    ];

    // Collect all events, then sort by date before inserting
    final events = <AssetEventsCompanion>[];

    for (final (assetId, basePrices, minQty, maxQty) in buyPlans) {
      for (var year = 2021; year <= 2025; year++) {
        final buysThisYear = 2 + rng.nextInt(3);
        final priceIdx = year - 2021;
        final basePrice = basePrices[priceIdx];

        for (var b = 0; b < buysThisYear; b++) {
          final month = 1 + rng.nextInt(12);
          final day = 1 + rng.nextInt(28);
          final date = DateTime(year, month, day);
          final qty = (minQty + rng.nextInt(maxQty - minQty + 1)).toDouble();
          final price = basePrice * (0.95 + rng.nextDouble() * 0.10);
          final commission = 1.5 + rng.nextDouble() * 3.0;
          final amount = qty * price + commission;
          final isUsd = assetId == 6;

          events.add(AssetEventsCompanion.insert(
            assetId: assetId,
            date: date,
            type: EventType.buy,
            quantity: Value(qty),
            price: Value(double.parse(price.toStringAsFixed(4))),
            amount: double.parse(amount.toStringAsFixed(2)),
            currency: Value(isUsd ? 'USD' : 'EUR'),
            exchangeRate: Value(isUsd ? 1.08 + rng.nextDouble() * 0.06 : null),
            commission: Value(double.parse(commission.toStringAsFixed(2))),
            source: const Value('Demo'),
          ));
        }
      }
    }

    // Sort by date so the chart renders as a proper function
    events.sort((a, b) => a.date.value.compareTo(b.date.value));
    for (final event in events) {
      await db.into(db.assetEvents).insert(event);
    }
  }

  static Future<void> _insertBuffer(AppDatabase db) async {
    // Create "Car Fund" buffer
    await db.into(db.buffers).insert(BuffersCompanion.insert(
      name: 'Car Fund',
      targetAmount: const Value(12000.0),
    ));

    final rng = Random(99);
    var balance = 0.0;
    for (var m = 0; m < 5; m++) {
      final date = DateTime(2024, 3 + m * 2, 15);
      final amount = 500.0 + rng.nextInt(300).toDouble();
      balance += amount;
      await db.into(db.bufferTransactions).insert(BufferTransactionsCompanion.insert(
        bufferId: 1,
        operationDate: date,
        valueDate: date,
        description: Value('Deposit #${m + 1}'),
        amount: amount,
        balanceAfter: balance,
      ));
    }
  }

  static Future<void> _insertDepreciation(AppDatabase db) async {
    final start = DateTime(2024, 1, 1);
    final end = DateTime(2026, 12, 31);

    await db.into(db.depreciationSchedules).insert(DepreciationSchedulesCompanion.insert(
      assetName: 'Used Car',
      assetCategory: 'Vehicle',
      totalAmount: 18000.0,
      method: DepreciationMethod.linear,
      startDate: start,
      endDate: end,
      usefulLifeMonths: 36,
      direction: DepreciationDirection.forward,
    ));

    // Generate monthly depreciation entries
    const monthlyAmount = 18000.0 / 36;
    var cumulative = 0.0;
    for (var m = 0; m < 36; m++) {
      final year = start.year + (start.month + m - 1) ~/ 12;
      final month = (start.month + m - 1) % 12 + 1;
      final date = DateTime(year, month, 1);
      cumulative += monthlyAmount;
      final remaining = 18000.0 - cumulative;

      await db.into(db.depreciationEntries).insert(DepreciationEntriesCompanion.insert(
        scheduleId: 1,
        date: date,
        amount: double.parse(monthlyAmount.toStringAsFixed(2)),
        cumulative: double.parse(cumulative.toStringAsFixed(2)),
        remaining: double.parse(remaining.toStringAsFixed(2)),
      ));
    }
  }

  static Future<void> _insertExchangeRates(AppDatabase db) async {
    final rng = Random(77);
    final start = DateTime(2023, 1, 1);
    final now = DateTime.now();

    // EUR/USD daily rates for ~2 years
    var rate = 1.08;
    for (var d = start; d.isBefore(now); d = d.add(const Duration(days: 1))) {
      // Random walk
      rate += (rng.nextDouble() - 0.5) * 0.005;
      rate = rate.clamp(1.02, 1.18);

      await db.into(db.exchangeRates).insert(ExchangeRatesCompanion(
        fromCurrency: const Value('EUR'),
        toCurrency: const Value('USD'),
        date: Value(d),
        rate: Value(double.parse(rate.toStringAsFixed(4))),
      ));
    }
  }
}
