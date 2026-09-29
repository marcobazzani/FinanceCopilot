// AssetEventEditScreen under the active locale and the ledger's date
// convention:
// - a fetched FX rate and the amount hint are spelled in the locale the save
//   parses with (it_IT used to get "1.080000", read back as 1080000);
// - editing writes the booking date (asset_events.date, the import dedup's
//   key) only when the user moved the day of an event whose booking date was
//   in sync with its value date;
// - a double tap on the save button inserts one event;
// - a rate or price answered for inputs the user has since changed is
//   dropped, and switching currency drops the previous pair's rate;
// - the event type dropdown shows localized labels, not enum names;
// - privacy mode masks the raw import values but keeps the column names and
//   the unit price field readable.
import 'dart:async';
import 'dart:convert';

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

/// FX rates the test answers: immediately from [immediate], or else through
/// one pending completer per requested currency.
class _FakeRates extends ExchangeRateService {
  _FakeRates(super.db, {this.immediate});

  final Map<String, double>? immediate;
  final pending = <String, Completer<double?>>{};

  @override
  Future<double?> getRate(String from, String to, DateTime date) {
    final answers = immediate;
    if (answers != null) return Future.value(answers[to]);
    return (pending[to] = Completer<double?>()).future;
  }
}

/// Asset prices the test answers, one pending completer per request.
class _FakePrices extends MarketPriceService {
  _FakePrices(super.db);

  final requests = <({DateTime date, Completer<double?> answer})>[];

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};

  @override
  Future<double?> getPrice(int assetId, DateTime date) {
    final answer = Completer<double?>();
    requests.add((date: date, answer: answer));
    return answer.future;
  }
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
  late int intermediaryId;

  setUpAll(() async => initializeDateFormatting());
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    intermediaryId = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<Asset> insertAsset(String currency) async {
    final id = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'World ETF',
            assetType: AssetType.stockEtf,
            instrumentType: const Value(InstrumentType.etf),
            assetClass: const Value(AssetClass.equity),
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: intermediaryId,
            currency: Value(currency),
          ),
        );
    return (db.select(db.assets)..where((a) => a.id.equals(id))).getSingle();
  }

  Future<AssetEvent> insertBuy(Asset asset, {required DateTime booked, required DateTime moved, String? rawMetadata}) async {
    final id = await db
        .into(db.assetEvents)
        .insert(
          AssetEventsCompanion.insert(
            assetId: asset.id,
            date: booked,
            valueDate: moved,
            type: EventType.buy,
            amount: 1000,
            quantity: const Value(10),
            price: const Value(100),
            currency: Value(asset.currency),
            rawMetadata: Value(rawMetadata),
          ),
        );
    return (db.select(db.assetEvents)..where((e) => e.id.equals(id))).getSingle();
  }

  Future<List<AssetEvent>> events() => db.select(db.assetEvents).get();

  Future<void> open(
    WidgetTester tester,
    Asset asset, {
    AssetEvent? event,
    ExchangeRateService Function(AppDatabase db)? rates,
    _FakePrices? prices,
    String language = 'en',
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('it_IT')),
          baseCurrencyProvider.overrideWith((ref) => Stream.value('EUR')),
          portableLanguageProvider.overrideWith((ref) => language),
          privacyModeProvider.overrideWith((ref) => false),
          marketPriceServiceProvider.overrideWithValue(prices ?? _FakePrices(db)),
          exchangeRateServiceProvider.overrideWithValue((rates ?? (db) => _FakeRates(db, immediate: const {}))(db)),
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
  InputDecoration decoration(WidgetTester tester, String label) =>
      tester.widget<TextField>(find.descendant(of: field(label), matching: find.byType(TextField))).decoration!;

  Future<void> pickDay(WidgetTester tester, int day) async {
    await tester.tap(field('Date *'));
    await settle(tester);
    await tester.tap(find.text('$day'));
    await tester.tap(find.text('OK'));
    await settle(tester);
  }

  Future<void> selectCurrency(WidgetTester tester, String currency) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await settle(tester);
    await tester.tap(find.text(currency).last);
    await settle(tester);
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(FilledButton, label));
    await settle(tester);
  }

  group('FX rate and amount hint spelled in the active locale', () {
    testWidgets('a fetched 1.08 rate is pre-filled as 1,080000 and saved as 1.08', (tester) async {
      final asset = await insertAsset('USD');
      await open(tester, asset, rates: (db) => _FakeRates(db, immediate: const {'USD': 1.08}));
      try {
        expect(text(tester, 'Rate EUR/USD'), '1,080000');
        await tester.enterText(field('Quantity *'), '10');
        await tester.enterText(field('Price (USD) *'), '100');
        await settle(tester);
        await tapButton(tester, 'Create Event');

        final saved = (await events()).single;
        expect(saved.exchangeRate, 1.08);
        expect(saved.amount, 1000);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('the direct-amount hint is an example the locale reads back', (tester) async {
      final asset = await insertAsset('EUR');
      await open(tester, asset);
      try {
        await tester.tap(find.byType(DropdownButtonFormField<EventType>));
        await settle(tester);
        await tester.tap(find.byWidgetPredicate((w) => w is DropdownMenuItem<EventType> && w.value == EventType.revalue).last);
        await settle(tester);

        expect(decoration(tester, 'Current Value').hintText, '1.000,00', reason: 'it_IT reads "1000.00" as 100000');
      } finally {
        await unmount(tester);
      }
    });
  });

  group('booking date on edit', () {
    testWidgets('a notes-only edit keeps the imported booking date', (tester) async {
      final asset = await insertAsset('EUR');
      final event = await insertBuy(asset, booked: DateTime(2024, 3, 13), moved: DateTime(2024, 3, 15));
      await open(tester, asset, event: event);
      try {
        await tester.enterText(field('Notes'), 'checked');
        await tapButton(tester, 'Save Changes');

        final saved = (await events()).single;
        expect(saved.notes, 'checked');
        expect(saved.valueDate, DateTime(2024, 3, 15));
        expect(saved.date, DateTime(2024, 3, 13), reason: 'the import dedup keys on the booking date');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('moving the date of an in-sync event moves the booking date too', (tester) async {
      final asset = await insertAsset('EUR');
      final event = await insertBuy(asset, booked: DateTime(2024, 3, 15), moved: DateTime(2024, 3, 15));
      await open(tester, asset, event: event);
      try {
        await pickDay(tester, 20);
        await tapButton(tester, 'Save Changes');

        final saved = (await events()).single;
        expect(saved.valueDate, DateTime(2024, 3, 20));
        expect(saved.date, DateTime(2024, 3, 20));
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('moving the date of an imported event moves only the value date', (tester) async {
      final asset = await insertAsset('EUR');
      final event = await insertBuy(asset, booked: DateTime(2024, 3, 13), moved: DateTime(2024, 3, 15));
      await open(tester, asset, event: event);
      try {
        await pickDay(tester, 20);
        await tapButton(tester, 'Save Changes');

        final saved = (await events()).single;
        expect(saved.valueDate, DateTime(2024, 3, 20));
        expect(saved.date, DateTime(2024, 3, 13), reason: 'a booking date distinct from the value date is the bank\'s');
      } finally {
        await unmount(tester);
      }
    });
  });

  testWidgets('two rapid taps on Create insert one event', (tester) async {
    final asset = await insertAsset('EUR');
    await open(tester, asset);
    try {
      await tester.enterText(field('Quantity *'), '10');
      await tester.enterText(field('Price *'), '100');
      await settle(tester);
      // Hold the database so the first save is still in flight when the
      // second tap lands, as with the app's background database isolate.
      final release = Completer<void>();
      final held = db.transaction(() => release.future);
      final create = find.widgetWithText(FilledButton, 'Create Event');
      await tester.tap(create);
      await tester.tap(create, warnIfMissed: false);
      release.complete();
      await held;
      await settle(tester);

      expect(await events(), hasLength(1));
    } finally {
      await unmount(tester);
    }
  });

  group('async lookups answered for stale inputs', () {
    testWidgets('a rate answered for the previous currency is dropped', (tester) async {
      final asset = await insertAsset('USD');
      late _FakeRates rates;
      await open(tester, asset, rates: (db) => rates = _FakeRates(db));
      try {
        expect(rates.pending.keys, ['USD']);
        await selectCurrency(tester, 'GBP');
        rates.pending['GBP']!.complete(0.85);
        await settle(tester);
        expect(text(tester, 'Rate EUR/GBP'), '0,850000');

        rates.pending['USD']!.complete(1.08);
        await settle(tester);
        expect(text(tester, 'Rate EUR/GBP'), '0,850000', reason: 'the USD answer is for a currency no longer selected');

        await tester.enterText(field('Quantity *'), '10');
        await tester.enterText(field('Price (GBP) *'), '100');
        await settle(tester);
        await tapButton(tester, 'Create Event');

        final saved = (await events()).single;
        expect(saved.currency, 'GBP');
        expect(saved.exchangeRate, 0.85);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('switching currency drops the previous pair\'s rate even when the new one is unknown', (tester) async {
      final asset = await insertAsset('USD');
      await open(tester, asset, rates: (db) => _FakeRates(db, immediate: const {'USD': 1.08}));
      try {
        expect(text(tester, 'Rate EUR/USD'), '1,080000');
        await selectCurrency(tester, 'GBP');

        expect(text(tester, 'Rate EUR/GBP'), isEmpty, reason: 'no GBP rate is known; the USD one is not a GBP rate');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a price answered for the previous date is dropped', (tester) async {
      final asset = await insertAsset('EUR');
      final prices = _FakePrices(db);
      await open(tester, asset, prices: prices);
      try {
        expect(prices.requests, hasLength(1), reason: 'create mode looks up the price for today');
        final now = DateTime.now();
        final day = now.day == 10 ? 11 : 10;
        await pickDay(tester, day);
        expect(prices.requests, hasLength(2));
        expect(prices.requests.last.date, DateTime(now.year, now.month, day));

        prices.requests.last.answer.complete(101);
        await settle(tester);
        expect(text(tester, 'Price *'), '101,0000');

        prices.requests.first.answer.complete(99);
        await settle(tester);
        expect(text(tester, 'Price *'), '101,0000', reason: 'the first answer is for a date no longer selected');
      } finally {
        await unmount(tester);
      }
    });
  });

  testWidgets('a typed commission the locale cannot read is flagged, not silently dropped', (tester) async {
    final asset = await insertAsset('EUR');
    await open(tester, asset);
    try {
      await tester.enterText(field('Quantity *'), '10');
      await tester.enterText(field('Price *'), '100');
      await tester.enterText(field('Commission'), '2.5');
      await settle(tester);
      await tapButton(tester, 'Create Event');

      expect(find.text('Invalid number'), findsOneWidget, reason: 'it_IT does not read "2.5"');
      expect(await events(), isEmpty);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('the event type dropdown shows the Italian label, not the enum name', (tester) async {
    final asset = await insertAsset('EUR');
    await open(tester, asset, language: 'it');
    try {
      expect(find.text('Acquisto'), findsOneWidget);
      expect(find.text('buy'), findsNothing);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('privacy mode masks the raw import values, keeps column names and the unit price readable', (tester) async {
    final asset = await insertAsset('EUR');
    final raw = jsonEncode({'Quantità': '10', 'Prezzo': '100,00', 'Controvalore': '1.000,00'});
    final event = await insertBuy(asset, booked: DateTime(2024, 3, 15), moved: DateTime(2024, 3, 15), rawMetadata: raw);
    await open(tester, asset, event: event);
    try {
      final panel = find.byKey(const Key('rawImportData'));
      Finder inPanel(String text) => find.descendant(of: panel, matching: find.text(text));
      bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

      expect(inPanel('1.000,00'), findsOneWidget);
      expect(masked(inPanel('1.000,00')), isFalse, reason: 'privacy mode is off');

      final container = ProviderScope.containerOf(tester.element(find.byType(AssetEventEditScreen)));
      container.read(privacyModeProvider.notifier).state = true;
      await settle(tester);

      expect(masked(inPanel('1.000,00')), isTrue, reason: 'a raw amount reveals the position size');
      expect(masked(inPanel('10')), isTrue, reason: 'a raw quantity reveals the position size');
      expect(inPanel('Controvalore: '), findsOneWidget);
      expect(masked(inPanel('Controvalore: ')), isFalse, reason: 'column names are not position sizes');
      expect(masked(find.text('Price *')), isFalse, reason: 'the unit price is public market data');
    } finally {
      await unmount(tester);
    }
  });
}
