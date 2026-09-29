// Event detail writes:
// - a reimbursement is booked through the buffer service, with the buffer's
//   running balance (the screen used to insert it directly with a 0 balance),
//   and together with the regenerated schedule in one transaction — nobody
//   ever reads the reimbursement next to a schedule that ignores it;
// - an amount the locale cannot read is reported, not silently dropped;
// - deleting a manual entry or a reimbursement asks first (they used to go at
//   the first tap), and a deleted reimbursement regenerates the schedule in
//   the same transaction.
import 'dart:async';

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

/// Holds the schedule regeneration until [hold] completes, when set: the
/// moment between the reimbursement write and the schedule write.
class _HeldEventService extends ExtraordinaryEventService {
  _HeldEventService(super.db);

  /// Created by the test body, so that completing it wakes the held write in
  /// the test's own (fake-async) zone.
  Completer<void>? hold;

  @override
  Future<void> generateScheduledEntries(int eventId) async {
    final held = hold;
    if (held != null) await held.future;
    return super.generateScheduledEntries(eventId);
  }
}

void main() {
  late AppDatabase db;
  late _HeldEventService events;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    events = _HeldEventService(db);
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  /// A 1200 spread over the 12 months before the event, reimbursable.
  Future<({int eventId, int bufferId})> seedSpread() async {
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
    return (eventId: eventId, bufferId: bufferId);
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

  Future<List<BufferTransaction>> reimbursements() => db.select(db.bufferTransactions).get();

  Future<double> scheduledTotal() async {
    final rows = await (db.select(db.extraordinaryEventEntries)..where((e) => e.entryKind.equalsValue(EventEntryKind.scheduled))).get();
    return rows.fold<double>(0, (sum, e) => sum + e.amount);
  }

  Future<void> addReimbursement(WidgetTester tester, String amount) async {
    await tester.tap(find.byTooltip('Add Reimbursement'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), amount);
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
  }

  Finder deleteIconOf(String rowText) => find.descendant(
    of: find.ancestor(of: find.text(rowText), matching: find.byType(ListTile)),
    matching: find.byIcon(Icons.delete_outline),
  );

  testWidgets('a reimbursement is booked with the buffer\'s running balance and regenerates the schedule', (tester) async {
    final seeded = await seedSpread();
    await BufferService(db).createTransaction(
      bufferId: seeded.bufferId,
      operationDate: DateTime(2025, 3, 1),
      amount: 50,
      currency: 'EUR',
      isReimbursement: true,
    );
    await events.generateScheduledEntries(seeded.eventId);
    await pumpDetail(tester, seeded.eventId);
    try {
      await addReimbursement(tester, '100');
      await settle(tester);

      final added = (await reimbursements()).firstWhere((t) => t.amount == 100);
      expect(added.isReimbursement, isTrue);
      expect(added.balanceAfter, 150, reason: 'the buffer held 50 before this 100 (it used to be written as 0)');
      expect(await scheduledTotal(), closeTo(-1050, 1e-9), reason: '1200 less the 150 reimbursed, spread');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a reimbursement and its regenerated schedule are one transaction', (tester) async {
    final seeded = await seedSpread();
    await pumpDetail(tester, seeded.eventId);
    try {
      final release = events.hold = Completer<void>();
      await addReimbursement(tester, '240');
      await settle(tester);

      // The reimbursement write is done, the schedule write held.
      final seen = db
          .customSelect(
            'SELECT (SELECT COUNT(*) FROM buffer_transactions) AS r, '
            "(SELECT COALESCE(SUM(amount), 0) FROM extraordinary_event_entries WHERE entry_kind = 'scheduled') AS s",
          )
          .getSingle();
      release.complete();
      await settle(tester);
      final row = await seen;
      final state = (row.read<int>('r'), row.read<double>('s'));
      expect(state, anyOf((0, -1200.0), (1, -960.0)), reason: 'a reader saw the reimbursement next to a schedule that ignores it');
      expect(await scheduledTotal(), closeTo(-960, 1e-9));
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('an amount the locale cannot read is reported and nothing is added', (tester) async {
    final seeded = await seedSpread();
    await pumpDetail(tester, seeded.eventId);
    try {
      // "240,5" is not a number in en_US (the comma groups thousands).
      await addReimbursement(tester, '240,5');
      await settle(tester);

      expect(find.text('Invalid number'), findsOneWidget, reason: 'the typed amount used to be dropped without a word');
      expect(await reimbursements(), isEmpty);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('deleting a manual entry asks first', (tester) async {
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
      final row = find.textContaining('75.25');
      await tester.tap(deleteIconOf('75.25 €'));
      await settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget, reason: 'the entry used to go at the first tap');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await settle(tester);
      expect(await db.select(db.extraordinaryEventEntries).get(), hasLength(1));
      expect(row, findsOneWidget);

      await tester.tap(deleteIconOf('75.25 €'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);
      expect(await db.select(db.extraordinaryEventEntries).get(), isEmpty);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('deleting a reimbursement asks first and regenerates the schedule', (tester) async {
    final seeded = await seedSpread();
    await BufferService(db).createTransaction(
      bufferId: seeded.bufferId,
      operationDate: DateTime(2025, 3, 1),
      amount: 240,
      currency: 'EUR',
      isReimbursement: true,
    );
    await events.generateScheduledEntries(seeded.eventId);
    await pumpDetail(tester, seeded.eventId);
    try {
      expect(await scheduledTotal(), closeTo(-960, 1e-9));
      await tester.tap(deleteIconOf('240.00 €'));
      await settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget, reason: 'the reimbursement used to go at the first tap');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await settle(tester);
      expect(await reimbursements(), hasLength(1));

      await tester.tap(deleteIconOf('240.00 €'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);
      expect(await reimbursements(), isEmpty);
      expect(await scheduledTotal(), closeTo(-1200, 1e-9));
    } finally {
      await unmount(tester);
    }
  });
}
