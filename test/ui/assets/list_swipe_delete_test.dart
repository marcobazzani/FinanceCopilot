// Swipe-to-delete on the asset lists: a swiped asset (Assets screen) or asset
// event (asset detail) asks the confirmation its own trashcan asks, Cancel
// keeps it, Delete removes it through the same service call — the asset with
// its events, snapshots and prices; the event with its revalue prices
// resynced.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/domain/asset_event_service.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/assets/asset_detail_screen.dart';
import 'package:finance_copilot/ui/screens/assets/assets_screen.dart';

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};

  @override
  Future<void> syncPrices({bool forceToday = false}) async {}
}

void main() {
  const s = AppStrings.en;
  final today = DateTime(2026, 3, 10);
  late AppDatabase db;
  late int broker;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          nowProvider.overrideWithValue(() => today.add(const Duration(hours: 12))),
          marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(home: home),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<int> seedAsset(String name) => db
      .into(db.assets)
      .insert(
        AssetsCompanion.insert(name: name, assetType: AssetType.stockEtf, valuationMethod: ValuationMethod.marketPrice, intermediaryId: broker),
      );

  Future<int> seedEvent(int assetId, EventType type, DateTime day, double amount, {double? quantity, double? price}) => db
      .into(db.assetEvents)
      .insert(
        AssetEventsCompanion.insert(
          assetId: assetId,
          date: day,
          valueDate: day,
          type: type,
          amount: amount,
          quantity: Value(quantity),
          price: Value(price),
        ),
      );

  Future<void> swipe(WidgetTester tester, Finder row) async {
    await tester.drag(row, const Offset(-900, 0));
    await settle(tester);
  }

  void expectConfirm(WidgetTester tester, {required String title, required String content}) {
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget, reason: 'a swipe asks first');
    final alert = tester.widget<AlertDialog>(dialog);
    expect((alert.title! as Text).data, title);
    expect((alert.content! as Text).data, content);
    final confirm = tester.widget<FilledButton>(find.descendant(of: dialog, matching: find.widgetWithText(FilledButton, s.delete)));
    expect(confirm.style?.backgroundColor?.resolve({}), Colors.red);
  }

  testWidgets('assets: a swiped asset asks like its trashcan; Cancel keeps it, Delete removes it with its events and prices', (tester) async {
    final etf = await seedAsset('World ETF');
    final bond = await seedAsset('Bond fund');
    await seedEvent(etf, EventType.buy, DateTime(2025, 1, 10), 1000, quantity: 10, price: 100);
    await seedEvent(bond, EventType.buy, DateTime(2025, 1, 10), 500, quantity: 5, price: 100);
    await db.into(db.marketPrices).insert(MarketPricesCompanion.insert(assetId: etf, date: today, closePrice: 110, currency: 'EUR'));
    await pump(tester, const AssetsScreen());
    try {
      await swipe(tester, find.text('World ETF'));
      expectConfirm(tester, title: s.deleteAssetTitle, content: s.deleteAssetConfirm('World ETF'));
      await tester.tap(find.widgetWithText(TextButton, s.cancel));
      await settle(tester);
      expect(find.text('World ETF'), findsOneWidget, reason: 'the row comes back');
      expect(await db.select(db.assets).get(), hasLength(2));

      await swipe(tester, find.text('World ETF'));
      await tester.tap(find.widgetWithText(FilledButton, s.delete));
      await settle(tester);
      expect((await db.select(db.assets).get()).map((a) => a.name), ['Bond fund']);
      expect((await db.select(db.assetEvents).get()).map((e) => e.assetId), [bond]);
      expect(await db.select(db.marketPrices).get(), isEmpty);
      expect(find.text('World ETF'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('assets: a long press still starts the multi-selection', (tester) async {
    await seedAsset('World ETF');
    await pump(tester, const AssetsScreen());
    try {
      await tester.longPress(find.text('World ETF'));
      await settle(tester);
      expect(find.text(s.nSelected(1)), findsOneWidget);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('asset events: a swiped event asks like its trashcan; Cancel keeps it, Delete removes it and resyncs revalue prices', (
    tester,
  ) async {
    final id = await seedAsset('House');
    await seedEvent(id, EventType.buy, DateTime(2025, 1, 10), 1000, quantity: 1);
    await AssetEventService(db).create(assetId: id, date: DateTime(2025, 6, 1), type: EventType.revalue, amount: 1200, currency: 'EUR');
    final asset = await (db.select(db.assets)..where((a) => a.id.equals(id))).getSingle();
    expect(await db.select(db.marketPrices).get(), isNotEmpty, reason: 'the revalue materialised a price');
    await pump(tester, AssetDetailScreen(asset: asset));
    try {
      final revalueRow = find.text('revalue');
      await swipe(tester, revalueRow);
      expectConfirm(tester, title: s.deleteEventTitle, content: s.cannotBeUndone);
      await tester.tap(find.widgetWithText(TextButton, s.cancel));
      await settle(tester);
      expect(revalueRow, findsOneWidget);
      expect(await db.select(db.assetEvents).get(), hasLength(2));

      await swipe(tester, revalueRow);
      await tester.tap(find.widgetWithText(FilledButton, s.delete));
      await settle(tester);
      expect((await db.select(db.assetEvents).get()).map((e) => e.type), [EventType.buy]);
      expect(await db.select(db.marketPrices).get(), isEmpty, reason: 'the service resynced the revalue prices');
      expect(revalueRow, findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await unmount(tester);
    }
  });
}
