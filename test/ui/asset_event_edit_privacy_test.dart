// AssetEventEditScreen, read-only derived figures and number validation:
// - privacy mode masks the auto-calculated total and the "≈" base-currency
//   equivalent (they are position sizes: they were shown in the clear), while
//   the inputs the user types, the unit price and the FX rate stay as they
//   are and the field labels stay readable;
// - a quantity or price the locale cannot read is flagged as an invalid
//   number (the shared message), an empty one as missing;
// - pin: a bond's price is quoted per 100 of face value, so its amount is
//   quantity × price / 100; any other instrument's is quantity × price.
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

class _Rates extends ExchangeRateService {
  _Rates(super.db);

  @override
  Future<double?> getRate(String from, String to, DateTime date) async => to == 'USD' ? 1.08 : null;
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
  late int broker;

  setUpAll(() async => initializeDateFormatting());
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<Asset> insertAsset({String currency = 'USD', InstrumentType type = InstrumentType.etf}) async {
    final id = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'Fund',
            assetType: AssetType.stockEtf,
            instrumentType: Value(type),
            assetClass: const Value(AssetClass.equity),
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: broker,
            currency: Value(currency),
          ),
        );
    return (db.select(db.assets)..where((a) => a.id.equals(id))).getSingle();
  }

  Future<void> open(WidgetTester tester, Asset asset, {bool isPrivate = false}) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('it_IT')),
          baseCurrencyProvider.overrideWith((ref) => Stream.value('EUR')),
          privacyModeProvider.overrideWith((ref) => isPrivate),
          marketPriceServiceProvider.overrideWithValue(_NoPrices(db)),
          exchangeRateServiceProvider.overrideWithValue(_Rates(db)),
        ],
        child: MaterialApp(home: _Launcher(() => AssetEventEditScreen(asset: asset))),
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
  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  Future<void> selectRevalue(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownButtonFormField<EventType>));
    await settle(tester);
    await tester.tap(find.byWidgetPredicate((w) => w is DropdownMenuItem<EventType> && w.value == EventType.revalue).last);
    await settle(tester);
  }

  group('privacy mode', () {
    testWidgets('a buy: the total and its "≈" equivalent are masked, the typed inputs, price, rate and labels are not', (tester) async {
      await open(tester, await insertAsset(), isPrivate: true);
      try {
        await tester.enterText(field('Quantity *'), '10');
        await tester.enterText(field('Price (USD) *'), '100');
        await settle(tester);

        final total = find.text('1.000,00');
        expect(total, findsOneWidget);
        expect(masked(total), isTrue, reason: 'quantity × price is the position size');
        final converted = find.text('≈ 925,93 €');
        expect(converted, findsOneWidget);
        expect(masked(converted), isTrue, reason: 'the base-currency equivalent of a position size');

        expect(masked(find.text('Total (USD) (auto)')), isFalse, reason: 'a label is no figure');
        expect(masked(field('Price (USD) *')), isFalse, reason: 'the unit price is public market data');
        expect(masked(field('Rate EUR/USD')), isFalse, reason: 'an exchange rate is public market data');
        expect(masked(field('Quantity *')), isFalse, reason: 'an input the user types stays as it is');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a revaluation: the "≈" equivalent is masked, the typed value field is not', (tester) async {
      await open(tester, await insertAsset(), isPrivate: true);
      try {
        await selectRevalue(tester);
        await tester.enterText(field('Current Value'), '1.080');
        await settle(tester);

        final converted = find.text('≈ 1.000,00 €');
        expect(converted, findsOneWidget);
        expect(masked(converted), isTrue);
        expect(masked(field('Current Value')), isFalse, reason: 'an input the user types stays as it is');
        expect(find.text('Current Value'), findsOneWidget);
        expect(masked(find.text('Current Value')), isFalse);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('privacy off: the total and its equivalent read in the clear', (tester) async {
      await open(tester, await insertAsset());
      try {
        await tester.enterText(field('Quantity *'), '10');
        await tester.enterText(field('Price (USD) *'), '100');
        await settle(tester);

        expect(find.text('1.000,00'), findsOneWidget);
        expect(masked(find.text('1.000,00')), isFalse);
        expect(find.text('≈ 925,93 €'), findsOneWidget);
        expect(masked(find.text('≈ 925,93 €')), isFalse);
      } finally {
        await unmount(tester);
      }
    });
  });

  group('quantity and price validation', () {
    for (final label in ['Quantity *', 'Price *']) {
      testWidgets('$label: unreadable text is an invalid number, empty text a missing one', (tester) async {
        await open(tester, await insertAsset(currency: 'EUR'));
        try {
          await tester.enterText(field('Quantity *'), '10');
          await tester.enterText(field('Price *'), '100');
          // "10.5" is not a number in it_IT (the dot groups thousands).
          await tester.enterText(field(label), '10.5');
          await settle(tester);
          await tester.tap(find.widgetWithText(FilledButton, 'Create Event'));
          await settle(tester);
          expect(find.descendant(of: field(label), matching: find.text('Invalid number')), findsOneWidget);

          await tester.enterText(field(label), '');
          await settle(tester);
          await tester.tap(find.widgetWithText(FilledButton, 'Create Event'));
          await settle(tester);
          expect(find.descendant(of: field(label), matching: find.text('Required')), findsOneWidget);
          expect(await db.select(db.assetEvents).get(), isEmpty);
        } finally {
          await unmount(tester);
        }
      });
    }
  });

  group('pin: quoted price divisor', () {
    for (final (type, qty, price, shown, expected) in [
      (InstrumentType.bond, '10', '98,5', '9,85', 10 * 98.5 / 100),
      (InstrumentType.etf, '3', '101,23', '303,69', 3 * 101.23),
    ]) {
      testWidgets('${type.name}: $qty × $price shows $shown and saves $expected', (tester) async {
        await open(tester, await insertAsset(currency: 'EUR', type: type));
        try {
          await tester.enterText(field('Quantity *'), qty);
          await tester.enterText(field('Price *'), price);
          await settle(tester);
          expect(find.text(shown), findsOneWidget);
          await tester.tap(find.widgetWithText(FilledButton, 'Create Event'));
          await settle(tester);

          final saved = (await db.select(db.assetEvents).get()).single;
          expect(saved.amount, expected);
        } finally {
          await unmount(tester);
        }
      });
    }
  });
}
