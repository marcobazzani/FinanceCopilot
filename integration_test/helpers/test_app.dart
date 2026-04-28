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
  /// Set to false to start with a genuinely empty DB — no Default
  /// intermediary, no `_test_seed` account. The app's landing page WILL
  /// show; tests that opt in must dismiss it (tap "Start fresh").
  bool seedTestState = true,
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

  if (seedTestState) {
    // Seed a default intermediary (required by assets since schema v29).
    await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(
      name: 'Default',
    ));
    // Seed a dummy account so the landing page doesn't show (empty DB check).
    await db.into(db.accounts).insert(AccountsCompanion.insert(
      name: '_test_seed', sortOrder: const Value(999),
    ));
  }

  if (seed != null) {
    await seed(db);
  }

  final overrides = [
    // Override DB with in-memory instance
    databaseProvider.overrideWith((ref) => db),
    // Stub Google Drive sync -- no network in tests
    googleDriveSyncProvider.overrideWith((ref) => GoogleDriveSyncService()),
  ];

  if (!useRealServices) {
    // Stubbed mode: NoOp market prices and FX without an investing service.
    overrides.add(
      marketPriceServiceProvider.overrideWith((ref) {
        return NoOpMarketPriceService(db);
      }),
    );
    overrides.add(
      exchangeRateServiceProvider.overrideWith((ref) {
        return ExchangeRateService(db);
      }),
    );
  }
  // useRealServices=true: leave marketPriceServiceProvider and
  // exchangeRateServiceProvider at their defaults so the real
  // InvestingComService + investing-backed FX run with real HTTP.

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
  await settle(tester);
  return db;
}

/// Load a real fixture file from integration_test/fixtures/ via the asset
/// bundle. Writes to a temp file so the real CSV/XLSX parser is exercised
/// end-to-end. Returns a FilePreview with ALL rows (not just the 5+5
/// preview cap), so service-driven imports get the full dataset.
Future<FilePreview> parseFixture(AppDatabase db, String fixtureName, {int skipRows = 0}) async {
  final importer = ImportService(db);
  final data = await rootBundle.load('integration_test/fixtures/$fixtureName');
  final tmpDir = await Directory.systemTemp.createTemp('fc_test_');
  final tmpFile = File('${tmpDir.path}/$fixtureName');
  await tmpFile.writeAsBytes(data.buffer.asUint8List());
  try {
    final preview = await importer.parseFile(tmpFile.path, skipRows: skipRows);
    // parseFile caps preview rows; expand to all rows before the tmp file
    // is deleted so service-driven imports see the full dataset.
    if (preview.rows.length < preview.totalRows) {
      return await importer.getFullRows(preview);
    }
    return preview;
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

/// When true, settle helpers pump 3x more frames to accommodate slow CI
/// emulators (e.g. GitHub Actions Android). Pass via:
///   flutter test integration_test/ --dart-define=SLOW_TESTS=true
/// Default false keeps local runs fast.
const _slowTests = bool.fromEnvironment('SLOW_TESTS');

// 60fps frame cadence — 16ms keeps the on-screen window animating
// smoothly during settle/longSettle/pumpFor. With 50ms frames the
// progress indicators stuttered visibly on the macOS test driver.
const _frameMs = _slowTests ? 33 : 16;
const _settleMs = _slowTests ? 600 : 200;
const _longSettleMs = _slowTests ? 1500 : 500;

/// Pump frames at ~60fps to let the widget tree rebuild after
/// navigation/tap. Use instead of pumpAndSettle() which hangs on
/// stream providers.
///
/// Default total wall time: 200ms (~12 frames at 16ms). SLOW_TESTS:
/// 600ms.
Future<void> settle(WidgetTester tester) async {
  final n = _settleMs ~/ _frameMs;
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: _frameMs));
  }
}

/// Extra-long settle for heavy UI transitions (scroll + dropdown rebuild).
/// Default: 500ms (~32 frames at 16ms). SLOW_TESTS: 1.5s.
Future<void> longSettle(WidgetTester tester) async {
  final n = _longSettleMs ~/ _frameMs;
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: _frameMs));
  }
}

/// Long live-pump: yields the test clock to runAsync (so real Futures —
/// HTTP, timers, isolate work — can complete) AND pumps frames between
/// each yield, so the on-screen window keeps animating during long
/// network waits. Replaces `runAsync(Future.delayed(45s)) + longSettle`
/// which froze the UI for the entire delay.
Future<void> pumpFor(WidgetTester tester, Duration total) async {
  final end = DateTime.now().add(total);
  while (DateTime.now().isBefore(end)) {
    // Yield ~100ms of real time so HTTP/timers can fire,
    // then pump one frame so the spinner / chart / list animates.
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: _frameMs));
  }
}

/// Bounded smart scroll that never enters the over-scroll bounce
/// zone. Each iteration picks the largest vertically-scrollable
/// widget currently in the tree (so chart gesture-detector
/// scrollables with maxExtent==0 don't short-circuit, and the right
/// scrollable is re-resolved if a tab swap rebuilt the tree). Checks
/// the edge BEFORE each drag — no rubber-band stretch on the last
/// step.
///
/// `direction = -1` scrolls down (drag content up), `+1` scrolls up.
Future<void> smartScroll(
  WidgetTester tester,
  Finder _, {
  int direction = -1,
  double step = 500,
  int maxIter = 20,
}) async {
  for (var i = 0; i < maxIter; i++) {
    Element? bestEl;
    ScrollableState? bestState;
    double bestExtent = -1;
    for (final el in find.byType(Scrollable).evaluate()) {
      final state = el is StatefulElement ? el.state : null;
      if (state is! ScrollableState) continue;
      if (state.position.axis != Axis.vertical) continue;
      final extent = state.position.maxScrollExtent;
      if (extent > bestExtent) {
        bestExtent = extent;
        bestState = state;
        bestEl = el;
      }
    }
    if (bestEl == null || bestState == null || bestExtent <= 0) return;
    final pos = bestState.position;
    if (direction < 0 && pos.pixels >= pos.maxScrollExtent - 1) return;
    if (direction > 0 && pos.pixels <= pos.minScrollExtent + 1) return;
    await tester.drag(find.byElementPredicate((e) => e == bestEl), Offset(0, direction * step));
    await settle(tester);
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
  final intermediaries = await db.select(db.intermediaries).get();
  return db.into(db.assets).insert(AssetsCompanion.insert(
        name: name,
        assetType: AssetType.stockEtf,
        instrumentType: const Value(InstrumentType.etf),
        assetClass: const Value(AssetClass.equity),
        valuationMethod: ValuationMethod.marketPrice,
        intermediaryId: intermediaries.first.id,
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

/// Tap the "Default" intermediary radio in the Confirm step of asset
/// imports. Required since schema v29 (asset imports refuse to proceed
/// without an intermediary). Assumes pumpApp seeded the "Default" name.
Future<void> selectDefaultIntermediary(WidgetTester tester) async {
  final defaultRadio = find.text('Default');
  await tester.ensureVisible(defaultRadio.first);
  await settle(tester);
  await tester.tap(defaultRadio.first);
  await settle(tester);
}

/// Pick a number-format locale from the Confirm step dropdown (schema v30).
/// Needed when the import fixture uses a format different from the test app
/// locale — e.g. comma-decimal European data on an en_US test environment.
/// Pass the label shown in the menu, e.g. 'Italiano (it_IT)'.
Future<void> selectImportLocale(WidgetTester tester, String label) async {
  final dropdown = find.byType(DropdownButton<String?>);
  await tester.ensureVisible(dropdown.first);
  await settle(tester);
  await tester.tap(dropdown.first);
  await settle(tester);
  await tester.tap(find.text(label).last);
  await settle(tester);
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
