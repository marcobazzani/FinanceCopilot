// Event detail:
// - the add-entry / add-reimbursement dialog can outlive its screen (the event
//   deleted while the dialog is open, e.g. by a sync): confirming it then used
//   `ref` of the screen that was gone ("Cannot use ref after the widget was
//   disposed"). It now writes nothing and raises nothing;
// - the dialog owns its text controllers: closing it with a field still
//   focused raises nothing;
// - the row trash icons say what they do (tooltip);
// - no entries: the shared empty state, inside the pull-to-refresh list.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/domain/extraordinary_event_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/events/event_detail_screen.dart';
import 'package:finance_copilot/ui/widgets/empty_state.dart';
import 'package:finance_copilot/ui/widgets/mobile_pull_to_refresh.dart';

void main() {
  const s = AppStrings.en;
  late AppDatabase db;
  late ExtraordinaryEventService events;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    events = ExtraordinaryEventService(db);
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpDetail(WidgetTester tester, int eventId) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          extraordinaryEventServiceProvider.overrideWithValue(events),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(home: EventDetailScreen(eventId: eventId)),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<int> instantEvent() => events.create(
    name: 'Bonus',
    direction: EventDirection.inflow,
    treatment: EventTreatment.instant,
    totalAmount: 5000,
    currency: 'EUR',
    eventDate: DateTime(2026, 1, 5),
  );

  Future<int> reimbursableSpread() async {
    final eventId = await events.create(
      name: 'Car',
      direction: EventDirection.outflow,
      treatment: EventTreatment.spread,
      totalAmount: 1200,
      currency: 'EUR',
      eventDate: DateTime(2026, 1, 1),
      stepFrequency: StepFrequency.monthly,
      spreadStart: DateTime(2025, 1, 1),
      spreadEnd: DateTime(2025, 12, 1),
    );
    await events.createLinkedBuffer(eventId);
    return eventId;
  }

  group('the add dialog outlives its screen', () {
    testWidgets('a manual entry confirmed once the event is gone writes nothing and raises nothing', (tester) async {
      final eventId = await instantEvent();
      await pumpDetail(tester, eventId);
      try {
        await tester.tap(find.text(s.addEventEntryTitle));
        await settle(tester);
        await tester.enterText(find.widgetWithText(TextField, s.amount), '75');
        await events.delete(eventId);
        await settle(tester);

        await tester.tap(find.widgetWithText(FilledButton, s.add));
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(AlertDialog), findsNothing);
        expect(await db.select(db.extraordinaryEventEntries).get(), isEmpty);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a reimbursement confirmed once the event is gone writes nothing and raises nothing', (tester) async {
      final eventId = await reimbursableSpread();
      await pumpDetail(tester, eventId);
      try {
        await tester.tap(find.byTooltip(s.tooltipAddReimbursement));
        await settle(tester);
        await tester.enterText(find.widgetWithText(TextField, s.amount), '100');
        await events.delete(eventId);
        await settle(tester);

        await tester.tap(find.widgetWithText(FilledButton, s.add));
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(await db.select(db.bufferTransactions).get(), isEmpty);
      } finally {
        await unmount(tester);
      }
    });
  });

  testWidgets('the add dialog closes with a field still focused without raising, and adds the entry', (tester) async {
    final eventId = await instantEvent();
    await pumpDetail(tester, eventId);
    try {
      await tester.tap(find.text(s.addEventEntryTitle));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, s.amount), '75.25');
      await tester.enterText(find.widgetWithText(TextField, s.descriptionOptional), '  Gift  ');
      await tester.tap(find.widgetWithText(FilledButton, s.add));
      await settle(tester);
      expect(tester.takeException(), isNull);
      final entry = await db.select(db.extraordinaryEventEntries).getSingle();
      expect(entry.amount, 75.25);
      expect(entry.description, 'Gift', reason: 'trimmed, as before');

      await tester.tap(find.text(s.addEventEntryTitle));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, s.amount), '10');
      await tester.tap(find.widgetWithText(TextButton, s.cancel));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(await db.select(db.extraordinaryEventEntries).get(), hasLength(1), reason: 'cancel adds nothing');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a deletable row\'s trash icon says what it does', (tester) async {
    final eventId = await instantEvent();
    await events.addManualEntry(eventId: eventId, date: DateTime(2026, 1, 20), amount: 75.25);
    await pumpDetail(tester, eventId);
    try {
      final row = find.ancestor(of: find.text('75.25 €'), matching: find.byType(ListTile));
      final trash = find.descendant(of: row, matching: find.byType(IconButton));
      expect(trash, findsOneWidget);
      expect(tester.widget<IconButton>(trash).tooltip, s.delete);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('no entries: the shared empty state, inside the pull-to-refresh list', (tester) async {
    final eventId = await instantEvent();
    await pumpDetail(tester, eventId);
    try {
      final empty = find.widgetWithText(EmptyState, s.noEntriesYet);
      expect(empty, findsOneWidget);
      expect(find.ancestor(of: empty, matching: find.byType(MobilePullToRefresh)), findsOneWidget);
      final list = tester.widget<ListView>(find.ancestor(of: empty, matching: find.byType(ListView)).first);
      expect(list.physics, isA<AlwaysScrollableScrollPhysics>());
    } finally {
      await unmount(tester);
    }
  });
}
