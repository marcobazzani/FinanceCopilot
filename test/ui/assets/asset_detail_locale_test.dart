// Asset detail under the active locale: the tax-rate label, and the unit price
// and quantity of each event, are spelled in it ("26,0%", "@ 100,00",
// "qtà: 10,00" in Italian); English reads as before.
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
import 'package:finance_copilot/ui/screens/assets/asset_detail_screen.dart';

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

  Future<Asset> seed() async {
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    final id = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'World ETF',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: broker,
            taxRate: const Value(0.26),
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
          ),
        );
    await db.into(db.marketPrices).insert(MarketPricesCompanion.insert(assetId: id, date: today, closePrice: 121, currency: 'EUR'));
    return (db.select(db.assets)..where((a) => a.id.equals(id))).getSingle();
  }

  for (final (language, locale, rate, price, qty) in [
    ('en', 'en_US', '26.0', '@ 100.00', '10.00'),
    ('it', 'it_IT', '26,0', '@ 100,00', '10,00'),
  ]) {
    testWidgets('$language: tax rate, execution price and quantity in the locale', (tester) async {
      final s = AppStrings.of(language);
      final asset = await seed();
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
            appLocaleProvider.overrideWith((ref) => Stream.value(locale)),
            privacyModeProvider.overrideWith((ref) => false),
          ],
          child: MaterialApp(home: AssetDetailScreen(asset: asset)),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      try {
        expect(find.text(s.taxRateLabel(rate)), findsOneWidget);
        expect(find.text(price), findsOneWidget);
        expect(find.text(s.eventQuantityShort(qty)), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
      }
    });
  }
}
