// The Create Asset dialog saves at most once: a second tap on Create while
// the first create is still running creates nothing (it used to create the
// asset twice), in the manual and in the search-result flow alike.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
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
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpAssets(WidgetTester tester, {MarketPriceService Function(AppDatabase db)? market}) async {
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

  Future<void> pickBroker(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await settle(tester);
    await tester.tap(find.text('Broker').last);
    await settle(tester);
  }

  /// Taps Create twice while the database holds the first create.
  Future<void> doubleTapCreate(WidgetTester tester) async {
    final create = find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Create'));
    expect(tester.widget<FilledButton>(create).onPressed, isNotNull);
    final release = Completer<void>();
    final held = db.transaction(() => release.future);
    await tester.tap(create);
    await tester.tap(create, warnIfMissed: false);
    release.complete();
    await held;
    await settle(tester);
  }

  testWidgets('manual flow: two rapid taps on Create create one asset', (tester) async {
    await pumpAssets(tester);
    try {
      await openCreateDialog(tester);
      await tester.tap(find.text('Enter manually'));
      await settle(tester);
      await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(TextField, 'Name')), 'Cash pot');
      await pickBroker(tester);
      await doubleTapCreate(tester);

      expect((await db.select(db.assets).get()).map((a) => a.name), ['Cash pot']);
      expect(find.byType(AlertDialog), findsNothing, reason: 'the first create closed the dialog');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('search flow: two rapid taps on Create create one asset', (tester) async {
    await pumpAssets(tester, market: (db) => WebMarketDataService(db, jsFetchOverride: (url, domainId) async => _searchPayload()));
    try {
      await openCreateDialog(tester);
      await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'SWDA');
      await tester.pump(const Duration(milliseconds: 500));
      await settle(tester);
      await tester.tap(find.text('iShares Core MSCI World UCITS ETF USD (Acc)'));
      await settle(tester);
      expect(find.text('Create Asset'), findsOneWidget);
      await pickBroker(tester);
      await doubleTapCreate(tester);

      expect((await db.select(db.assets).get()).map((a) => a.name), ['iShares Core MSCI World UCITS ETF USD (Acc)']);
      expect(find.byType(AlertDialog), findsNothing, reason: 'the first create closed the dialog');
    } finally {
      await unmount(tester);
    }
  });
}
