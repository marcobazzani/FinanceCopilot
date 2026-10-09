// A scoped import config is keyed by the id its scope names (the account, the
// intermediary or the asset). Saving one without that id is a caller bug: it
// must fail with an error naming the missing key before anything is read or
// written — it used to crash on a null check inside the lookup query.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/import/import_config_service.dart';

void main() {
  late AppDatabase db;
  late ImportConfigService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = ImportConfigService(db);
  });
  tearDown(() => db.close());

  Future<void> save(ImportConfigScope scope, {int? accountId, int? intermediaryId, int? assetId}) => service.saveScoped(
    scope: scope,
    accountId: accountId,
    intermediaryId: intermediaryId,
    assetId: assetId,
    skipRows: 0,
    mappings: const {'date': 'Date'},
    formula: const [],
    hashColumns: const [],
  );

  Matcher missing(String key) => throwsA(isA<ArgumentError>().having((e) => e.name, 'name', key));

  test('each scoped config refuses to be saved without the id it is keyed by', () async {
    await expectLater(save(ImportConfigScope.transaction), missing('accountId'));
    await expectLater(save(ImportConfigScope.assetByIsin), missing('intermediaryId'));
    await expectLater(save(ImportConfigScope.assetSingle), missing('assetId'));

    expect(await db.select(db.importConfigs).get(), isEmpty, reason: 'nothing is written');
  });

  test("another scope's id does not stand in for the missing one", () async {
    await expectLater(save(ImportConfigScope.transaction, intermediaryId: 1, assetId: 2), missing('accountId'));
    await expectLater(save(ImportConfigScope.assetSingle, accountId: 1), missing('assetId'));

    expect(await db.select(db.importConfigs).get(), isEmpty);
  });

  test('the income config needs no id', () async {
    await save(ImportConfigScope.income);

    expect((await service.getIncome())?.mappingsJson, '{"date":"Date"}');
  });
}
