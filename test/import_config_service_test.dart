import 'dart:convert';

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

    // Create an account to reference in import configs.
    accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Test Account'));
  });

  tearDown(() async => await db.close());

  group('getByAccount', () {
    test('returns null when no config exists', () async {
      final config = await service.getByAccount(accountId);
      expect(config, isNull);
    });
  });

  group('save and retrieve', () {
    test('save creates config and getByAccount retrieves it', () async {
      final mappings = {'date': 'Date', 'amount': 'Amount', 'desc': null};
      final formula = [
        {'operator': '+', 'sourceColumn': 'Credit'},
        {'operator': '-', 'sourceColumn': 'Debit'},
      ];
      final hashColumns = ['Date', 'Amount', 'Description'];

      await service.save(
        accountId: accountId,
        skipRows: 2,
        mappings: mappings,
        formula: formula,
        hashColumns: hashColumns,
      );

      final config = await service.getByAccount(accountId);
      expect(config, isNotNull);
      expect(config!.accountId, accountId);
      expect(config.skipRows, 2);
    });

    test('save again (upsert) updates existing config', () async {
      // First save
      await service.save(
        accountId: accountId,
        skipRows: 1,
        mappings: {'date': 'A'},
        formula: [],
        hashColumns: ['A'],
      );

      // Second save — should update, not create duplicate
      await service.save(
        accountId: accountId,
        skipRows: 5,
        mappings: {'date': 'B', 'amount': 'C'},
        formula: [
          {'operator': '*', 'sourceColumn': 'X'},
        ],
        hashColumns: ['B', 'C'],
      );

      final config = await service.getByAccount(accountId);
      expect(config, isNotNull);
      expect(config!.skipRows, 5);

      // Verify updated JSON fields
      final mappings = jsonDecode(config.mappingsJson) as Map<String, dynamic>;
      expect(mappings['date'], 'B');
      expect(mappings['amount'], 'C');

      final formula = jsonDecode(config.formulaJson) as List<dynamic>;
      expect(formula.length, 1);
      expect(formula[0]['operator'], '*');

      final hashColumns = jsonDecode(config.hashColumnsJson) as List<dynamic>;
      expect(hashColumns, ['B', 'C']);
    });
  });

  group('JSON serialization', () {
    test('mappings with null values stored and retrieved correctly', () async {
      final mappings = {
        'date': 'Date',
        'amount': null,
        'description': 'Desc',
      };

      await service.save(
        accountId: accountId,
        skipRows: 0,
        mappings: mappings,
        formula: [],
        hashColumns: [],
      );

      final config = await service.getByAccount(accountId);
      final decoded = jsonDecode(config!.mappingsJson) as Map<String, dynamic>;
      expect(decoded['date'], 'Date');
      expect(decoded['amount'], isNull);
      expect(decoded['description'], 'Desc');
    });

    test('formula list with multiple entries stored correctly', () async {
      final formula = [
        {'operator': '+', 'sourceColumn': 'Credit'},
        {'operator': '-', 'sourceColumn': 'Debit'},
        {'operator': '*', 'sourceColumn': 'Factor'},
      ];

      await service.save(
        accountId: accountId,
        skipRows: 0,
        mappings: {},
        formula: formula,
        hashColumns: [],
      );

      final config = await service.getByAccount(accountId);
      final decoded = jsonDecode(config!.formulaJson) as List<dynamic>;
      expect(decoded.length, 3);
      expect(decoded[1]['operator'], '-');
      expect(decoded[2]['sourceColumn'], 'Factor');
    });

    test('hashColumns list stored and retrieved correctly', () async {
      final hashColumns = ['Date', 'Amount', 'Description', 'Reference'];

      await service.save(
        accountId: accountId,
        skipRows: 0,
        mappings: {},
        formula: [],
        hashColumns: hashColumns,
      );

      final config = await service.getByAccount(accountId);
      final decoded = jsonDecode(config!.hashColumnsJson) as List<dynamic>;
      expect(decoded, ['Date', 'Amount', 'Description', 'Reference']);
    });

    test('empty collections stored correctly', () async {
      await service.save(
        accountId: accountId,
        skipRows: 0,
        mappings: {},
        formula: [],
        hashColumns: [],
      );

      final config = await service.getByAccount(accountId);
      expect(jsonDecode(config!.mappingsJson), isEmpty);
      expect(jsonDecode(config.formulaJson), isEmpty);
      expect(jsonDecode(config.hashColumnsJson), isEmpty);
    });
  });

  group('scoped configs (intermediary / asset / income)', () {
    late int intermediaryId;
    late int assetId;

    setUp(() async {
      intermediaryId = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
      assetId = await db
          .into(db.assets)
          .insert(
            AssetsCompanion.insert(
              name: 'Pension',
              assetType: AssetType.pension,
              valuationMethod: ValuationMethod.eventDriven,
              intermediaryId: intermediaryId,
            ),
          );
    });

    test('intermediary-scoped save/get round-trips', () async {
      await service.saveScoped(
        scope: ImportConfigScope.assetByIsin,
        intermediaryId: intermediaryId,
        skipRows: 3,
        mappings: {'isin': 'ISIN', '__typeMode': 'column'},
        formula: [],
        hashColumns: [],
        numberLocale: 'en_US',
      );
      final c = await service.getByIntermediary(intermediaryId);
      expect(c, isNotNull);
      expect(c!.scope, 'assetByIsin');
      expect(c.intermediaryId, intermediaryId);
      expect(c.accountId, isNull);
      expect(c.assetId, isNull);
      expect(c.skipRows, 3);
      expect(c.numberLocale, 'en_US');
    });

    test('asset-scoped (single asset) save/get round-trips', () async {
      await service.saveScoped(
        scope: ImportConfigScope.assetSingle,
        assetId: assetId,
        skipRows: 0,
        mappings: {'amount': 'Entrate', '__revalueAmountColumn': 'Saldo', '__revalueValues': '["POSIZIONE INDIVIDUALE"]'},
        formula: [],
        hashColumns: [],
        numberLocale: 'it_IT',
      );
      final c = await service.getByAsset(assetId);
      expect(c, isNotNull);
      expect(c!.scope, 'assetSingle');
      expect(c.assetId, assetId);
      expect(c.intermediaryId, isNull);
      final m = jsonDecode(c.mappingsJson) as Map<String, dynamic>;
      expect(m['__revalueAmountColumn'], 'Saldo');
      expect(m['__revalueValues'], '["POSIZIONE INDIVIDUALE"]');
    });

    test('income-scoped (global, no key) save/get round-trips', () async {
      await service.saveScoped(
        scope: ImportConfigScope.income,
        skipRows: 1,
        mappings: {'date': 'Data', 'amount': 'Netto'},
        formula: [],
        hashColumns: [],
      );
      final c = await service.getIncome();
      expect(c, isNotNull);
      expect(c!.scope, 'income');
      expect(c.accountId, isNull);
      expect(c.intermediaryId, isNull);
      expect(c.assetId, isNull);
    });

    test('income upsert updates the single global row, never duplicates', () async {
      await service.saveScoped(scope: ImportConfigScope.income, skipRows: 1, mappings: {}, formula: [], hashColumns: []);
      await service.saveScoped(scope: ImportConfigScope.income, skipRows: 9, mappings: {'date': 'X'}, formula: [], hashColumns: []);
      final c = await service.getIncome();
      expect(c!.skipRows, 9);
      final all = await db.select(db.importConfigs).get();
      expect(all.where((r) => r.scope == 'income'), hasLength(1));
    });

    test('scopes are isolated — same asset/intermediary/account do not collide', () async {
      // account and asset/intermediary configs coexist independently.
      await service.save(accountId: accountId, skipRows: 1, mappings: {'date': 'acct'}, formula: [], hashColumns: []);
      await service.saveScoped(
        scope: ImportConfigScope.assetByIsin,
        intermediaryId: intermediaryId,
        skipRows: 2,
        mappings: {'date': 'inter'},
        formula: [],
        hashColumns: [],
      );
      await service.saveScoped(
        scope: ImportConfigScope.assetSingle,
        assetId: assetId,
        skipRows: 3,
        mappings: {'date': 'asset'},
        formula: [],
        hashColumns: [],
      );

      expect((await service.getByAccount(accountId))!.skipRows, 1);
      expect((await service.getByIntermediary(intermediaryId))!.skipRows, 2);
      expect((await service.getByAsset(assetId))!.skipRows, 3);
    });
  });
}
