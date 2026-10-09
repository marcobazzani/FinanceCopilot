// Pins the portfolio model tiles of the Pillars screen: a built-in model and a
// custom one are the same collapsible — its rows (ISIN, description, target
// weight) when expanded, indented like every level of the tree — but a
// built-in model is read-only (its own icon, no action), while a custom one
// has its icon and, after its rows, the action that edits it.
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
import 'package:finance_copilot/services/pillars/pillar_performance.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show AllSeriesData, allSeriesDataProvider;
import 'package:finance_copilot/ui/screens/pillars/pillars_screen.dart';

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};

  @override
  Future<void> syncPrices({bool forceToday = false}) async {}
}

PortfolioModel _model(
  String id,
  String name, {
  required bool builtIn,
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
  const s = AppStrings.en;
  late AppDatabase db;

  final models = [
    _model('m24', 'Mini 60', builtIn: true, year: 2024, equity: 60, variant: PortfolioModelVariant.mini),
    _model('ca', 'Alpha', builtIn: false),
  ];
  final items = {
    'm24': [const PortfolioModelItem(id: 1, modelId: 'm24', isin: 'IE00B4L5Y983', targetWeight: 60, description: 'World', sortOrder: 0)],
    'ca': [const PortfolioModelItem(id: 2, modelId: 'ca', isin: 'IE00BKM4GZ66', targetWeight: 12.5, description: 'Emerging', sortOrder: 0)],
  };

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Finder tileOf(String title) => find.ancestor(of: find.text(title), matching: find.byType(ExpansionTile)).first;

  Future<void> expand(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await settle(tester);
  }

  testWidgets('a built-in model lists its rows and offers nothing; a custom one lists its rows, then Edit', (tester) async {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          portableLanguageProvider.overrideWith((ref) => 'en'),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
          allSeriesDataProvider.overrideWithValue(const AsyncData<AllSeriesData?>(null)),
          pillarPerformanceSnapshotsProvider.overrideWithValue(const AsyncData(<String, PillarPerformanceSnapshot>{})),
          privacyModeProvider.overrideWith((ref) => false),
          portfolioModelsProvider.overrideWithValue(AsyncData(models)),
          portfolioModelItemsProvider.overrideWith((ref, id) => Stream.value(items[id] ?? const [])),
        ],
        child: const MaterialApp(home: PillarsScreen()),
      ),
    );
    await settle(tester);
    try {
      await tester.tap(find.widgetWithText(Tab, s.pillarTabPortfolioModels));
      await settle(tester);
      for (final title in ['2024', s.portfolioModelMini, '60%', 'Mini 60', 'Alpha']) {
        await expand(tester, title);
      }

      void expectRows(String model, List<String> row) {
        final tile = tester.widget<ExpansionTile>(tileOf(model));
        expect(tile.childrenPadding, const EdgeInsetsDirectional.only(start: 16), reason: model);
        for (final text in row) {
          expect(
            find.descendant(of: tileOf(model), matching: find.widgetWithText(ListTile, text)),
            findsOneWidget,
            reason: '$model: $text',
          );
        }
      }

      expectRows('Mini 60', ['IE00B4L5Y983', 'World', '60.00%']);
      expect((tester.widget<ExpansionTile>(tileOf('Mini 60')).leading! as Icon).icon, Icons.inventory_2_outlined);
      expect(
        find.descendant(of: tileOf('Mini 60'), matching: find.byType(TextButton)),
        findsNothing,
        reason: 'built-in: read-only',
      );

      expectRows('Alpha', ['IE00BKM4GZ66', 'Emerging', '12.50%']);
      expect((tester.widget<ExpansionTile>(tileOf('Alpha')).leading! as Icon).icon, Icons.tune);
      final edit = find.descendant(of: tileOf('Alpha'), matching: find.widgetWithText(TextButton, s.edit));
      expect(edit, findsOneWidget);
      expect(find.descendant(of: edit, matching: find.byIcon(Icons.edit)), findsOneWidget);
      final align = tester.widget<Align>(find.ancestor(of: edit, matching: find.byType(Align)).first);
      expect(align.alignment, AlignmentDirectional.centerEnd);
      expect(
        tester.getTopLeft(edit).dy,
        greaterThan(tester.getTopLeft(find.text('Emerging')).dy),
        reason: 'the action follows the rows',
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}
