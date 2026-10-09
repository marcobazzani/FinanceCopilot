// Composition editor: each row keeps its own fields. Deleting a row used to
// leave the focus (and so the typing) at the same position on screen, which
// now showed the next row: a user fixing "Japan" who removed the row above it
// went on to rename "UK" instead.
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
  const s = AppStrings.en;
  late AppDatabase db;
  late Asset asset;

  setUpAll(() async => initializeDateFormatting('en'));
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
    // Shown by weight, heaviest first: USA, Japan, UK.
    for (final (name, weight) in [('USA', 50.0), ('Japan', 30.0), ('UK', 20.0)]) {
      await db.into(db.assetCompositions).insert(AssetCompositionsCompanion.insert(assetId: id, type: 'country', name: name, weight: weight));
    }
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

  Future<void> openCountryEditor(WidgetTester tester) async {
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
          portableLanguageProvider.overrideWith((ref) => 'en'),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
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

  Finder inDialog(Finder f) => find.descendant(of: find.byType(AlertDialog), matching: f);
  Finder nameField(int row) => inDialog(find.byType(TextField)).at(row * 2);

  /// The name typed in each row, top to bottom.
  List<String> names(WidgetTester tester) => [
    for (final (i, field) in tester.widgetList<TextField>(inDialog(find.byType(TextField))).indexed)
      if (i.isEven) field.controller!.text,
  ];

  /// The text of the field that has the keyboard focus.
  String focusedText(WidgetTester tester) =>
      tester.widgetList<EditableText>(inDialog(find.byType(EditableText))).singleWhere((e) => e.focusNode.hasFocus).controller.text;

  Future<Map<String, double>> stored() async => {
    for (final c in await (db.select(db.assetCompositions)..where((c) => c.assetId.equals(asset.id) & c.type.equals('country'))).get())
      c.name: c.weight,
  };

  testWidgets('deleting the row above the one being edited keeps the focus and the typing on that row', (tester) async {
    await openCountryEditor(tester);
    try {
      expect(names(tester), ['USA', 'Japan', 'UK']);
      await tester.showKeyboard(nameField(1));
      await tester.pump();
      expect(focusedText(tester), 'Japan');

      // Remove the USA row while Japan is being edited.
      await tester.tap(inDialog(find.byIcon(Icons.delete_outline)).first);
      await tester.pump();
      expect(names(tester), ['Japan', 'UK']);
      expect(focusedText(tester), 'Japan', reason: 'the focus stays on the row being edited, not on the row now in its place');

      tester.testTextInput.enterText('Japan (JP)');
      await tester.pump();
      expect(names(tester), ['Japan (JP)', 'UK'], reason: 'the typing goes to the row being edited');

      await tester.tap(find.widgetWithText(FilledButton, s.save));
      await settle(tester);
      expect(await stored(), {'Japan (JP)': 30, 'UK': 20});
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('deleting a row below the one being edited leaves that row as it was', (tester) async {
    await openCountryEditor(tester);
    try {
      await tester.showKeyboard(nameField(0));
      await tester.pump();

      await tester.tap(inDialog(find.byIcon(Icons.delete_outline)).at(1));
      await tester.pump();
      expect(names(tester), ['USA', 'UK']);
      expect(focusedText(tester), 'USA');

      tester.testTextInput.enterText('United States');
      await tester.pump();
      expect(names(tester), ['United States', 'UK']);
    } finally {
      await unmount(tester);
    }
  });
}
