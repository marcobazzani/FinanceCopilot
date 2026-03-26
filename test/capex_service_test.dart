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

  group('schedule with quarterly frequency', () {
    test('create with quarterly frequency generates correct entries', () async {
      final id = await service.create(
        name: 'Quarterly Item',
        totalAmount: 1200,
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
