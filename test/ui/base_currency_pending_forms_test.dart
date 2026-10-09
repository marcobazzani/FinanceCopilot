// Forms that fall back to the base currency: until the stored base currency
// has loaded they save nothing. They used to guess 'EUR' meanwhile — an asset
// event then fetched and stamped its FX rate against EUR, and a new adjustment
// was created in EUR, whatever the user's base currency was.
//
// Also: the "≈" base-currency equivalent of an asset event's amount is spelled
// in the active locale ("≈ 925,93 €" in it_IT, not "≈ 925.93 €").
import 'dart:async';

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
import 'package:finance_copilot/ui/screens/events/event_edit_screen.dart';

/// Answers every rate request with [rates][to], and records the requests.
class _Rates extends ExchangeRateService {
  _Rates(super.db, this.rates);

  final Map<String, double> rates;
  final requests = <(String, String)>[];

  @override
  Future<double?> getRate(String from, String to, DateTime date) async {
    requests.add((from, to));
    return rates[to];
  }
}

class _NoPrices extends MarketPriceService {
  _NoPrices(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};

  @override
  Future<double?> getPrice(int assetId, DateTime date) async => null;
}

/// Opens [screen] once the locale has loaded — the base currency is left to
/// the test.
class _Launcher extends ConsumerWidget {
  const _Launcher(this.screen);
  final Widget Function() screen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(appLocaleProvider).hasValue;
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
  late StreamController<String> base;
  late _Rates rates;

  setUpAll(() async => initializeDateFormatting());
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    base = StreamController<String>();
    rates = _Rates(db, const {'USD': 1.08});
  });
  tearDown(() async {
    // Not awaited: a stream nobody listened to (a seeded form never asks for
    // the base currency) completes its close only once listened to.
    unawaited(base.close());
    await db.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> open(WidgetTester tester, Widget Function() screen, {String locale = 'en_US'}) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value(locale)),
          baseCurrencyProvider.overrideWith((ref) => base.stream),
          privacyModeProvider.overrideWith((ref) => false),
          marketPriceServiceProvider.overrideWithValue(_NoPrices(db)),
          exchangeRateServiceProvider.overrideWithValue(rates),
        ],
        child: MaterialApp(home: _Launcher(screen)),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('open')));
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);
  FilledButton button(WidgetTester tester, String label) => tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));

  Future<void> tap(WidgetTester tester, String label) async {
    final finder = find.widgetWithText(FilledButton, label);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await settle(tester);
  }

  Future<Asset> insertAsset(String currency) async {
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    final id = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'US Fund',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: broker,
            currency: Value(currency),
          ),
        );
    return (db.select(db.assets)..where((a) => a.id.equals(id))).getSingle();
  }

  group('asset event', () {
    testWidgets('while the base currency loads nothing is saved nor fetched against a guess; then it saves against the real one', (
      tester,
    ) async {
      final asset = await insertAsset('USD');
      await open(tester, () => AssetEventEditScreen(asset: asset));
      try {
        expect(button(tester, 'Create Event').onPressed, isNull, reason: 'the base currency is not known yet');
        expect(rates.requests, isEmpty, reason: 'no rate against a guessed EUR base');
        await tester.enterText(field('Quantity *'), '10');
        await tester.enterText(field('Price *'), '100');
        await settle(tester);

        // The base currency is the asset's own: nothing to convert.
        base.add('USD');
        await settle(tester);
        expect(button(tester, 'Create Event').onPressed, isNotNull);
        expect(rates.requests, isEmpty, reason: 'a USD event on a USD base needs no rate');
        await tap(tester, 'Create Event');

        final saved = await db.select(db.assetEvents).getSingle();
        expect(saved.currency, 'USD');
        expect(saved.exchangeRate, isNull, reason: 'the EUR/USD rate of a guessed base is no rate of this event');
        expect(saved.exchangeRateBase, isNull, reason: 'no rate, no base to stamp it with');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('once the base currency loads, the rate is fetched against it and stamped with it', (tester) async {
      final asset = await insertAsset('USD');
      await open(tester, () => AssetEventEditScreen(asset: asset));
      try {
        base.add('EUR');
        await settle(tester);
        expect(rates.requests, [('EUR', 'USD')]);
        expect(tester.widget<TextFormField>(field('Rate EUR/USD')).controller!.text, '1.080000');
        await tester.enterText(field('Quantity *'), '10');
        await tester.enterText(field('Price (USD) *'), '100');
        await settle(tester);
        await tap(tester, 'Create Event');

        final saved = await db.select(db.assetEvents).getSingle();
        expect(saved.exchangeRate, 1.08);
        expect(saved.exchangeRateBase, 'EUR');
      } finally {
        await unmount(tester);
      }
    });

    for (final (locale, converted) in [('en_US', '≈ 925.93 €'), ('it_IT', '≈ 925,93 €')]) {
      testWidgets('$locale: the base-currency equivalent is spelled in the locale', (tester) async {
        final asset = await insertAsset('USD');
        base.add('EUR');
        await open(tester, () => AssetEventEditScreen(asset: asset), locale: locale);
        try {
          await tester.enterText(field('Quantity *'), '10');
          await tester.enterText(field('Price (USD) *'), '100');
          await settle(tester);

          // The read-only total is a decorated figure (masked in privacy
          // mode), not a text field: its equivalent is read from it.
          final total = find.ancestor(of: find.text('Total (USD) (auto)'), matching: find.byType(InputDecorator));
          expect(
            find.descendant(of: total, matching: find.text(converted)),
            findsOneWidget,
            reason: '1,000 USD / 1.08',
          );
        } finally {
          await unmount(tester);
        }
      });
    }
  });

  group('adjustment', () {
    String? currency(WidgetTester tester) => tester.state<FormFieldState<String>>(find.byType(DropdownButtonFormField<String>)).value;

    testWidgets('while the base currency loads nothing is created; then it is created in the base currency', (tester) async {
      await open(tester, () => const EventEditScreen());
      try {
        expect(button(tester, 'Create').onPressed, isNull, reason: 'the base currency is not known yet');
        expect(currency(tester), isNull, reason: 'no guessed currency is offered');
        await tester.enterText(field('Name'), 'Car repair');
        await tester.enterText(field('Amount'), '1200');
        await settle(tester);

        base.add('USD');
        await settle(tester);
        expect(currency(tester), 'USD');
        expect(button(tester, 'Create').onPressed, isNotNull);
        await tap(tester, 'Create');

        final saved = await db.select(db.extraordinaryEvents).getSingle();
        expect(saved.currency, 'USD', reason: 'it used to be created in EUR');
        expect(saved.totalAmount, 1200);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a seeded currency needs no base currency', (tester) async {
      await open(tester, () => const EventEditScreen(seedCurrency: 'GBP', seedName: 'Rent', seedAmount: 900));
      try {
        expect(currency(tester), 'GBP');
        expect(button(tester, 'Create').onPressed, isNotNull);
        await tap(tester, 'Create');

        final saved = await db.select(db.extraordinaryEvents).getSingle();
        expect(saved.currency, 'GBP');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a currency picked before the base currency loads is kept', (tester) async {
      await open(tester, () => const EventEditScreen());
      try {
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await settle(tester);
        await tester.tap(find.text('CHF').last);
        await settle(tester);
        base.add('USD');
        await settle(tester);
        expect(currency(tester), 'CHF', reason: 'the user\'s pick, not the base currency');
      } finally {
        await unmount(tester);
      }
    });
  });
}
