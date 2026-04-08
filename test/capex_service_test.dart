import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/capex_service.dart';

void main() {
  late AppDatabase db;
  late CapexService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = CapexService(db);
  });

  tearDown(() async => await db.close());

  group('Schedule CRUD', () {
    test('create schedule and verify entries auto-generated', () async {
      final id = await service.create(
        name: 'Laptop',
        totalAmount: 1200,
        currency: 'EUR',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 12, 1),
      );

      final schedule = await service.getById(id);
      expect(schedule.assetName, 'Laptop');
      expect(schedule.totalAmount, 1200);

      final entries = await service.getEntries(id);
      // Jan to Dec = 12 months
      expect(entries, hasLength(12));
    });

    test('entries spread amount correctly across steps', () async {
      final id = await service.create(
        name: 'Desk',
        totalAmount: 600,
        currency: 'EUR',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 6, 1),
      );

      final entries = await service.getEntries(id);
      expect(entries, hasLength(6));
      // 600 / 6 = 100 per step
      expect(entries[0].amount, 100);
      expect(entries[1].amount, 100);
      expect(entries[0].cumulative, 100);
      expect(entries[1].cumulative, 200);
      expect(entries.last.remaining, 0);
    });

    test('update schedule regenerates entries', () async {
      final id = await service.create(
        name: 'Chair',
        totalAmount: 300,
        currency: 'EUR',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 3, 1),
      );

      var entries = await service.getEntries(id);
      expect(entries, hasLength(3));

      // Extend the end date
      await service.update(
        id,
        DepreciationSchedulesCompanion(endDate: Value(DateTime(2024, 6, 1))),
      );

      entries = await service.getEntries(id);
      expect(entries, hasLength(6));
    });

    test('delete schedule cascades entries', () async {
      final id = await service.create(
        name: 'Monitor',
        totalAmount: 400,
        currency: 'EUR',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 4, 1),
      );

      var entries = await service.getEntries(id);
      expect(entries, hasLength(4));

      await service.delete(id);

      // Entries are gone
      final allEntries = await db.select(db.depreciationEntries).get();
      expect(allEntries, isEmpty);

      // Schedule is gone
      final schedules = await service.getAll();
      expect(schedules, isEmpty);
    });

    test('entries ordered asc by date', () async {
      final id = await service.create(
        name: 'Keyboard',
        totalAmount: 120,
        currency: 'EUR',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 4, 1),
      );

      final entries = await service.getEntries(id);
      for (var i = 1; i < entries.length; i++) {
        expect(entries[i].date.isAfter(entries[i - 1].date), isTrue);
      }
    });

    test('getAll returns only active schedules', () async {
      await service.create(
        name: 'Active',
        totalAmount: 100,
        currency: 'EUR',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 3, 1),
      );

      final all = await service.getAll();
      expect(all, hasLength(1));
      expect(all.first.assetName, 'Active');
    });
  });

  group('computeStepDates', () {
    test('monthly produces correct dates', () {
      final dates = CapexService.computeStepDates(
        DateTime(2024, 1, 1),
        DateTime(2024, 6, 1),
        StepFrequency.monthly,
      );

      expect(dates, hasLength(6));
      expect(dates[0], DateTime(2024, 1, 1));
      expect(dates[1], DateTime(2024, 2, 1));
      expect(dates[2], DateTime(2024, 3, 1));
      expect(dates[3], DateTime(2024, 4, 1));
      expect(dates[4], DateTime(2024, 5, 1));
      expect(dates[5], DateTime(2024, 6, 1));
    });

    test('quarterly produces correct dates', () {
      final dates = CapexService.computeStepDates(
        DateTime(2024, 1, 1),
        DateTime(2024, 12, 31),
        StepFrequency.quarterly,
      );

      expect(dates, hasLength(4));
      expect(dates[0], DateTime(2024, 1, 1));
      expect(dates[1], DateTime(2024, 4, 1));
      expect(dates[2], DateTime(2024, 7, 1));
      expect(dates[3], DateTime(2024, 10, 1));
    });

    test('weekly produces correct dates', () {
      final dates = CapexService.computeStepDates(
        DateTime(2024, 1, 1),
        DateTime(2024, 1, 29),
        StepFrequency.weekly,
      );

      expect(dates, hasLength(5));
      expect(dates[0], DateTime(2024, 1, 1));
      expect(dates[1], DateTime(2024, 1, 8));
      expect(dates[2], DateTime(2024, 1, 15));
      expect(dates[3], DateTime(2024, 1, 22));
      expect(dates[4], DateTime(2024, 1, 29));
    });

    test('yearly produces correct dates', () {
      final dates = CapexService.computeStepDates(
        DateTime(2022, 1, 1),
        DateTime(2024, 12, 31),
        StepFrequency.yearly,
      );

      expect(dates, hasLength(3));
      expect(dates[0], DateTime(2022, 1, 1));
      expect(dates[1], DateTime(2023, 1, 1));
      expect(dates[2], DateTime(2024, 1, 1));
    });
  });

  group('computeEndDate / computeStartDate', () {
    test('computeEndDate monthly', () {
      final end = CapexService.computeEndDate(
        DateTime(2024, 1, 1),
        6,
        StepFrequency.monthly,
      );
      expect(end, DateTime(2024, 6, 1));
    });

    test('computeEndDate quarterly', () {
      final end = CapexService.computeEndDate(
        DateTime(2024, 1, 1),
        4,
        StepFrequency.quarterly,
      );
      expect(end, DateTime(2024, 10, 1));
    });

    test('computeStartDate monthly', () {
      final start = CapexService.computeStartDate(
        DateTime(2024, 6, 1),
        6,
        StepFrequency.monthly,
      );
      expect(start, DateTime(2024, 1, 1));
    });

    test('computeStartDate quarterly', () {
      final start = CapexService.computeStartDate(
        DateTime(2024, 10, 1),
        4,
        StepFrequency.quarterly,
      );
      expect(start, DateTime(2024, 1, 1));
    });

    test('computeEndDate and computeStartDate are inverse', () {
      final origin = DateTime(2024, 3, 15);
      const steps = 8;
      const freq = StepFrequency.monthly;

      final end = CapexService.computeEndDate(origin, steps, freq);
      final back = CapexService.computeStartDate(end, steps, freq);
      expect(back, origin);
    });
  });

  group('_totalReimbursed', () {
    test('sums abs of reimbursement transactions only', () async {
      // Create a buffer
      final bufferId = await db.into(db.buffers).insert(
        BuffersCompanion.insert(name: 'Test Buffer'),
      );

      // Create a schedule linked to that buffer
      final scheduleId = await service.create(
        name: 'Reimbursed Item',
        totalAmount: 1000,
        currency: 'EUR',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 6, 1),
      );
      await (db.update(db.depreciationSchedules)
            ..where((s) => s.id.equals(scheduleId)))
          .write(DepreciationSchedulesCompanion(bufferId: Value(bufferId)));

      // Insert 2 reimbursement transactions and 1 non-reimbursement
      final now = DateTime(2024, 3, 1);
      await db.into(db.bufferTransactions).insert(
        BufferTransactionsCompanion.insert(
          bufferId: bufferId,
          operationDate: now,
          valueDate: now,
          amount: -50.0,
          balanceAfter: -50.0,
          isReimbursement: const Value(true),
        ),
      );
      await db.into(db.bufferTransactions).insert(
        BufferTransactionsCompanion.insert(
          bufferId: bufferId,
          operationDate: now,
          valueDate: now,
          amount: -30.0,
          balanceAfter: -80.0,
          isReimbursement: const Value(true),
        ),
      );
      await db.into(db.bufferTransactions).insert(
        BufferTransactionsCompanion.insert(
          bufferId: bufferId,
          operationDate: now,
          valueDate: now,
          amount: -100.0,
          balanceAfter: -180.0,
          isReimbursement: const Value(false),
        ),
      );

      final stats = await service.watchStatsForAll().first;
      expect(stats[scheduleId]!.totalReimbursed, 80.0);
    });

    test('returns 0 when no reimbursements', () async {
      final bufferId = await db.into(db.buffers).insert(
        BuffersCompanion.insert(name: 'No Reimb Buffer'),
      );

      final scheduleId = await service.create(
        name: 'No Reimb Item',
        totalAmount: 500,
        currency: 'EUR',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 3, 1),
      );
      await (db.update(db.depreciationSchedules)
            ..where((s) => s.id.equals(scheduleId)))
          .write(DepreciationSchedulesCompanion(bufferId: Value(bufferId)));

      // Only non-reimbursement transactions
      final now = DateTime(2024, 2, 1);
      await db.into(db.bufferTransactions).insert(
        BufferTransactionsCompanion.insert(
          bufferId: bufferId,
          operationDate: now,
          valueDate: now,
          amount: -100.0,
          balanceAfter: -100.0,
          isReimbursement: const Value(false),
        ),
      );

      final stats = await service.watchStatsForAll().first;
      expect(stats[scheduleId]!.totalReimbursed, 0.0);
    });

    test('returns 0 when schedule has no buffer', () async {
      final scheduleId = await service.create(
        name: 'No Buffer Item',
        totalAmount: 300,
        currency: 'EUR',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 3, 1),
      );

      final stats = await service.watchStatsForAll().first;
      expect(stats[scheduleId]!.totalReimbursed, 0.0);
    });
  });

  group('watchStatsForAll', () {
    test('returns correct stats for multiple schedules', () async {
      // Schedule 1: 3 months, 600 total
      final id1 = await service.create(
        name: 'Schedule A',
        totalAmount: 600,
        currency: 'EUR',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 3, 1),
      );

      // Schedule 2: 4 months, 1200 total, with reimbursement
      final id2 = await service.create(
        name: 'Schedule B',
        totalAmount: 1200,
        currency: 'EUR',
        startDate: DateTime(2024, 4, 1),
        endDate: DateTime(2024, 7, 1),
      );

      // Link a buffer to schedule 2 with a reimbursement
      final bufferId = await db.into(db.buffers).insert(
        BuffersCompanion.insert(name: 'Buffer B'),
      );
      await (db.update(db.depreciationSchedules)
            ..where((s) => s.id.equals(id2)))
          .write(DepreciationSchedulesCompanion(bufferId: Value(bufferId)));
      await db.into(db.bufferTransactions).insert(
        BufferTransactionsCompanion.insert(
          bufferId: bufferId,
          operationDate: DateTime(2024, 5, 1),
          valueDate: DateTime(2024, 5, 1),
          amount: -200.0,
          balanceAfter: -200.0,
          isReimbursement: const Value(true),
        ),
      );
      // Regenerate entries for schedule 2 now that buffer exists
      await service.generateEntries(id2);

      // Create an inactive schedule (should not appear)
      final id3 = await service.create(
        name: 'Inactive',
        totalAmount: 100,
        currency: 'EUR',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 2, 1),
      );
      await (db.update(db.depreciationSchedules)
            ..where((s) => s.id.equals(id3)))
          .write(const DepreciationSchedulesCompanion(isActive: Value(false)));

      final stats = await service.watchStatsForAll().first;

      // Inactive schedule should NOT be in results
      expect(stats.containsKey(id3), isFalse);

      // Schedule A: 3 entries, 600/3=200 each, remaining=0
      final s1 = stats[id1]!;
      expect(s1.entryCount, 3);
      expect(s1.totalSpread, closeTo(600, 0.01));
      expect(s1.firstDate, DateTime(2024, 1, 1));
      expect(s1.lastDate, DateTime(2024, 3, 1));
      expect(s1.remaining, closeTo(0, 0.01));
      expect(s1.totalReimbursed, 0.0);

      // Schedule B: 4 entries, (1200-200)/4=250 each, remaining=0
      final s2 = stats[id2]!;
      expect(s2.entryCount, 4);
      expect(s2.totalSpread, closeTo(1000, 0.01));
      expect(s2.firstDate, DateTime(2024, 4, 1));
      expect(s2.lastDate, DateTime(2024, 7, 1));
      expect(s2.remaining, closeTo(0, 0.01));
      expect(s2.totalReimbursed, 200.0);
    });
  });

  group('schedule with quarterly frequency', () {
    test('create with quarterly frequency generates correct entries', () async {
      final id = await service.create(
        name: 'Quarterly Item',
        totalAmount: 1200,
        currency: 'EUR',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 10, 1),
        stepFrequency: StepFrequency.quarterly,
      );

      final entries = await service.getEntries(id);
      expect(entries, hasLength(4));
      // 1200 / 4 = 300 per step
      expect(entries[0].amount, 300);
      expect(entries.last.remaining, 0);
    });
  });
}
