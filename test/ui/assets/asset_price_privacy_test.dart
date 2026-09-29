// A unit price is public market data only when it comes from a market: it is
// identical for every holder and privacy mode leaves it readable. A manually
// valued (event-driven) asset has no market price — its per-unit figure is the
// user's own revaluation divided by the units held, and for a single-unit
// holding it IS the position value — so privacy mode masks it like one.
//
// Each test asserts the masked and the readable half side by side, so a screen
// that simply blurred everything would fail just as one that leaked.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/assets/asset_detail_screen.dart';
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
  late Asset fund;
  late Asset house;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Asset> seedAsset({
    required String name,
    required ValuationMethod valuation,
    required double qty,
    required List<(DateTime, double)> closes,
  }) async {
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: '$name broker'));
    final id = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: name,
            assetType: valuation == ValuationMethod.marketPrice ? AssetType.stockEtf : AssetType.realEstate,
            valuationMethod: valuation,
            intermediaryId: broker,
          ),
        );
    final (firstDay, firstClose) = closes.first;
    await db
        .into(db.assetEvents)
        .insert(
          AssetEventsCompanion.insert(
            assetId: id,
            date: firstDay,
            valueDate: firstDay,
            type: EventType.buy,
            amount: qty * firstClose,
            quantity: Value(qty),
            price: Value(firstClose),
          ),
        );
    for (final (date, close) in closes) {
      await db.into(db.marketPrices).insert(MarketPricesCompanion.insert(assetId: id, date: date, closePrice: close, currency: 'EUR'));
    }
    return (db.select(db.assets)..where((a) => a.id.equals(id))).getSingle();
  }

  Future<void> seed() async {
    // A listed fund: 10 units, public close 121 today.
    fund = await seedAsset(
      name: 'Fund',
      valuation: ValuationMethod.marketPrice,
      qty: 10,
      closes: [(DateTime(2025, 1, 10), 100), (DateTime(2025, 6, 2), 110), (today, 121)],
    );
    // A house valued by hand: one unit, so its "price" is the whole position.
    house = await seedAsset(
      name: 'House',
      valuation: ValuationMethod.eventDriven,
      qty: 1,
      closes: [(DateTime(2025, 1, 5), 250000), (DateTime(2025, 6, 1), 260000)],
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
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
        child: MaterialApp(home: screen),
      ),
    );
    container = ProviderScope.containerOf(tester.element(find.byWidget(screen)));
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> setPrivate(WidgetTester tester, bool value) async {
    container.read(privacyModeProvider.notifier).state = value;
    await settle(tester);
  }

  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  /// The unit-price piece of an asset tile's `price × quantity` line.
  Finder unitPrice(String price) => find.byWidgetPredicate((w) {
    if (w is! Text) return false;
    final text = w.data ?? w.textSpan?.toPlainText() ?? '';
    return text.startsWith(price) && !text.contains('€');
  });

  testWidgets('asset list: a listed fund keeps its unit price readable, a manually valued house masks it; both quantities are masked', (
    tester,
  ) async {
    await seed();
    await pumpScreen(tester, const AssetsScreen());
    try {
      expect(unitPrice('121.00'), findsOneWidget);
      expect(unitPrice('260,000.00'), findsOneWidget);
      expect(masked(unitPrice('260,000.00')), isFalse, reason: 'nothing is masked before privacy is on');

      await setPrivate(tester, true);
      expect(masked(unitPrice('260,000.00')), isTrue, reason: 'one unit of a hand-valued house: the price is the position value');
      expect(masked(unitPrice('121.00')), isFalse, reason: 'a listed price is public market data');
      expect(masked(find.text('10')), isTrue, reason: 'units held are position size');
      expect(masked(find.text('1')), isTrue, reason: 'units held are position size');
      expect(masked(find.textContaining('×')), isFalse, reason: 'the separator between price and quantity carries nothing');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('asset detail: the price chart and execution price of a listed fund stay readable, a hand-valued house masks them', (
    tester,
  ) async {
    await seed();

    Finder cardTitled(String title) => find.ancestor(of: find.text(title), matching: find.byType(Card)).first;
    Finder inCard(String title, String text) => find.descendant(of: cardTitled(title), matching: find.text(text));
    final valueRange = find.textContaining(RegExp('€[0-9,.]+ – €'));

    Future<TestGesture> expandAndDrag(String title) async {
      await tester.tap(find.text(title));
      await settle(tester);
      final chart = find.descendant(of: cardTitled(title), matching: find.byType(LineChart));
      final center = tester.getCenter(chart);
      final gesture = await tester.startGesture(center - const Offset(120, 40), kind: PointerDeviceKind.mouse);
      await gesture.moveTo(center + const Offset(120, 40));
      await tester.pump();
      return gesture;
    }

    // ── Listed fund ──────────────────────────────────────────────────────
    await pumpScreen(tester, AssetDetailScreen(asset: fund));
    try {
      await setPrivate(tester, true);
      expect(inCard('Price', '€121.00'), findsOneWidget, reason: 'the price card shows the last close');
      expect(masked(inCard('Price', '€121.00')), isFalse, reason: 'a listed close is public market data');
      expect(masked(inCard('Asset', '€1,210')), isTrue, reason: 'the market value of the holding is position size');
      expect(masked(find.text('@ 100.00')), isFalse, reason: 'an execution price on a market is public');
      expect(masked(find.text('qty: 10.00')), isTrue, reason: 'units held are position size');

      final gesture = await expandAndDrag('Price');
      expect(valueRange, findsOneWidget);
      expect(masked(valueRange), isFalse, reason: 'a range of listed prices is market data');
      await gesture.up();
      await tester.pump();
    } finally {
      await unmount(tester);
    }

    // ── Hand-valued house ────────────────────────────────────────────────
    await pumpScreen(tester, AssetDetailScreen(asset: house));
    try {
      await setPrivate(tester, true);
      expect(inCard('Price', '€260,000.00'), findsOneWidget);
      expect(masked(inCard('Price', '€260,000.00')), isTrue, reason: 'the per-unit value of a one-unit house is the position value');
      expect(masked(find.text('@ 250000.00')), isTrue, reason: 'a hand-entered unit price reveals the position');
      expect(masked(find.text('Price')), isFalse, reason: 'the card title is a label');

      final gesture = await expandAndDrag('Price');
      expect(valueRange, findsOneWidget);
      expect(masked(valueRange), isTrue, reason: 'the range of a hand-valued price is position size');
      await gesture.up();
      await tester.pump();
    } finally {
      await unmount(tester);
    }
  });
}
