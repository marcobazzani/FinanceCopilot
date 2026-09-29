// The Create Asset dialog (Assets → +):
// - the instrument type / asset class pickers of the search-result and manual
//   flows are the same controls, and what is picked is what is created;
// - a TER or tax rate the active locale cannot read is flagged on its field
//   and nothing is created (strict parsing returns null, and the dialog used
//   to create the asset without the typed value);
// - an intermediary added inline shows up — selected — in the dialog's picker
//   (the picker watched the list through the Assets screen's ref, so the open
//   dialog never rebuilt when the list changed).
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/market/web_market_data_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/assets/assets_screen.dart';

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

/// One listing, in the shape the instrument-search endpoint returns it.
Map<String, dynamic> _searchPayload() => {
  'instruments': [
    {
      'id': 46925,
      'symbol': 'SWDA',
      'display_symbol': 'SWDA',
      'exchange_short_name': 'Milan',
      'long_name': 'iShares Core MSCI World UCITS ETF USD (Acc)',
      'short_name': 'iShares Core MSCI World UCITS',
      'country': 'Italy',
      'type': 'etf',
      'link': '/etfs/ishares-msci-world---acc?cid=46925',
      'ISIN': 'IE00B4L5Y983',
    },
  ],
};

void main() {
  late AppDatabase db;

  setUpAll(() async => initializeDateFormatting());
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpAssets(
    WidgetTester tester, {
    MarketPriceService Function(AppDatabase db)? market,
    Stream<List<Intermediary>>? intermediaries,
  }) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          marketPriceServiceProvider.overrideWithValue((market ?? _OfflineMarketPriceService.new)(db)),
          appLocaleProvider.overrideWith((ref) => Stream.value('it_IT')),
          privacyModeProvider.overrideWith((ref) => false),
          if (intermediaries != null) intermediariesProvider.overrideWith((ref) => intermediaries),
        ],
        child: const MaterialApp(home: AssetsScreen()),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openCreateDialog(WidgetTester tester) async {
    final fab = find.byWidgetPredicate((w) => w is FloatingActionButton && w.heroTag == 'add_asset');
    await tester.tap(fab.evaluate().isNotEmpty ? fab : find.text('Create Asset'));
    await settle(tester);
    expect(find.text('New Asset'), findsOneWidget);
  }

  Future<void> openManual(WidgetTester tester) async {
    await openCreateDialog(tester);
    await tester.tap(find.text('Enter manually'));
    await settle(tester);
    expect(find.text('New Asset (Manual)'), findsOneWidget);
  }

  Future<void> pick<T>(WidgetTester tester, String label) async {
    await tester.tap(find.byType(DropdownButtonFormField<T>));
    await settle(tester);
    await tester.tap(find.text(label).last);
    await settle(tester);
  }

  Finder dialogField(String label) => find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(TextField, label));

  Future<void> tapCreate(WidgetTester tester) async {
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Create')));
    await settle(tester);
  }

  Future<int> insertBroker(String name) => db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: name));

  group('instrument type and asset class pickers', () {
    testWidgets('manual flow: the picked type and class are what is created', (tester) async {
      await insertBroker('Broker');
      await pumpAssets(tester);
      try {
        await openManual(tester);
        await tester.enterText(dialogField('Name'), 'Gov bond 2030');
        expect(find.text('Instrument Type'), findsOneWidget);
        expect(find.text('Asset Class'), findsOneWidget);
        await pick<InstrumentType>(tester, 'Bond');
        await pick<AssetClass>(tester, 'Fixed Income');
        await pick<int>(tester, 'Broker');
        await tapCreate(tester);

        final asset = (await db.select(db.assets).get()).single;
        expect(asset.name, 'Gov bond 2030');
        expect(asset.instrumentType, InstrumentType.bond);
        expect(asset.assetClass, AssetClass.fixedIncome);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('search flow: the result pre-selects its type and class, and a changed class is what is created', (tester) async {
      await insertBroker('Broker');
      await pumpAssets(tester, market: (db) => WebMarketDataService(db, jsFetchOverride: (url, domainId) async => _searchPayload()));
      try {
        await openCreateDialog(tester);
        await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'SWDA');
        await tester.pump(const Duration(milliseconds: 500));
        await settle(tester);
        await tester.tap(find.text('iShares Core MSCI World UCITS ETF USD (Acc)'));
        await settle(tester);

        expect(find.text('Create Asset'), findsOneWidget);
        expect(find.descendant(of: find.byType(DropdownButtonFormField<InstrumentType>), matching: find.text('ETF')), findsOneWidget);
        expect(find.descendant(of: find.byType(DropdownButtonFormField<AssetClass>), matching: find.text('Equity')), findsOneWidget);
        await pick<AssetClass>(tester, 'Multi-Asset');
        await pick<int>(tester, 'Broker');
        await tapCreate(tester);

        final asset = (await db.select(db.assets).get()).single;
        expect(asset.name, 'iShares Core MSCI World UCITS ETF USD (Acc)');
        expect(asset.instrumentType, InstrumentType.etf);
        expect(asset.assetClass, AssetClass.multiAsset);
      } finally {
        await unmount(tester);
      }
    });
  });

  group('TER and tax rate the locale cannot read', () {
    Future<void> fillManual(WidgetTester tester) async {
      await openManual(tester);
      await tester.enterText(dialogField('Name'), 'Fund');
      await pick<int>(tester, 'Broker');
      await tester.tap(find.byIcon(Icons.lock_outline));
      await settle(tester);
    }

    testWidgets('an unreadable TER is flagged and nothing is created', (tester) async {
      await insertBroker('Broker');
      await pumpAssets(tester);
      try {
        await fillManual(tester);
        // "0.22" is not a number in it_IT (the dot groups thousands).
        await tester.enterText(dialogField('TER (%)'), '0.22');
        await tapCreate(tester);

        expect(find.text('Invalid number'), findsOneWidget);
        expect(await db.select(db.assets).get(), isEmpty, reason: 'it used to be created without its TER');

        await tester.enterText(dialogField('TER (%)'), '0,22');
        await tapCreate(tester);
        expect((await db.select(db.assets).get()).single.ter, 0.22);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('an unreadable tax rate is flagged and nothing is created', (tester) async {
      await insertBroker('Broker');
      await pumpAssets(tester);
      try {
        await fillManual(tester);
        await tester.enterText(dialogField('Tax rate (%)'), '12.5');
        await tapCreate(tester);

        expect(find.text('Invalid number'), findsOneWidget);
        expect(await db.select(db.assets).get(), isEmpty, reason: 'it used to be created without its tax-rate override');

        await tester.enterText(dialogField('Tax rate (%)'), '12,5');
        await tapCreate(tester);
        expect((await db.select(db.assets).get()).single.taxRate, closeTo(0.125, 1e-12));
      } finally {
        await unmount(tester);
      }
    });
  });

  testWidgets('an intermediary added inline is listed and selected in the picker', (tester) async {
    // The list arrives when the test says so: in the app the database answers
    // on a background isolate, after the dialog has already rebuilt.
    final intermediaries = StreamController<List<Intermediary>>();
    addTearDown(intermediaries.close);
    intermediaries.add(const []);
    await pumpAssets(tester, intermediaries: intermediaries.stream);
    try {
      await openManual(tester);
      expect(find.text('No intermediary yet. Create one to continue.'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Add Intermediary'));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Intermediary Name'), 'New broker');
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Create').last);
      await settle(tester);
      intermediaries.add(await db.select(db.intermediaries).get());
      await settle(tester);

      expect(find.text('No intermediary yet. Create one to continue.'), findsNothing);
      expect(find.descendant(of: find.byType(DropdownButtonFormField<int>), matching: find.text('New broker')), findsOneWidget);

      await tester.enterText(dialogField('Name'), 'Cash pot');
      await settle(tester);
      await tapCreate(tester);
      final broker = (await db.select(db.intermediaries).get()).single;
      expect((await db.select(db.assets).get()).single.intermediaryId, broker.id);
    } finally {
      await unmount(tester);
    }
  });
}
