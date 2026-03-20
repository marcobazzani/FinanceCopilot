import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asset_manager/database/database.dart';
import 'package:asset_manager/services/income_service.dart';

void main() {
  late AppDatabase db;
  late IncomeService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = IncomeService(db);
  });

  tearDown(() async => await db.close());

  group('Income CRUD', () {
    test('create and retrieve', () async {
      final id = await service.create(
        date: DateTime(2024, 6, 15),
        amount: 3000,
        description: 'June salary',
        currency: 'EUR',
      );

      final income = await service.getById(id);
      expect(income.amount, 3000);
      expect(income.description, 'June salary');
      expect(income.currency, 'EUR');
      expect(income.date, DateTime(2024, 6, 15));
    });

    test('create uses default currency EUR', () async {
      final id = await service.create(
        date: DateTime(2024, 1, 1),
        amount: 1000,
      );

      final income = await service.getById(id);
      expect(income.currency, 'EUR');
      expect(income.description, '');
    });

    test('getAll returns ordered by date desc', () async {
      await service.create(date: DateTime(2023, 1, 1), amount: 1000, description: 'Oldest');
      await service.create(date: DateTime(2025, 1, 1), amount: 2000, description: 'Newest');
      await service.create(date: DateTime(2024, 6, 1), amount: 1500, description: 'Middle');

      final all = await service.getAll();
      expect(all, hasLength(3));
      expect(all[0].description, 'Newest');
      expect(all[1].description, 'Middle');
      expect(all[2].description, 'Oldest');
    });

    test('update fields', () async {
      final id = await service.create(
        date: DateTime(2024, 1, 1),
        amount: 1000,
        description: 'Original',
      );

      await service.update(
        id,
        const IncomesCompanion(
          description: Value('Updated'),
          amount: Value(2000),
        ),
      );

      final updated = await service.getById(id);
      expect(updated.description, 'Updated');
      expect(updated.amount, 2000);
    });

    test('delete removes record', () async {
      final id = await service.create(
        date: DateTime(2024, 1, 1),
        amount: 1000,
      );

      await service.delete(id);
      final all = await service.getAll();
      expect(all, isEmpty);
    });
  });

  group('Bulk create', () {
    test('inserts multiple records', () async {
      final entries = [
        IncomesCompanion.insert(
          date: DateTime(2024, 1, 15),
          amount: 3000,
          description: const Value('Jan salary'),
        ),
        IncomesCompanion.insert(
          date: DateTime(2024, 2, 15),
          amount: 3000,
          description: const Value('Feb salary'),
        ),
        IncomesCompanion.insert(
          date: DateTime(2024, 3, 15),
          amount: 3200,
          description: const Value('Mar salary'),
          currency: const Value('USD'),
        ),
      ];

      await service.bulkCreate(entries);

      final all = await service.getAll();
      expect(all, hasLength(3));
      // Ordered by date desc
      expect(all[0].description, 'Mar salary');
      expect(all[0].currency, 'USD');
      expect(all[2].description, 'Jan salary');
    });

    test('empty list does nothing', () async {
      await service.bulkCreate([]);
      final all = await service.getAll();
      expect(all, isEmpty);
    });
  });
}
