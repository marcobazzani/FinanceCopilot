// Asset list: an asset whose cost basis is unknown — a buy in another currency
// without a rate for its day — shows its value, no gain, and says why the gain
// is missing; the gain percentage of a known cost is spelled in the locale.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
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

  setUpAll(() async => initializeDateFormatting());
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

  Future<void> pump(WidgetTester tester, String language) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          nowProvider.overrideWithValue(() => today.add(const Duration(hours: 12))),
          marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
          portableLanguageProvider.overrideWith((ref) => language),
          appLocaleProvider.overrideWith((ref) => Stream.value(language == 'it' ? 'it_IT' : 'en_US')),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: const MaterialApp(home: AssetsScreen()),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder inTile(int id, Finder f) => find.descendant(of: find.byKey(ValueKey(id)), matching: f);

  for (final (language, value, gainPct) in [('en', '1,210.00 €', ' (21.0%)'), ('it', '1.210,00 €', ' (21,0%)')]) {
    testWidgets('$language: an unknown cost basis is marked, a known one shows its gain in the locale', (tester) async {
      final s = AppStrings.of(language);
      final boughtInUsd = await seedFund('Bought in USD', buyCurrency: 'USD');
      final boughtInEur = await seedFund('Bought in EUR', buyCurrency: 'EUR');
      await pump(tester, language);
      try {
        expect(inTile(boughtInUsd, find.text(value)), findsOneWidget, reason: 'the value is known');
        expect(inTile(boughtInUsd, find.text(s.costBasisUnknown)), findsOneWidget, reason: 'the missing gain is explained');
        expect(inTile(boughtInUsd, find.byTooltip(s.costBasisUnknownHint)), findsOneWidget);
        expect(inTile(boughtInUsd, find.textContaining('▲')), findsNothing);
        expect(inTile(boughtInUsd, find.textContaining('▼')), findsNothing);

        expect(inTile(boughtInEur, find.text(s.costBasisUnknown)), findsNothing, reason: 'a known cost is not marked');
        expect(inTile(boughtInEur, find.text(gainPct)), findsOneWidget, reason: '210 on 1,000');
      } finally {
        await unmount(tester);
      }
    });
  }
}
