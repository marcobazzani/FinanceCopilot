// Asset list: an asset in the base currency bought in another currency has no
// known cost basis while that buy has no rate for its day — the list shows its
// value and no gain or loss. The buy's amount used to be taken unconverted
// (1,000 USD read as 1,000 EUR), and a gain was computed against it.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> seedFund(String name, {required String buyCurrency}) async {
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: '$name broker'));
    final id = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: name,
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
            price: const Value(100),
            currency: Value(buyCurrency),
          ),
        );
    await db.into(db.marketPrices).insert(MarketPricesCompanion.insert(assetId: id, date: today, closePrice: 121, currency: 'EUR'));
    return id;
  }

  testWidgets('a buy in another currency without a rate: the value, and no gain against an unknown cost', (tester) async {
    final boughtInUsd = await seedFund('Bought in USD', buyCurrency: 'USD');
    final boughtInEur = await seedFund('Bought in EUR', buyCurrency: 'EUR');
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
        child: const MaterialApp(home: AssetsScreen()),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    try {
      Finder inTile(int id, Finder f) => find.descendant(of: find.byKey(ValueKey(id)), matching: f);
      for (final id in [boughtInUsd, boughtInEur]) {
        expect(inTile(id, find.text('1,210.00 €')), findsOneWidget, reason: 'the value is known either way');
      }
      expect(inTile(boughtInUsd, find.textContaining('▲')), findsNothing, reason: 'no gain against 1,000 USD read as EUR');
      expect(inTile(boughtInUsd, find.textContaining('▼')), findsNothing);
      expect(inTile(boughtInEur, find.textContaining('▲')), findsOneWidget, reason: 'a known cost keeps its gain');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}
