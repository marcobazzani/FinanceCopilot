import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/services/pillars/pillar_performance.dart';
import 'package:finance_copilot/services/pillars/pillar_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show AllSeriesData, allSeriesDataProvider;
import 'package:finance_copilot/ui/screens/pillars/pillar_detail_screen.dart';
import 'package:finance_copilot/ui/screens/pillars/pillars_screen.dart';

void main() {
  late AppDatabase db;
  late Pillar pillar;
  late String pillarId;

  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    pillarId = await PillarService(db).create(name: 'Retirement');
    pillar = (await PillarService(db).getById(pillarId))!;
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('pillar detail renders KPI labels and fallback dashes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        db: db,
        pillar: pillar,
        performanceByPillar: {
          pillarId: PillarPerformanceSnapshot.empty(DateTime(2024, 1, 1)),
        },
        child: PillarDetailScreen(pillarId: pillarId),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Absolute return'), findsOneWidget);
    expect(find.text('TWRR'), findsOneWidget);
    expect(find.text('CAGR'), findsOneWidget);
    expect(find.text('—'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('pillars list renders compact KPI summary on pillar cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        db: db,
        pillar: pillar,
        performanceByPillar: {
          pillarId: PillarPerformanceSnapshot(
            asOfDate: DateTime(2024, 1, 11),
            marketValue: 1200,
            netInvested: 1000,
            absoluteReturnAmount: 200,
            absoluteReturnPct: 0.2,
            twrr: 0.18,
            cagr: 0.17,
            hasSufficientHistory: true,
          ),
        },
        child: const PillarsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Retirement'), findsOneWidget);
    expect(find.textContaining('Abs 200.00 EUR (20.0%)'), findsOneWidget);
    expect(find.textContaining('TWRR 18.0%'), findsOneWidget);
    expect(find.textContaining('CAGR 17.0%'), findsOneWidget);
    expect(find.text('Unassigned'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

Widget _testApp({
  required AppDatabase db,
  required Pillar pillar,
  required Map<String, PillarPerformanceSnapshot> performanceByPillar,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      appLocaleProvider.overrideWith((ref) => Stream.value('en')),
      baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
      pillarsProvider.overrideWithValue(AsyncData([pillar])),
      activeAssetsProvider.overrideWithValue(const AsyncData([])),
      assetsProvider.overrideWithValue(const AsyncData([])),
      pillarAssetsProvider.overrideWithValue(const AsyncData([])),
      assetMarketValuesProvider.overrideWithValue(const AsyncData({})),
      unassignedFractionProvider.overrideWithValue(const AsyncData({})),
      allSeriesDataProvider.overrideWithValue(
        const AsyncData<AllSeriesData?>(null),
      ),
      pillarPerformanceSnapshotsProvider.overrideWithValue(
        AsyncData(performanceByPillar),
      ),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}
