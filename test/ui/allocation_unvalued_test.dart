// Assets Overview: the percentages are shares of what the charts show — a
// liability is in no slice and does not shrink the total (6,000 EUR and
// 4,000 USD beside a -5,000 loan used to read 120% / 80%) — and a held asset
// without a price or exchange rate, in no slice either, is counted under the
// charts instead of vanishing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/allocation/allocation_tab.dart';

Asset _asset(int id, String name, {String currency = 'EUR', InstrumentType type = InstrumentType.etf, bool active = true}) {
  final now = DateTime(2025, 1, 1);
  return Asset(
    id: id,
    name: name,
    ticker: name,
    assetType: AssetType.stockEtf,
    instrumentType: type,
    assetClass: AssetClass.equity,
    intermediaryId: 1,
    assetGroup: '',
    currency: currency,
    valuationMethod: ValuationMethod.marketPrice,
    isActive: active,
    includeInSavings: true,
    sortOrder: 0,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  const s = AppStrings.en;
  final world = _asset(1, 'WRLD');
  final usa = _asset(2, 'USA', currency: 'USD');
  final loan = _asset(3, 'LOAN', type: InstrumentType.liability);

  Future<void> pump(WidgetTester tester, Widget body, {List<Override> overrides = const []}) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          portableLanguageProvider.overrideWith((ref) => 'en'),
          privacyModeProvider.overrideWith((ref) => false),
          ...overrides,
        ],
        child: MaterialApp(home: Scaffold(body: body)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder inCard(String title, Finder f) => find.descendant(
    of: find.ancestor(of: find.text(title), matching: find.byType(Card)).first,
    matching: f,
  );

  testWidgets('a liability is in no slice and does not shrink the total the percentages are shares of', (tester) async {
    await pump(
      tester,
      AllocationOverviewBody(
        assets: [world, usa, loan],
        marketValues: const {1: 6000, 2: 4000, 3: -5000},
        baseCurrency: 'EUR',
        compositions: const {},
      ),
    );
    expect(inCard(s.allocCurrency, find.text('EUR 60.0%')), findsOneWidget);
    expect(inCard(s.allocCurrency, find.text('USD 40.0%')), findsOneWidget);
    expect(find.textContaining('120.0%'), findsNothing);
    expect(inCard(s.concentrationRisk, find.textContaining('10,000')), findsOneWidget, reason: 'the portfolio value the shares add up to');
    expect(inCard(s.concentrationRisk, find.text('60.0%  (WRLD)')), findsOneWidget);
  });

  group('AllocationTab', () {
    List<Override> providers(List<Asset> assets, Map<int, double> values, Map<int, AssetStats> stats) => [
      assetsProvider.overrideWithValue(AsyncData(assets)),
      assetMarketValuesProvider.overrideWithValue(AsyncData(values)),
      assetStatsProvider.overrideWithValue(AsyncData(stats)),
      assetCompositionsProvider.overrideWithValue(const AsyncData({})),
      baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
    ];
    const held = AssetStats(eventCount: 1, totalQuantity: 10, totalInvested: 1000);

    testWidgets('a held asset without a value is counted under the charts; a closed or inactive one is not', (tester) async {
      final unpriced = _asset(4, 'UNPR');
      final closed = _asset(5, 'SOLD');
      final inactive = _asset(6, 'OLD', active: false);
      await pump(
        tester,
        const AllocationTab(),
        overrides: providers(
          [world, usa, unpriced, closed, inactive],
          const {1: 6000, 2: 4000},
          {1: held, 2: held, 4: held, 5: const AssetStats(eventCount: 2), 6: held},
        ),
      );
      expect(find.text(s.unpricedExcludedFromTotal(1)), findsOneWidget);
      expect(inCard(s.allocCurrency, find.text('EUR 60.0%')), findsOneWidget, reason: 'the shares are of the valued holdings');
    });

    testWidgets('every held asset valued: no note', (tester) async {
      await pump(tester, const AllocationTab(), overrides: providers([world, usa], const {1: 6000, 2: 4000}, {1: held, 2: held}));
      expect(find.textContaining('excluded from the total'), findsNothing);
    });
  });
}
