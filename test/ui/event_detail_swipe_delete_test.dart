// Event detail timeline: a manual entry or a reimbursement is deleted the
// canonical way — the trash icon on its row, or a swipe (Dismissible) — and
// both ask the same confirmation first. A cancelled swipe keeps the row; a
// scheduled entry (regenerated from the event) has neither affordance.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/buffer_service.dart';
import 'package:finance_copilot/services/domain/extraordinary_event_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/events/event_detail_screen.dart';

void main() {
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

  Finder rowOf(String amount) => find.ancestor(of: find.text(amount), matching: find.byType(ListTile));

  Future<void> swipeAway(WidgetTester tester, String amount) async {
    await tester.drag(rowOf(amount), const Offset(-800, 0));
    await settle(tester);
  }

  Future<List<ExtraordinaryEventEntry>> entries() => db.select(db.extraordinaryEventEntries).get();

  Future<double> scheduledTotal() async {
    final rows = await (db.select(db.extraordinaryEventEntries)..where((e) => e.entryKind.equalsValue(EventEntryKind.scheduled))).get();
    return rows.fold<double>(0, (sum, e) => sum + e.amount);
  }

  testWidgets('swiping a manual entry asks first: cancel keeps it, confirm deletes it', (tester) async {
    final eventId = await events.create(
      name: 'Bonus',
      direction: EventDirection.inflow,
      treatment: EventTreatment.instant,
      totalAmount: 5000,
      currency: 'EUR',
      eventDate: DateTime(2026, 1, 5),
    );
    await events.addManualEntry(eventId: eventId, date: DateTime(2026, 1, 20), amount: 75.25);
    await pumpDetail(tester, eventId);
    try {
      await swipeAway(tester, '75.25 €');
      expect(find.byType(AlertDialog), findsOneWidget, reason: 'a swipe asks like the trash icon does');
      expect(find.widgetWithText(FilledButton, 'Delete'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await settle(tester);
      expect(await entries(), hasLength(1), reason: 'a cancelled swipe deletes nothing');
      expect(rowOf('75.25 €'), findsOneWidget, reason: 'the row comes back');
      expect(
        find.descendant(of: rowOf('75.25 €'), matching: find.byIcon(Icons.delete_outline)),
        findsOneWidget,
        reason: 'the trash icon stays on the row',
      );

      await swipeAway(tester, '75.25 €');
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);
      expect(await entries(), isEmpty);
      expect(find.text('75.25 €'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('swiping a reimbursement asks first; a confirmed delete regenerates the schedule', (tester) async {
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
    final bufferId = await events.createLinkedBuffer(eventId);
    await BufferService(db).createTransaction(
      bufferId: bufferId,
      operationDate: DateTime(2025, 3, 1),
      amount: 240,
      currency: 'EUR',
      isReimbursement: true,
    );
    await events.generateScheduledEntries(eventId);
    await pumpDetail(tester, eventId);
    try {
      expect(await scheduledTotal(), closeTo(-960, 1e-9));
      await swipeAway(tester, '240.00 €');
      expect(find.byType(AlertDialog), findsOneWidget, reason: 'a swipe asks like the trash icon does');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await settle(tester);
      expect(await db.select(db.bufferTransactions).get(), hasLength(1));
      expect(rowOf('240.00 €'), findsOneWidget);

      await swipeAway(tester, '240.00 €');
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);
      expect(await db.select(db.bufferTransactions).get(), isEmpty);
      expect(await scheduledTotal(), closeTo(-1200, 1e-9), reason: 'the whole amount is spread again');
      expect(find.text('240.00 €'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a scheduled entry has no trash icon and cannot be swiped away', (tester) async {
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
    await events.generateScheduledEntries(eventId);
    await pumpDetail(tester, eventId);
    try {
      final scheduled = rowOf('100.00 €');
      expect(scheduled, findsWidgets);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget, reason: 'only the app bar delete of the event itself');
      expect(find.ancestor(of: scheduled.first, matching: find.byType(Dismissible)), findsNothing);

      await tester.drag(scheduled.first, const Offset(-800, 0));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(await scheduledTotal(), closeTo(-1200, 1e-9));
    } finally {
      await unmount(tester);
    }
  });
}
