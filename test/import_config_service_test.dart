import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/import_config_service.dart';

void main() {
  late AppDatabase db;
  late ImportConfigService service;
  late int accountId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = ImportConfigService(db);

    // Create an account to reference in import configs.
    accountId = await db
        .into(db.accounts)
        .insert(AccountsCompanion.insert(name: 'Test Account'));
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
          {'operator': '*', 'sourceColumn': 'X'}
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

      final formula =
          jsonDecode(config.formulaJson) as List<dynamic>;
      expect(formula.length, 1);
      expect(formula[0]['operator'], '*');

      final hashColumns =
          jsonDecode(config.hashColumnsJson) as List<dynamic>;
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
      final decoded =
          jsonDecode(config!.mappingsJson) as Map<String, dynamic>;
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
      final decoded =
          jsonDecode(config!.formulaJson) as List<dynamic>;
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
      final decoded =
          jsonDecode(config!.hashColumnsJson) as List<dynamic>;
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
}
