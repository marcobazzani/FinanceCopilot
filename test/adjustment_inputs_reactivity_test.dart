// Adjustment-entry reactivity — regression tests.
//
// Marking a transaction as an adjustment writes ONLY to
// `extraordinary_event_entries`. Before this fix, every reactive consumer
// hung off `select(extraordinaryEvents).watch()`, which fires only on the
// `extraordinary_events` table. So a freshly-flagged adjustment stayed
// invisible for the rest of the session: no badge in the ledger, and the
// transaction kept counting toward the day/month totals. It only appeared
// after an app restart (when the provider ran once at launch) or after some
// unrelated write to the events table.
//
// `readsFrom` declared on a one-shot `.get()` is inert — it only affects
// `.watch()`. These tests pin that the trigger stream genuinely re-emits on
// entry/buffer writes with NO write to `extraordinary_events`.

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/extraordinary_event_service.dart';
import 'package:finance_copilot/ui/screens/accounts/adjustment_items.dart';

void main() {
  late AppDatabase db;
  late ExtraordinaryEventService service;

  int dayKey(DateTime d) => DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = ExtraordinaryEventService(db);
  });

  tearDown(() async => await db.close());

  Future<int> insEphemeralInflow({
    required String name,
    required double total,
    required DateTime date,
  }) => service.create(
    name: name,
    direction: EventDirection.inflow,
    treatment: EventTreatment.instant,
    totalAmount: total,
    currency: 'EUR',
    eventDate: date,
    isEphemeral: true,
  );

  group('watchAdjustmentRevision', () {
    test('re-emits after addManualEntry with no write to extraordinary_events', () async {
      final eventId = await insEphemeralInflow(
        name: 'Fido Fideuram',
        total: 200000,
        date: DateTime(2026, 7, 7),
      );

      final emissions = <int>[];
      var tick = 0;
      final sub = service.watchAdjustmentRevision().listen((_) => emissions.add(tick++));

      // Initial emission on subscribe — the UI needs data on first build.
      await pumpEventQueue();
      expect(emissions.length, 1, reason: 'trigger must emit immediately on subscribe');

      // The ONLY write is to extraordinary_event_entries.
      await service.addManualEntry(
        eventId: eventId,
        date: DateTime(2026, 8, 3),
        amount: 3089.24,
        description: 'Disposizione Di Bonifico',
      );
      await pumpEventQueue();

      expect(
        emissions.length,
        greaterThan(1),
        reason: 'adding a manual entry must re-emit without touching extraordinary_events',
      );

      await sub.cancel();
    });

    test('re-emits after deleteEntry', () async {
      final eventId = await insEphemeralInflow(
        name: 'Fido Fideuram',
        total: 200000,
        date: DateTime(2026, 7, 7),
      );
      final entryId = await service.addManualEntry(
        eventId: eventId,
        date: DateTime(2026, 8, 3),
        amount: 3089.24,
      );

      var count = 0;
      final sub = service.watchAdjustmentRevision().listen((_) => count++);
      await pumpEventQueue();
      final afterSubscribe = count;

      await service.deleteEntry(entryId);
      await pumpEventQueue();

      expect(count, greaterThan(afterSubscribe), reason: 'deleting an entry must re-emit');

      await sub.cancel();
    });

    test('re-emits after a buffer reimbursement insert', () async {
      final bufferId = await db.into(db.buffers).insert(BuffersCompanion.insert(name: 'Buf'));

      var count = 0;
      final sub = service.watchAdjustmentRevision().listen((_) => count++);
      await pumpEventQueue();
      final afterSubscribe = count;

      await db
          .into(db.bufferTransactions)
          .insert(
            BufferTransactionsCompanion.insert(
              bufferId: bufferId,
              operationDate: DateTime(2026, 8, 3),
              valueDate: DateTime(2026, 8, 3),
              amount: 500,
              balanceAfter: 0,
              isReimbursement: const Value(true),
            ),
          );
      await pumpEventQueue();

      expect(count, greaterThan(afterSubscribe), reason: 'buffer reimbursement must re-emit');

      await sub.cancel();
    });
  });

  group('watchStatsForAll', () {
    test('reflects a new manual entry without a write to extraordinary_events', () async {
      final eventId = await insEphemeralInflow(
        name: 'Fido Fideuram',
        total: 200000,
        date: DateTime(2026, 7, 7),
      );

      final seen = <ExtraordinaryEventStats>[];
      final sub = service.watchStatsForAll().listen((m) {
        final s = m[eventId];
        if (s != null) seen.add(s);
      });
      await pumpEventQueue();
      expect(seen.last.entryCount, 0);

      await service.addManualEntry(
        eventId: eventId,
        date: DateTime(2026, 8, 3),
        amount: 3089.24,
      );
      await pumpEventQueue();

      expect(seen.last.entryCount, 1, reason: 'stats must pick up the new entry live');
      expect(seen.last.totalAllocated, closeTo(3089.24, 0.001));
      expect(seen.last.remaining, closeTo(200000 - 3089.24, 0.001));

      await sub.cancel();
    });
  });

  group('duplicate manual entries', () {
    test('countIdenticalManualEntries counts 0/1/2 for same event+day+amount', () async {
      final eventId = await insEphemeralInflow(
        name: 'Fido Fideuram',
        total: 200000,
        date: DateTime(2026, 7, 7),
      );
      final date = DateTime(2026, 8, 3);

      expect(
        await service.countIdenticalManualEntries(eventId: eventId, date: date, amount: 3089.24),
        0,
      );

      await service.addManualEntry(eventId: eventId, date: date, amount: 3089.24);
      expect(
        await service.countIdenticalManualEntries(eventId: eventId, date: date, amount: 3089.24),
        1,
      );

      // Second identical entry is allowed (two identical same-day drawdowns are
      // legitimate) — the count simply reports it so the UI can confirm.
      await service.addManualEntry(eventId: eventId, date: date, amount: 3089.24);
      expect(
        await service.countIdenticalManualEntries(eventId: eventId, date: date, amount: 3089.24),
        2,
      );
    });

    test('different amounts on the same day are not flagged as duplicates', () async {
      // Pins the real-world case: Credit Lombard has 13834.61 and 377.31 both
      // on 2026-07-01. These are distinct drawdowns, never duplicates.
      final eventId = await insEphemeralInflow(
        name: 'Credit Lombard',
        total: 231000,
        date: DateTime(2026, 4, 8),
      );
      final date = DateTime(2026, 7, 1);

      await service.addManualEntry(eventId: eventId, date: date, amount: 13834.61);

      expect(
        await service.countIdenticalManualEntries(eventId: eventId, date: date, amount: 377.31),
        0,
        reason: 'a different amount on the same day is a distinct entry',
      );
      expect(
        await service.countIdenticalManualEntries(eventId: eventId, date: date, amount: 13834.61),
        1,
      );
    });

    test('a different day with the same amount is not a duplicate', () async {
      final eventId = await insEphemeralInflow(
        name: 'Fido Fideuram',
        total: 200000,
        date: DateTime(2026, 7, 7),
      );

      await service.addManualEntry(eventId: eventId, date: DateTime(2026, 8, 3), amount: 3089.24);

      expect(
        await service.countIdenticalManualEntries(
          eventId: eventId,
          date: DateTime(2026, 8, 4),
          amount: 3089.24,
        ),
        0,
      );
    });

    test('ignores time-of-day when comparing dates', () async {
      final eventId = await insEphemeralInflow(
        name: 'Fido Fideuram',
        total: 200000,
        date: DateTime(2026, 7, 7),
      );

      await service.addManualEntry(eventId: eventId, date: DateTime(2026, 8, 3), amount: 3089.24);

      expect(
        await service.countIdenticalManualEntries(
          eventId: eventId,
          date: DateTime(2026, 8, 3, 17, 42),
          amount: 3089.24,
        ),
        1,
        reason: 'duplicate detection is day-granular, not timestamp-granular',
      );
    });
  });

  group('end-to-end: flagging a credit-line drawdown', () {
    test('freshly added entry annotates the negative tx as Financed, no saving rows', () async {
      final acc = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Fideuram'));
      final eventId = await insEphemeralInflow(
        name: 'Fido Fideuram',
        total: 200000,
        date: DateTime(2026, 7, 7),
      );

      // The real bank movement: a negative Fideuram transfer.
      final txId = await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              accountId: acc,
              operationDate: DateTime(2026, 8, 3),
              valueDate: DateTime(2026, 8, 3),
              amount: -3089.24,
              description: const Value('Disposizione Di Bonifico'),
            ),
          );
      final tx = await (db.select(db.transactions)..where((t) => t.id.equals(txId))).getSingle();

      // Flag it — writes an entry only.
      await service.addManualEntry(
        eventId: eventId,
        date: tx.valueDate,
        amount: tx.amount.abs(),
        description: tx.description,
      );

      // Reload inputs the way the ledger does, then resolve.
      final events = await service.getAll();
      final entries = await service.getEntries(eventId);
      final res = resolveAdjustments(
        events: events,
        entriesByEvent: {eventId: entries},
        reimbursementsByEvent: const {},
        transactions: [tx],
        dayKey: dayKey,
        adjustedLabel: (n) => 'Adjusted: $n',
        reimbLabel: (n) => '$n reimb.',
        savingForLabel: (n) => 'Saving for $n',
        financedLabel: (n) => 'Financed: $n',
      );

      expect(res.annotatedTxIds[tx.id], 'Financed: Fido Fideuram');
      expect(res.savingItems, isEmpty, reason: 'ephemeral inflows produce no saving schedule rows');
    });
  });
}
