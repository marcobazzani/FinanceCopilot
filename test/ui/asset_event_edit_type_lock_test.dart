import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/ui/screens/assets/asset_event_edit_screen.dart';

// Pins the invariant that an existing event's TYPE is immutable.
//
// Background: switching a `buy` into a `revalue` in place reinterprets the
// stale qty/price product as a revalue total, collapsing e.g. a
// 3000 @ 100 = 300,000 position down to 3,000 (close_price = amount/qty = 1).
// The fix locks the type dropdown in edit mode (onChanged == null) so the
// only way to change an event's type is delete + recreate.
//
// create mode  -> dropdown enabled (onChanged != null)
// edit   mode  -> dropdown disabled (onChanged == null)
void main() {
  late AppDatabase db;
  late Asset asset;
  late AssetEvent buyEvent;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final iid = await db.into(db.intermediaries).insert(
          IntermediariesCompanion.insert(name: 'Default'),
        );
    final assetId = await db.into(db.assets).insert(
          AssetsCompanion.insert(
            name: 'VWCE',
            assetType: AssetType.stockEtf,
            instrumentType: const Value(InstrumentType.etf),
            assetClass: const Value(AssetClass.equity),
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: iid,
          ),
        );
    asset = await (db.select(db.assets)..where((a) => a.id.equals(assetId))).getSingle();
    final eventId = await db.into(db.assetEvents).insert(
          AssetEventsCompanion.insert(
            assetId: assetId,
            date: DateTime(2024, 3, 15),
            valueDate: DateTime(2024, 3, 15),
            type: EventType.buy,
            amount: 300000.0,
            quantity: const Value(3000.0),
            price: const Value(100.0),
            currency: const Value('EUR'),
          ),
        );
    buyEvent = await (db.select(db.assetEvents)..where((e) => e.id.equals(eventId))).getSingle();
  });

  tearDown(() async => await db.close());

  Widget harness({AssetEvent? event}) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: AssetEventEditScreen(asset: asset, event: event),
      ),
    );
  }

  DropdownButtonFormField<EventType> typeDropdown(WidgetTester tester) {
    final finder = find.byType(DropdownButtonFormField<EventType>);
    expect(finder, findsOneWidget, reason: 'event type dropdown must render');
    return tester.widget<DropdownButtonFormField<EventType>>(finder);
  }

  // Unmount the screen and drain the drift stream-query timer so the
  // post-test "Timer is still pending" invariant doesn't trip. The DB-backed
  // StreamProviders (locale/base currency) keep a watch timer alive.
  Future<void> teardownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('create mode: event type dropdown is enabled', (tester) async {
    // Create mode fires async FX/price fetches in initState. runAsync lets
    // those real Futures/timers complete instead of leaving a pending timer
    // that trips the post-test invariant check.
    await tester.runAsync(() async {
      await tester.pumpWidget(harness(event: null));
      await tester.pump();
    });
    await tester.pump();

    expect(
      typeDropdown(tester).onChanged,
      isNotNull,
      reason: 'type must be selectable when creating a new event',
    );
    await teardownTree(tester);
  });

  testWidgets('edit mode: event type dropdown is locked (disabled)', (tester) async {
    await tester.pumpWidget(harness(event: buyEvent));
    await tester.pump();

    expect(
      typeDropdown(tester).onChanged,
      isNull,
      reason: 'type must be immutable when editing an existing event '
          '(buy->revalue in place corrupts the position)',
    );
    await teardownTree(tester);
  });

  testWidgets('edit mode: tapping the locked dropdown does not open other types', (tester) async {
    await tester.pumpWidget(harness(event: buyEvent));
    await tester.pump();

    // The current type is shown; the alternative options must not appear.
    await tester.tap(find.byType(DropdownButtonFormField<EventType>));
    await tester.pump();

    expect(
      find.text(EventType.revalue.name),
      findsNothing,
      reason: 'a disabled dropdown must not surface the revalue option',
    );
    expect(
      find.text(EventType.sell.name),
      findsNothing,
      reason: 'a disabled dropdown must not surface the sell option',
    );
    await teardownTree(tester);
  });
}
