// Pillar list / detail formatting.
//
// Pinned bugs:
//  * The pillar card wrote its target with NumberFormat.simpleCurrency in the
//    BASE currency, while the target is stored in its own target currency (and
//    the rest of the app formats money with formatters.currencyFormat +
//    currencySymbol). A USD target on a EUR book read "€100,000.00".
//  * A provider error rendered as the raw exception text instead of the
//    localized "Error: …" line every other screen shows.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/pillars/pillar_performance.dart';
import 'package:finance_copilot/services/pillars/pillar_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show AllSeriesData, allSeriesDataProvider;
import 'package:finance_copilot/ui/screens/pillars/pillar_detail_screen.dart';
import 'package:finance_copilot/ui/screens/pillars/pillars_screen.dart';

void main() {
  const s = AppStrings.en;
  late AppDatabase db;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget screen, {required AsyncValue<List<Pillar>> pillars, String base = 'EUR'}) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('en')),
          baseCurrencyProvider.overrideWithValue(AsyncData(base)),
          pillarsProvider.overrideWithValue(pillars),
          standardPillarsProvider.overrideWithValue(pillars),
          virtualPortfoliosProvider.overrideWithValue(const AsyncData([])),
          activeAssetsProvider.overrideWithValue(const AsyncData([])),
          assetsProvider.overrideWithValue(const AsyncData([])),
          pillarAssetsProvider.overrideWithValue(const AsyncData([])),
          assetMarketValuesProvider.overrideWithValue(const AsyncData({})),
          unassignedFractionProvider.overrideWithValue(const AsyncData({})),
          allSeriesDataProvider.overrideWithValue(const AsyncData<AllSeriesData?>(null)),
          pillarPerformanceSnapshotsProvider.overrideWithValue(const AsyncData(<String, PillarPerformanceSnapshot>{})),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(home: screen),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<Pillar> seedPillar({required double target, required String currency}) async {
    final id = await PillarService(db).create(name: 'Retirement', targetValue: target, targetCurrency: currency);
    return (await PillarService(db).getById(id))!;
  }

  testWidgets('pillar card: the target is written in its own currency with the app currency format', (tester) async {
    final pillar = await seedPillar(target: 100000, currency: 'USD');
    await pump(tester, const PillarsScreen(), pillars: AsyncData([pillar]));
    try {
      expect(find.text(s.pillarTarget(r'$100,000.00')), findsOneWidget);
      expect(find.textContaining('€100,000'), findsNothing, reason: 'a USD target must not be labelled with the EUR base currency');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('pillar card: a target in the base currency keeps that currency', (tester) async {
    final pillar = await seedPillar(target: 5000, currency: 'EUR');
    await pump(tester, const PillarsScreen(), pillars: AsyncData([pillar]));
    try {
      expect(find.text(s.pillarTarget('€5,000.00')), findsOneWidget);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('pillar list: a load error is shown as the localized error line', (tester) async {
    await pump(tester, const PillarsScreen(), pillars: AsyncError(StateError('boom'), StackTrace.empty));
    try {
      expect(find.text(s.error(StateError('boom'))), findsOneWidget);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('pillar detail: a load error in the title is shown as the localized error line', (tester) async {
    await pump(tester, const PillarDetailScreen(pillarId: 'missing'), pillars: AsyncError(StateError('boom'), StackTrace.empty));
    try {
      expect(find.text(s.error(StateError('boom'))), findsOneWidget);
    } finally {
      await unmount(tester);
    }
  });
}
