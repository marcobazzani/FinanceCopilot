import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/income_service.dart';

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
        type: IncomeType.income,
        currency: 'EUR',
      );

      final income = await service.getById(id);
      expect(income.amount, 3000);
      expect(income.type, IncomeType.income);
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
      expect(income.type, IncomeType.income);
    });

    test('getAll returns ordered by date desc', () async {
      await service.create(date: DateTime(2023, 1, 1), amount: 1000);
      await service.create(date: DateTime(2025, 1, 1), amount: 2000, type: IncomeType.refund);
      await service.create(date: DateTime(2024, 6, 1), amount: 1500);

      final all = await service.getAll();
      expect(all, hasLength(3));
      expect(all[0].amount, 2000);
      expect(all[0].type, IncomeType.refund);
      expect(all[1].amount, 1500);
      expect(all[2].amount, 1000);
    });

    test('update fields', () async {
      final id = await service.create(
        date: DateTime(2024, 1, 1),
        amount: 1000,
      );

      await service.update(
        id,
        const IncomesCompanion(
          type: Value(IncomeType.refund),
          amount: Value(2000),
        ),
      );

      final updated = await service.getById(id);
      expect(updated.type, IncomeType.refund);
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
      final entries = <IncomesCompanion>[
        IncomesCompanion.insert(
          date: DateTime(2024, 1, 15),
          amount: 3000,
        ),
        IncomesCompanion.insert(
          date: DateTime(2024, 2, 15),
          amount: 3000,
          type: const Value(IncomeType.refund),
        ),
        IncomesCompanion.insert(
          date: DateTime(2024, 3, 15),
          amount: 3200,
          currency: const Value('USD'),
        ),
      ];

      await service.bulkCreate(entries);

      final all = await service.getAll();
      expect(all, hasLength(3));
      // Ordered by date desc
      expect(all[0].amount, 3200);
      expect(all[0].currency, 'USD');
      expect(all[1].type, IncomeType.refund);
      expect(all[2].amount, 3000);
    });

    test('empty list does nothing', () async {
      await service.bulkCreate([]);
      final all = await service.getAll();
      expect(all, isEmpty);
    });
  });
}
