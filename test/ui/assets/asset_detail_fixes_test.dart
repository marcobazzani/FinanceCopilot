// Asset detail:
// - pin: deleting the asset from its detail view removes the asset with its
//   events, snapshots and prices — and nothing of another asset — then leaves
//   the screen (the screen used to wrap the atomic AssetService.delete in a
//   second transaction with its own events delete first);
// - "Assign to pillar" on a lone detail screen opens the pillar picker: it
//   used to await pillarsProvider.future, which never completes while nothing
//   listens to the provider (Riverpod pauses unlistened providers);
// - no events: the shared empty state, inside the pull-to-refresh list.
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
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/pillars/pillar_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/assets/asset_detail_screen.dart';
import 'package:finance_copilot/ui/widgets/empty_state.dart';
import 'package:finance_copilot/ui/widgets/mobile_pull_to_refresh.dart';

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};

  @override
  Future<void> syncPrices({bool forceToday = false}) async {}
}

void main() {
  const s = AppStrings.en;
  final today = DateTime(2026, 3, 10);
  late AppDatabase db;
  late int broker;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<Asset> seedAsset(String name, {bool withEvent = true}) async {
    final id = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: name,
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: broker,
          ),
        );
    if (withEvent) {
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: id,
              date: DateTime(2025, 1, 10),
              valueDate: DateTime(2025, 1, 10),
              type: EventType.buy,
              amount: 1000,
              quantity: const Value(10),
              price: const Value(100),
            ),
          );
      await db.into(db.marketPrices).insert(MarketPricesCompanion.insert(assetId: id, date: today, closePrice: 110, currency: 'EUR'));
      await db
          .into(db.assetSnapshots)
          .insert(
            AssetSnapshotsCompanion.insert(
              assetId: id,
              date: today,
              value: 1100,
              invested: 1000,
              growth: 100,
              growthPercent: 10,
              afterTaxValue: 1074,
            ),
          );
    }
    return (db.select(db.assets)..where((a) => a.id.equals(id))).getSingle();
  }

  /// A host whose only button pushes the detail screen of [asset], alone.
  Future<void> pumpDetail(WidgetTester tester, Asset asset) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          nowProvider.overrideWithValue(() => today.add(const Duration(hours: 12))),
          marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => AssetDetailScreen(asset: asset))),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<Map<String, int>> rowsOf(int assetId) async {
    Future<int> count(String table) async =>
        (await db.customSelect('SELECT COUNT(*) AS c FROM $table WHERE asset_id = ?', variables: [Variable.withInt(assetId)]).getSingle())
            .read<int>('c');
    return {
      'events': await count('asset_events'),
      'snapshots': await count('asset_snapshots'),
      'prices': await count('market_prices'),
      'asset': (await (db.select(db.assets)..where((a) => a.id.equals(assetId))).get()).length,
    };
  }

  testWidgets('pin: the detail delete removes the asset with its events, snapshots and prices, and only those', (tester) async {
    final gone = await seedAsset('World ETF');
    final kept = await seedAsset('Bond fund');
    await pumpDetail(tester, gone);
    try {
      await tester.tap(find.byTooltip(s.tooltipDeleteAsset));
      await settle(tester);
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect((dialog.title! as Text).data, s.deleteAssetTitle);
      expect((dialog.content! as Text).data, s.deleteAssetConfirm('World ETF'));
      await tester.tap(find.widgetWithText(FilledButton, s.delete));
      await settle(tester);

      expect(await rowsOf(gone.id), {'events': 0, 'snapshots': 0, 'prices': 0, 'asset': 0});
      expect(await rowsOf(kept.id), {'events': 1, 'snapshots': 1, 'prices': 1, 'asset': 1});
      expect(find.byType(AssetDetailScreen), findsNothing, reason: 'the screen of a deleted asset closes');
      expect(tester.takeException(), isNull);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('Assign to pillar on a lone detail screen opens the pillar picker', (tester) async {
    await PillarService(db).create(name: 'Retirement');
    final asset = await seedAsset('World ETF');
    await pumpDetail(tester, asset);
    try {
      await tester.tap(find.byTooltip(s.pillarAssignToTitle));
      await settle(tester);
      expect(find.widgetWithText(SimpleDialog, s.pillarPickPillar), findsOneWidget, reason: 'the picker used to wait forever');
      expect(find.widgetWithText(SimpleDialogOption, 'Retirement'), findsOneWidget);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('Assign to pillar without pillars says there are none', (tester) async {
    final asset = await seedAsset('World ETF');
    await pumpDetail(tester, asset);
    try {
      await tester.tap(find.byTooltip(s.pillarAssignToTitle));
      await settle(tester);
      expect(find.text(s.pillarsEmptyTitle), findsOneWidget);
      expect(find.byType(SimpleDialog), findsNothing);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('no events: the shared empty state, inside the pull-to-refresh list', (tester) async {
    final asset = await seedAsset('World ETF', withEvent: false);
    await pumpDetail(tester, asset);
    try {
      final empty = find.widgetWithText(EmptyState, s.noEventsYet);
      expect(empty, findsOneWidget);
      expect(find.ancestor(of: empty, matching: find.byType(MobilePullToRefresh)), findsOneWidget);
      final list = tester.widget<ListView>(find.ancestor(of: empty, matching: find.byType(ListView)).first);
      expect(list.physics, isA<AlwaysScrollableScrollPhysics>());
    } finally {
      await unmount(tester);
    }
  });
}
