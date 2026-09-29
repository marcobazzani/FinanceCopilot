// The asset Edit dialog (unlocked): a tax-rate override the user leaves alone
// saves unchanged. It was pre-filled as a percentage with three decimals at
// most, so saving the unlocked dialog rewrote a stored 0.123456 as 0.12346.
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
import 'package:finance_copilot/ui/screens/assets/asset_detail_screen.dart';

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
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<Asset> insertAsset(double taxRate) async {
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    final id = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'World ETF',
            assetType: AssetType.stockEtf,
            instrumentType: const Value(InstrumentType.etf),
            assetClass: const Value(AssetClass.equity),
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: broker,
            taxRate: Value(taxRate),
          ),
        );
    return (db.select(db.assets)..where((a) => a.id.equals(id))).getSingle();
  }

  Future<void> openUnlockedEditDialog(WidgetTester tester, Asset asset, String locale) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
          appLocaleProvider.overrideWith((ref) => Stream.value(locale)),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(home: AssetDetailScreen(asset: asset)),
      ),
    );
    await settle(tester);
    await tester.tap(find.byTooltip('Edit Asset'));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.lock_outline));
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder dialogField(String label) => find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(TextField, label));

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Save')));
    await settle(tester);
  }

  for (final (stored, locale, spelled) in [
    (0.123456, 'it_IT', '12,3456'),
    (0.123456, 'en_US', '12.3456'),
    // 0.07 × 100 is 7.000000000000001 and 0.29 × 100 is 28.999999999999996:
    // shown as the percentages they are, not with the product's float noise.
    (0.07, 'it_IT', '7'),
    (0.29, 'en_US', '29'),
  ]) {
    testWidgets('a stored $stored override left alone ($locale) shows as $spelled% and saves unchanged', (tester) async {
      final asset = await insertAsset(stored);
      await openUnlockedEditDialog(tester, asset, locale);
      try {
        expect(tester.widget<TextField>(dialogField('Tax rate (%)')).controller!.text, spelled);
        await tester.enterText(dialogField('Name'), 'World ETF (acc)');
        await tapSave(tester);

        expect(find.byType(AlertDialog), findsNothing);
        final saved = await (db.select(db.assets)..where((a) => a.id.equals(asset.id))).getSingle();
        expect(saved.name, 'World ETF (acc)');
        expect(saved.taxRate, stored, reason: 'the untouched override is saved as it is stored');
      } finally {
        await unmount(tester);
      }
    });
  }

  testWidgets('a typed override is still saved', (tester) async {
    final asset = await insertAsset(0.123456);
    await openUnlockedEditDialog(tester, asset, 'it_IT');
    try {
      await tester.enterText(dialogField('Tax rate (%)'), '12,5');
      await tapSave(tester);

      expect(find.byType(AlertDialog), findsNothing);
      final saved = await (db.select(db.assets)..where((a) => a.id.equals(asset.id))).getSingle();
      expect(saved.taxRate, closeTo(0.125, 1e-12));
    } finally {
      await unmount(tester);
    }
  });
}
