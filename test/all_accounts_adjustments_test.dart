// All-Accounts adjustment resolution — mirrors NAV adjustment composition.
//
// Anchor + buffer reimbursements match EXISTING transactions (annotated,
// excluded from totals). Scheduled spread entries are synthetic "Saving for X"
// rows (included). Ephemeral inflows: matching tx annotated (kept out of
// totals), no saving rows.
//
// NAV-equivalence pin: T-Roc's net All-Accounts cashflow == the scheduled
// spread (−12,400), with anchor (−20,400) and Morena reimbursements (+8,000)
// excluded — exactly NAV's net for a fully-reimbursed/amortized CAPEX.

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/ui/screens/accounts/adjustment_items.dart';

void main() {
  late AppDatabase db;
  late int acc;
  late int bufferId;

  int dayKey(DateTime d) => DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    acc = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Fineco'));
    bufferId = await db.into(db.buffers).insert(BuffersCompanion.insert(name: 'Buf'));
  });

  tearDown(() async => db.close());

  Future<Transaction> insTx(double amount, DateTime date, String desc) async {
    final id = await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: acc,
            operationDate: date,
            valueDate: date,
            amount: amount,
            description: Value(desc),
          ),
        );
    return (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<ExtraordinaryEvent> insEvent({
    required String name,
    required EventDirection dir,
    required double total,
    required DateTime date,
    bool ephemeral = false,
    int? buffer,
  }) async {
    final id = await db
        .into(db.extraordinaryEvents)
        .insert(
          ExtraordinaryEventsCompanion.insert(
            name: name,
            direction: dir,
            treatment: EventTreatment.spread,
            totalAmount: total,
            eventDate: date,
            isEphemeral: Value(ephemeral),
            bufferId: Value(buffer),
          ),
        );
    return (db.select(db.extraordinaryEvents)..where((e) => e.id.equals(id))).getSingle();
  }

  Future<ExtraordinaryEventEntry> insEntry(int eventId, DateTime date, double amount, EventEntryKind kind) async {
    final id = await db
        .into(db.extraordinaryEventEntries)
        .insert(
          ExtraordinaryEventEntriesCompanion.insert(eventId: eventId, date: date, amount: amount, entryKind: kind),
        );
    return (db.select(db.extraordinaryEventEntries)..where((e) => e.id.equals(id))).getSingle();
  }

  Future<BufferTransaction> insReimb(int buf, DateTime date, double amount) async {
    final id = await db
        .into(db.bufferTransactions)
        .insert(
          BufferTransactionsCompanion.insert(
            bufferId: buf,
            operationDate: date,
            valueDate: date,
            amount: amount,
            balanceAfter: 0,
            isReimbursement: const Value(true),
          ),
        );
    return (db.select(db.bufferTransactions)..where((t) => t.id.equals(id))).getSingle();
  }

  String adjusted(String n) => 'Adjusted: $n';
  String reimb(String n) => '$n reimb.';
  String savingFor(String n) => 'Saving for $n';
  String financed(String n) => 'Financed: $n';

  AdjustmentResolution run({
    required List<ExtraordinaryEvent> events,
    required Map<int, List<ExtraordinaryEventEntry>> entries,
    required Map<int, List<BufferTransaction>> reimbs,
    required List<Transaction> txs,
  }) {
    return resolveAdjustments(
      events: events,
      entriesByEvent: entries,
      reimbursementsByEvent: reimbs,
      transactions: txs,
      dayKey: dayKey,
      adjustedLabel: adjusted,
      reimbLabel: reimb,
      savingForLabel: savingFor,
      financedLabel: financed,
    );
  }

  test('T-Roc: anchor + reimbursements annotated, scheduled spread materialized', () async {
    final ev = await insEvent(name: 'T-Roc', dir: EventDirection.outflow, total: 20400, date: DateTime(2025, 3, 25), buffer: bufferId);
    final anchorTx = await insTx(-20400, DateTime(2025, 3, 25), 'GRUPPO M SRL');
    final m1 = await insTx(3000, DateTime(2025, 4, 13), 'PAGANO MORENA');
    final m2 = await insTx(5000, DateTime(2025, 7, 28), 'PAGANO MORENA');
    final r1 = await insReimb(bufferId, DateTime(2025, 4, 13), 3000);
    final r2 = await insReimb(bufferId, DateTime(2025, 7, 28), 5000);
    final entries = <ExtraordinaryEventEntry>[];
    for (var i = 0; i < 30; i++) {
      entries.add(await insEntry(ev.id, DateTime(2017, 4 + (i % 9), 25), -413.3333333, EventEntryKind.scheduled));
    }

    final res = run(
      events: [ev],
      entries: {ev.id: entries},
      reimbs: {
        ev.id: [r1, r2],
      },
      txs: [anchorTx, m1, m2],
    );

    expect(res.annotatedTxIds[anchorTx.id], 'Adjusted: T-Roc');
    expect(res.annotatedTxIds[m1.id], 'T-Roc reimb.');
    expect(res.annotatedTxIds[m2.id], 'T-Roc reimb.');
    expect(res.savingItems, hasLength(30));
    expect(res.savingItems.fold<double>(0, (s, e) => s + e.amount), closeTo(-12400, 0.01));
  });

  test('NAV-equivalence: net cashflow = scheduled spread only (anchor+reimb excluded)', () async {
    final ev = await insEvent(name: 'T-Roc', dir: EventDirection.outflow, total: 20400, date: DateTime(2025, 3, 25), buffer: bufferId);
    final anchorTx = await insTx(-20400, DateTime(2025, 3, 25), 'car');
    final m1 = await insTx(3000, DateTime(2025, 4, 13), 'morena');
    final r1 = await insReimb(bufferId, DateTime(2025, 4, 13), 3000);
    final sched = [await insEntry(ev.id, DateTime(2017, 4, 25), -12400, EventEntryKind.scheduled)];

    final res = run(
      events: [ev],
      entries: {ev.id: sched},
      reimbs: {
        ev.id: [r1],
      },
      txs: [anchorTx, m1],
    );

    // anchor + reimbursement excluded from totals (annotated)
    final excludedIds = res.annotatedTxIds.keys.toSet();
    expect(excludedIds, containsAll([anchorTx.id, m1.id]));
    // The only thing counting toward totals is the scheduled spread.
    final savingTotal = res.savingItems.fold<double>(0, (s, e) => s + e.amount);
    expect(savingTotal, -12400);
  });

  test('Donazione (inflow instant): anchor annotated, no saving rows', () async {
    final ev = await insEvent(name: 'Donazione', dir: EventDirection.inflow, total: 250000, date: DateTime(2025, 12, 15));
    final tx = await insTx(250000, DateTime(2025, 12, 15), 'BAZZANI GIULIANO');

    final res = run(events: [ev], entries: {}, reimbs: {}, txs: [tx]);
    expect(res.annotatedTxIds[tx.id], 'Adjusted: Donazione');
    expect(res.savingItems, isEmpty);
  });

  test('ephemeral inflow (Fido): matching tx annotated, excluded, no saving rows', () async {
    final ev = await insEvent(name: 'Fido', dir: EventDirection.inflow, total: 231000, date: DateTime(2026, 4, 8), ephemeral: true);
    final tx = await insTx(231000, DateTime(2026, 4, 8), 'credit line');

    final res = run(events: [ev], entries: {}, reimbs: {}, txs: [tx]);
    expect(res.annotatedTxIds.containsKey(tx.id), isTrue);
    expect(res.savingItems, isEmpty);
  });

  test('Fido credit-line drawdowns: manual entries match NEGATIVE txns, marked Financed, excluded', () async {
    final ev = await insEvent(name: 'Fido', dir: EventDirection.inflow, total: 231000, date: DateTime(2026, 4, 8), ephemeral: true);
    // Construction outflows paid by the credit line (negative txns).
    final serra1 = await insTx(-6540.01, DateTime(2026, 3, 2), 'TERMOIDRAULICA');
    final serra2 = await insTx(-45925.0, DateTime(2026, 4, 20), 'SERRA BETON');
    // Fido's manual entries are positive (drawdowns), matching the negative txns.
    final entries = [
      await insEntry(ev.id, DateTime(2026, 3, 2), 6540.01, EventEntryKind.manual),
      await insEntry(ev.id, DateTime(2026, 4, 20), 45925.0, EventEntryKind.manual),
    ];

    final res = run(events: [ev], entries: {ev.id: entries}, reimbs: {}, txs: [serra1, serra2]);

    expect(res.annotatedTxIds[serra1.id], 'Financed: Fido');
    expect(res.annotatedTxIds[serra2.id], 'Financed: Fido');
    expect(res.savingItems, isEmpty, reason: 'manual entries matched real txns — no synthetic rows');
  });

  test('anchor sign matters: outflow does not match a positive tx', () async {
    final ev = await insEvent(name: 'X', dir: EventDirection.outflow, total: 100, date: DateTime(2025, 1, 1));
    final wrongSign = await insTx(100, DateTime(2025, 1, 1), 'positive'); // outflow should match negative

    final res = run(events: [ev], entries: {}, reimbs: {}, txs: [wrongSign]);
    expect(res.annotatedTxIds, isEmpty);
  });

  test('different date/amount does not match anchor', () async {
    final ev = await insEvent(name: 'X', dir: EventDirection.outflow, total: 100, date: DateTime(2025, 1, 1));
    final wrongDate = await insTx(-100, DateTime(2025, 1, 2), 'next day');
    final wrongAmt = await insTx(-101, DateTime(2025, 1, 1), 'off by one');

    final res = run(events: [ev], entries: {}, reimbs: {}, txs: [wrongDate, wrongAmt]);
    expect(res.annotatedTxIds, isEmpty);
  });
}
