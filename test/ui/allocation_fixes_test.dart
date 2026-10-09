// Assets Overview:
//  * a TER is coloured by its rating exactly as the Health tab colours that
//    rating (RatingExt.color) — same rating, same colour everywhere, instead
//    of a second palette of its own;
//  * nothing valued: the shared empty state, in a scrollable the
//    pull-to-refresh gesture can drive.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/app_actions_controller.dart';
import 'package:finance_copilot/services/pillars/financial_health_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/allocation/allocation_tab.dart';
import 'package:finance_copilot/ui/widgets/empty_state.dart';

Asset _asset(int id, String name, {double? ter}) {
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
  const s = AppStrings.en;

  Future<void> pump(WidgetTester tester, List<Asset> assets, Map<int, double> values, {List<Override> overrides = const []}) async {
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
        child: MaterialApp(
          home: Scaffold(
            body: AllocationOverviewBody(assets: assets, marketValues: values, baseCurrency: 'EUR', compositions: const {}),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a TER takes the colour of its rating, as on the Health tab', (tester) async {
    // 0.20% Excellent, 0.50% Good, 0.90% Fair, 1.50% Poor; weighted 0.56% Fair.
    await pump(
      tester,
      [_asset(1, 'CHEAP', ter: 0.2), _asset(2, 'MID', ter: 0.5), _asset(3, 'DEAR', ter: 0.9), _asset(4, 'LUXE', ter: 1.5)],
      {1: 4000, 2: 3000, 3: 2000, 4: 1000},
    );
    final card = find.ancestor(of: find.text(s.healthInvestmentCosts), matching: find.byType(Card));
    Color? colorOf(String text) => tester.widget<Text>(find.descendant(of: card, matching: find.text(text))).style?.color;
    for (final (text, ter) in [('0.20%', 0.2), ('0.50%', 0.5), ('0.90%', 0.9), ('1.50%', 1.5), ('0.56%', 0.56)]) {
      expect(colorOf(text), rateTer(ter).color, reason: '$text is ${rateTer(ter).name}');
    }
    expect(colorOf('0.50%'), Rating.buono.color, reason: 'Good is the Health tab\'s blue, not a light green of its own');
  });

  testWidgets('nothing valued: the shared empty state, and a pull refreshes', (tester) async {
    var refreshes = 0;
    final registry = GlobalActionsRegistry(
      manualRefresh: () async => refreshes++,
      showImportExportDialog: (_) async {},
      showSettingsDialog: (_) async {},
      openImportFiles: (_) async {},
      openSupport: (_) async {},
      retryNetwork: () async {},
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await pump(tester, const [], const {}, overrides: [globalActionsRegistryProvider.overrideWith((ref) => registry)]);
      final empty = find.byType(EmptyState);
      expect(empty, findsOneWidget);
      expect(find.descendant(of: empty, matching: find.text(s.noMarketValues)), findsOneWidget);
      final scrollable = find.ancestor(of: empty, matching: find.byType(Scrollable)).first;
      expect(tester.widget<Scrollable>(scrollable).physics, isA<AlwaysScrollableScrollPhysics>());

      await tester.fling(find.text(s.noMarketValues), const Offset(0, 1000), 1000);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(refreshes, 1);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
