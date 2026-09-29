// Pins the date-bounded reads of the domain services before their watch/get
// query pairs share one builder and their "as of" SQL shares one bound: the
// rows each read returns, in the order it returns them, unbounded and as of
// a day given with a time of day (the whole day is in, the next one out).
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/account_service.dart';
import 'package:finance_copilot/services/domain/asset_event_service.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';
import 'package:finance_copilot/services/domain/buffer_service.dart';
import 'package:finance_copilot/services/domain/extraordinary_event_service.dart';
import 'package:finance_copilot/services/domain/income_service.dart';

void main() {
  final d0 = DateTime(2024, 1, 10, 12);
  final d1 = DateTime(2024, 2, 29, 23, 30); // late on the day read "as of"
  final d2 = DateTime(2024, 3, 1, 0, 30); // early on the day after
  final d3 = DateTime(2024, 4, 1, 12);
  final through = DateTime(2024, 2, 29, 15, 42);
  // Inserted out of chronological order: the order read back is the query's.
  final insertionOrder = [d2, d0, d3, d1];

  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> asset(String name) async {
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker $name'));
    return db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: name,
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: broker,
          ),
        );
  }

  Future<int> assetEvent(int assetId, DateTime on, EventType type, {required double amount, double? qty, double? price}) => db
      .into(db.assetEvents)
      .insert(
        AssetEventsCompanion.insert(
          assetId: assetId,
          date: on,
          valueDate: on,
          type: type,
          amount: amount,
          quantity: Value(qty),
          price: Value(price),
        ),
      );

  test('asset events of one asset: newest first; several assets grouped, each newest first', () async {
    final svc = AssetEventService(db);
    final a = await asset('A');
    final b = await asset('B');
    final ids = <DateTime, int>{};
    for (final on in insertionOrder) {
      ids[on] = await assetEvent(a, on, EventType.buy, amount: 10, qty: 1, price: 10);
      // A minute later: B's event of the day is the newer one.
      await assetEvent(b, on.add(const Duration(minutes: 1)), EventType.buy, amount: 20, qty: 2, price: 10);
    }

    List<int> idsOf(List<AssetEvent> events) => events.map((e) => e.id).toList();
    final all = [ids[d3]!, ids[d2]!, ids[d1]!, ids[d0]!];
    final asOf = [ids[d1]!, ids[d0]!];
    expect(idsOf(await svc.getByAsset(a)), all);
    expect(idsOf(await svc.watchByAsset(a).first), all);
    expect(idsOf(await svc.getByAsset(a, through: through)), asOf);
    expect(idsOf(await svc.watchByAsset(a, through: through).first), asOf);

    final grouped = await svc.getByAssets([a, b], through: through);
    expect(grouped.keys, [b, a], reason: 'grouped in the order the rows come: newest first');
    expect(idsOf(grouped[a]!), asOf);
    expect(grouped[b]!.map((e) => e.valueDate), [d1, d0].map((on) => on.add(const Duration(minutes: 1))));
    expect(idsOf((await svc.getByAssets([a]))[a]!), all);
  });

  test('asset events as of the day: average buy price and latest revalue', () async {
    final svc = AssetEventService(db);
    final a = await asset('A');
    await assetEvent(a, d0, EventType.buy, amount: 10, qty: 1, price: 10);
    await assetEvent(a, d1, EventType.buy, amount: 60, qty: 2, price: 30);
    await assetEvent(a, d2, EventType.buy, amount: 1000, qty: 1, price: 1000);
    await assetEvent(a, d1, EventType.revalue, amount: 111);
    await assetEvent(a, d3, EventType.revalue, amount: 333);

    expect(await svc.getAverageBuyPrice(a), (10 + 60 + 1000) / 4);
    expect(await svc.getAverageBuyPrice(a, through: through), 70 / 3);
    expect(await svc.getLatestRevalueAmount(a), 333);
    expect(await svc.getLatestRevalueAmount(a, through: through), 111);
    expect(await svc.getLatestRevalueAmount(a, through: DateTime(2024, 2, 28)), isNull);
  });

  test('asset stats as of the day', () async {
    final svc = AssetService(db);
    final a = await asset('A');
    await assetEvent(a, d0, EventType.buy, amount: 10, qty: 1, price: 10);
    await assetEvent(a, d1, EventType.buy, amount: 60, qty: 2, price: 30);
    await assetEvent(a, d2, EventType.sell, amount: 40, qty: 1, price: 40);

    for (final stats in [await svc.getStatsForAll(), await svc.watchStatsForAll().first]) {
      expect((stats[a]!.eventCount, stats[a]!.totalQuantity, stats[a]!.lastDate), (3, 2, d2));
    }
    for (final stats in [await svc.getStatsForAll(through: through), await svc.watchStatsForAll(through: through).first]) {
      expect((stats[a]!.eventCount, stats[a]!.totalQuantity, stats[a]!.totalInvested, stats[a]!.lastDate), (2, 3, 70, d1));
    }
  });

  test('incomes: newest first', () async {
    final svc = IncomeService(db);
    final ids = <DateTime, int>{};
    for (final on in insertionOrder) {
      ids[on] = await svc.create(date: on, amount: 10, currency: 'EUR');
    }

    final all = [ids[d3]!, ids[d2]!, ids[d1]!, ids[d0]!];
    final asOf = [ids[d1]!, ids[d0]!];
    expect((await svc.getAll()).map((i) => i.id), all);
    expect((await svc.watchAll().first).map((i) => i.id), all);
    expect((await svc.getAll(through: through)).map((i) => i.id), asOf);
    expect((await svc.watchAll(through: through).first).map((i) => i.id), asOf);
  });

  test('buffer transactions: read oldest first, watched newest first; the balance as of the day', () async {
    final svc = BufferService(db);
    final buffer = await svc.create(name: 'Holiday');
    final other = await svc.create(name: 'Other');
    final ids = <DateTime, int>{};
    for (final (i, on) in insertionOrder.indexed) {
      ids[on] = await svc.createTransaction(bufferId: buffer, operationDate: on, amount: 10.0 * (i + 1), currency: 'EUR');
      await svc.createTransaction(bufferId: other, operationDate: on, amount: 1000, currency: 'EUR');
    }

    final oldestFirst = [ids[d0]!, ids[d1]!, ids[d2]!, ids[d3]!];
    expect((await svc.getByBuffer(buffer)).map((t) => t.id), oldestFirst);
    expect((await svc.watchByBuffer(buffer).first).map((t) => t.id), oldestFirst.reversed);
    expect((await svc.getByBuffer(buffer, through: through)).map((t) => t.id), [ids[d0]!, ids[d1]!]);
    expect((await svc.watchByBuffer(buffer, through: through).first).map((t) => t.id), [ids[d1]!, ids[d0]!]);
    expect(await svc.computeBalance(buffer), 100);
    expect(await svc.computeBalance(buffer, through: through), 20 + 40);
  });

  test('adjustments: active events newest first, entries oldest first, stats as of the day', () async {
    final svc = ExtraordinaryEventService(db);
    final buffer = await db.into(db.buffers).insert(BuffersCompanion.insert(name: 'Refunds'));
    Future<int> event(String name, DateTime on, {bool active = true, int? bufferId}) => db
        .into(db.extraordinaryEvents)
        .insert(
          ExtraordinaryEventsCompanion.insert(
            name: name,
            direction: EventDirection.outflow,
            treatment: EventTreatment.instant,
            totalAmount: 500,
            eventDate: on,
            isActive: Value(active),
            bufferId: Value(bufferId),
          ),
        );
    final late = await event('Late', d3);
    final early = await event('Early', d0, bufferId: buffer);
    await event('Inactive', d0, active: false);
    final onTheDay = await event('On the day', d1);

    final entryIds = <DateTime, int>{};
    for (final on in insertionOrder) {
      entryIds[on] = await db
          .into(db.extraordinaryEventEntries)
          .insert(ExtraordinaryEventEntriesCompanion.insert(eventId: early, date: on, amount: -50, entryKind: EventEntryKind.manual));
      await db
          .into(db.extraordinaryEventEntries)
          .insert(ExtraordinaryEventEntriesCompanion.insert(eventId: late, date: on, amount: -5, entryKind: EventEntryKind.manual));
      await db
          .into(db.bufferTransactions)
          .insert(
            BufferTransactionsCompanion.insert(
              bufferId: buffer,
              operationDate: on,
              valueDate: on,
              amount: 20,
              balanceAfter: 0,
              isReimbursement: const Value(true),
            ),
          );
    }

    expect((await svc.getAll()).map((e) => e.id), [late, onTheDay, early]);
    expect((await svc.watchAll().first).map((e) => e.id), [late, onTheDay, early]);
    expect((await svc.getAll(through: through)).map((e) => e.id), [onTheDay, early]);
    expect((await svc.watchAll(through: through).first).map((e) => e.id), [onTheDay, early]);

    final oldestFirst = [entryIds[d0]!, entryIds[d1]!, entryIds[d2]!, entryIds[d3]!];
    expect((await svc.getEntries(early)).map((e) => e.id), oldestFirst);
    expect((await svc.watchEntries(early).first).map((e) => e.id), oldestFirst);
    expect((await svc.getEntries(early, through: through)).map((e) => e.id), [entryIds[d0]!, entryIds[d1]!]);
    expect((await svc.watchEntries(early, through: through).first).map((e) => e.id), [entryIds[d0]!, entryIds[d1]!]);

    final all = await svc.watchStatsForAll().first;
    expect(all.keys, [late, early, onTheDay]);
    expect((all[early]!.entryCount, all[early]!.totalAllocated, all[early]!.totalReimbursed), (4, 200, 80));
    expect((all[early]!.firstDate, all[early]!.lastDate), (d0, d3));
    final asOf = await svc.watchStatsForAll(through: through).first;
    expect(asOf.keys, [early, onTheDay]);
    expect((asOf[early]!.entryCount, asOf[early]!.totalAllocated, asOf[early]!.totalReimbursed), (2, 100, 40));
    expect((asOf[early]!.firstDate, asOf[early]!.lastDate, asOf[early]!.remaining), (d0, d1, 400));
    expect((asOf[onTheDay]!.entryCount, asOf[onTheDay]!.firstDate), (0, null));
  });

  test('account stats and latest balance as of the day', () async {
    final svc = AccountService(db);
    final account = await svc.create(name: 'Main', currency: 'EUR');
    final other = await svc.create(name: 'Other', currency: 'EUR');
    for (final (i, on) in insertionOrder.indexed) {
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              accountId: account,
              operationDate: on,
              valueDate: on,
              amount: 10,
              balanceAfter: Value(100.0 + on.month + i),
            ),
          );
    }
    await db
        .into(db.transactions)
        .insert(TransactionsCompanion.insert(accountId: other, operationDate: d2, valueDate: d2, amount: 5, balanceAfter: const Value(5)));

    for (final stats in [await svc.getStatsForAll(), await svc.watchStatsForAll().first]) {
      expect(stats.keys, [account, other]);
      expect((stats[account]!.count, stats[account]!.firstDate, stats[account]!.lastDate, stats[account]!.balance), (4, d0, d3, 106));
      expect(stats[other]!.balance, 5);
    }
    for (final stats in [await svc.getStatsForAll(through: through), await svc.watchStatsForAll(through: through).first]) {
      expect(stats.keys, [account]);
      expect((stats[account]!.count, stats[account]!.firstDate, stats[account]!.lastDate, stats[account]!.balance), (2, d0, d1, 105));
    }
  });
}
