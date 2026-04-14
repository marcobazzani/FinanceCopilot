import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/main.dart';
import 'package:finance_copilot/services/exchange_rate_service.dart';
import 'package:finance_copilot/services/google_drive_sync_service.dart';
import 'package:finance_copilot/services/import_service.dart';
import 'package:finance_copilot/services/market_price_service.dart';
import 'package:finance_copilot/ui/screens/import/import_screen.dart';
import 'package:flutter/material.dart';
import 'package:finance_copilot/services/providers/providers.dart';

/// No-op market price service that never makes HTTP calls.
class NoOpMarketPriceService extends MarketPriceService {
  NoOpMarketPriceService(super.db);

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
  bool useRealServices = false,
  bool createDbFile = true,
}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());

  // Create the DB file on disk so the landing page filesystem check passes.
  // (initState checks AppDatabase.dbFile().existsSync() before touching providers)
  // Set createDbFile=false for tests that need to simulate a missing DB (e.g. legacy migration).
  if (createDbFile) {
    final dbFile = await AppDatabase.dbFile();
    if (!dbFile.existsSync()) {
      await dbFile.parent.create(recursive: true);
      await dbFile.writeAsBytes([]);
    }
  }

  // Seed a dummy account so the landing page doesn't show (empty DB check)
  await db.into(db.accounts).insert(AccountsCompanion.insert(
    name: '_test_seed', sortOrder: const Value(999),
  ));

  if (seed != null) {
    await seed(db);
  }

  final overrides = [
    // Override DB with in-memory instance
    databaseProvider.overrideWith((ref) => db),
    // Stub exchange rate service -- uses DB but won't sync
    exchangeRateServiceProvider.overrideWith((ref) {
      return ExchangeRateService(db);
    }),
    // Stub Google Drive sync -- no network in tests
    googleDriveSyncProvider.overrideWith((ref) => GoogleDriveSyncService()),
  ];

  if (!useRealServices) {
    overrides.add(
      marketPriceServiceProvider.overrideWith((ref) {
        return NoOpMarketPriceService(db);
      }),
    );
  }

  // Suppress non-logic Flutter errors in integration tests:
  // - KeyUpEvent: keyboard state leak between tests in same process
  // - overflowed: RenderFlex overflow on small CI screens (not a logic error)
  final origHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    final msg = details.toString();
    if (msg.contains('KeyUpEvent') || msg.contains('overflowed')) return;
    origHandler?.call(details);
  };

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const FinanceCopilotApp(),
    ),
  );
  // Pump frames to build the initial UI.
  // Don't use pumpAndSettle — stream providers never settle.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return db;
}

/// Load a real fixture file from integration_test/fixtures/ via the asset bundle.
/// Writes to a temp file so the real CSV/XLSX parser is exercised end-to-end.
Future<FilePreview> parseFixture(AppDatabase db, String fixtureName, {int skipRows = 0}) async {
  final importer = ImportService(db);
  final data = await rootBundle.load('integration_test/fixtures/$fixtureName');
  final tmpDir = await Directory.systemTemp.createTemp('fc_test_');
  final tmpFile = File('${tmpDir.path}/$fixtureName');
  await tmpFile.writeAsBytes(data.buffer.asUint8List());
  try {
    return await importer.parseFile(tmpFile.path, skipRows: skipRows);
  } finally {
    await tmpDir.delete(recursive: true);
  }
}


/// Navigate to ImportScreen with a pre-parsed preview and optional target.
/// This tests both the file parser (via parseFixture) and the full UI import flow.
///
/// [accountName] resolves to the matching account row's id and is passed as
/// preselectedAccountId. This is required for transaction imports because the
/// account selector lives in step 1 (above the file picker) — tests that pre-load
/// a preview can't easily interact with that selector after the fact.
Future<void> pushImportScreen(
  WidgetTester tester, {
  required FilePreview preview,
  ImportTarget? target,
  String? accountName,
  AppDatabase? db,
}) async {
  int? accountId;
  if (accountName != null) {
    final database = db ?? AppDatabase.forTesting(NativeDatabase.memory());
    final acc = await (database.select(database.accounts)
          ..where((a) => a.name.equals(accountName)))
        .getSingleOrNull();
    accountId = acc?.id;
  }
  final context = tester.element(find.byType(Navigator).first);
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ImportScreen(
        testPreview: preview,
        preselectedTarget: target,
        preselectedAccountId: accountId,
      ),
    ),
  );
  await settle(tester);
}

/// Pump multiple frames to let the widget tree rebuild after navigation/tap.
/// Use instead of pumpAndSettle() which hangs on stream providers.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Wait for real async work (HTTP calls) to complete, then pump to render results.
/// Use after triggering price sync, import, or any network operation.
Future<void> waitForNetwork(WidgetTester tester, {int seconds = 10}) async {
  await tester.runAsync(() => Future.delayed(Duration(seconds: seconds)));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

// ── Seed helpers ──────────────────────────────────────

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
  String? exchange,
  String? currency,
}) async {
  return db.into(db.assets).insert(AssetsCompanion.insert(
        name: name,
        assetType: AssetType.stockEtf,
        instrumentType: const Value(InstrumentType.etf),
        assetClass: const Value(AssetClass.equity),
        valuationMethod: ValuationMethod.marketPrice,
        isin: Value(isin),
        ticker: Value(ticker),
        exchange: Value(exchange),
        currency: Value(currency ?? 'EUR'),
        sortOrder: const Value(1),
      ));
}

/// Inserts a buy event for an asset.
Future<int> seedBuyEvent(
  AppDatabase db, {
  required int assetId,
  required DateTime date,
  required double amount,
  double? quantity,
  double? price,
  String currency = 'EUR',
}) async {
  return db.into(db.assetEvents).insert(AssetEventsCompanion.insert(
        assetId: assetId,
        date: date,
        valueDate: date,
        type: EventType.buy,
        amount: amount,
        quantity: Value(quantity),
        price: Value(price),
        currency: Value(currency),
      ));
}

/// Inserts a market price for an asset.
Future<void> seedPrice(
  AppDatabase db, {
  required int assetId,
  required DateTime date,
  required double price,
  String currency = 'EUR',
}) async {
  await db.into(db.marketPrices).insert(MarketPricesCompanion.insert(
        assetId: assetId,
        date: date,
        closePrice: price,
        currency: currency,
      ));
}

/// Inserts a sample income record and returns its id.
Future<int> seedIncome(AppDatabase db, {double amount = 1000.0}) async {
  return db.into(db.incomes).insert(IncomesCompanion.insert(
        date: DateTime(2025, 1, 15),
        valueDate: DateTime(2025, 1, 15),
        amount: amount,
      ));
}

/// Tap Buy/Sell ChoiceChips for asset type-from-column mapping.
/// First row's value → Buy, second row's value → Sell.
Future<void> tapBuySellChips(WidgetTester tester) async {
  final buyChips = find.widgetWithText(ChoiceChip, 'Buy');
  final sellChips = find.widgetWithText(ChoiceChip, 'Sell');
  if (buyChips.evaluate().isNotEmpty) {
    await tester.ensureVisible(buyChips.first);
    await settle(tester);
    await tester.tap(buyChips.first);
    await settle(tester);
  }
  if (sellChips.evaluate().length >= 2) {
    await tester.ensureVisible(sellChips.last);
    await settle(tester);
    await tester.tap(sellChips.last);
    await settle(tester);
  }
}

/// Creates a FilePreview from raw CSV content (for import tests).
FilePreview makePreview(String csv) {
  final lines = csv.trim().split('\n');
  final columns = lines.first.split(',');
  final rows = lines.skip(1).map((line) {
    final values = line.split(',');
    final map = <String, String>{};
    for (var i = 0; i < columns.length && i < values.length; i++) {
      map[columns[i]] = values[i];
    }
    return map;
  }).toList();
  return FilePreview(
    columns: columns,
    rows: rows,
    totalRows: rows.length,
  );
}
