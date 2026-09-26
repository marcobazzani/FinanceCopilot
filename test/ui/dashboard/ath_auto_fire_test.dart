// The dashboard's ATH auto-fire, driven end-to-end through the real
// DashboardScreen on a fixed clock and a fixed price history.
//
// This path used to be exercised only by the live-data integration
// walkthrough, where it ran or not depending on whether that day's market
// close happened to be a new high for the fixture portfolio (never on a
// weekend). These tests make the outcome depend on the data alone.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

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

const _athTitle = 'NEW ALL-TIME HIGH!';

void main() {
  // A Tuesday: "today" has its own close, as on any trading day.
  final today = DateTime(2026, 3, 10);
  late AppDatabase db;
  late ProviderContainer container;

  setUpAll(() async => initializeDateFormatting('en'));

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// One position of 10 units bought at 100 three days ago, closing at
  /// [closes] (oldest first, the last one is today's).
  Future<void> seedPosition(List<double> closes) async {
    final intermediaryId = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    final assetId = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'Fund',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: intermediaryId,
          ),
        );
    final firstDay = today.subtract(Duration(days: closes.length - 1));
    await db
        .into(db.assetEvents)
        .insert(
          AssetEventsCompanion.insert(
            assetId: assetId,
            date: firstDay,
            valueDate: firstDay,
            type: EventType.buy,
            amount: 1000,
            quantity: const Value(10),
            price: const Value(100),
          ),
        );
    for (var i = 0; i < closes.length; i++) {
      await db
          .into(db.marketPrices)
          .insert(
            MarketPricesCompanion.insert(
              assetId: assetId,
              date: firstDay.add(Duration(days: i)),
              closePrice: closes[i],
              currency: 'EUR',
            ),
          );
    }
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpDashboard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          nowProvider.overrideWithValue(() => today.add(const Duration(hours: 12))),
          marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    container = ProviderScope.containerOf(tester.element(find.byType(DashboardScreen)));
    await settle(tester);
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(Tab, label));
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('a close above every prior value fires once the History tab is opened, then never again this session', (
    tester,
  ) async {
    await seedPosition([100, 105, 103, 110]);
    await pumpDashboard(tester);
    try {
      // Startup gate: the dashboard opens on Health, and a new high must not
      // ambush the user before they look at the history.
      expect(find.text(_athTitle), findsNothing);
      expect(container.read(athFiredThisSessionProvider), isEmpty);

      // Arriving on History is enough — no other rebuild (price refresh,
      // data change) may be needed for the scan to run.
      await openTab(tester, 'History');
      // 1100 today > 1050 prior max for the market value, and the gain (100)
      // beats its prior best (50): all three in-scope series celebrate.
      expect(find.text(_athTitle), findsNWidgets(3));
      expect(container.read(athFiredThisSessionProvider), {'Total Assets', 'Portfolio', 'Performance'});

      // Cards expire; coming back to History later in the session is silent.
      await tester.pump(const Duration(seconds: 10));
      expect(find.text(_athTitle), findsNothing);
      await openTab(tester, 'Health');
      await openTab(tester, 'History');
      expect(find.text(_athTitle), findsNothing);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('no celebration when today does not break the prior high', (tester) async {
    await seedPosition([100, 105, 103, 104]);
    await pumpDashboard(tester);
    try {
      await openTab(tester, 'History');
      expect(find.text(_athTitle), findsNothing);
      expect(container.read(athFiredThisSessionProvider), isEmpty);
    } finally {
      await unmount(tester);
    }
  });
}
