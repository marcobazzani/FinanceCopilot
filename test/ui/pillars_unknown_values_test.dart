// Pillars: a figure that is not known is a dash, never 0; a value left out of
// a total is counted under it; and a target stored in another currency is
// converted at the stored exchange rate before the progress is measured —
// without a rate there is no progress to show.
//
// Pinned bugs:
//  * The Unassigned card summed only the assets with a price and exchange
//    rate but counted them all, without saying some were left out.
//  * A pillar card read 0.00 EUR while its performance was loading or failed.
//  * The progress bar divided a base-currency value by a target in its own
//    currency: 45,000 EUR against a 100,000 USD target read 45%.
//  * A held asset without a price, off the model portfolio, read 0.00 EUR in
//    the extra holdings.
import 'package:drift/drift.dart' hide isNotNull, isNull;
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
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show AllSeriesData, allSeriesDataProvider;
import 'package:finance_copilot/ui/screens/pillars/pillar_detail_screen.dart';
import 'package:finance_copilot/ui/screens/pillars/pillars_screen.dart';

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
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
  const s = AppStrings.en;
  final today = DateTime(2026, 3, 10);
  late AppDatabase db;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
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

  Future<void> storeRate(String from, String to, double rate) => db
      .into(db.exchangeRates)
      .insert(ExchangeRatesCompanion.insert(fromCurrency: from, toCurrency: to, date: DateTime(2026, 3, 9), rate: rate));

  Future<Pillar> seedPillar({double? target, String currency = 'EUR'}) async {
    final id = await PillarService(db).create(name: 'Retirement', targetValue: target, targetCurrency: currency);
    return (await PillarService(db).getById(id))!;
  }

  Future<void> pumpList(
    WidgetTester tester, {
    required List<Pillar> pillars,
    AsyncValue<Map<String, PillarPerformanceSnapshot>> performance = const AsyncData({}),
    Map<int, double> unassigned = const {},
    Map<int, double> marketValues = const {},
  }) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          databaseProvider.overrideWithValue(db),
          nowProvider.overrideWithValue(() => today.add(const Duration(hours: 12))),
          marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
          appLocaleProvider.overrideWith((ref) => Stream.value('en')),
          baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
          pillarsProvider.overrideWithValue(AsyncData(pillars)),
          standardPillarsProvider.overrideWithValue(AsyncData(pillars)),
          virtualPortfoliosProvider.overrideWithValue(const AsyncData([])),
          activeAssetsProvider.overrideWithValue(const AsyncData([])),
          assetsProvider.overrideWithValue(const AsyncData([])),
          pillarAssetsProvider.overrideWithValue(const AsyncData([])),
          assetMarketValuesProvider.overrideWithValue(AsyncData(marketValues)),
          unassignedFractionProvider.overrideWithValue(AsyncData(unassigned)),
          allSeriesDataProvider.overrideWithValue(const AsyncData<AllSeriesData?>(null)),
          pillarPerformanceSnapshotsProvider.overrideWithValue(performance),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: const MaterialApp(home: PillarsScreen()),
      ),
    );
    await settle(tester);
  }

  group('Unassigned card', () {
    testWidgets('assets without a price or exchange rate are left out of its value and counted under it', (tester) async {
      final pillar = await seedPillar();
      // Asset 1 priced (fully unassigned), asset 2 unpriced (half unassigned),
      // asset 3 fully assigned elsewhere.
      await pumpList(tester, pillars: [pillar], unassigned: {1: 1.0, 2: 0.5, 3: 0.0}, marketValues: {1: 1000, 3: 500});
      try {
        final card = find.ancestor(of: find.text(s.pillarUnassigned), matching: find.byType(Card));
        expect(find.descendant(of: card, matching: find.text('1,000.00 EUR')), findsOneWidget);
        expect(find.descendant(of: card, matching: find.text(' · ${s.pillarAssetCount(2)}')), findsOneWidget);
        expect(find.descendant(of: card, matching: find.text(s.pillarUnpricedExcluded(1))), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('only unpriced assets: a dash for the value, not a hidden card', (tester) async {
      final pillar = await seedPillar();
      await pumpList(tester, pillars: [pillar], unassigned: {2: 1.0}, marketValues: const {});
      try {
        final card = find.ancestor(of: find.text(s.pillarUnassigned), matching: find.byType(Card));
        expect(card, findsOneWidget);
        expect(find.descendant(of: card, matching: find.text('—')), findsOneWidget);
        expect(find.descendant(of: card, matching: find.text(s.pillarUnpricedExcluded(1))), findsOneWidget);
        expect(find.descendant(of: card, matching: find.textContaining('0.00')), findsNothing);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('every asset priced: no footnote', (tester) async {
      final pillar = await seedPillar();
      await pumpList(tester, pillars: [pillar], unassigned: {1: 1.0}, marketValues: {1: 1000});
      try {
        expect(find.text('1,000.00 EUR'), findsOneWidget);
        expect(find.textContaining('excluded'), findsNothing);
      } finally {
        await unmount(tester);
      }
    });
  });

  group('pillar card value', () {
    for (final (label, performance) in [
      ('loading', const AsyncLoading<Map<String, PillarPerformanceSnapshot>>()),
      ('failed', AsyncError<Map<String, PillarPerformanceSnapshot>>(StateError('boom'), StackTrace.empty)),
    ]) {
      testWidgets('performance $label: a dash, not 0.00 EUR', (tester) async {
        final pillar = await seedPillar(target: 1000);
        await pumpList(tester, pillars: [pillar], performance: performance);
        try {
          expect(find.textContaining('0.00 EUR'), findsNothing);
          final card = find.ancestor(of: find.text('Retirement'), matching: find.byType(Card));
          expect(find.descendant(of: card, matching: find.text('—')), findsWidgets);
          expect(find.byType(LinearProgressIndicator), findsNothing, reason: 'no progress against an unknown value');
        } finally {
          await unmount(tester);
        }
      });
    }
  });

  group('target progress on the pillar card', () {
    Finder progressLabel(String text) => find.text(text);

    testWidgets('a USD target on a EUR book is converted at the stored rate', (tester) async {
      await storeRate('USD', 'EUR', 0.9);
      final pillar = await seedPillar(target: 100000, currency: 'USD');
      await pumpList(tester, pillars: [pillar], performance: AsyncData({pillar.id: _snapshot(45000)}));
      try {
        // 100,000 USD × 0.9 = 90,000 EUR; 45,000 / 90,000 = 50%.
        expect(progressLabel('50% · '), findsOneWidget);
        expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, 0.5);
        expect(find.text(s.pillarTarget(r'$100,000.00')), findsOneWidget, reason: 'the target keeps its own currency');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('without a stored rate there is no progress: a dash, no bar', (tester) async {
      final pillar = await seedPillar(target: 100000, currency: 'USD');
      await pumpList(tester, pillars: [pillar], performance: AsyncData({pillar.id: _snapshot(45000)}));
      try {
        expect(progressLabel('— · '), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.textContaining('45%'), findsNothing, reason: 'never compared across currencies');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a target in the base currency needs no rate', (tester) async {
      final pillar = await seedPillar(target: 100000);
      await pumpList(tester, pillars: [pillar], performance: AsyncData({pillar.id: _snapshot(45000)}));
      try {
        expect(progressLabel('45% · '), findsOneWidget);
        expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, 0.45);
      } finally {
        await unmount(tester);
      }
    });
  });

  group('pillar detail', () {
    Future<int> seedHeldAsset(String ticker, {String? isin}) async {
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

    Future<void> pumpDetail(
      WidgetTester tester,
      Pillar pillar,
      Map<int, double> marketValues, {
      List<PortfolioModelItem> modelItems = const [],
    }) async {
      final assets = await db.select(db.assets).get();
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            databaseProvider.overrideWithValue(db),
            nowProvider.overrideWithValue(() => today.add(const Duration(hours: 12))),
            marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
            appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
            baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
            pillarsProvider.overrideWithValue(AsyncData([pillar])),
            standardPillarsProvider.overrideWithValue(AsyncData([pillar])),
            virtualPortfoliosProvider.overrideWithValue(const AsyncData([])),
            activeAssetsProvider.overrideWithValue(AsyncData(assets)),
            assetsProvider.overrideWithValue(AsyncData(assets)),
            pillarAssetsProvider.overrideWithValue(const AsyncData([])),
            assetMarketValuesProvider.overrideWithValue(AsyncData(marketValues)),
            unassignedFractionProvider.overrideWithValue(const AsyncData({})),
            allSeriesDataProvider.overrideWithValue(const AsyncData<AllSeriesData?>(null)),
            pillarPerformanceSnapshotsProvider.overrideWithValue(const AsyncData({})),
            if (modelItems.isNotEmpty) portfolioModelItemsProvider.overrideWith((ref, modelId) => Stream.value(modelItems)),
            privacyModeProvider.overrideWith((ref) => false),
          ],
          child: MaterialApp(home: PillarDetailScreen(pillarId: pillar.id)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('objective: a USD target is converted before the progress is measured', (tester) async {
      await storeRate('USD', 'EUR', 0.9);
      final id = await seedHeldAsset('EM');
      final pillar = await seedPillar(target: 20000, currency: 'USD');
      await PillarService(db).assign(pillarId: pillar.id, assetId: id, qty: 10);
      await pumpDetail(tester, pillar, {id: 9000});
      try {
        // 20,000 USD × 0.9 = 18,000 EUR; 9,000 / 18,000 = 0.5.
        expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, 0.5);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('objective: no stored rate, no progress bar — a dash', (tester) async {
      final id = await seedHeldAsset('EM');
      final pillar = await seedPillar(target: 20000, currency: 'USD');
      await PillarService(db).assign(pillarId: pillar.id, assetId: id, qty: 10);
      await pumpDetail(tester, pillar, {id: 9000});
      try {
        expect(find.byType(LinearProgressIndicator), findsNothing);
        final objective = find.ancestor(of: find.text(s.pillarObjective), matching: find.byType(Card));
        // The performance rows have dashes of their own, each inside a Row;
        // the progress dash stands alone where the bar would be.
        final progressDashes = find.descendant(of: objective, matching: find.text('—')).evaluate().where((e) {
          var inRow = false;
          e.visitAncestorElements((a) {
            if (a.widget is Card) return false;
            if (a.widget is Row) inRow = true;
            return !inRow;
          });
          return !inRow;
        });
        expect(progressDashes, hasLength(1));
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('extra holdings: an unpriced asset off the model shows a dash, never 0.00 EUR', (tester) async {
      final priced = await seedHeldAsset('EM', isin: 'IE00BKM4GZ66');
      final unpricedOff = await seedHeldAsset('GOLD', isin: 'IE00B4ND3602');
      final unpricedNoIsin = await seedHeldAsset('ART');
      final base = await seedPillar();
      for (final id in [priced, unpricedOff, unpricedNoIsin]) {
        await PillarService(db).assign(pillarId: base.id, assetId: id, qty: 10);
      }
      final pillar = base.copyWith(portfolioModelId: const Value('model-1'));
      final target = PortfolioModelItem(id: 1, modelId: 'model-1', isin: 'IE00BKM4GZ66', targetWeight: 100, description: 'EM', sortOrder: 0);
      await pumpDetail(tester, pillar, {priced: 1000}, modelItems: [target]);
      try {
        await tester.scrollUntilVisible(find.text(s.portfolioExtraHoldings), 200, scrollable: find.byType(Scrollable).last);
        await tester.pumpAndSettle();
        for (final name in ['GOLD fund', 'ART fund']) {
          final tile = find.widgetWithText(ListTile, name);
          expect(tile, findsOneWidget);
          expect(
            find.descendant(of: tile, matching: find.text('—')),
            findsOneWidget,
            reason: '$name has no value',
          );
        }
        expect(find.text('0.00 EUR'), findsNothing);
      } finally {
        await unmount(tester);
      }
    });
  });
}
