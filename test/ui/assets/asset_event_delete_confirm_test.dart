// An asset event is deleted from two places — its edit screen's trashcan and
// the asset detail row's swipe — and both ask the same confirmation: "Delete
// Event?", "This cannot be undone.", Cancel and a red Delete. Cancel keeps
// the event; Delete removes it through the asset event service (which
// resyncs the asset's revalue prices). The trashcan then leaves the edit
// screen for the asset.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:logging/logging.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/domain/asset_event_service.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/assets/asset_detail_screen.dart';
import 'package:finance_copilot/ui/screens/assets/asset_event_edit_screen.dart';

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};

  @override
  Future<void> syncPrices({bool forceToday = false}) async {}
}

/// Records the deletes it is asked for.
class _RecordingAssetEventService extends AssetEventService {
  _RecordingAssetEventService(super.db);

  final deleted = <int>[];

  @override
  Future<int> delete(int id) {
    deleted.add(id);
    return super.delete(id);
  }
}

/// What a confirmation shows: title, message, cancel and confirm labels, and
/// the confirm button's colour.
typedef _Confirmation = (String?, String?, String?, String?, Color?);

void main() {
  const s = AppStrings.en;
  final today = DateTime(2026, 3, 10);
  late AppDatabase db;
  late _RecordingAssetEventService service;
  late Asset house;
  late int revalue;
  late List<LogRecord> warnings;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = _RecordingAssetEventService(db);
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    final id = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'House',
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
            date: DateTime(2025, 1, 10),
            valueDate: DateTime(2025, 1, 10),
            type: EventType.buy,
            amount: 1000,
            quantity: const Value(1),
          ),
        );
    revalue = await AssetEventService(
      db,
    ).create(assetId: id, date: DateTime(2025, 6, 1), type: EventType.revalue, amount: 1200, currency: 'EUR');
    house = await (db.select(db.assets)..where((a) => a.id.equals(id))).getSingle();
    warnings = [];
    final sub = Logger.root.onRecord.where((r) => r.level == Level.WARNING).listen(warnings.add);
    addTearDown(sub.cancel);
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpAsset(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          nowProvider.overrideWithValue(() => today.add(const Duration(hours: 12))),
          marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
          assetEventServiceProvider.overrideWithValue(service),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(home: AssetDetailScreen(asset: house)),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<List<EventType>> eventTypes() async => [for (final e in await db.select(db.assetEvents).get()) e.type];

  /// The UI's own delete lines (the service logs its own as well).
  List<String> uiDeleteLogs() => [
    for (final r in warnings)
      if (r.message.startsWith('deleting event')) r.message,
  ];

  Finder revalueRow() => find.text('revalue');

  Future<void> openEditScreen(WidgetTester tester) async {
    await tester.tap(revalueRow());
    await settle(tester);
    expect(find.byType(AssetEventEditScreen), findsOneWidget);
  }

  Future<void> tapTrashcan(WidgetTester tester) async {
    await tester.tap(find.descendant(of: find.byType(AssetEventEditScreen), matching: find.byIcon(Icons.delete_outline)));
    await settle(tester);
  }

  Future<void> swipeRevalue(WidgetTester tester) async {
    await tester.drag(revalueRow(), const Offset(-900, 0));
    await settle(tester);
  }

  _Confirmation openConfirmation(WidgetTester tester) {
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget, reason: 'a delete asks first');
    final alert = tester.widget<AlertDialog>(dialog);
    final cancel = tester.widget<TextButton>(find.descendant(of: dialog, matching: find.byType(TextButton)));
    final confirm = tester.widget<FilledButton>(find.descendant(of: dialog, matching: find.byType(FilledButton)));
    return (
      (alert.title! as Text).data,
      (alert.content! as Text).data,
      (cancel.child! as Text).data,
      (confirm.child! as Text).data,
      confirm.style?.backgroundColor?.resolve({}),
    );
  }

  const expected = ('Delete Event?', 'This cannot be undone.', 'Cancel', 'Delete', Colors.red);

  Future<void> tapCancel(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextButton, s.cancel));
    await settle(tester);
  }

  Future<void> tapDelete(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, s.delete));
    await settle(tester);
  }

  group('pinned', () {
    testWidgets('the trashcan asks; Cancel keeps the event and the screen; Delete removes it, logs it and goes back to the asset', (
      tester,
    ) async {
      expect(await db.select(db.marketPrices).get(), isNotEmpty, reason: 'the revalue materialised a price');
      await pumpAsset(tester);
      try {
        await openEditScreen(tester);
        await tapTrashcan(tester);
        expect(openConfirmation(tester), expected);
        await tapCancel(tester);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(AssetEventEditScreen), findsOneWidget, reason: 'Cancel stays on the edit screen');
        expect(service.deleted, isEmpty);
        expect(await eventTypes(), [EventType.buy, EventType.revalue]);
        expect(uiDeleteLogs(), isEmpty);

        await tapTrashcan(tester);
        await tapDelete(tester);
        expect(service.deleted, [revalue]);
        expect(await eventTypes(), [EventType.buy]);
        expect(await db.select(db.marketPrices).get(), isEmpty, reason: 'the service resynced the revalue prices');
        expect(uiDeleteLogs(), ['deleting event id=$revalue']);
        expect(find.byType(AssetEventEditScreen), findsNothing, reason: 'back to the asset');
        expect(revalueRow(), findsNothing);
        expect(find.text('buy'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('the swipe asks; Cancel slides the row back; Delete removes it through the service', (tester) async {
      await pumpAsset(tester);
      try {
        await swipeRevalue(tester);
        expect(openConfirmation(tester), expected);
        await tapCancel(tester);
        expect(revalueRow(), findsOneWidget);
        expect(service.deleted, isEmpty);

        await swipeRevalue(tester);
        await tapDelete(tester);
        expect(service.deleted, [revalue]);
        expect(await eventTypes(), [EventType.buy]);
        expect(await db.select(db.marketPrices).get(), isEmpty);
        expect(revalueRow(), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('the Italian texts are the same from both', (tester) async {
      await pumpAsset(tester);
      final container = ProviderScope.containerOf(tester.element(find.byType(AssetDetailScreen)));
      container.read(portableLanguageProvider.notifier).state = 'it';
      await settle(tester);
      try {
        const it = AppStrings.it;
        final italian = (it.deleteEventTitle, it.cannotBeUndone, it.cancel, it.delete, Colors.red);
        await swipeRevalue(tester);
        expect(openConfirmation(tester), italian);
        await tester.tap(find.widgetWithText(TextButton, it.cancel));
        await settle(tester);

        await openEditScreen(tester);
        await tapTrashcan(tester);
        expect(openConfirmation(tester), italian);
        await tester.tap(find.widgetWithText(TextButton, it.cancel));
        await settle(tester);
        expect(service.deleted, isEmpty);
      } finally {
        await unmount(tester);
      }
    });
  });

  group('one confirm-and-delete', () {
    testWidgets('confirmAndDeleteAssetEvent: Cancel deletes nothing and says so; Delete deletes, logs and says so', (tester) async {
      final event = await (db.select(db.assetEvents)..where((e) => e.id.equals(revalue))).getSingle();
      final results = <bool>[];
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            assetEventServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: TextButton(
                  onPressed: () async => results.add(await confirmAndDeleteAssetEvent(context, ref, event)),
                  child: const Text('ask'),
                ),
              ),
            ),
          ),
        ),
      );
      try {
        await tester.tap(find.text('ask'));
        await settle(tester);
        expect(openConfirmation(tester), expected);
        await tapCancel(tester);
        expect(results, [false]);
        expect(service.deleted, isEmpty);
        expect(uiDeleteLogs(), isEmpty);

        await tester.tap(find.text('ask'));
        await settle(tester);
        await tapDelete(tester);
        expect(results, [false, true]);
        expect(service.deleted, [revalue]);
        expect(await eventTypes(), [EventType.buy]);
        expect(await db.select(db.marketPrices).get(), isEmpty, reason: 'the service resynced the revalue prices');
        expect(uiDeleteLogs(), ['deleting event id=$revalue']);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('the swipe logs the delete as the trashcan does', (tester) async {
      await pumpAsset(tester);
      try {
        await swipeRevalue(tester);
        await tapDelete(tester);
        expect(uiDeleteLogs(), ['deleting event id=$revalue']);
      } finally {
        await unmount(tester);
      }
    });
  });
}
