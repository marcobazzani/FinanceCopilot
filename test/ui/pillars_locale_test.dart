// Pillars under a comma-decimal locale: the target / current / divergence
// weights of the pillar detail, the before → after weights of the rebalance
// preview and the weight total of the portfolio model dialog are spelled in the
// active locale ("60,00%" in it_IT, not "60.00%"); the whole-number progress of
// a pillar card reads the same. English reads as before.
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
import 'package:finance_copilot/services/domain/asset_event_service.dart';
import 'package:finance_copilot/services/pillars/pillar_performance.dart';
import 'package:finance_copilot/services/pillars/pillar_service.dart';
import 'package:finance_copilot/services/portfolio/portfolio_rebalance_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show AllSeriesData, allSeriesDataProvider;
import 'package:finance_copilot/ui/screens/pillars/pillar_detail_screen.dart';
import 'package:finance_copilot/ui/screens/pillars/pillars_screen.dart';
import 'package:finance_copilot/ui/screens/pillars/portfolio_model_dialog.dart';
import 'package:finance_copilot/ui/screens/pillars/rebalance_preview_dialog.dart';

final _draft = PortfolioRebalanceDraft(
  mode: PortfolioRebalanceMode.sellAndBuy,
  scope: const PortfolioRebalanceScope.currentPillar('pillar-1'),
  baseCurrency: 'EUR',
  rows: const [
    PortfolioRebalanceDraftRow(
      pillarId: 'pillar-1',
      pillarName: 'Growth',
      assetId: 1,
      assetName: 'World ETF',
      isin: null,
      type: EventType.buy,
      amount: 1234.5,
      baseAmount: 1234.5,
      estimatedQuantity: 12,
      price: 100,
      currency: 'EUR',
      fxRate: 1,
      estimatedTax: 0,
      currentBaseValue: 2000,
      projectedBaseValue: 3234.5,
      notes: '',
    ),
  ],
  unresolved: const [],
  availableCashBase: 1000,
  targetBuyBase: 980,
  executedBuyBase: 950,
  buyShortfallBase: 30,
  leftoverCashBase: 50,
  currentPortfolioValueBase: 5000,
  projectedPortfolioValueBase: 6234.5,
);

class _FakeRebalanceService extends PortfolioRebalanceService {
  _FakeRebalanceService(super.db);

  @override
  Stream<PortfolioRebalanceDraft> buildDraftStream({
    required PortfolioRebalanceScope scope,
    required PortfolioRebalanceMode mode,
    double contributionAmount = 0,
    DateTime? asOf,
  }) => Stream.value(_draft);

  @override
  Future<List<int>> applyDraft(PortfolioRebalanceDraft draft, AssetEventService eventService, {DateTime? date}) async => const [];
}

PillarPerformanceSnapshot _snapshot(double marketValue) => PillarPerformanceSnapshot(
  asOfDate: DateTime(2026, 3, 10),
  marketValue: marketValue,
  netInvested: marketValue,
  absoluteReturnAmount: 0,
  absoluteReturnPct: 0,
  twrr: null,
  cagr: null,
  hasSufficientHistory: false,
);

void main() {
  late AppDatabase db;

  setUpAll(() async => initializeDateFormatting());
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  String localeOf(String language) => language == 'it' ? 'it_IT' : 'en_US';

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<int> seedAsset(String ticker, String isin) async {
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker $ticker'));
    final id = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: '$ticker fund',
            ticker: Value(ticker),
            isin: Value(isin),
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
            date: DateTime(2025, 1, 1),
            valueDate: DateTime(2025, 1, 1),
            type: EventType.buy,
            amount: 100,
            quantity: const Value(10),
            price: const Value(10),
          ),
        );
    return id;
  }

  for (final (language, sixty, seventyFive, fifteen, forty) in [
    ('en', '60.00', '75.00', '15.00', '40.00'),
    ('it', '60,00', '75,00', '15,00', '40,00'),
  ]) {
    testWidgets('$language: pillar detail — target, current and divergence weights', (tester) async {
      final s = AppStrings.of(language);
      final em = await seedAsset('EM', 'IE00BKM4GZ66');
      final gold = await seedAsset('GOLD', 'IE00B4ND3602');
      final pillarId = await PillarService(db).create(name: 'Retirement');
      await PillarService(db).assign(pillarId: pillarId, assetId: em, qty: 10);
      await PillarService(db).assign(pillarId: pillarId, assetId: gold, qty: 10);
      final pillar = (await PillarService(db).getById(pillarId))!.copyWith(portfolioModelId: const Value('model-1'));
      final targets = [
        PortfolioModelItem(id: 1, modelId: 'model-1', isin: 'IE00BKM4GZ66', targetWeight: 60, description: 'EM', sortOrder: 0),
        PortfolioModelItem(id: 2, modelId: 'model-1', isin: 'IE00B3RBWM25', targetWeight: 40, description: 'World', sortOrder: 1),
      ];
      final assets = await db.select(db.assets).get();
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            portableLanguageProvider.overrideWith((ref) => language),
            appLocaleProvider.overrideWith((ref) => Stream.value(localeOf(language))),
            baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
            pillarsProvider.overrideWithValue(AsyncData([pillar])),
            standardPillarsProvider.overrideWithValue(AsyncData([pillar])),
            virtualPortfoliosProvider.overrideWithValue(const AsyncData([])),
            activeAssetsProvider.overrideWithValue(AsyncData(assets)),
            assetsProvider.overrideWithValue(AsyncData(assets)),
            pillarAssetsProvider.overrideWithValue(const AsyncData([])),
            assetMarketValuesProvider.overrideWithValue(AsyncData({em: 7500, gold: 2500})),
            unassignedFractionProvider.overrideWithValue(const AsyncData({})),
            allSeriesDataProvider.overrideWithValue(const AsyncData<AllSeriesData?>(null)),
            pillarPerformanceSnapshotsProvider.overrideWithValue(const AsyncData({})),
            portfolioModelItemsProvider.overrideWith((ref, modelId) => Stream.value(targets)),
            privacyModeProvider.overrideWith((ref) => false),
          ],
          child: MaterialApp(home: PillarDetailScreen(pillarId: pillarId)),
        ),
      );
      await tester.pumpAndSettle();
      try {
        expect(
          find.text(
            '${s.portfolioDivergenceTarget}: $sixty% · ${s.portfolioDivergenceCurrent}: $seventyFive% · ${s.portfolioDivergenceDelta}: $fifteen%',
          ),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(find.text(s.portfolioUnmatchedRows), 200, scrollable: find.byType(Scrollable).last);
        await tester.pumpAndSettle();
        expect(find.widgetWithText(ListTile, '${s.portfolioDivergenceTarget}: $forty%'), findsOneWidget, reason: 'a model row not held');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('$language: rebalance preview — before → after weights', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            portableLanguageProvider.overrideWith((ref) => language),
            appLocaleProvider.overrideWith((ref) => Stream.value(localeOf(language))),
            portfolioRebalanceServiceProvider.overrideWithValue(_FakeRebalanceService(db)),
            privacyModeProvider.overrideWith((ref) => false),
          ],
          child: const MaterialApp(
            home: Scaffold(body: RebalancePreviewDialog(pillarId: 'pillar-1')),
          ),
        ),
      );
      await settle(tester);
      try {
        final weights = language == 'it' ? '40,00% → 51,88%' : '40.00% → 51.88%';
        expect(find.textContaining(weights), findsOneWidget, reason: '2,000 of 5,000 → 3,234.50 of 6,234.50');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('$language: portfolio model dialog — the weight total', (tester) async {
      final s = AppStrings.of(language);
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            portableLanguageProvider.overrideWith((ref) => language),
            appLocaleProvider.overrideWith((ref) => Stream.value(localeOf(language))),
          ],
          child: const MaterialApp(home: Scaffold(body: PortfolioModelDialog())),
        ),
      );
      await settle(tester);
      try {
        final weight = find.descendant(of: find.byType(PortfolioModelDialog), matching: find.byType(TextField)).at(2);
        await tester.enterText(weight, language == 'it' ? '37,5' : '37.5');
        await settle(tester);
        expect(find.text(s.portfolioModelWeightTotal(language == 'it' ? '37,50' : '37.50')), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('$language: pillar card — the whole-number progress toward the target', (tester) async {
      final id = await PillarService(db).create(name: 'Retirement', targetValue: 100000);
      final pillar = (await PillarService(db).getById(id))!;
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            portableLanguageProvider.overrideWith((ref) => language),
            appLocaleProvider.overrideWith((ref) => Stream.value(localeOf(language))),
            baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
            pillarsProvider.overrideWithValue(AsyncData([pillar])),
            standardPillarsProvider.overrideWithValue(AsyncData([pillar])),
            virtualPortfoliosProvider.overrideWithValue(const AsyncData([])),
            activeAssetsProvider.overrideWithValue(const AsyncData([])),
            assetsProvider.overrideWithValue(const AsyncData([])),
            pillarAssetsProvider.overrideWithValue(const AsyncData([])),
            assetMarketValuesProvider.overrideWithValue(const AsyncData({})),
            unassignedFractionProvider.overrideWithValue(const AsyncData({})),
            allSeriesDataProvider.overrideWithValue(const AsyncData<AllSeriesData?>(null)),
            pillarPerformanceSnapshotsProvider.overrideWithValue(AsyncData({pillar.id: _snapshot(45000)})),
            privacyModeProvider.overrideWith((ref) => false),
          ],
          child: const MaterialApp(home: PillarsScreen()),
        ),
      );
      await settle(tester);
      try {
        expect(find.text('45% · '), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });
  }
}
