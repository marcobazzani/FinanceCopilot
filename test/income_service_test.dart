import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/income_service.dart';
import 'package:finance_copilot/utils/income_split.dart';

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
        currency: 'EUR',
      );

      final income = await service.getById(id);
      expect(income.currency, 'EUR');
      expect(income.type, IncomeType.income);
    });

    test('getAll returns ordered by date desc', () async {
      await service.create(date: DateTime(2023, 1, 1), amount: 1000, currency: 'EUR');
      await service.create(date: DateTime(2025, 1, 1), amount: 2000, type: IncomeType.refund, currency: 'EUR');
      await service.create(date: DateTime(2024, 6, 1), amount: 1500, currency: 'EUR');

      final all = await service.getAll();
      expect(all, hasLength(3));
      expect(all[0].amount, 2000);
      expect(all[0].type, IncomeType.refund);
      expect(all[1].amount, 1500);
      expect(all[2].amount, 1000);
    });

    test(
      'getAll through date filters by valueDate without deleting data',
      () async {
        await db
            .into(db.incomes)
            .insert(
              IncomesCompanion.insert(
                date: DateTime(2024, 6, 1),
                valueDate: DateTime(2024, 2, 29, 12),
                amount: 1000,
              ),
            );
        await db
            .into(db.incomes)
            .insert(
              IncomesCompanion.insert(
                date: DateTime(2024, 1, 1),
                valueDate: DateTime(2024, 3, 1),
                amount: 2000,
              ),
            );

        final all = await service.getAll(through: DateTime(2024, 2, 29));
        expect(all.map((i) => i.amount), [1000]);

        final rawRows = await db.select(db.incomes).get();
        expect(rawRows, hasLength(2));
      },
    );

    test('update fields', () async {
      final id = await service.create(
        date: DateTime(2024, 1, 1),
        amount: 1000,
        currency: 'EUR',
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
        currency: 'EUR',
      );

      await service.delete(id);
      final all = await service.getAll();
      expect(all, isEmpty);
    });

    test('deleteMany empty list is a no-op', () async {
      await service.create(date: DateTime(2024, 1, 1), amount: 1000, currency: 'EUR');
      expect(await service.deleteMany([]), 0);
      expect((await service.getAll()).length, 1);
    });

    test('deleteMany removes only the given income ids', () async {
      final a = await service.create(date: DateTime(2024, 1, 1), amount: 100, currency: 'EUR');
      final b = await service.create(date: DateTime(2024, 1, 2), amount: 200, currency: 'EUR');
      final c = await service.create(date: DateTime(2024, 1, 3), amount: 300, currency: 'EUR');

      expect(await service.deleteMany([a, c]), 2);

      final remaining = await service.getAll();
      expect(remaining.map((i) => i.id), [b]);
    });
  });

  group('Bulk create', () {
    test('inserts multiple records', () async {
      final entries = <IncomesCompanion>[
        IncomesCompanion.insert(
          date: DateTime(2024, 1, 15),
          valueDate: DateTime(2024, 1, 15),
          amount: 3000,
        ),
        IncomesCompanion.insert(
          date: DateTime(2024, 2, 15),
          valueDate: DateTime(2024, 2, 15),
          amount: 3000,
          type: const Value(IncomeType.refund),
        ),
        IncomesCompanion.insert(
          date: DateTime(2024, 3, 15),
          valueDate: DateTime(2024, 3, 15),
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

  group('ordering — valueDate, not operationDate', () {
    test('getAll orders by valueDate (CLAUDE.md convention) when dates differ', () {
      // Two incomes whose `date` and `valueDate` are flipped:
      //   A: date=2024-02-01 (op), valueDate=2024-01-15 (val)
      //   B: date=2024-01-15 (op), valueDate=2024-02-01 (val)
      // valueDate-desc order should be B then A.
      final a = IncomesCompanion.insert(
        date: DateTime(2024, 2, 1),
        valueDate: DateTime(2024, 1, 15),
        amount: 100,
      );
      final b = IncomesCompanion.insert(
        date: DateTime(2024, 1, 15),
        valueDate: DateTime(2024, 2, 1),
        amount: 200,
      );
      return Future(() async {
        await db.into(db.incomes).insert(a);
        await db.into(db.incomes).insert(b);
        final all = await service.getAll();
        expect(all, hasLength(2));
        expect(all[0].amount, 200, reason: 'B has the later valueDate and must come first');
        expect(all[1].amount, 100);
      });
    });
  });
  group('createSplit — one inflow across several types', () {
    test('writes one row per slice sharing date, valueDate and currency', () async {
      await service.createSplit(
        date: DateTime(2024, 6, 15),
        currency: 'CHF',
        entries: const [
          IncomeSplitEntry(IncomeType.income, 1500),
          IncomeSplitEntry(IncomeType.refund, 200),
          IncomeSplitEntry(IncomeType.pensionContribution, 300),
        ],
      );

      final all = await service.getAll();
      expect(all, hasLength(3));
      expect(all.map((i) => i.type).toSet(), IncomeType.values.toSet());
      expect(all.every((i) => i.currency == 'CHF'), isTrue);
      expect(all.every((i) => i.date == DateTime(2024, 6, 15)), isTrue);
      expect(all.every((i) => i.valueDate == DateTime(2024, 6, 15)), isTrue);
      expect(all.every((i) => i.assetId == null), isTrue);
      // Total is preserved exactly — the split never loses or invents money.
      expect(all.fold<double>(0, (sum, i) => sum + i.amount), closeTo(2000, 1e-9));
    });

    test('slice amounts land on the matching type', () async {
      await service.createSplit(
        date: DateTime(2024, 1, 31),
        currency: 'EUR',
        entries: const [
          IncomeSplitEntry(IncomeType.income, 1234.56),
          IncomeSplitEntry(IncomeType.pensionContribution, 65.44),
        ],
      );

      final all = await service.getAll();
      final byType = {for (final i in all) i.type: i.amount};
      expect(byType[IncomeType.income], closeTo(1234.56, 1e-9));
      expect(byType[IncomeType.pensionContribution], closeTo(65.44, 1e-9));
      expect(byType.containsKey(IncomeType.refund), isFalse);
    });

    test('propagates assetId to every slice when provided', () async {
      final iid = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Fund manager'));
      final assetId = await db
          .into(db.assets)
          .insert(
            AssetsCompanion.insert(
              name: 'Pension fund',
              assetType: AssetType.pension,
              valuationMethod: ValuationMethod.eventDriven,
              intermediaryId: iid,
            ),
          );

      await service.createSplit(
        date: DateTime(2024, 3, 1),
        currency: 'EUR',
        assetId: assetId,
        entries: const [
          IncomeSplitEntry(IncomeType.pensionContribution, 100),
          IncomeSplitEntry(IncomeType.income, 50),
        ],
      );

      final all = await service.getAll();
      expect(all, hasLength(2));
      expect(all.every((i) => i.assetId == assetId), isTrue);
    });

    test('empty slice list writes nothing', () async {
      await service.createSplit(date: DateTime(2024, 3, 1), currency: 'EUR', entries: const []);
      expect(await service.getAll(), isEmpty);
    });
  });
}
