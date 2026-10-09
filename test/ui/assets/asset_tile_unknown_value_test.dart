// Asset list: an asset whose value cannot be computed — no price at all, or a
// foreign price without an exchange rate — shows a dash where the market value
// goes, keeps the "no market data" badge, and has no gain line. Its cost basis
// used to sit in the market-value slot, unlabeled, reading as a value.
import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/assets/assets_screen.dart';

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

void main() {
  final today = DateTime(2026, 3, 10);
  late AppDatabase db;
  late ProviderContainer container;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> seedAsset(String name, {String currency = 'EUR', double? buyPrice, List<double> closes = const []}) async {
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: '$name broker'));
    final id = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: name,
            currency: Value(currency),
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
            date: DateTime(2025, 1, 10),
            valueDate: DateTime(2025, 1, 10),
            type: EventType.buy,
            amount: 1000,
            quantity: const Value(10),
            price: Value(buyPrice),
          ),
        );
    for (final close in closes) {
      await db.into(db.marketPrices).insert(MarketPricesCompanion.insert(assetId: id, date: today, closePrice: close, currency: currency));
    }
    return id;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpScreen(WidgetTester tester, {List<Override> overrides = const []}) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const screen = AssetsScreen();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          nowProvider.overrideWithValue(() => today.add(const Duration(hours: 12))),
          marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          privacyModeProvider.overrideWith((ref) => false),
          ...overrides,
        ],
        child: const MaterialApp(home: screen),
      ),
    );
    container = ProviderScope.containerOf(tester.element(find.byWidget(screen)));
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  testWidgets('no price at all, or no exchange rate: a dash and the no-market-data badge, never the cost basis or a gain', (tester) async {
    // 10 units bought for 1,000 with no unit price and no close on record.
    final unpriced = await seedAsset('Unpriced');
    // 10 USD units closing at 110 today, but no USD→EUR rate stored.
    final foreign = await seedAsset('Foreign', currency: 'USD', buyPrice: 100, closes: [110]);
    // A listed fund: 10 units at 121 today.
    final fund = await seedAsset('Fund', buyPrice: 100, closes: [121]);
    await pumpScreen(tester);
    try {
      Finder inTile(int id, Finder f) => find.descendant(of: find.byKey(ValueKey(id)), matching: f);

      for (final (id, cost) in [(unpriced, '1,000.00 EUR'), (foreign, '1,000.00 USD')]) {
        expect(inTile(id, find.text('—')), findsOneWidget, reason: 'the value is unknown');
        expect(inTile(id, find.text(cost)), findsNothing, reason: 'the cost basis is not a market value');
        expect(inTile(id, find.text('No market data')), findsOneWidget, reason: 'why the value is missing');
        expect(inTile(id, find.textContaining('▲')), findsNothing, reason: 'no gain against an unknown value');
        expect(inTile(id, find.textContaining('▼')), findsNothing, reason: 'no loss against an unknown value');
      }

      // A priced asset keeps its value and its gain.
      expect(inTile(fund, find.text('1,210.00 €')), findsOneWidget);
      expect(inTile(fund, find.textContaining('▲')), findsOneWidget);
      expect(inTile(fund, find.text('No market data')), findsNothing);

      // Privacy: the known value is position size, the dash reveals nothing.
      container.read(privacyModeProvider.notifier).state = true;
      await settle(tester);
      expect(masked(inTile(fund, find.text('1,210.00 €'))), isTrue);
      expect(masked(inTile(unpriced, find.text('—'))), isFalse, reason: 'an unknown value carries no position size');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('while the values load: a dash, but no "no market data" badge yet', (tester) async {
    final fund = await seedAsset('Fund', buyPrice: 100, closes: [121]);
    await pumpScreen(tester, overrides: [assetMarketValuesProvider.overrideWith((ref) => Completer<Map<int, double>>().future)]);
    try {
      final tile = find.byKey(ValueKey(fund));
      expect(find.descendant(of: tile, matching: find.text('—')), findsOneWidget);
      expect(
        find.descendant(of: tile, matching: find.text('No market data')),
        findsNothing,
        reason: 'not missing, still loading',
      );
      expect(
        find.descendant(of: tile, matching: find.text('1,000.00 EUR')),
        findsNothing,
        reason: 'never the cost basis',
      );
    } finally {
      await unmount(tester);
    }
  });
}
