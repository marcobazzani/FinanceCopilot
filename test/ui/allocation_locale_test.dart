// Assets Overview: every percentage — donut legends, slice labels, the
// drill-down header, the top holdings and the concentration shares — is
// spelled in the active locale ("60,0%" in it_IT, not "60.0%"), and English
// reads as before.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/allocation/allocation_tab.dart';

Asset _asset(int id, String name, {required String currency, required String country}) {
  final now = DateTime(2025, 1, 1);
  return Asset(
    id: id,
    name: name,
    ticker: name,
    assetType: AssetType.stockEtf,
    instrumentType: InstrumentType.etf,
    assetClass: AssetClass.equity,
    intermediaryId: 1,
    assetGroup: '',
    currency: currency,
    country: country,
    valuationMethod: ValuationMethod.marketPrice,
    isActive: true,
    includeInSavings: true,
    sortOrder: 0,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  final assets = [_asset(1, 'WRLD', currency: 'EUR', country: 'IE'), _asset(2, 'USA', currency: 'USD', country: 'US')];
  const values = {1: 6000.0, 2: 4000.0};

  Future<void> pump(WidgetTester tester, String language) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLocaleProvider.overrideWith((ref) => Stream.value(language == 'it' ? 'it_IT' : 'en_US')),
          portableLanguageProvider.overrideWith((ref) => language),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AllocationOverviewBody(assets: assets, marketValues: values, baseCurrency: 'EUR', compositions: const {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder inCard(String title, Finder f) => find.descendant(
    of: find.ancestor(of: find.text(title), matching: find.byType(Card)).first,
    matching: f,
  );

  for (final (language, sixty, forty, hundred) in [('en', '60.0', '40.0', '100.0'), ('it', '60,0', '40,0', '100,0')]) {
    testWidgets('$language: the shares are spelled in the locale', (tester) async {
      final s = AppStrings.of(language);
      await pump(tester, language);

      // Donut legends, and the slice labels drawn on the donut.
      expect(inCard(s.allocCurrency, find.text('EUR $sixty%')), findsOneWidget);
      expect(inCard(s.allocCurrency, find.text('USD $forty%')), findsOneWidget);
      final slices = tester.widget<PieChart>(inCard(s.allocCurrency, find.byType(PieChart))).data.sections.map((p) => p.title);
      expect(slices, ['$sixty%', '$forty%']);
      expect(inCard(s.allocGeographic, find.text('IE $sixty%')), findsOneWidget);
      final drillable = tester.widget<PieChart>(inCard(s.allocGeographic, find.byType(PieChart))).data.sections.map((p) => p.title);
      expect(drillable, ['$sixty%', '$forty%']);

      // Top holdings bars.
      expect(inCard(s.allocTopHoldings, find.text('$sixty%')), findsOneWidget);
      expect(inCard(s.allocTopHoldings, find.text('$forty%')), findsOneWidget);

      // Concentration shares; the HHI is a whole number either way.
      expect(inCard(s.concentrationRisk, find.text('$sixty%  (WRLD)')), findsOneWidget);
      expect(inCard(s.concentrationRisk, find.text('$hundred%')), findsNWidgets(2), reason: 'top 3 and top 5');
      expect(inCard(s.concentrationRisk, find.text('5200')), findsOneWidget);

      // The drill-down header of a slice.
      await tester.tap(inCard(s.allocGeographic, find.text('IE $sixty%')));
      await tester.pumpAndSettle();
      expect(inCard(s.allocGeographic, find.text('IE  $sixty%')), findsOneWidget);
    });
  }
}
