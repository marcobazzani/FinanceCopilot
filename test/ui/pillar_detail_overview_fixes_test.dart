// Pillar detail overview:
//  * opened on its own — nothing else on screen listening to the asset
//    providers — it loads its rows (it used to await a provider no one
//    listened to, which Riverpod 3 pauses: an endless spinner);
//  * no held asset, or a filter hiding every one, shows the shared empty state
//    with the right message, not "No pillars yet";
//  * the asset list is the screen's scrollable for pull-to-refresh.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/app_actions_controller.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/pillars/pillar_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/pillars/pillar_detail_screen.dart';
import 'package:finance_copilot/ui/widgets/empty_state.dart';

class _OfflinePrices extends MarketPriceService {
  _OfflinePrices(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

void main() {
  const s = AppStrings.en;
  final today = DateTime(2026, 3, 10);
  late AppDatabase db;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    rootBundle.clear();
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// 10 units of a listed fund closing at 110.
  Future<int> seedFund() async {
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    final id = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'World fund',
            ticker: const Value('WRLD'),
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: broker,
          ),
        );
    await db
        .into(db.assetEvents)
        .insert(
          AssetEventsCompanion.insert(
            assetId: id,
            date: DateTime(2025, 1, 2),
            valueDate: DateTime(2025, 1, 2),
            type: EventType.buy,
            amount: 1000,
            quantity: const Value(10),
            price: const Value(100),
          ),
        );
    for (final (date, close) in [(DateTime(2025, 1, 2), 100.0), (today, 110.0)]) {
      await db.into(db.marketPrices).insert(MarketPricesCompanion.insert(assetId: id, date: date, closePrice: close, currency: 'EUR'));
    }
    return id;
  }

  /// The pillar detail screen alone, on the real providers.
  Future<void> pumpAlone(WidgetTester tester, String pillarId, {List<Override> overrides = const []}) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          nowProvider.overrideWithValue(() => today.add(const Duration(hours: 12))),
          marketPriceServiceProvider.overrideWithValue(_OfflinePrices(db)),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          privacyModeProvider.overrideWith((ref) => false),
          ...overrides,
        ],
        child: MaterialApp(home: PillarDetailScreen(pillarId: pillarId)),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('opened on its own, the overview loads its assets', (tester) async {
    final fund = await seedFund();
    final pillarId = await PillarService(db).create(name: 'Retirement');
    await pumpAlone(tester, pillarId);
    try {
      expect(find.byKey(ValueKey('pillar-row-$fund')), findsOneWidget, reason: 'the held fund gets its slider row');
      expect(find.byType(CircularProgressIndicator), findsNothing, reason: 'no endless spinner');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('no held asset: the shared empty state says there are no assets, not that there are no pillars', (tester) async {
    final pillarId = await PillarService(db).create(name: 'Retirement');
    await pumpAlone(tester, pillarId);
    try {
      final empty = find.byType(EmptyState);
      expect(empty, findsOneWidget);
      expect(find.descendant(of: empty, matching: find.text(s.noAssetsYet)), findsOneWidget);
      expect(find.text(s.pillarsEmptyTitle), findsNothing);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a search matching no asset: the shared empty state says nothing matched', (tester) async {
    await seedFund();
    final pillarId = await PillarService(db).create(name: 'Retirement');
    await pumpAlone(tester, pillarId);
    try {
      await tester.enterText(find.widgetWithText(TextField, s.pillarSearchAssets), 'bonds');
      await settle(tester);
      final empty = find.byType(EmptyState);
      expect(empty, findsOneWidget);
      expect(find.descendant(of: empty, matching: find.text(s.noResultsFound)), findsOneWidget);
      expect(find.text(s.pillarsEmptyTitle), findsNothing);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('the asset list is always scrollable and a pull refreshes', (tester) async {
    final fund = await seedFund();
    final pillarId = await PillarService(db).create(name: 'Retirement');
    var refreshes = 0;
    final registry = GlobalActionsRegistry(
      manualRefresh: () async => refreshes++,
      showImportExportDialog: (_) async {},
      showSettingsDialog: (_) async {},
      openImportFiles: (_) async {},
      openSupport: (_) async {},
      retryNetwork: () async {},
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await pumpAlone(tester, pillarId, overrides: [globalActionsRegistryProvider.overrideWith((ref) => registry)]);
      final row = find.byKey(ValueKey('pillar-row-$fund'));
      expect(row, findsOneWidget);
      final list = find.ancestor(of: row, matching: find.byType(Scrollable)).first;
      expect(tester.widget<Scrollable>(list).physics, isA<AlwaysScrollableScrollPhysics>());
      expect(find.ancestor(of: row, matching: find.byType(RefreshIndicator)), findsOneWidget);

      // Grab the row by its name (not its slider) and pull the list down.
      await tester.fling(find.descendant(of: row, matching: find.textContaining('WRLD')).first, const Offset(0, 1000), 1000);
      await settle(tester);
      expect(refreshes, 1);
    } finally {
      await unmount(tester);
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
