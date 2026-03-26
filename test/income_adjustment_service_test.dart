import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/income_adjustment_service.dart';

void main() {
  late AppDatabase db;
  late IncomeAdjustmentService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = IncomeAdjustmentService(db);
  });

  tearDown(() async => await db.close());

  group('Adjustment CRUD', () {
    test('create and retrieve', () async {
      final id = await service.create(
        name: 'Bonus 2024',
        totalAmount: 5000,
        incomeDate: DateTime(2024, 6, 15),
      );

      final adjustment = await service.getById(id);
      expect(adjustment.name, 'Bonus 2024');
      expect(adjustment.totalAmount, 5000);
      expect(adjustment.currency, 'EUR');
      expect(adjustment.incomeDate, DateTime(2024, 6, 15));
    });

    test('getAll returns only active, ordered by incomeDate desc', () async {
      await service.create(
        name: 'Oldest',
        totalAmount: 1000,
        incomeDate: DateTime(2023, 1, 1),
      );
      await service.create(
        name: 'Newest',
        totalAmount: 2000,
        incomeDate: DateTime(2025, 1, 1),
      );
      await service.create(
        name: 'Middle',
        totalAmount: 1500,
        incomeDate: DateTime(2024, 6, 1),
      );

      final all = await service.getAll();
      expect(all, hasLength(3));
      expect(all[0].name, 'Newest');
      expect(all[1].name, 'Middle');
      expect(all[2].name, 'Oldest');
    });

    test('update name and amount', () async {
      final id = await service.create(
        name: 'Original',
        totalAmount: 1000,
        incomeDate: DateTime(2024, 1, 1),
      );

      await service.update(
        id,
        const IncomeAdjustmentsCompanion(
          name: Value('Updated'),
          totalAmount: Value(2000),
        ),
      );

      final updated = await service.getById(id);
      expect(updated.name, 'Updated');
      expect(updated.totalAmount, 2000);
    });

    test('delete cascades expenses', () async {
      final id = await service.create(
        name: 'To Delete',
        totalAmount: 3000,
        incomeDate: DateTime(2024, 1, 1),
      );

      await service.addExpense(
        adjustmentId: id,
        date: DateTime(2024, 2, 1),
        amount: 500,
        description: 'Expense 1',
      );
      await service.addExpense(
        adjustmentId: id,
        date: DateTime(2024, 3, 1),
        amount: 700,
        description: 'Expense 2',
      );

      // Verify expenses exist
      final expensesBefore = await service.getExpenses(id);
      expect(expensesBefore, hasLength(2));

      await service.delete(id);

      // Adjustment gone
      final all = await service.getAll();
      expect(all, isEmpty);

      // Expenses gone
      final allExpenses = await db.select(db.incomeAdjustmentExpenses).get();
      expect(allExpenses, isEmpty);
    });
  });

  group('Expenses CRUD', () {
    late int adjustmentId;

    setUp(() async {
      adjustmentId = await service.create(
        name: 'Test Adjustment',
        totalAmount: 5000,
        incomeDate: DateTime(2024, 6, 1),
      );
    });

    test('add expenses and verify ordering asc by date', () async {
      await service.addExpense(
        adjustmentId: adjustmentId,
        date: DateTime(2024, 9, 1),
        amount: 300,
        description: 'Third',
      );
      await service.addExpense(
        adjustmentId: adjustmentId,
        date: DateTime(2024, 7, 1),
        amount: 100,
        description: 'First',
      );
      await service.addExpense(
        adjustmentId: adjustmentId,
        date: DateTime(2024, 8, 1),
        amount: 200,
        description: 'Second',
      );

      final expenses = await service.getExpenses(adjustmentId);
      expect(expenses, hasLength(3));
      expect(expenses[0].description, 'First');
      expect(expenses[1].description, 'Second');
      expect(expenses[2].description, 'Third');
    });

    test('totalSpent sums expenses correctly', () async {
      await service.addExpense(
        adjustmentId: adjustmentId,
        date: DateTime(2024, 7, 1),
        amount: 1000,
      );
      await service.addExpense(
        adjustmentId: adjustmentId,
        date: DateTime(2024, 8, 1),
        amount: 1500,
      );
      await service.addExpense(
        adjustmentId: adjustmentId,
        date: DateTime(2024, 9, 1),
        amount: 500,
      );

      final total = await service.totalSpent(adjustmentId);
      expect(total, 3000);
    });

    test('totalSpent returns 0 when no expenses', () async {
      final total = await service.totalSpent(adjustmentId);
      expect(total, 0);
    });

    test('deleteExpense removes single expense', () async {
      final expId1 = await service.addExpense(
        adjustmentId: adjustmentId,
        date: DateTime(2024, 7, 1),
        amount: 100,
        description: 'Keep',
      );
      final expId2 = await service.addExpense(
        adjustmentId: adjustmentId,
        date: DateTime(2024, 8, 1),
        amount: 200,
        description: 'Remove',
      );

      await service.deleteExpense(expId2);

      final expenses = await service.getExpenses(adjustmentId);
      expect(expenses, hasLength(1));
      expect(expenses.first.id, expId1);
      expect(expenses.first.description, 'Keep');
    });

    test('updateExpense modifies fields', () async {
      final expId = await service.addExpense(
        adjustmentId: adjustmentId,
        date: DateTime(2024, 7, 1),
        amount: 100,
        description: 'Original',
      );

      await service.updateExpense(
        expId,
        const IncomeAdjustmentExpensesCompanion(
          description: Value('Modified'),
          amount: Value(250),
        ),
      );

      final expenses = await service.getExpenses(adjustmentId);
      expect(expenses.first.description, 'Modified');
      expect(expenses.first.amount, 250);
    });
  });
}
