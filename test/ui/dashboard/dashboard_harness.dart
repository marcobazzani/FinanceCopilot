// Shared set-up for the dashboard widget tests: an in-memory database with a
// small portfolio and the full DashboardScreen pumped on top of it, offline.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart';

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

class DashboardHarness {
  static final today = DateTime(2026, 3, 10);

  late AppDatabase db;
  late ProviderContainer container;

  /// Call from `setUp`. The bundle caches the default-charts JSON as a Future
  /// created in the first test's fake-async zone; a later test awaiting it
  /// would never resume, hence the clear.
  void open() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    rootBundle.clear();
  }

  Future<void> close() => db.close();

  /// 15,000 cash; a listed fund (10 units, TER 0.20%) closing at 121 today,
  /// below its March high so no all-time-high celebration fires; a 3,000
  /// salary every month of 2025 and of January–February 2026.
  Future<void> seed() async {
    final acct = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: acct,
            operationDate: DateTime(2024, 12, 1),
            valueDate: DateTime(2024, 12, 1),
            amount: 15000,
            balanceAfter: const Value(15000),
            description: const Value('Opening'),
          ),
        );
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    final fund = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'Fund',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: broker,
            ter: const Value(0.2),
          ),
        );
    await db
        .into(db.assetEvents)
        .insert(
          AssetEventsCompanion.insert(
            assetId: fund,
            date: DateTime(2024, 12, 2),
            valueDate: DateTime(2024, 12, 2),
            type: EventType.buy,
            amount: 1000,
            quantity: const Value(10),
            price: const Value(100),
          ),
        );
    for (final (date, close) in [(DateTime(2024, 12, 2), 100.0), (DateTime(2026, 3, 2), 125.0), (DateTime(2026, 3, 9), 120.0), (today, 121.0)]) {
      await db.into(db.marketPrices).insert(MarketPricesCompanion.insert(assetId: fund, date: date, closePrice: close, currency: 'EUR'));
    }
    for (final (year, months) in [(2025, 12), (2026, 2)]) {
      for (var m = 1; m <= months; m++) {
        final d = DateTime(year, m, 15);
        await db.into(db.incomes).insert(IncomesCompanion.insert(date: d, valueDate: d, amount: 3000));
      }
    }
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pump(
    WidgetTester tester, {
    String language = 'en',
    String locale = 'en_US',
    bool isPrivate = false,
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          nowProvider.overrideWithValue(() => today.add(const Duration(hours: 12))),
          marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
          privacyModeProvider.overrideWith((ref) => isPrivate),
          portableLanguageProvider.overrideWith((ref) => language),
          appLocaleProvider.overrideWith((ref) => Stream.value(locale)),
          ...overrides,
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    container = ProviderScope.containerOf(tester.element(find.byType(DashboardScreen)));
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(Tab, label));
    await settle(tester);
  }

  /// The KPI card showing [kpiName] on the Health tab.
  Finder kpiCard(String kpiName) => find.ancestor(of: find.text(kpiName), matching: find.byType(Card)).first;

  Future<void> openInfo(WidgetTester tester, String kpiName) async {
    final info = find.descendant(of: kpiCard(kpiName), matching: find.byIcon(Icons.info_outline));
    await tester.ensureVisible(info);
    await settle(tester);
    await tester.tap(info);
    await settle(tester);
  }

  /// Every text in the open dialog, one widget per line.
  String dialogText(WidgetTester tester) => [
    for (final w in tester.widgetList(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byWidgetPredicate((w) => w is SelectableText || w is Text),
      ),
    ))
      if (w is SelectableText) (w.data ?? w.textSpan!.toPlainText()) else if (w is Text) (w.data ?? w.textSpan?.toPlainText() ?? ''),
  ].join('\n');

  Future<void> tapDialogButton(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byWidgetPredicate((w) => (w is TextButton || w is FilledButton) && _label(w) == label),
      ),
    );
    await settle(tester);
  }

  static String? _label(Widget button) {
    final child = button is TextButton ? button.child : (button as FilledButton).child;
    return child is Text ? child.data : null;
  }
}
