// Deleting an intermediary unlinks its accounts, then deletes it. The two
// writes were separate: a failure on the delete left every account unlinked
// from an intermediary that still exists. They are now one transaction.
//
// The failure is injected with a trigger that aborts the intermediary's
// delete.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/intermediary_service.dart';

void main() {
  late AppDatabase db;
  late IntermediaryService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = IntermediaryService(db);
  });
  tearDown(() => db.close());

  Future<List<int?>> links() async => [for (final a in await db.select(db.accounts).get()) a.intermediaryId];

  Future<int> bankWithAccounts() async {
    final bank = await service.create(name: 'Bank');
    for (final name in ['Checking', 'Savings']) {
      final id = await db.into(db.accounts).insert(AccountsCompanion.insert(name: name));
      await service.moveAccount(id, bank);
    }
    return bank;
  }

  test('a failure on the delete keeps the intermediary and its accounts linked', () async {
    final bank = await bankWithAccounts();
    await db.customStatement(
      "CREATE TEMP TRIGGER fail_delete BEFORE DELETE ON intermediaries BEGIN SELECT RAISE(ABORT, 'injected failure'); END",
    );

    await expectLater(service.delete(bank), throwsA(anything));
    expect(await links(), [bank, bank], reason: 'nothing unlinked');
    expect((await service.getAll()).map((i) => i.id), [bank]);
  });

  test('baseline: the accounts are unlinked and the intermediary deleted', () async {
    final bank = await bankWithAccounts();
    await service.delete(bank);
    expect(await links(), [null, null]);
    expect(await service.getAll(), isEmpty);
  });

  test('an intermediary that still holds assets is refused, nothing changed', () async {
    final bank = await bankWithAccounts();
    await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'Fund',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: bank,
          ),
        );
    await expectLater(service.delete(bank), throwsA(isA<StateError>()));
    expect(await links(), [bank, bank]);
    expect((await service.getAll()).map((i) => i.id), [bank]);
  });
}
