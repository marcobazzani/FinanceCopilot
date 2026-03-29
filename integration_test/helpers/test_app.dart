import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/main.dart';
import 'package:finance_copilot/services/exchange_rate_service.dart';
import 'package:finance_copilot/services/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';

/// No-op market price service that never makes HTTP calls.
class _NoOpMarketPriceService extends MarketPriceService {
  _NoOpMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(
      String ticker, String currency, DateTime from) async {
    return {};
  }

  @override
  Future<void> syncPrices({bool forceToday = false}) async {}
}

/// Pumps the full app with an in-memory database and stubbed services.
///
/// [seed] runs after DB creation to insert test data before the UI builds.
/// Returns the [AppDatabase] so tests can insert/query directly.
Future<AppDatabase> pumpApp(
  WidgetTester tester, {
  Future<void> Function(AppDatabase db)? seed,
}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());

  if (seed != null) {
    await seed(db);
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Point to in-memory DB, skip DbPickerScreen
        dbPathProvider.overrideWith((ref) => ':memory:'),
        databaseProvider.overrideWith((ref) => db),
        // Stub exchange rate service — uses DB but won't sync
        exchangeRateServiceProvider.overrideWith((ref) {
          return ExchangeRateService(db);
        }),
        // Stub market price service — no HTTP
        marketPriceServiceProvider.overrideWith((ref) {
          return _NoOpMarketPriceService(db);
        }),
      ],
      child: const FinanceCopilotApp(),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

/// Inserts a sample account and returns its id.
Future<int> seedAccount(AppDatabase db, {String name = 'Test Account'}) async {
  return db.into(db.accounts).insert(AccountsCompanion.insert(
        name: name,
        sortOrder: const Value(1),
      ));
}

/// Inserts a sample asset and returns its id.
Future<int> seedAsset(
  AppDatabase db, {
  String name = 'Test Asset',
  String? isin,
  String? ticker,
}) async {
  return db.into(db.assets).insert(AssetsCompanion.insert(
        name: name,
        assetType: AssetType.stockEtf,
        instrumentType: const Value(InstrumentType.etf),
        assetClass: const Value(AssetClass.equity),
        valuationMethod: ValuationMethod.marketPrice,
        isin: Value(isin),
        ticker: Value(ticker),
        sortOrder: const Value(1),
      ));
}

/// Inserts a sample income record and returns its id.
Future<int> seedIncome(AppDatabase db, {double amount = 1000.0}) async {
  return db.into(db.incomes).insert(IncomesCompanion.insert(
        date: DateTime(2025, 1, 15),
        amount: amount,
      ));
}
