// Composition panel and editor, in the active locale:
// - a weight the user leaves alone saves unchanged: the editor pre-filled
//   three decimals at most, so saving an untouched section rewrote a stored
//   57.12345 as 57.123;
// - the rows' weights and the editor's Σ line are spelled in the locale
//   ("57,1%" in it_IT); they used Dart's own "57.1%" whatever the locale.
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
    await db.into(db.assetCompositions).insert(AssetCompositionsCompanion.insert(assetId: id, type: 'country', name: 'USA', weight: 57.12345));
    await db.into(db.assetCompositions).insert(AssetCompositionsCompanion.insert(assetId: id, type: 'country', name: 'Japan', weight: 42.87655));
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

  /// Opens the asset detail and expands its Composition panel.
  Future<void> openPanel(WidgetTester tester, AppStrings s, String language) async {
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
  }

  Future<void> openCountryEditor(WidgetTester tester, AppStrings s, String language) async {
    await openPanel(tester, s, language);
    // The pencil icons follow the section order: asset class, country, …
    await tester.tap(find.byTooltip(s.compositionEditTooltip).at(1));
    await settle(tester);
  }

  String weightText(WidgetTester tester, int row) =>
      tester.widget<TextField>(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).at(row * 2 + 1)).controller!.text;

  Future<Map<String, double>> stored() async => {
    for (final c in await (db.select(db.assetCompositions)..where((c) => c.assetId.equals(asset.id) & c.type.equals('country'))).get())
      c.name: c.weight,
  };

  for (final (language, usa, japan) in [('it', '57,12345', '42,87655'), ('en', '57.12345', '42.87655')]) {
    testWidgets('editor ($language): weights left alone are pre-filled with every digit and save unchanged', (tester) async {
      final s = AppStrings.of(language);
      await openCountryEditor(tester, s, language);
      try {
        expect(weightText(tester, 0), usa, reason: 'it used to be pre-filled with three decimals at most');
        expect(weightText(tester, 1), japan);
        await tester.tap(find.widgetWithText(FilledButton, s.save));
        await settle(tester);

        expect(find.byType(AlertDialog), findsNothing);
        expect(await stored(), {'USA': 57.12345, 'Japan': 42.87655}, reason: 'an untouched section rewrote 57.12345 as 57.123');
      } finally {
        await unmount(tester);
      }
    });
  }

  testWidgets('Italian: the rows\' weights and the Σ line are spelled in the locale', (tester) async {
    const s = AppStrings.it;
    await openPanel(tester, s, 'it');
    try {
      expect(find.text('57,1%'), findsOneWidget);
      expect(find.text('42,9%'), findsOneWidget);
      expect(find.text('57.1%'), findsNothing);

      await tester.tap(find.byTooltip(s.compositionEditTooltip).at(1));
      await settle(tester);
      expect(find.text('Σ 100,0%'), findsOneWidget);
      expect(find.text('Σ 100.0%'), findsNothing);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('English: the rows\' weights and the Σ line keep the dot', (tester) async {
    const s = AppStrings.en;
    await openPanel(tester, s, 'en');
    try {
      expect(find.text('57.1%'), findsOneWidget);
      expect(find.text('42.9%'), findsOneWidget);

      await tester.tap(find.byTooltip(s.compositionEditTooltip).at(1));
      await settle(tester);
      expect(find.text('Σ 100.0%'), findsOneWidget);
    } finally {
      await unmount(tester);
    }
  });
}
