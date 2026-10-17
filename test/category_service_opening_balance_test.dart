// Which category an opening-balance adjustment gets, by its sign (see
// TransactionService.planOpeningBalance). A positive one is pre-existing
// money, like salary or any other inflow that happened before tracked
// history. A negative one (credit card, overdraft, loan) must stay out of
// isSpendingCategoryType's categories, or it reads as that year's spending —
// Transfer is the seeded category already excluded there.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/classification/category_service.dart';

void main() {
  late AppDatabase db;
  late CategoryService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = CategoryService(db);
  });
  tearDown(() => db.close());

  test('positive: the seeded "other income" category', () async {
    final id = await service.openingBalanceCategoryFor(50);
    final cat = await service.getByKey(CategoryService.openingBalanceIncomeKey);
    expect(id, cat!.id);
  });

  test('zero: reads as positive, not a debt', () async {
    final id = await service.openingBalanceCategoryFor(0);
    final cat = await service.getByKey(CategoryService.openingBalanceIncomeKey);
    expect(id, cat!.id);
  });

  test('negative: the seeded "transfer" category, so it is never counted as spending', () async {
    final id = await service.openingBalanceCategoryFor(-50);
    final cat = await service.getByKey(CategoryService.openingBalanceDebtKey);
    expect(id, cat!.id);
  });

  test('the seeded category was deleted: null, not another one guessed', () async {
    final cat = await service.getByKey(CategoryService.openingBalanceIncomeKey);
    await service.delete(cat!.id);
    expect(await service.openingBalanceCategoryFor(50), isNull);
  });

  test('the seeded category was archived: null', () async {
    final cat = await service.getByKey(CategoryService.openingBalanceDebtKey);
    await service.setArchived(cat!.id, true);
    expect(await service.openingBalanceCategoryFor(-50), isNull);
  });
}
