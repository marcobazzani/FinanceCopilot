// A saved import config's number format is the format of the statements the
// account's rows were read from. "Auto" (a null format) is no choice, so
// saving a config with it keeps the stored format; only an explicit format
// replaces it. It used to overwrite the stored format with null.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/import/import_config_service.dart';

void main() {
  late AppDatabase db;
  late ImportConfigService service;
  late int accountId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = ImportConfigService(db);
    accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
  });
  tearDown(() => db.close());

  Future<void> save(String? numberLocale, {int skipRows = 0}) => service.save(
    accountId: accountId,
    skipRows: skipRows,
    mappings: const {'date': 'Date', 'amount': 'Amount'},
    formula: const [],
    hashColumns: const [],
    numberLocale: numberLocale,
  );

  test('saving with "Auto" keeps the stored number format and updates the rest', () async {
    await save('it_IT');
    await save(null, skipRows: 3);

    final config = (await service.getByAccount(accountId))!;
    expect(config.numberLocale, 'it_IT');
    expect(config.skipRows, 3);
  });

  test('an explicit number format replaces the stored one', () async {
    await save('it_IT');
    await save('en_US');

    expect((await service.getByAccount(accountId))!.numberLocale, 'en_US');
  });

  test('a new config saved with "Auto" has no number format', () async {
    await save(null);

    expect((await service.getByAccount(accountId))!.numberLocale, isNull);
  });

  test('every scope keeps its stored format on "Auto"', () async {
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    final asset = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'Fund',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            currency: const Value('EUR'),
            intermediaryId: broker,
          ),
        );
    Future<void> saveScoped(ImportConfigScope scope, String? numberLocale) => service.saveScoped(
      scope: scope,
      intermediaryId: scope == ImportConfigScope.assetByIsin ? broker : null,
      assetId: scope == ImportConfigScope.assetSingle ? asset : null,
      skipRows: 0,
      mappings: const {'date': 'Date'},
      formula: const [],
      hashColumns: const [],
      numberLocale: numberLocale,
    );

    for (final scope in [ImportConfigScope.assetByIsin, ImportConfigScope.assetSingle, ImportConfigScope.income]) {
      await saveScoped(scope, 'de_DE');
      await saveScoped(scope, null);
    }

    expect((await service.getByIntermediary(broker))!.numberLocale, 'de_DE');
    expect((await service.getByAsset(asset))!.numberLocale, 'de_DE');
    expect((await service.getIncome())!.numberLocale, 'de_DE');
  });
}
