// Pillars screen lists:
// - pin (before the built-in grouping moved onto buildPortfolioModelTreeData):
//   built-in models nest year → variant → equity → model, each level in
//   ascending order, Mini before Full; the custom models follow in their order;
// - every model tile is the reference collapsible (cashflow_tab.dart): w600
//   title at the tile's size, bodySmall subtitle, the default chevron, no card
//   and no custom trailing — a custom model is edited from its expanded rows;
// - the pillar and model lists pull to refresh; no model at all shows the
//   shared empty state;
// - a model row's target weight is spelled in the locale ("12,50%");
// - a pillar, a virtual portfolio and a custom model swipe to delete, asking
//   the confirmation of their detail view (a built-in model does not swipe);
//   a custom model's dialog has the trashcan in its title row.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/pillars/pillar_performance.dart';
import 'package:finance_copilot/services/pillars/pillar_service.dart';
import 'package:finance_copilot/services/portfolio/portfolio_model_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show AllSeriesData, allSeriesDataProvider;
import 'package:finance_copilot/ui/screens/pillars/pillars_screen.dart';
import 'package:finance_copilot/ui/screens/pillars/portfolio_model_dialog.dart';
import 'package:finance_copilot/ui/widgets/empty_state.dart';
import 'package:finance_copilot/ui/widgets/mobile_pull_to_refresh.dart';

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
  bool builtIn = true,
  int? year,
  int? equity,
  PortfolioModelVariant variant = PortfolioModelVariant.custom,
  int sortOrder = 0,
}) => PortfolioModel(
  id: id,
  name: name,
  isBuiltIn: builtIn,
  year: year,
  equityPercent: equity,
  variant: variant,
  sortOrder: sortOrder,
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2025, 1, 1),
);

void main() {
  late AppDatabase db;

  // In the order the service lists them: sort order, then name.
  final models = [
    _model('f25', 'Full 60 A', year: 2025, equity: 60, variant: PortfolioModelVariant.full),
    _model('f24', 'Full 40', year: 2024, equity: 40, variant: PortfolioModelVariant.full),
    _model('m24b', 'Mini 60 B', year: 2024, equity: 60, variant: PortfolioModelVariant.mini),
    _model('m24a', 'Mini 60 A', year: 2024, equity: 60, variant: PortfolioModelVariant.mini),
    _model('m24c', 'Mini 80', year: 2024, equity: 80, variant: PortfolioModelVariant.mini),
    _model('ca', 'Alpha', builtIn: false, sortOrder: 1),
    _model('cb', 'Beta', builtIn: false, sortOrder: 2),
  ];
  final items = {
    for (final m in models) m.id: const <PortfolioModelItem>[],
    'm24a': [const PortfolioModelItem(id: 1, modelId: 'm24a', isin: 'IE00B4L5Y983', targetWeight: 60, description: 'World', sortOrder: 0)],
    'ca': [const PortfolioModelItem(id: 2, modelId: 'ca', isin: 'IE00BKM4GZ66', targetWeight: 12.5, description: 'Emerging', sortOrder: 0)],
  };

  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('it');
  });
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  /// The Pillars screen on [db]; [fixed] replaces the models and their rows
  /// with the list above, [language] picks the strings and the locale.
  Future<void> pumpScreen(WidgetTester tester, {bool fixed = false, String language = 'en', List<Override> overrides = const []}) async {
    // Wide enough for the model labels in the test font.
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          portableLanguageProvider.overrideWith((ref) => language),
          appLocaleProvider.overrideWith((ref) => Stream.value(language == 'it' ? 'it_IT' : 'en_US')),
          marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
          allSeriesDataProvider.overrideWithValue(const AsyncData<AllSeriesData?>(null)),
          pillarPerformanceSnapshotsProvider.overrideWithValue(const AsyncData(<String, PillarPerformanceSnapshot>{})),
          privacyModeProvider.overrideWith((ref) => false),
          if (fixed) ...[
            portfolioModelsProvider.overrideWithValue(AsyncData(models)),
            portfolioModelItemsProvider.overrideWith((ref, id) => Stream.value(items[id] ?? const [])),
          ],
          ...overrides,
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

  Future<void> openModelsTab(WidgetTester tester, AppStrings s) async {
    await tester.tap(find.widgetWithText(Tab, s.pillarTabPortfolioModels));
    await settle(tester);
  }

  double top(WidgetTester tester, String text) => tester.getTopLeft(find.text(text).first).dy;

  Finder tileOf(String title) => find.ancestor(of: find.text(title), matching: find.byType(ExpansionTile)).first;

  Future<void> expand(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await settle(tester);
  }

  group('portfolio models tab', () {
    const s = AppStrings.en;

    testWidgets('pin: built-in year → variant → equity → model, ascending, Mini before Full; custom models after, in order', (tester) async {
      await pumpScreen(tester, fixed: true);
      try {
        await openModelsTab(tester, s);
        expect(top(tester, s.portfolioModelsBuiltIn), lessThan(top(tester, '2024')));
        expect(top(tester, '2024'), lessThan(top(tester, '2025')));
        expect(top(tester, '2025'), lessThan(top(tester, s.portfolioModelsCustom)));
        expect(top(tester, s.portfolioModelsCustom), lessThan(top(tester, 'Alpha')));
        expect(top(tester, 'Alpha'), lessThan(top(tester, 'Beta')));
        expect(find.text(s.portfolioModelMini), findsNothing, reason: 'the years start collapsed');

        await expand(tester, '2024');
        expect(top(tester, s.portfolioModelMini), lessThan(top(tester, s.portfolioModelFull)));
        await expand(tester, s.portfolioModelMini);
        expect(top(tester, '60%'), lessThan(top(tester, '80%')));
        await expand(tester, '60%');
        expect(top(tester, 'Mini 60 A'), lessThan(top(tester, 'Mini 60 B')));
        expect(find.text('Mini 80'), findsNothing, reason: 'under its own equity');
        expect(find.text('Full 60 A'), findsNothing, reason: 'under 2025, still collapsed');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('every model tile is the reference collapsible, without a card or a custom trailing', (tester) async {
      await pumpScreen(tester, fixed: true);
      try {
        await openModelsTab(tester, s);
        await expand(tester, '2024');
        await expand(tester, s.portfolioModelMini);
        await expand(tester, '60%');
        final subtitles = {'Mini 60 A': 'Year 2024 · 60% equity · Mini', 'Alpha': s.portfolioModelCustom};
        for (final title in ['2024', s.portfolioModelMini, '60%', 'Mini 60 A', 'Alpha']) {
          final tile = tester.widget<ExpansionTile>(tileOf(title));
          expect(tile.trailing, isNull, reason: '"$title": the default rotating chevron');
          expect(tile.showTrailingIcon, isTrue, reason: '"$title"');
          expect(tile.dense, isNot(isTrue), reason: '"$title"');
          final style = tester.widget<Text>(find.text(title)).style;
          expect(style?.fontWeight, FontWeight.w600, reason: '"$title": the reference title weight');
          expect(style?.fontSize, isNull, reason: '"$title": the tile\'s own size');
          expect(
            find.ancestor(of: tileOf(title), matching: find.byType(Card)),
            findsNothing,
            reason: '"$title": no card',
          );
          final subtitle = subtitles[title];
          if (subtitle != null) {
            final text = find.descendant(of: tileOf(title), matching: find.text(subtitle)).first;
            expect(tester.widget<Text>(text).style, Theme.of(tester.element(text)).textTheme.bodySmall, reason: '"$subtitle"');
          }
        }
        expect(
          find.descendant(of: tileOf('Alpha'), matching: find.byType(IconButton)),
          findsNothing,
          reason: 'no row buttons',
        );
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a custom model is edited from its expanded rows', (tester) async {
      await pumpScreen(tester, fixed: true);
      try {
        await openModelsTab(tester, s);
        await expand(tester, 'Alpha');
        await tester.tap(find.descendant(of: tileOf('Alpha'), matching: find.widgetWithText(TextButton, s.edit)));
        await settle(tester);
        final dialog = tester.widget<PortfolioModelDialog>(find.byType(PortfolioModelDialog));
        expect(dialog.existing?.id, 'ca');
        expect(find.widgetWithText(AlertDialog, s.portfolioModelEditTitle), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });

    for (final (language, weight) in [('en', '12.50%'), ('it', '12,50%')]) {
      testWidgets('$language: a model row\'s target weight is spelled in the locale', (tester) async {
        final s = AppStrings.of(language);
        await pumpScreen(tester, fixed: true, language: language);
        try {
          await openModelsTab(tester, s);
          await expand(tester, 'Alpha');
          expect(find.widgetWithText(ListTile, weight), findsOneWidget);
        } finally {
          await unmount(tester);
        }
      });
    }

    testWidgets('no model at all: the shared empty state', (tester) async {
      await pumpScreen(tester, overrides: [portfolioModelsProvider.overrideWithValue(const AsyncData(<PortfolioModel>[]))]);
      try {
        await openModelsTab(tester, s);
        expect(find.widgetWithText(EmptyState, s.portfolioModelsEmpty), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('the model list pulls to refresh', (tester) async {
      await pumpScreen(tester, fixed: true);
      try {
        await openModelsTab(tester, s);
        final header = find.text(s.portfolioModelsBuiltIn);
        expect(find.ancestor(of: header, matching: find.byType(MobilePullToRefresh)), findsOneWidget);
        expect(
          tester.widget<ListView>(find.ancestor(of: header, matching: find.byType(ListView)).first).physics,
          isA<AlwaysScrollableScrollPhysics>(),
        );
      } finally {
        await unmount(tester);
      }
    });
  });

  group('swipe to delete', () {
    const s = AppStrings.en;

    /// The open confirmation: [content], Delete in red (as the detail view
    /// and every other delete ask).
    void expectConfirm(WidgetTester tester, String content) {
      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget, reason: 'a swipe asks first');
      final alert = tester.widget<AlertDialog>(dialog);
      expect((alert.title! as Text).data, s.delete);
      expect((alert.content! as Text).data, content);
      expect(
        tester
            .widget<FilledButton>(find.descendant(of: dialog, matching: find.widgetWithText(FilledButton, s.delete)))
            .style
            ?.backgroundColor
            ?.resolve({}),
        Colors.red,
      );
    }

    Future<void> swipe(WidgetTester tester, String text) async {
      await tester.drag(find.text(text), const Offset(-1500, 0));
      await settle(tester);
    }

    /// The models straight from the database, without the catalog seeding
    /// (asset loading), plus one built-in model row.
    Future<List<Override>> modelsFromDb() async {
      await db
          .into(db.portfolioModels)
          .insert(
            PortfolioModelsCompanion.insert(
              id: 'builtin_2026_60',
              name: 'Built-in 60',
              variant: PortfolioModelVariant.mini,
              isBuiltIn: const Value(true),
              year: const Value(2026),
              equityPercent: const Value(60),
            ),
          );
      return [portfolioModelsProvider.overrideWith((ref) => ref.watch(portfolioModelServiceProvider).watchAll())];
    }

    testWidgets('a pillar and a virtual portfolio: Cancel keeps them, Delete removes them', (tester) async {
      final pillars = PillarService(db);
      await pillars.create(name: 'Retirement');
      await pillars.create(name: 'Play money', kind: PillarKind.virtual);
      await pumpScreen(tester);
      try {
        expect(find.ancestor(of: find.text('Retirement'), matching: find.byType(MobilePullToRefresh)), findsOneWidget);
        expect(
          tester.widget<ListView>(find.ancestor(of: find.text('Retirement'), matching: find.byType(ListView)).first).physics,
          isA<AlwaysScrollableScrollPhysics>(),
          reason: 'the pillar list pulls to refresh',
        );

        await swipe(tester, 'Retirement');
        expectConfirm(tester, s.pillarDeleteConfirm);
        await tester.tap(find.widgetWithText(TextButton, s.cancel));
        await settle(tester);
        expect(find.text('Retirement'), findsOneWidget);
        expect(await pillars.getAll(), hasLength(2));

        await swipe(tester, 'Retirement');
        await tester.tap(find.widgetWithText(FilledButton, s.delete));
        await settle(tester);
        expect((await pillars.getAll()).map((p) => p.name), ['Play money']);

        await tester.tap(find.widgetWithText(Tab, s.pillarTabVirtualPortfolios));
        await settle(tester);
        await swipe(tester, 'Play money');
        expectConfirm(tester, s.virtualPortfolioDeleteConfirm);
        await tester.tap(find.widgetWithText(FilledButton, s.delete));
        await settle(tester);
        expect(await pillars.getAll(), isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a custom model: Cancel keeps it, Delete removes it; a built-in model does not swipe', (tester) async {
      final service = PortfolioModelService(db);
      final id = await service.createCustomModel(
        name: 'My model',
        items: const [PortfolioModelInputItem(isin: 'IE00B4L5Y983', targetWeight: 100, description: 'World')],
      );
      await pumpScreen(tester, overrides: await modelsFromDb());
      try {
        await openModelsTab(tester, s);
        expect(
          find.ancestor(of: find.text('2026'), matching: find.byType(Dismissible)),
          findsNothing,
          reason: 'built-in models are read-only',
        );

        await swipe(tester, 'My model');
        expectConfirm(tester, s.portfolioModelDeleteConfirm);
        await tester.tap(find.widgetWithText(TextButton, s.cancel));
        await settle(tester);
        expect(find.text('My model'), findsOneWidget);
        expect(await service.getById(id), isNotNull);

        await swipe(tester, 'My model');
        await tester.tap(find.widgetWithText(FilledButton, s.delete));
        await settle(tester);
        expect(await service.getById(id), isNull);
        expect(find.text('My model'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a custom model\'s dialog has the trashcan in its title row: Cancel keeps it, Delete removes it and closes', (tester) async {
      final service = PortfolioModelService(db);
      final id = await service.createCustomModel(
        name: 'My model',
        items: const [PortfolioModelInputItem(isin: 'IE00B4L5Y983', targetWeight: 100, description: 'World')],
      );
      await pumpScreen(tester, overrides: await modelsFromDb());
      try {
        await openModelsTab(tester, s);
        await expand(tester, 'My model');
        await tester.tap(find.descendant(of: tileOf('My model'), matching: find.widgetWithText(TextButton, s.edit)));
        await settle(tester);
        final trashcan = find.byKey(const Key('portfolioModelDeleteButton'));
        expect(trashcan, findsOneWidget);
        expect(tester.widget<IconButton>(trashcan).tooltip, s.delete);
        final title = (tester.widget<AlertDialog>(find.byType(AlertDialog)).title! as Row);
        expect(
          find.descendant(of: find.byWidget(title), matching: trashcan),
          findsOneWidget,
          reason: 'in the title row',
        );

        await tester.tap(trashcan);
        await settle(tester);
        final confirm = find.widgetWithText(AlertDialog, s.portfolioModelDeleteConfirm);
        expect(confirm, findsOneWidget);
        await tester.tap(find.descendant(of: confirm, matching: find.widgetWithText(TextButton, s.cancel)));
        await settle(tester);
        expect(find.byType(PortfolioModelDialog), findsOneWidget, reason: 'the dialog stays open');
        expect(await service.getById(id), isNotNull);

        await tester.tap(trashcan);
        await settle(tester);
        await tester.tap(find.widgetWithText(FilledButton, s.delete));
        await settle(tester);
        expect(await service.getById(id), isNull);
        expect(find.byType(PortfolioModelDialog), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a new model\'s dialog has no trashcan', (tester) async {
      await pumpScreen(tester, overrides: await modelsFromDb());
      try {
        await openModelsTab(tester, s);
        await tester.tap(find.byType(FloatingActionButton));
        await settle(tester);
        expect(find.byType(PortfolioModelDialog), findsOneWidget);
        expect(find.byKey(const Key('portfolioModelDeleteButton')), findsNothing);
      } finally {
        await unmount(tester);
      }
    });
  });
}
