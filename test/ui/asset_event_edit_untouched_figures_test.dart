// AssetEventEditScreen never rewrites a figure the user did not touch: an
// imported event's quantity, price, amount, commission and FX rate keep
// every digit through an edit that only changes the notes. The form used to
// pre-fill them rounded (4 decimals for quantity/price/rate, 2 for amounts)
// and to recompute the amount as quantity × price on every save, so opening
// an imported event to add a note silently changed its figures.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/market/exchange_rate_service.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/assets/asset_event_edit_screen.dart';

class _NoRates extends ExchangeRateService {
  _NoRates(super.db);

  @override
  Future<double?> getRate(String from, String to, DateTime date) async => null;
}

class _NoPrices extends MarketPriceService {
  _NoPrices(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};

  @override
  Future<double?> getPrice(int assetId, DateTime date) async => null;
}

/// Opens [screen] on a push once the locale and base currency are loaded, as
/// in the app (the shell watches them): the screen reads them in initState.
class _Launcher extends ConsumerWidget {
  const _Launcher(this.screen);
  final Widget Function() screen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(appLocaleProvider).hasValue && ref.watch(baseCurrencyProvider).hasValue;
    return Scaffold(
      body: Center(
        child: ready
            ? TextButton(
                key: const Key('open'),
                onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen())),
                child: const Text('open'),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

void main() {
  late AppDatabase db;
  late Asset asset;

  setUpAll(() async => initializeDateFormatting());
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    final id = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'US Fund',
            assetType: AssetType.stockEtf,
            instrumentType: const Value(InstrumentType.etf),
            assetClass: const Value(AssetClass.equity),
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: broker,
            currency: const Value('USD'),
          ),
        );
    asset = await (db.select(db.assets)..where((a) => a.id.equals(id))).getSingle();
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<AssetEvent> insertEvent(AssetEventsCompanion event) async {
    final id = await db.into(db.assetEvents).insert(event);
    return (db.select(db.assetEvents)..where((e) => e.id.equals(id))).getSingle();
  }

  Future<AssetEvent> reload(AssetEvent event) => (db.select(db.assetEvents)..where((e) => e.id.equals(event.id))).getSingle();

  Future<void> open(WidgetTester tester, AssetEvent event) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('it_IT')),
          baseCurrencyProvider.overrideWith((ref) => Stream.value('EUR')),
          privacyModeProvider.overrideWith((ref) => false),
          marketPriceServiceProvider.overrideWithValue(_NoPrices(db)),
          exchangeRateServiceProvider.overrideWithValue(_NoRates(db)),
        ],
        child: MaterialApp(
          home: _Launcher(() => AssetEventEditScreen(asset: asset, event: event)),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('open')));
    await settle(tester);
    expect(find.byType(AssetEventEditScreen), findsOneWidget);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);
  String text(WidgetTester tester, String label) => tester.widget<TextFormField>(field(label)).controller!.text;

  Future<void> saveWithNote(WidgetTester tester) async {
    await tester.enterText(field('Notes'), 'checked');
    await tester.tap(find.widgetWithText(FilledButton, 'Save Changes'));
    await settle(tester);
    expect(find.byType(AssetEventEditScreen), findsNothing, reason: 'saved without a validation error');
  }

  testWidgets('a notes-only edit keeps every figure of an imported buy', (tester) async {
    // The broker's amount is not quantity × price (316.17396...): it is what
    // was actually paid, and it is what the event must keep.
    final event = await insertEvent(
      AssetEventsCompanion.insert(
        assetId: asset.id,
        date: DateTime(2024, 3, 13),
        valueDate: DateTime(2024, 3, 15),
        type: EventType.buy,
        amount: 316.17,
        quantity: const Value(3.123456),
        price: const Value(101.23456),
        currency: const Value('USD'),
        exchangeRate: const Value(1.08765),
        // Quoted when the base currency was another one: an untouched rate
        // keeps the base it was quoted against.
        exchangeRateBase: const Value('CHF'),
        commission: const Value(1.2345),
      ),
    );
    await open(tester, event);
    try {
      expect(text(tester, 'Quantity *'), '3,123456', reason: 'pre-filled with every digit, in the it_IT spelling');
      expect(text(tester, 'Price (USD) *'), '101,23456');
      await saveWithNote(tester);

      final saved = await reload(event);
      expect(saved.notes, 'checked');
      expect(saved.quantity, 3.123456);
      expect(saved.price, 101.23456);
      expect(saved.amount, 316.17, reason: 'not recomputed as quantity × price');
      expect(saved.commission, 1.2345);
      expect(saved.exchangeRate, 1.08765);
      expect(saved.exchangeRateBase, 'CHF');
      expect(saved.currency, 'USD');
      expect(saved.valueDate, DateTime(2024, 3, 15));
      expect(saved.date, DateTime(2024, 3, 13));
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a figure the locale spells exactly keeps its usual pre-fill', (tester) async {
    final event = await insertEvent(
      AssetEventsCompanion.insert(
        assetId: asset.id,
        date: DateTime(2024, 3, 15),
        valueDate: DateTime(2024, 3, 15),
        type: EventType.buy,
        amount: 1000,
        quantity: const Value(10),
        price: const Value(100),
        currency: const Value('USD'),
      ),
    );
    await open(tester, event);
    try {
      expect(text(tester, 'Quantity *'), '10,0000');
      expect(text(tester, 'Price (USD) *'), '100,0000');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('changing the quantity still recomputes the amount', (tester) async {
    final event = await insertEvent(
      AssetEventsCompanion.insert(
        assetId: asset.id,
        date: DateTime(2024, 3, 15),
        valueDate: DateTime(2024, 3, 15),
        type: EventType.buy,
        amount: 316.17,
        quantity: const Value(3.123456),
        price: const Value(101.23456),
        currency: const Value('USD'),
        exchangeRate: const Value(1.08765),
        exchangeRateBase: const Value('CHF'),
      ),
    );
    await open(tester, event);
    try {
      await tester.enterText(field('Quantity *'), '4');
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save Changes'));
      await settle(tester);

      final saved = await reload(event);
      expect(saved.quantity, 4);
      expect(saved.price, 101.23456);
      expect(saved.amount, closeTo(4 * 101.23456, 1e-9));
      expect(saved.exchangeRate, 1.08765, reason: 'the rate was not touched');
      expect(saved.exchangeRateBase, 'CHF');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a typed new rate is stamped with the base it is quoted against', (tester) async {
    final event = await insertEvent(
      AssetEventsCompanion.insert(
        assetId: asset.id,
        date: DateTime(2024, 3, 15),
        valueDate: DateTime(2024, 3, 15),
        type: EventType.buy,
        amount: 1000,
        quantity: const Value(10),
        price: const Value(100),
        currency: const Value('USD'),
        exchangeRate: const Value(1.08765),
        exchangeRateBase: const Value('CHF'),
      ),
    );
    await open(tester, event);
    try {
      await tester.enterText(field('Rate EUR/USD'), '1,1');
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save Changes'));
      await settle(tester);

      final saved = await reload(event);
      expect(saved.exchangeRate, 1.1);
      expect(saved.exchangeRateBase, 'EUR', reason: 'the label quotes the rate against the current base');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a notes-only edit keeps every digit of a revaluation amount', (tester) async {
    final event = await insertEvent(
      AssetEventsCompanion.insert(
        assetId: asset.id,
        date: DateTime(2024, 3, 15),
        valueDate: DateTime(2024, 3, 15),
        type: EventType.revalue,
        amount: 12345.678,
        currency: const Value('USD'),
      ),
    );
    await open(tester, event);
    try {
      expect(text(tester, 'Current Value'), '12345,678');
      await saveWithNote(tester);

      expect((await reload(event)).amount, 12345.678);
    } finally {
      await unmount(tester);
    }
  });
}
