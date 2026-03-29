import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:drift/drift.dart';

import '../database/database.dart';
import '../database/tables.dart';
import '../utils/logger.dart';

final _log = getLogger('DemoDbService');

/// Generates a demo database with realistic, anonymized financial data.
///
/// Generation order: market prices → FX rates → asset events (using actual
/// market prices on buy dates) → transactions (with balance guard ≥ 0).
class DemoDbService {
  DemoDbService._();

  /// Minimum balance the main account is allowed to have. Investment buys
  /// are skipped for the month if they would push the balance below this.
  static const _minBalance = 2000.0;

  /// Runs demo generation in a separate isolate so the UI stays responsive.
  /// [onProgress] receives (step, totalSteps, label) updates from the isolate.
  static Future<void> generateDemoDb(String path, {void Function(int step, int total, String label)? onProgress}) async {
    _log.info('Generating demo DB at $path (in isolate)');

    final receivePort = ReceivePort();
    await Isolate.spawn(
      (message) async {
        final sendPort = message.$1 as SendPort;
        final dbPath = message.$2 as String;
        await _generateDemoDb(dbPath, sendPort: sendPort);
        sendPort.send('DONE');
        Isolate.exit();
      },
      (receivePort.sendPort, path),
    );

    await for (final msg in receivePort) {
      if (msg == 'DONE') break;
      if (msg is List && msg.length == 3) {
        onProgress?.call(msg[0] as int, msg[1] as int, msg[2] as String);
      }
    }
    receivePort.close();
    _log.info('Demo DB generation complete');
  }

  static Future<void> _generateDemoDb(String path, {SendPort? sendPort}) async {
    final db = AppDatabase.withPath(path);
    const total = 9;
    var step = 0;
    void progress(String label) { step++; sendPort?.send([step, total, label]); }

    try {
      await db.customSelect('SELECT 1').get();

      progress('Creating accounts...');
      await _insertAccounts(db);
      await _insertCategories(db);
      await _insertAssets(db);

      progress('Generating prices...');
      final priceTimeSeries = _generatePriceTimeSeries();
      await _writeMarketPrices(db, priceTimeSeries);

      progress('Generating FX rates...');
      final fxRates = _generateFxRates();
      await _writeFxRates(db, fxRates);

      progress('Generating transactions...');
      await _insertEventsAndTransactions(db, priceTimeSeries, fxRates);

      progress('Generating income records...');
      await _insertIncomes(db);

      progress('Creating buffer...');
      await _insertBuffer(db);

      progress('Creating adjustments...');
      await _insertDepreciation(db);

      progress('Creating charts...');
      await _insertDashboardCharts(db);

      progress('Finalizing...');
    } finally {
      await db.close();
    }
  }

  // ── Accounts ──

  static Future<void> _insertAccounts(AppDatabase db) async {
    final accounts = [
      ('Main Account', AccountType.bank, 'EUR', 'National Bank', 1),
      ('Daily Spending', AccountType.bank, 'EUR', 'Digital Bank', 2),
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

  // ── Categories ──

  static Future<void> _insertCategories(AppDatabase db) async {
    final categories = [
      ('Salary', CategoryType.income, true),          // 1
      ('Freelance', CategoryType.income, false),       // 2
      ('Rent', CategoryType.expense, true),            // 3
      ('Groceries', CategoryType.expense, true),       // 4
      ('Utilities', CategoryType.expense, true),       // 5
      ('Transport', CategoryType.expense, false),      // 6
      ('Subscriptions', CategoryType.expense, false),  // 7
      ('Dining Out', CategoryType.expense, false),     // 8
      ('Healthcare', CategoryType.expense, true),      // 9
      ('Investments', CategoryType.expense, false),    // 10
      ('Transfer', CategoryType.transfer, false),      // 11
    ];
    for (final (name, type, essential) in categories) {
      await db.into(db.categories).insert(CategoriesCompanion.insert(
        name: name,
        type: type,
        isEssential: Value(essential),
      ));
    }
  }

  // ── Assets (fictional, anonymized) ──

  static Future<void> _insertAssets(AppDatabase db) async {
    final assets = [
      ('VWCE', 'Vanguard FTSE All-World', AssetType.stockEtf, InstrumentType.etf, AssetClass.equity, 'EUR', 'MIL', 'VWCE.MI', 'IE00BK5BQT80', 'global'),
      ('AGGH', 'iShares Core Global Agg Bond', AssetType.bondEtf, InstrumentType.etf, AssetClass.fixedIncome, 'EUR', 'MIL', 'AGGH.MI', 'IE00BDBRDM35', 'bonds'),
      ('VFEA', 'Vanguard FTSE Emerging Markets', AssetType.stockEtf, InstrumentType.etf, AssetClass.equity, 'EUR', 'MIL', 'VFEA.MI', 'IE00BK5BR733', 'emerging'),
      ('CSSPX', 'iShares Core S&P 500 Acc', AssetType.stockEtf, InstrumentType.etf, AssetClass.equity, 'EUR', 'MIL', 'CSSPX.MI', 'IE00B5BMR087', 'us-large'),
      ('SGLD', 'Invesco Physical Gold ETC', AssetType.goldEtc, InstrumentType.etc, AssetClass.commodities, 'EUR', 'MIL', 'SGLD.MI', 'IE00B579F325', 'commodities'),
      ('MSFT', 'Microsoft Corp', AssetType.stock, InstrumentType.stock, AssetClass.equity, 'USD', 'NYQ', 'MSFT', 'US5949181045', 'us-tech'),
    ];
    for (var i = 0; i < assets.length; i++) {
      final (ticker, name, type, instrument, assetCls, currency, exchange, yahoo, isin, group) = assets[i];
      await db.into(db.assets).insert(AssetsCompanion.insert(
        name: name,
        ticker: Value(ticker),
        isin: Value(isin),
        assetType: type,
        instrumentType: Value(instrument),
        assetClass: Value(assetCls),
        assetGroup: Value(group),
        currency: Value(currency),
        exchange: Value(exchange),
        yahooTicker: Value(yahoo),
        valuationMethod: ValuationMethod.marketPrice,
        sortOrder: Value(i + 1),
      ));
    }
  }

  // ══════════════════════════════════════════════════
  // Market price generation (in-memory, then persisted)
  // ══════════════════════════════════════════════════

  static Map<int, Map<int, double>> _generatePriceTimeSeries() {
    final rng = Random(55);
    final now = DateTime.now();

    // (assetId, startDate, startPrice, annualDrift, dailyVol)
    final specs = [
      (1, DateTime(2022, 1, 3), 68.0, 0.07, 0.011),  // VWCE
      (2, DateTime(2022, 1, 3), 105.0, 0.01, 0.003),  // AGGH
      (3, DateTime(2022, 1, 3), 28.0, 0.06, 0.014),   // VFEA
      (4, DateTime(2022, 1, 3), 48.0, 0.07, 0.012),   // CSSPX
      (5, DateTime(2022, 1, 3), 160.0, 0.05, 0.010),  // SGLD
      (6, DateTime(2017, 1, 3), 45.0, 0.15, 0.020),   // MSFT (USD)
    ];

    final result = <int, Map<int, double>>{};
    for (final (assetId, startDate, startPrice, drift, vol) in specs) {
      var price = startPrice;
      final dailyDrift = drift / 252;
      final dayMap = <int, double>{};

      for (var d = startDate; d.isBefore(now); d = d.add(const Duration(days: 1))) {
        if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) continue;
        final z = _normalRandom(rng);
        price *= (1 + dailyDrift + vol * z);
        if (price < 1.0) price = 1.0;
        dayMap[_dayKey(d)] = double.parse(price.toStringAsFixed(4));
      }
      result[assetId] = dayMap;
    }
    return result;
  }

  static Future<void> _writeMarketPrices(
    AppDatabase db, Map<int, Map<int, double>> priceTimeSeries,
  ) async {
    const currencies = {1: 'EUR', 2: 'EUR', 3: 'EUR', 4: 'EUR', 5: 'EUR', 6: 'USD'};
    for (final assetId in priceTimeSeries.keys) {
      final dayMap = priceTimeSeries[assetId]!;
      final currency = currencies[assetId]!;
      final sortedDays = dayMap.keys.toList()..sort();
      for (final dk in sortedDays) {
        final d = DateTime.fromMillisecondsSinceEpoch(dk * 86400000);
        await db.into(db.marketPrices).insert(MarketPricesCompanion(
          assetId: Value(assetId),
          date: Value(d),
          closePrice: Value(dayMap[dk]!),
          currency: Value(currency),
        ));
      }
    }
  }

  // ══════════════════════════════════════════════════
  // FX rates
  // ══════════════════════════════════════════════════

  static Map<int, double> _generateFxRates() {
    final rng = Random(77);
    final start = DateTime(2017, 1, 1);
    final now = DateTime.now();
    final rates = <int, double>{};
    var rate = 1.08;
    for (var d = start; d.isBefore(now); d = d.add(const Duration(days: 1))) {
      rate += (rng.nextDouble() - 0.5) * 0.005;
      rate = rate.clamp(1.02, 1.18);
      rates[_dayKey(d)] = double.parse(rate.toStringAsFixed(4));
    }
    return rates;
  }

  static Future<void> _writeFxRates(AppDatabase db, Map<int, double> fxRates) async {
    final sortedDays = fxRates.keys.toList()..sort();
    for (final dk in sortedDays) {
      final d = DateTime.fromMillisecondsSinceEpoch(dk * 86400000);
      await db.into(db.exchangeRates).insert(ExchangeRatesCompanion(
        fromCurrency: const Value('EUR'),
        toCurrency: const Value('USD'),
        date: Value(d),
        rate: Value(fxRates[dk]!),
      ));
    }
  }

  // ══════════════════════════════════════════════════
  // Events + Transactions (interleaved so balance stays ≥ 0)
  // ══════════════════════════════════════════════════

  /// Builds a chronological list of _MonthlyBuy candidates, then processes
  /// months in order: salary in → expenses out → check if buy fits → insert.
  static Future<void> _insertEventsAndTransactions(
    AppDatabase db,
    Map<int, Map<int, double>> prices,
    Map<int, double> fxRates,
  ) async {
    final rng = Random(42);
    final now = DateTime.now();

    // ── Pre-compute all potential monthly EUR buys ──
    // Each month: buy 4 ETFs with a target budget of ~2500 EUR.
    // Quantities are small enough so the total fits in a normal salary.
    //
    // (assetId, ticker, targetAmountPerBuy in EUR)
    const eurAlloc = [
      (1, 'VWCE', 1000.0),  // All-World – largest allocation
      (2, 'AGGH', 300.0),   // Bonds – small
      (3, 'VFEA', 500.0),   // Emerging
      (4, 'CSSPX', 700.0),   // S&P 500
    ];

    // Collect buy candidates: (date, assetId, ticker, qty, price, eurAmount)
    final buyCandidates = <(DateTime, List<(int, String, double, double, double)>)>[];

    for (var year = 2022; year <= now.year; year++) {
      final startMonth = year == 2022 ? 5 : 1;
      final endMonth = year == now.year ? now.month - 1 : 12;

      for (var month = startMonth; month <= endMonth; month++) {
        var buyDay = 15 + rng.nextInt(4);
        var buyDate = DateTime(year, month, buyDay);
        while (buyDate.weekday == DateTime.saturday || buyDate.weekday == DateTime.sunday) {
          buyDay++;
          buyDate = DateTime(year, month, buyDay);
        }
        if (buyDate.isAfter(now)) break;

        final batch = <(int, String, double, double, double)>[];
        for (final (assetId, ticker, targetEur) in eurAlloc) {
          final price = _priceOn(prices, assetId, buyDate);
          final qty = (targetEur / price).floorToDouble();
          if (qty < 1) continue;
          final commission = 2.0 + rng.nextDouble() * 2.0;
          final amount = qty * price + commission;
          batch.add((assetId, ticker, qty, price, amount));
        }
        buyCandidates.add((buyDate, batch));
      }
    }

    // SGLD occasional buys
    final gldxBuys = [
      (DateTime(2022, 5, 18), 5, 5.0),
      (DateTime(2023, 6, 5), 5, 3.0),
      (DateTime(2025, 1, 6), 5, 4.0),
    ];

    // MSFT (USD) buys
    final ustkBuys = [
      (DateTime(2018, 2, 15), 6, 20.0),
      (DateTime(2019, 2, 15), 6, 40.0),
      (DateTime(2019, 8, 15), 6, 50.0),
      (DateTime(2020, 2, 18), 6, 30.0),
      (DateTime(2020, 8, 17), 6, 60.0),
    ];

    // ── Build a month-by-month timeline of all financial events ──

    // Account 1: Main Account
    var balanceMain = 25000.0;
    await _insertTx(db, 1, DateTime(2018, 1, 1), balanceMain, balanceMain,
        'Opening balance', 1);

    // Pre-index buy candidates by (year, month) for quick lookup
    final buyByMonth = <(int, int), List<(int, String, double, double, double)>>{};
    final buyDateByMonth = <(int, int), DateTime>{};
    for (final (date, batch) in buyCandidates) {
      buyByMonth[(date.year, date.month)] = batch;
      buyDateByMonth[(date.year, date.month)] = date;
    }

    // Pre-index one-off buys by (year, month)
    final oneOffBuysByMonth = <(int, int), List<(int, double, double, double, DateTime)>>{};
    for (final (date, assetId, qty) in gldxBuys) {
      if (date.isAfter(now)) continue;
      final price = _priceOn(prices, assetId, date);
      final amount = qty * price + 9.95;
      oneOffBuysByMonth.putIfAbsent((date.year, date.month), () => [])
          .add((assetId, qty, price, amount, date));
    }
    for (final (date, assetId, qty) in ustkBuys) {
      if (date.isAfter(now)) continue;
      final price = _priceOn(prices, assetId, date);
      final fxRate = _fxOn(fxRates, date);
      final usdAmount = qty * price;
      final eurAmount = usdAmount / fxRate;
      oneOffBuysByMonth.putIfAbsent((date.year, date.month), () => [])
          .add((assetId, qty, price, eurAmount, date));
    }

    // All asset events to insert at the end (sorted)
    final allEvents = <(DateTime, AssetEventsCompanion)>[];

    // Monthly loop
    for (var year = 2018; year <= now.year; year++) {
      final endMonth = year == now.year ? now.month : 12;
      for (var month = 1; month <= endMonth; month++) {
        if (DateTime(year, month, 1).isAfter(now)) break;

        // ── Income: salary ~27th ──
        final baseSalary = 3200.0 + (year - 2018) * 120.0;
        final salary = baseSalary + rng.nextInt(200).toDouble();
        final salaryDay = min(27, DateTime(year, month + 1, 0).day);
        final salaryDate = DateTime(year, month, salaryDay);
        if (!salaryDate.isAfter(now)) {
          balanceMain += salary;
          await _insertTx(db, 1, salaryDate, salary, balanceMain, 'Monthly salary', 1);
        }

        // ── Expenses ──
        // Rent (2020+)
        if (year >= 2020) {
          final rentDate = DateTime(year, month, 1);
          if (!rentDate.isAfter(now)) {
            const rent = -850.0;
            balanceMain += rent;
            await _insertTx(db, 1, rentDate, rent, balanceMain, 'Rent payment', 3);
          }
        }

        // Utilities 15th
        final utilDate = DateTime(year, month, 15);
        if (!utilDate.isAfter(now)) {
          final util = -(80.0 + rng.nextInt(40).toDouble());
          balanceMain += util;
          await _insertTx(db, 1, utilDate, util, balanceMain, 'Electricity & gas', 5);
        }

        // Subscriptions 10th
        final subDate = DateTime(year, month, 10);
        if (!subDate.isAfter(now)) {
          const sub = -14.99;
          balanceMain += sub;
          await _insertTx(db, 1, subDate, sub, balanceMain, 'Streaming subscription', 7);
        }

        // Transfer to spending account (2022+)
        if (year >= 2022) {
          for (final topUpDay in [5, 20]) {
            final topUpDate = DateTime(year, month, topUpDay);
            if (!topUpDate.isAfter(now)) {
              final topUp = -(300.0 + rng.nextInt(100).toDouble());
              if (balanceMain + topUp >= _minBalance) {
                balanceMain += topUp;
                await _insertTx(db, 1, topUpDate, topUp, balanceMain,
                    'Transfer to Daily Spending', 11);
              }
            }
          }
        }

        // ── One-off buys (SGLD, MSFT) ──
        final oneOffs = oneOffBuysByMonth[(year, month)];
        if (oneOffs != null) {
          for (final (assetId, qty, price, eurAmount, date) in oneOffs) {
            if (balanceMain - eurAmount < _minBalance) continue;
            balanceMain -= eurAmount;
            await _insertTx(db, 1, date, -eurAmount, balanceMain,
                'Buy ${_tickerForId(assetId)} ${qty.toInt()}', 10);

            final isUsd = assetId == 6;
            allEvents.add((date, AssetEventsCompanion.insert(
              assetId: assetId,
              date: date,
              type: EventType.buy,
              quantity: Value(qty),
              price: Value(price),
              amount: double.parse((qty * price).toStringAsFixed(2)),
              currency: Value(isUsd ? 'USD' : 'EUR'),
              exchangeRate: Value(isUsd ? _fxOn(fxRates, date) : 1.0),
              commission: Value(isUsd ? 0.0 : 9.95),
              source: const Value('Demo'),
            )));
          }
        }

        // ── Monthly batch ETF buys ──
        final batch = buyByMonth[(year, month)];
        if (batch != null) {
          final buyDate = buyDateByMonth[(year, month)]!;
          final totalCost = batch.fold(0.0, (sum, b) => sum + b.$5);

          // Only buy if we can afford the whole batch
          if (balanceMain - totalCost >= _minBalance) {
            final descriptions = <String>[];
            for (final (assetId, ticker, qty, price, amount) in batch) {
              allEvents.add((buyDate, AssetEventsCompanion.insert(
                assetId: assetId,
                date: buyDate,
                type: EventType.buy,
                quantity: Value(qty),
                price: Value(price),
                amount: double.parse(amount.toStringAsFixed(2)),
                currency: const Value('EUR'),
                exchangeRate: const Value(1.0),
                commission: Value(double.parse((amount - qty * price).toStringAsFixed(2))),
                source: const Value('Demo'),
              )));
              descriptions.add('$ticker ${qty.toInt()}');
            }
            balanceMain -= totalCost;
            await _insertTx(db, 1, buyDate, -totalCost, balanceMain,
                'Buy ${descriptions.join(", ")}', 10);
          }
        }
      }
    }

    // Insert all asset events sorted by date
    allEvents.sort((a, b) => a.$1.compareTo(b.$1));
    for (final (_, event) in allEvents) {
      await db.into(db.assetEvents).insert(event);
    }

    // ── Account 2: Daily Spending ──
    var balanceSpending = 0.0;
    for (var year = 2022; year <= now.year; year++) {
      final endMonth = year == now.year ? now.month : 12;
      for (var month = 1; month <= endMonth; month++) {
        if (DateTime(year, month, 1).isAfter(now)) break;

        // Top-ups from main account
        for (final topUpDay in [5, 20]) {
          final topUpDate = DateTime(year, month, topUpDay);
          if (!topUpDate.isAfter(now)) {
            final topUp = 300.0 + rng.nextInt(100).toDouble();
            balanceSpending += topUp;
            await _insertTx(db, 2, topUpDate, topUp, balanceSpending,
                'Top-up from Main Account', 11);
          }
        }

        // Groceries
        final groceryCount = 3 + rng.nextInt(2);
        for (var g = 0; g < groceryCount; g++) {
          final day = 3 + rng.nextInt(25);
          final groceryDate = DateTime(year, month, min(day, 28));
          if (!groceryDate.isAfter(now)) {
            final amount = -(30.0 + rng.nextInt(60).toDouble());
            if (balanceSpending + amount >= 0) {
              balanceSpending += amount;
              await _insertTx(db, 2, groceryDate, amount, balanceSpending,
                  'Supermarket', 4);
            }
          }
        }

        // Dining out
        final diningCount = 1 + rng.nextInt(2);
        for (var g = 0; g < diningCount; g++) {
          final day = 5 + rng.nextInt(23);
          final diningDate = DateTime(year, month, min(day, 28));
          if (!diningDate.isAfter(now)) {
            final amount = -(20.0 + rng.nextInt(40).toDouble());
            if (balanceSpending + amount >= 0) {
              balanceSpending += amount;
              await _insertTx(db, 2, diningDate, amount, balanceSpending,
                  'Restaurant', 8);
            }
          }
        }

        // Transport
        final transportDate = DateTime(year, month, 12);
        if (!transportDate.isAfter(now)) {
          final amount = -(30.0 + rng.nextInt(20).toDouble());
          if (balanceSpending + amount >= 0) {
            balanceSpending += amount;
            await _insertTx(db, 2, transportDate, amount, balanceSpending,
                'Fuel', 6);
          }
        }
      }
    }
  }

  static String _tickerForId(int id) =>
      const {1: 'VWCE', 2: 'AGGH', 3: 'VFEA', 4: 'CSSPX', 5: 'SGLD', 6: 'MSFT'}[id] ?? '?';

  // ══════════════════════════════════════════════════
  // Helpers
  // ══════════════════════════════════════════════════

  static double _priceOn(Map<int, Map<int, double>> prices, int assetId, DateTime date) {
    final dayMap = prices[assetId]!;
    var dk = _dayKey(date);
    for (var i = 0; i < 5; i++) {
      if (dayMap.containsKey(dk - i)) return dayMap[dk - i]!;
    }
    final sorted = dayMap.keys.toList()..sort();
    return dayMap[sorted.first]!;
  }

  static double _fxOn(Map<int, double> fxRates, DateTime date) {
    var dk = _dayKey(date);
    for (var i = 0; i < 5; i++) {
      if (fxRates.containsKey(dk - i)) return fxRates[dk - i]!;
    }
    return 1.10;
  }

  static Future<void> _insertTx(
    AppDatabase db, int accountId, DateTime date, double amount,
    double balanceAfter, String description, int categoryId,
  ) async {
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
      accountId: accountId,
      operationDate: date,
      valueDate: date,
      amount: double.parse(amount.toStringAsFixed(2)),
      balanceAfter: Value(double.parse(balanceAfter.toStringAsFixed(2))),
      description: Value(description),
      categoryId: Value(categoryId),
    ));
  }

  static double _normalRandom(Random rng) {
    final u1 = rng.nextDouble();
    final u2 = rng.nextDouble();
    return sqrt(-2 * log(u1)) * cos(2 * pi * u2);
  }

  static int _dayKey(DateTime d) => d.millisecondsSinceEpoch ~/ 86400000;

  // ── Income records ──

  static Future<void> _insertIncomes(AppDatabase db) async {
    final now = DateTime.now();
    final rng = Random(99);

    for (int year = 2018; year <= now.year; year++) {
      final maxMonth = year == now.year ? now.month : 12;
      for (int month = 1; month <= maxMonth; month++) {
        final date = DateTime(year, month, 27);
        if (date.isAfter(now)) break;

        // Monthly salary — grows over the years
        final salary = 3200.0 + (year - 2018) * 120.0 + rng.nextInt(200);
        await db.into(db.incomes).insert(IncomesCompanion.insert(
          date: date,
          amount: salary.toDouble(),
          type: const Value(IncomeType.income),
          currency: const Value('EUR'),
        ));

        // Occasional refunds (every ~4 months)
        if (month % 4 == 2) {
          final refund = 50.0 + rng.nextInt(200);
          await db.into(db.incomes).insert(IncomesCompanion.insert(
            date: DateTime(year, month, 15),
            amount: refund.toDouble(),
            type: const Value(IncomeType.refund),
            currency: const Value('EUR'),
          ));
        }
      }
    }
  }

  // ── Buffer ──

  static Future<void> _insertBuffer(AppDatabase db) async {
    await db.into(db.buffers).insert(BuffersCompanion.insert(
      name: 'Car Fund',
      targetAmount: const Value(12000.0),
    ));

    final rng = Random(99);
    var balance = 0.0;
    for (var m = 0; m < 8; m++) {
      final date = DateTime(2024, 1 + m, 15);
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

  // ── Depreciation ──

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

  // ── Dashboard charts ──

  static Future<void> _insertDashboardCharts(AppDatabase db) async {
    final investedMarketSeries = <Map<String, dynamic>>[];
    for (var id = 1; id <= 6; id++) {
      investedMarketSeries.add({'type': 'asset_market', 'id': id});
      investedMarketSeries.add({'type': 'asset_invested', 'id': id});
    }
    await db.into(db.dashboardCharts).insert(DashboardChartsCompanion.insert(
      title: 'Invested vs Market Value',
      sortOrder: const Value(0),
      seriesJson: jsonEncode(investedMarketSeries),
    ));

    final netWorthSeries = <Map<String, dynamic>>[
      {'type': 'account', 'id': 1},
      {'type': 'account', 'id': 2},
      {'type': 'adjustment', 'id': 1},
      for (var id = 1; id <= 6; id++) {'type': 'asset_invested', 'id': id},
    ];
    await db.into(db.dashboardCharts).insert(DashboardChartsCompanion.insert(
      title: 'Net Worth',
      sortOrder: const Value(1),
      seriesJson: jsonEncode(netWorthSeries),
    ));
  }
}
