// Composition editor: a weight the locale cannot read is flagged on its field
// and nothing is saved. It used to count as 0 in the Σ line and its row was
// dropped on save without a word, silently rewriting the asset's breakdown.
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
import 'package:finance_copilot/services/market/composition_service.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/assets/asset_detail_screen.dart';

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};

  @override
  Future<void> syncPrices({bool forceToday = false}) async {}
}

/// Stores edits for real, never fetches composition data.
class _OfflineCompositionService extends CompositionService {
  _OfflineCompositionService(super.db);

  @override
  Future<void> clearAndResync(int assetId) async {}

  @override
  Future<void> syncCompositions() async {}
}

void main() {
  late AppDatabase db;
  late Asset asset;

  setUpAll(() async => initializeDateFormatting());
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    final id = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'World fund',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: broker,
          ),
        );
    await db.into(db.assetCompositions).insert(AssetCompositionsCompanion.insert(assetId: id, type: 'country', name: 'USA', weight: 60));
    await db.into(db.assetCompositions).insert(AssetCompositionsCompanion.insert(assetId: id, type: 'country', name: 'Japan', weight: 40));
    asset = await (db.select(db.assets)..where((a) => a.id.equals(id))).getSingle();
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openCountryEditor(WidgetTester tester, AppStrings s, String language) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          nowProvider.overrideWithValue(() => DateTime(2026, 3, 10, 12)),
          marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
          compositionServiceProvider.overrideWithValue(_OfflineCompositionService(db)),
          portableLanguageProvider.overrideWith((ref) => language),
          appLocaleProvider.overrideWith((ref) => Stream.value(language == 'it' ? 'it_IT' : 'en_US')),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(home: AssetDetailScreen(asset: asset)),
      ),
    );
    await settle(tester);
    await tester.ensureVisible(find.text(s.composition));
    await tester.tap(find.text(s.composition));
    await settle(tester);
    // The pencil icons follow the section order: asset class, country, …
    await tester.tap(find.byTooltip(s.compositionEditTooltip).at(1));
    await settle(tester);
  }

  Finder weightField(int row) => find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).at(row * 2 + 1);

  Future<Map<String, double>> stored() async => {
    for (final c in await (db.select(db.assetCompositions)..where((c) => c.assetId.equals(asset.id) & c.type.equals('country'))).get())
      c.name: c.weight,
  };

  testWidgets('an unreadable weight is flagged, the Σ line does not count it, and nothing is saved', (tester) async {
    const s = AppStrings.en;
    await openCountryEditor(tester, s, 'en');
    try {
      expect(find.text('Σ 100.0%'), findsOneWidget);
      await tester.enterText(weightField(1), '4O'); // letter O for a zero
      await tester.pump();
      expect(find.text(s.invalidNumber), findsOneWidget, reason: 'the unreadable weight is flagged as it is typed');

      await tester.tap(find.widgetWithText(FilledButton, s.save));
      await settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget, reason: 'nothing was saved, the dialog stays open');
      expect(await stored(), {'USA': 60, 'Japan': 40}, reason: 'the Japan row is not dropped');

      await tester.enterText(weightField(1), '40');
      await tester.pump();
      expect(find.text(s.invalidNumber), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, s.save));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(await stored(), {'USA': 60, 'Japan': 40});
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('Italian: a weight in the English spelling is not a number here; the Italian one saves', (tester) async {
    const s = AppStrings.it;
    await openCountryEditor(tester, s, 'it');
    try {
      await tester.enterText(weightField(0), '59.5');
      await tester.pump();
      expect(find.text(s.invalidNumber), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, s.save));
      await settle(tester);
      expect(await stored(), {'USA': 60, 'Japan': 40});

      await tester.enterText(weightField(0), '59,5');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, s.save));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(await stored(), {'USA': 59.5, 'Japan': 40});
    } finally {
      await unmount(tester);
    }
  });
}
