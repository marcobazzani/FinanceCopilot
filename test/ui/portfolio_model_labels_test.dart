// Portfolio models are summarised the same way wherever they are listed: the
// built-in tiles and the custom cards of the Portfolio Models tab read
// "Year · equity · variant", the pillar dialog's model picker puts the model
// name first, and an expanded model lists its rows as ISIN, description and
// target weight.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/pillars/pillar_performance.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show AllSeriesData, allSeriesDataProvider;
import 'package:finance_copilot/ui/screens/pillars/pillar_create_dialog.dart';
import 'package:finance_copilot/ui/screens/pillars/pillars_screen.dart';

PortfolioModel _model(
  String id,
  String name, {
  bool builtIn = false,
  int? year,
  int? equity,
  PortfolioModelVariant variant = PortfolioModelVariant.custom,
}) => PortfolioModel(
  id: id,
  name: name,
  isBuiltIn: builtIn,
  year: year,
  equityPercent: equity,
  variant: variant,
  sortOrder: 0,
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2025, 1, 1),
);

void main() {
  late AppDatabase db;
  final models = [
    _model('b1', 'Mini 60', builtIn: true, year: 2024, equity: 60, variant: PortfolioModelVariant.mini),
    _model('c1', 'My model'),
    _model('c2', 'Growth', equity: 80),
  ];
  final items = {
    'b1': [PortfolioModelItem(id: 1, modelId: 'b1', isin: 'IE00B4L5Y983', targetWeight: 60, description: 'World', sortOrder: 0)],
    'c1': [PortfolioModelItem(id: 2, modelId: 'c1', isin: 'IE00BKM4GZ66', targetWeight: 12.5, description: 'Emerging', sortOrder: 0)],
    'c2': const <PortfolioModelItem>[],
  };

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pump(WidgetTester tester, String language) async {
    // Wide enough for the model labels in the test font.
    tester.view.physicalSize = const Size(2400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          portableLanguageProvider.overrideWith((ref) => language),
          appLocaleProvider.overrideWith((ref) => Stream.value(language == 'it' ? 'it_IT' : 'en_US')),
          baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
          pillarsProvider.overrideWithValue(const AsyncData([])),
          standardPillarsProvider.overrideWithValue(const AsyncData([])),
          virtualPortfoliosProvider.overrideWithValue(const AsyncData([])),
          activeAssetsProvider.overrideWithValue(const AsyncData([])),
          assetsProvider.overrideWithValue(const AsyncData([])),
          pillarAssetsProvider.overrideWithValue(const AsyncData([])),
          assetMarketValuesProvider.overrideWithValue(const AsyncData({})),
          unassignedFractionProvider.overrideWithValue(const AsyncData({})),
          allSeriesDataProvider.overrideWithValue(const AsyncData<AllSeriesData?>(null)),
          pillarPerformanceSnapshotsProvider.overrideWithValue(const AsyncData(<String, PillarPerformanceSnapshot>{})),
          portfolioModelsProvider.overrideWithValue(AsyncData(models)),
          portfolioModelItemsProvider.overrideWith((ref, id) => Stream.value(items[id]!)),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: const MaterialApp(home: PillarsScreen()),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  for (final (language, builtInSummary, customSummary, growthSummary, pickerLabels) in [
    (
      'en',
      'Year 2024 · 60% equity · Mini',
      'Custom',
      '80% equity · Custom',
      ['Mini 60 · Year 2024 · 60% equity · Mini', 'My model · Custom', 'Growth · 80% equity · Custom'],
    ),
    (
      'it',
      'Anno 2024 · 60% azionario · Mini',
      'Personalizzato',
      '80% azionario · Personalizzato',
      ['Mini 60 · Anno 2024 · 60% azionario · Mini', 'My model · Personalizzato', 'Growth · 80% azionario · Personalizzato'],
    ),
  ]) {
    testWidgets('$language: model summaries in the tab and in the pillar dialog, and the rows of an expanded model', (tester) async {
      final s = AppStrings.of(language);
      await pump(tester, language);
      try {
        await tester.tap(find.widgetWithText(Tab, s.pillarTabPortfolioModels));
        await settle(tester);

        // Custom models: one card each, summary under the name.
        expect(find.widgetWithText(ListTile, customSummary), findsOneWidget);
        expect(find.widgetWithText(ListTile, growthSummary), findsOneWidget);
        await tester.tap(find.text('My model'));
        await settle(tester);
        expect(find.widgetWithText(ListTile, 'IE00BKM4GZ66'), findsOneWidget);
        expect(find.widgetWithText(ListTile, 'Emerging'), findsOneWidget);
        // The target weight in the locale's spelling.
        expect(find.widgetWithText(ListTile, language == 'it' ? '12,50%' : '12.50%'), findsOneWidget);

        // Built-in models: year → variant → equity → model.
        await tester.tap(find.text('2024'));
        await settle(tester);
        await tester.tap(find.text(s.portfolioModelMini));
        await settle(tester);
        await tester.tap(find.text('60%'));
        await settle(tester);
        expect(find.widgetWithText(ListTile, builtInSummary), findsOneWidget);
        await tester.tap(find.text('Mini 60'));
        await settle(tester);
        expect(find.widgetWithText(ListTile, 'IE00B4L5Y983'), findsOneWidget);
        expect(find.widgetWithText(ListTile, 'World'), findsOneWidget);
        expect(find.widgetWithText(ListTile, language == 'it' ? '60,00%' : '60.00%'), findsOneWidget);

        // The pillar dialog's picker: name first, then the same summary.
        await tester.tap(find.widgetWithText(Tab, s.pillarTabPillars));
        await settle(tester);
        await tester.tap(find.byType(FloatingActionButton));
        await settle(tester);
        await tester.tap(find.descendant(of: find.byType(PillarCreateDialog), matching: find.text(s.portfolioModelNone)));
        await settle(tester);
        for (final label in pickerLabels) {
          expect(find.text(label), findsWidgets, reason: label);
        }
      } finally {
        await unmount(tester);
      }
    });
  }
}
