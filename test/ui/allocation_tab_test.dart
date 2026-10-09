// Assets Overview: the concentration labels come from AppStrings; privacy mode
// masks the position figures of the Investment Costs table (values, costs,
// totals) and keeps the TER percentages and placeholders readable; the
// weighted TER leaves out funds whose TER is unknown instead of counting them
// as free, and says how many it left out.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/pillars/financial_health_service.dart' show Rating, RatingExt;
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/allocation/allocation_tab.dart';

Asset _asset(int id, String name, {InstrumentType type = InstrumentType.etf, double? ter}) {
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
    currency: 'EUR',
    valuationMethod: ValuationMethod.marketPrice,
    ter: ter,
    isActive: true,
    includeInSavings: true,
    sortOrder: 0,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  // 6,000 at 0.20% + 3,000 at 0.50% + a 1,000 stock (no TER, none expected):
  // 27 a year on 10,000 → 0.27%.
  final known = [_asset(1, 'EMKT', ter: 0.2), _asset(2, 'BOND', ter: 0.5), _asset(3, 'ACME', type: InstrumentType.stock)];
  const knownValues = {1: 6000.0, 2: 3000.0, 3: 1000.0};

  Future<ProviderContainer> pump(WidgetTester tester, List<Asset> assets, Map<int, double> values, {String language = 'en'}) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final body = AllocationOverviewBody(assets: assets, marketValues: values, baseCurrency: 'EUR', compositions: const {});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLocaleProvider.overrideWith((ref) => Stream.value(language == 'it' ? 'it_IT' : 'en_US')),
          portableLanguageProvider.overrideWith((ref) => language),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(home: Scaffold(body: body)),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byWidget(body)));
  }

  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;
  Finder costs(String text) => find.descendant(
    of: find.ancestor(of: find.text('Investment Costs'), matching: find.byType(Card)),
    matching: find.text(text),
  );

  testWidgets('weighted TER, totals and rows when every fund has a TER', (tester) async {
    await pump(tester, known, knownValues);
    expect(costs('0.27%'), findsOneWidget);
    expect(costs('€10,000'), findsOneWidget, reason: 'total value');
    expect(costs('€27'), findsOneWidget, reason: 'total yearly cost');
    expect(costs('0.20%'), findsOneWidget);
    expect(costs('0.50%'), findsOneWidget);
    expect(costs('-'), findsNWidgets(2), reason: 'the stock has no TER and so no cost');
    // Rating bands: ≤ 0.20 Excellent, ≤ 0.50 Good — in the rating's own
    // colour, the one the Health tab uses.
    Color? colorOf(String text) => tester.widget<Text>(costs(text)).style?.color;
    expect(colorOf('0.20%'), Rating.ottimo.color);
    expect(colorOf('0.50%'), Rating.buono.color);
    expect(colorOf('0.27%'), Rating.buono.color);
  });

  testWidgets('a fund with an unknown TER is left out of the weighted TER, and counted', (tester) async {
    await pump(tester, [...known, _asset(4, 'MYST')], {...knownValues, 4: 5000.0});
    expect(costs('0.27%'), findsOneWidget, reason: 'counting the unknown fund as free would read 27 / 15,000 = 0.18%');
    expect(costs('0.18%'), findsNothing);
    expect(costs('1 fund without a TER excluded from the average'), findsOneWidget);
  });

  testWidgets('Italian: the exclusion note', (tester) async {
    await pump(
      tester,
      [...known, _asset(4, 'MYST'), _asset(5, 'OTHR', type: InstrumentType.fund)],
      {...knownValues, 4: 5000.0, 5: 100.0},
      language: 'it',
    );
    final card = find.ancestor(of: find.text('Costi degli investimenti'), matching: find.byType(Card));
    expect(find.descendant(of: card, matching: find.text('2 fondi senza TER esclusi dalla media')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('0,27%')), findsOneWidget);
  });

  testWidgets('concentration labels', (tester) async {
    await pump(tester, known, knownValues);
    for (final label in ['Top 1', 'Top 3', 'Top 5', 'HHI']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('60.0%  (EMKT)'), findsOneWidget);
  });

  testWidgets('privacy: values and costs are masked, TERs and placeholders stay readable', (tester) async {
    final container = await pump(tester, known, knownValues);
    for (final text in ['€6,000', '€12', '€10,000', '€27']) {
      expect(masked(costs(text)), isFalse, reason: 'nothing is masked before privacy is on');
    }

    container.read(privacyModeProvider.notifier).state = true;
    await tester.pumpAndSettle();
    for (final text in ['€6,000', '€3,000', '€1,000', '€12', '€15', '€10,000', '€27']) {
      expect(costs(text), findsOneWidget, reason: '$text still rendered');
      expect(masked(costs(text)), isTrue, reason: '$text is position size');
    }
    for (final text in ['0.20%', '0.50%', '0.27%']) {
      expect(masked(costs(text)), isFalse, reason: 'a TER is a percentage, not position size');
    }
    // The stock's cost keeps its placeholder and its grey colour.
    final placeholders = tester.widgetList<Text>(costs('-')).toList();
    expect(placeholders, hasLength(2));
    for (final t in placeholders) {
      expect(t.style?.color, Colors.grey);
    }
    // Concentration: the portfolio value is masked, the holdings count is not.
    expect(masked(find.text('€10,000').first), isTrue);
    expect(masked(find.text('3')), isFalse);
  });
}
