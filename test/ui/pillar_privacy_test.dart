// Pillar detail: the "max N% · X units in other pillars" hint and the extra
// holdings of a model portfolio. The cap percentage is a share of the holding
// (shape) and stays readable; the units held elsewhere are a quantity — with
// the percentage and the units shown in the row, the whole position could be
// reconstructed — and the value of an extra holding is position size: both
// are masked in privacy mode.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/pillars/pillar_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show AllSeriesData, allSeriesDataProvider;
import 'package:finance_copilot/ui/screens/pillars/pillar_detail_screen.dart';

void main() {
  late AppDatabase db;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> seedAsset({required String ticker, required double qty, String? isin}) async {
    final interId = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker $ticker'));
    final id = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: '$ticker fund',
            ticker: Value(ticker),
            isin: Value(isin),
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: interId,
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
            amount: qty * 10,
            quantity: Value(qty),
            price: const Value(10),
          ),
        );
    return id;
  }

  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  testWidgets('max-cap hint keeps the percentage readable and masks the units elsewhere; extra holdings mask their value', (tester) async {
    // 129 units held, 3.87 of them in another standard pillar: this one caps at 97%.
    final em = await seedAsset(ticker: 'EM13', qty: 129, isin: 'IE00BKM4GZ66');
    final gold = await seedAsset(ticker: 'GOLD', qty: 10);
    final other = await PillarService(db).create(name: 'FIRE');
    await PillarService(db).assign(pillarId: other, assetId: em, qty: 3.87);
    final pillarId = await PillarService(db).create(name: 'Lombard');
    await PillarService(db).assign(pillarId: pillarId, assetId: em, qty: 50);
    await PillarService(db).assign(pillarId: pillarId, assetId: gold, qty: 10);
    // Tie the pillar to a model portfolio whose only target is not held.
    final pillar = (await PillarService(db).getById(pillarId))!.copyWith(portfolioModelId: const Value('model-1'));
    final pillars = [pillar, (await PillarService(db).getById(other))!];
    final assets = await db.select(db.assets).get();
    final target = PortfolioModelItem(id: 1, modelId: 'model-1', isin: 'IE00B4L5Y983', targetWeight: 60, description: 'World', sortOrder: 0);

    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final screen = PillarDetailScreen(pillarId: pillarId);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('en')),
          baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
          pillarsProvider.overrideWithValue(AsyncData(pillars)),
          standardPillarsProvider.overrideWithValue(AsyncData(pillars)),
          virtualPortfoliosProvider.overrideWithValue(const AsyncData([])),
          activeAssetsProvider.overrideWithValue(AsyncData(assets)),
          assetsProvider.overrideWithValue(AsyncData(assets)),
          pillarAssetsProvider.overrideWithValue(const AsyncData([])),
          assetMarketValuesProvider.overrideWithValue(AsyncData({em: 12900, gold: 2000})),
          unassignedFractionProvider.overrideWithValue(const AsyncData({})),
          allSeriesDataProvider.overrideWithValue(const AsyncData<AllSeriesData?>(null)),
          pillarPerformanceSnapshotsProvider.overrideWithValue(const AsyncData({})),
          portfolioModelItemsProvider.overrideWith((ref, modelId) => Stream.value([target])),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byWidget(screen)));
    container.read(privacyModeProvider.notifier).state = true;
    await tester.pumpAndSettle();

    final cap = find.textContaining('max 97%');
    expect(cap, findsOneWidget);
    expect(masked(cap), isFalse, reason: 'the cap is a share of the holding: shape, not magnitude');
    final elsewhere = find.text('3.87');
    expect(elsewhere, findsOneWidget, reason: 'the units held in other pillars are rendered on their own');
    expect(masked(elsewhere), isTrue, reason: 'units held are position size');

    await tester.scrollUntilVisible(find.text('Extra holdings'), 200, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    // EM13: 50 of 129 units of 12,900 → 5,000.00; GOLD (no ISIN): all 10 of 2,000.
    for (final value in ['5,000.00 EUR', '2,000.00 EUR']) {
      final trailing = find.descendant(of: find.byType(ListTile), matching: find.text(value));
      expect(trailing, findsOneWidget);
      expect(masked(trailing), isTrue, reason: 'the value of an extra holding is position size');
    }
    expect(masked(find.text('Missing ISIN')), isFalse);
    expect(masked(find.text('Target: 60.00%')), isFalse, reason: 'a target weight is a percentage');
  });
}
