import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/extraordinary_event_service.dart';

void main() {
  late AppDatabase db;
  late ExtraordinaryEventService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = ExtraordinaryEventService(db);
  });

  tearDown(() async => await db.close());

  group('Instant events', () {
    test('create inflow/instant event with no entries', () async {
      final id = await service.create(
        name: 'Inheritance',
        direction: EventDirection.inflow,
        treatment: EventTreatment.instant,
        totalAmount: 100000,
        currency: 'EUR',
        eventDate: DateTime(2024, 6, 1),
      );

      final event = await service.getById(id);
      expect(event.name, 'Inheritance');
      expect(event.direction, EventDirection.inflow);
      expect(event.treatment, EventTreatment.instant);
      expect(event.totalAmount, 100000);

      final entries = await service.getEntries(id);
      expect(entries, isEmpty);
    });

    test('create outflow/instant event (credit-line bucket)', () async {
      final id = await service.create(
        name: 'Credit Line',
        direction: EventDirection.outflow,
        treatment: EventTreatment.instant,
        totalAmount: 0,
        currency: 'EUR',
        eventDate: DateTime(2024, 1, 1),
      );

      final event = await service.getById(id);
      expect(event.direction, EventDirection.outflow);
      expect(event.treatment, EventTreatment.instant);
      expect(event.totalAmount, 0);
    });

    test('addManualEntry on inflow event stores positive amount', () async {
      final id = await service.create(
        name: 'Gift',
        direction: EventDirection.inflow,
        treatment: EventTreatment.instant,
        totalAmount: 10000,
        currency: 'EUR',
        eventDate: DateTime(2024, 6, 1),
      );

      await service.addManualEntry(
        eventId: id,
        date: DateTime(2024, 7, 1),
        amount: 1500,
        description: 'Car down payment',
      );

      final entries = await service.getEntries(id);
      expect(entries, hasLength(1));
      expect(entries[0].amount, 1500); // positive — restores saving
      expect(entries[0].entryKind, EventEntryKind.manual);
      expect(entries[0].description, 'Car down payment');
    });

    test('addManualEntry on outflow event stores negative amount', () async {
      final id = await service.create(
        name: 'Credit Line',
        direction: EventDirection.outflow,
        treatment: EventTreatment.instant,
        totalAmount: 0,
        currency: 'EUR',
        eventDate: DateTime(2024, 1, 1),
      );

      await service.addManualEntry(
        eventId: id,
        date: DateTime(2024, 3, 1),
        amount: 6540,
      );

      final entries = await service.getEntries(id);
      expect(entries, hasLength(1));
      expect(entries[0].amount, -6540); // negative — reduces saving
      expect(entries[0].entryKind, EventEntryKind.manual);
    });

    test('addManualEntry normalizes the sign regardless of user input sign', () async {
      final id = await service.create(
        name: 'Gift',
        direction: EventDirection.inflow,
        treatment: EventTreatment.instant,
        totalAmount: 10000,
        currency: 'EUR',
        eventDate: DateTime(2024, 6, 1),
      );

      // User passes a negative number by mistake — we still want +100 stored.
      await service.addManualEntry(
        eventId: id,
        date: DateTime(2024, 7, 1),
        amount: -100,
      );

      final entries = await service.getEntries(id);
      expect(entries[0].amount, 100);
    });
  });

  group('Spread events', () {
    test('outflow/spread auto-generates scheduled entries with negative amounts', () async {
      final id = await service.create(
        name: 'Car',
        direction: EventDirection.outflow,
        treatment: EventTreatment.spread,
        totalAmount: 600,
        currency: 'EUR',
        eventDate: DateTime(2024, 1, 1),
        stepFrequency: StepFrequency.monthly,
        spreadStart: DateTime(2024, 1, 1),
        spreadEnd: DateTime(2024, 6, 1),
      );

      final entries = await service.getEntries(id);
      expect(entries, hasLength(6));
      // 600 / 6 = 100 per step, negated for outflow direction.
      expect(entries[0].amount, -100);
      expect(entries[5].amount, -100);
      // Cumulative/remaining track the unsigned spread progress.
      expect(entries[0].cumulative, 100);
      expect(entries[5].cumulative, 600);
      expect(entries.last.remaining, 0);
      expect(entries.every((e) => e.entryKind == EventEntryKind.scheduled), isTrue);
    });

    test('inflow/spread auto-generates scheduled entries with positive amounts', () async {
      final id = await service.create(
        name: 'Structured settlement',
        direction: EventDirection.inflow,
        treatment: EventTreatment.spread,
        totalAmount: 1200,
        currency: 'EUR',
        eventDate: DateTime(2024, 1, 1),
        stepFrequency: StepFrequency.monthly,
        spreadStart: DateTime(2024, 1, 1),
        spreadEnd: DateTime(2024, 12, 1),
      );

      final entries = await service.getEntries(id);
      expect(entries, hasLength(12));
      expect(entries[0].amount, 100); // positive for inflow direction
    });

    test('update spread event regenerates scheduled entries', () async {
      final id = await service.create(
        name: 'Test',
        direction: EventDirection.outflow,
        treatment: EventTreatment.spread,
        totalAmount: 300,
        currency: 'EUR',
        eventDate: DateTime(2024, 1, 1),
        stepFrequency: StepFrequency.monthly,
        spreadStart: DateTime(2024, 1, 1),
        spreadEnd: DateTime(2024, 3, 1),
      );

      var entries = await service.getEntries(id);
      expect(entries, hasLength(3));

      // Extend the spread end date.
      await service.update(
        id,
        ExtraordinaryEventsCompanion(spreadEnd: Value(DateTime(2024, 6, 1))),
      );

      entries = await service.getEntries(id);
      expect(entries, hasLength(6));
      expect(entries[0].amount, -50); // 300 / 6 = 50, negated
    });

    test('spread event without required fields throws', () async {
      expect(
        () => service.create(
          name: 'Bad',
          direction: EventDirection.outflow,
          treatment: EventTreatment.spread,
          totalAmount: 100,
          currency: 'EUR',
          eventDate: DateTime(2024, 1, 1),
          // missing stepFrequency / spreadStart / spreadEnd
        ),
        throwsArgumentError,
      );
    });
  });

  group('Delete behavior', () {
    test('delete cascades entries', () async {
      final id = await service.create(
        name: 'Test',
        direction: EventDirection.outflow,
        treatment: EventTreatment.spread,
        totalAmount: 300,
        currency: 'EUR',
        eventDate: DateTime(2024, 1, 1),
        stepFrequency: StepFrequency.monthly,
        spreadStart: DateTime(2024, 1, 1),
        spreadEnd: DateTime(2024, 3, 1),
      );

      expect(await service.getEntries(id), hasLength(3));
      await service.delete(id);

      final remaining = await (db.select(db.extraordinaryEventEntries)
            ..where((e) => e.eventId.equals(id)))
          .get();
      expect(remaining, isEmpty);
    });

    test('deleteMany removes multiple events', () async {
      final id1 = await service.create(
        name: 'A',
        direction: EventDirection.inflow,
        treatment: EventTreatment.instant,
        totalAmount: 100,
        currency: 'EUR',
        eventDate: DateTime(2024, 1, 1),
      );
      final id2 = await service.create(
        name: 'B',
        direction: EventDirection.outflow,
        treatment: EventTreatment.instant,
        totalAmount: 200,
        currency: 'EUR',
        eventDate: DateTime(2024, 1, 1),
      );

      final deleted = await service.deleteMany([id1, id2]);
      expect(deleted, 2);
      expect(await service.getAll(), isEmpty);
    });

    test('deleteMany empty list is a no-op', () async {
      final deleted = await service.deleteMany([]);
      expect(deleted, 0);
    });
  });

  group('Stats', () {
    test('watchStatsForAll returns correct aggregates for mixed kinds', () async {
      final outflowId = await service.create(
        name: 'Car',
        direction: EventDirection.outflow,
        treatment: EventTreatment.spread,
        totalAmount: 600,
        currency: 'EUR',
        eventDate: DateTime(2024, 1, 1),
        stepFrequency: StepFrequency.monthly,
        spreadStart: DateTime(2024, 1, 1),
        spreadEnd: DateTime(2024, 6, 1),
      );

      final inflowId = await service.create(
        name: 'Gift',
        direction: EventDirection.inflow,
        treatment: EventTreatment.instant,
        totalAmount: 10000,
        currency: 'EUR',
        eventDate: DateTime(2024, 6, 1),
      );
      await service.addManualEntry(
        eventId: inflowId,
        date: DateTime(2024, 7, 1),
        amount: 1500,
      );

      final stats = await service.watchStatsForAll().first;
      expect(stats, hasLength(2));

      final outflowStats = stats[outflowId]!;
      expect(outflowStats.entryCount, 6);
      expect(outflowStats.totalAmount, 600);
      expect(outflowStats.totalAllocated, 600); // sum of |amount| = 6 * 100

      final inflowStats = stats[inflowId]!;
      expect(inflowStats.entryCount, 1);
      expect(inflowStats.totalAmount, 10000);
      expect(inflowStats.totalAllocated, 1500);
      expect(inflowStats.remaining, 8500);
    });
  });

  group('Ephemeral inflow flag', () {
    test('defaults to false when not specified', () async {
      final id = await service.create(
        name: 'Regular inflow',
        direction: EventDirection.inflow,
        treatment: EventTreatment.instant,
        totalAmount: 500,
        currency: 'EUR',
        eventDate: DateTime(2024, 6, 1),
      );
      final event = await service.getById(id);
      expect(event.isEphemeral, isFalse);
    });

    test('persists when set to true on inflow/instant', () async {
      final id = await service.create(
        name: 'Line of credit',
        direction: EventDirection.inflow,
        treatment: EventTreatment.instant,
        totalAmount: 500,
        currency: 'EUR',
        eventDate: DateTime(2024, 6, 1),
        isEphemeral: true,
      );
      final event = await service.getById(id);
      expect(event.isEphemeral, isTrue);
    });

    test('rejects ephemeral on outflow direction', () async {
      expect(
        () => service.create(
          name: 'Bad',
          direction: EventDirection.outflow,
          treatment: EventTreatment.instant,
          totalAmount: 100,
          currency: 'EUR',
          eventDate: DateTime(2024, 6, 1),
          isEphemeral: true,
        ),
        throwsArgumentError,
      );
    });

    test('rejects ephemeral on spread treatment', () async {
      expect(
        () => service.create(
          name: 'Bad',
          direction: EventDirection.inflow,
          treatment: EventTreatment.spread,
          totalAmount: 1200,
          currency: 'EUR',
          eventDate: DateTime(2024, 1, 1),
          stepFrequency: StepFrequency.monthly,
          spreadStart: DateTime(2024, 1, 1),
          spreadEnd: DateTime(2024, 12, 1),
          isEphemeral: true,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Buffer linking', () {
    test('createLinkedBuffer works for spread events', () async {
      final id = await service.create(
        name: 'Car',
        direction: EventDirection.outflow,
        treatment: EventTreatment.spread,
        totalAmount: 600,
        currency: 'EUR',
        eventDate: DateTime(2024, 1, 1),
        stepFrequency: StepFrequency.monthly,
        spreadStart: DateTime(2024, 1, 1),
        spreadEnd: DateTime(2024, 6, 1),
      );

      final bufferId = await service.createLinkedBuffer(id);
      expect(bufferId, greaterThan(0));

      final event = await service.getById(id);
      expect(event.bufferId, bufferId);
    });

    test('createLinkedBuffer throws for instant events', () async {
      final id = await service.create(
        name: 'Gift',
        direction: EventDirection.inflow,
        treatment: EventTreatment.instant,
        totalAmount: 10000,
        currency: 'EUR',
        eventDate: DateTime(2024, 6, 1),
      );

      expect(
        () => service.createLinkedBuffer(id),
        throwsStateError,
      );
    });

    test('reimbursements reduce effective spread amount', () async {
      final id = await service.create(
        name: 'Car',
        direction: EventDirection.outflow,
        treatment: EventTreatment.spread,
        totalAmount: 600,
        currency: 'EUR',
        eventDate: DateTime(2024, 1, 1),
        stepFrequency: StepFrequency.monthly,
        spreadStart: DateTime(2024, 1, 1),
        spreadEnd: DateTime(2024, 6, 1),
      );

      final bufferId = await service.createLinkedBuffer(id);

      // Insert a reimbursement transaction on the buffer.
      await db.into(db.bufferTransactions).insert(
        BufferTransactionsCompanion.insert(
          bufferId: bufferId,
          operationDate: DateTime(2024, 2, 1),
          valueDate: DateTime(2024, 2, 1),
          amount: 300,
          balanceAfter: 300,
          isReimbursement: const Value(true),
        ),
      );

      // Regenerate to pick up the reimbursement.
      await service.generateScheduledEntries(id);

      final entries = await service.getEntries(id);
      // (600 - 300) / 6 = 50 per step, negated for outflow.
      expect(entries[0].amount, -50);
    });
  });
}
