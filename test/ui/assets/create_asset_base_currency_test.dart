// The Create Asset dialog gives a manual asset the stored base currency, and
// creates nothing until it has loaded: it used to fall back to a guessed
// 'EUR' when the base currency had not loaded yet.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/assets/assets_screen.dart';

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

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

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('manual flow: Create is off until the base currency has loaded, then the asset gets it', (tester) async {
    await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    final baseCurrency = StreamController<String>();
    addTearDown(baseCurrency.close);
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
          appLocaleProvider.overrideWith((ref) => Stream.value('it_IT')),
          baseCurrencyProvider.overrideWith((ref) => baseCurrency.stream),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: const MaterialApp(home: AssetsScreen()),
      ),
    );
    await settle(tester);
    try {
      final fab = find.byWidgetPredicate((w) => w is FloatingActionButton && w.heroTag == 'add_asset');
      await tester.tap(fab.evaluate().isNotEmpty ? fab : find.text('Create Asset'));
      await settle(tester);
      await tester.tap(find.text('Enter manually'));
      await settle(tester);
      await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(TextField, 'Name')), 'Cash pot');
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await settle(tester);
      await tester.tap(find.text('Broker').last);
      await settle(tester);

      final create = find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Create'));
      expect(tester.widget<FilledButton>(create).onPressed, isNull, reason: 'the base currency is not known yet');
      await tester.tap(create, warnIfMissed: false);
      await settle(tester);
      expect(await db.select(db.assets).get(), isEmpty, reason: 'it used to be created in a guessed EUR');

      baseCurrency.add('CHF');
      await settle(tester);
      expect(tester.widget<FilledButton>(create).onPressed, isNotNull);
      await tester.tap(create);
      await settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      final asset = (await db.select(db.assets).get()).single;
      expect(asset.name, 'Cash pot');
      expect(asset.currency, 'CHF', reason: 'the stored base currency, not a default');
    } finally {
      await unmount(tester);
    }
  });
}
