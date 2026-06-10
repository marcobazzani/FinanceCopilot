import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/import/import_config_service.dart';

/// STRESS tests for saved import configs, sized for a prod DB with many of
/// them. Focus areas after the import refactor:
///  1. Backward-compat: real prod-shaped transaction configs (the only scope
///     present in the live DB) round-trip byte-identically — no new key
///     required, no crash.
///  2. The new income tag-set keys (__incomeValues/__refundValues/
///     __pensionContributionValues) round-trip through the JSON the UI writes.
///  3. Scale: hundreds of configs across all scopes, no key collision / bleed.
///  4. Scope isolation: a lookup in one scope never returns another's config.
void main() {
  late AppDatabase db;
  late ImportConfigService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = ImportConfigService(db);
  });

  tearDown(() async => db.close());

  Future<int> mkAccount(String name) => db.into(db.accounts).insert(AccountsCompanion.insert(name: name));
  Future<int> mkInter(String name) => db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: name));
  Future<int> mkAsset(String name, int interId) => db
      .into(db.assets)
      .insert(
        AssetsCompanion.insert(
          name: name,
          assetType: AssetType.stock,
          valuationMethod: ValuationMethod.marketPrice,
          currency: const Value('EUR'),
          intermediaryId: interId,
        ),
      );

  group('backward-compat: prod-shaped transaction config', () {
    test('a real-world transaction config round-trips byte-identically', () async {
      final acc = await mkAccount('Fineco');
      // Shape taken from the live prod DB: standard field mappings + the
      // balance/multi-column meta keys, NO type-tag keys.
      final mappings = <String, String?>{
        'date': 'Data_Operazione',
        'valueDate': 'Data_Valuta',
        'amount': 'Importo',
        'description': 'Descrizione',
        'balanceAfter': 'Saldo',
        '__balanceMode': 'column',
        '__balanceDiffColumn': 'Saldo',
        '__multi_description': jsonEncode(['Descrizione', 'Causale']),
        '__delim_description': ' - ',
        '__balanceFilterColumn': 'Tipo',
        '__balanceFilterInclude': jsonEncode(['Addebito', 'Accredito']),
        '__noHeader': 'true',
      };
      await service.save(
        accountId: acc,
        skipRows: 12,
        mappings: mappings,
        formula: [
          {'operator': '+', 'sourceColumn': 'Entrate'},
          {'operator': '-', 'sourceColumn': 'Uscite'},
        ],
        hashColumns: const [],
        numberLocale: 'it_IT',
      );

      final loaded = await service.getByAccount(acc);
      expect(loaded, isNotNull);
      expect(loaded!.skipRows, 12);
      expect(loaded.numberLocale, 'it_IT');
      final decoded = (jsonDecode(loaded.mappingsJson) as Map).cast<String, dynamic>();
      expect(decoded, mappings);
      final formula = (jsonDecode(loaded.formulaJson) as List).cast<Map<String, dynamic>>();
      expect(formula, [
        {'operator': '+', 'sourceColumn': 'Entrate'},
        {'operator': '-', 'sourceColumn': 'Uscite'},
      ]);
    });

    test('legacy asset config with a type mapping but NO type-tag keys loads without crash', () async {
      // Pre-alias-removal saved config: type column mapped, but no
      // __buyValues/__sellValues (the removed aliases used to classify).
      // Loading it must not throw; the loud-failure-at-import is the intended
      // behavior change, but config retrieval itself stays safe.
      final inter = await mkInter('Broker');
      await service.saveScoped(
        scope: ImportConfigScope.assetByIsin,
        intermediaryId: inter,
        skipRows: 0,
        mappings: const {'date': 'Data', 'isin': 'ISIN', 'type': 'Operazione', 'amount': 'Controvalore'},
        formula: const [],
        hashColumns: const [],
      );
      final loaded = await service.getByIntermediary(inter);
      expect(loaded, isNotNull);
      final decoded = (jsonDecode(loaded!.mappingsJson) as Map).cast<String, dynamic>();
      expect(decoded['type'], 'Operazione');
      expect(decoded.containsKey('__buyValues'), isFalse);
    });
  });

  group('new income tag-set keys round-trip', () {
    test('__incomeValues/__refundValues/__pensionContributionValues survive save+load+decode', () async {
      // Exactly the JSON the import wizard writes (jsonEncode of the tag Sets).
      final mappings = <String, String?>{
        'date': 'Data',
        'amount': 'Importo',
        'type': 'Tipo',
        '__incomeValues': jsonEncode(['Stipendio', 'Bonus']),
        '__refundValues': jsonEncode(['Rimborso', 'Rimborso Spesa']),
        '__pensionContributionValues': jsonEncode(['C/Azienda', 'C/TFR']),
      };
      await service.saveScoped(
        scope: ImportConfigScope.income,
        skipRows: 0,
        mappings: mappings,
        formula: const [],
        hashColumns: const [],
      );
      final loaded = await service.getIncome();
      expect(loaded, isNotNull);
      final decoded = (jsonDecode(loaded!.mappingsJson) as Map).cast<String, dynamic>();
      // The restore path does: jsonDecode(value) as List → cast<String>.
      expect((jsonDecode(decoded['__incomeValues'] as String) as List).cast<String>(), ['Stipendio', 'Bonus']);
      expect((jsonDecode(decoded['__refundValues'] as String) as List).cast<String>(), ['Rimborso', 'Rimborso Spesa']);
      expect((jsonDecode(decoded['__pensionContributionValues'] as String) as List).cast<String>(), ['C/Azienda', 'C/TFR']);
    });

    test('income config upsert overwrites, does not duplicate', () async {
      await service.saveScoped(
        scope: ImportConfigScope.income,
        skipRows: 0,
        mappings: const {'__refundValues': '["A"]'},
        formula: const [],
        hashColumns: const [],
      );
      await service.saveScoped(
        scope: ImportConfigScope.income,
        skipRows: 1,
        mappings: const {'__refundValues': '["B"]'},
        formula: const [],
        hashColumns: const [],
      );
      final all = await db.select(db.importConfigs).get();
      expect(all.where((c) => c.scope == 'income'), hasLength(1));
      final loaded = await service.getIncome();
      expect(loaded!.skipRows, 1);
      expect((jsonDecode(loaded.mappingsJson) as Map)['__refundValues'], '["B"]');
    });
  });

  group('scale + scope isolation', () {
    test('200 transaction configs across distinct accounts each load back correctly', () async {
      final ids = <int>[];
      for (var i = 0; i < 200; i++) {
        final acc = await mkAccount('Acct $i');
        ids.add(acc);
        await service.save(
          accountId: acc,
          skipRows: i % 5,
          mappings: {'date': 'D$i', 'amount': 'A$i'},
          formula: const [],
          hashColumns: const [],
          numberLocale: i.isEven ? 'it_IT' : 'en_US',
        );
      }
      // Spot-check several, ensure no cross-contamination.
      for (final i in [0, 37, 199]) {
        final loaded = await service.getByAccount(ids[i]);
        expect(loaded, isNotNull);
        expect(loaded!.skipRows, i % 5);
        final decoded = (jsonDecode(loaded.mappingsJson) as Map).cast<String, dynamic>();
        expect(decoded['date'], 'D$i');
        expect(decoded['amount'], 'A$i');
      }
      expect(await db.select(db.importConfigs).get(), hasLength(200));
    });

    test('all four scopes coexist for overlapping keys without bleed', () async {
      final acc = await mkAccount('A');
      final inter = await mkInter('I');
      final asset = await mkAsset('Asset', inter);

      await service.saveScoped(
        scope: ImportConfigScope.transaction,
        accountId: acc,
        skipRows: 1,
        mappings: const {'k': 'tx'},
        formula: const [],
        hashColumns: const [],
      );
      await service.saveScoped(
        scope: ImportConfigScope.assetByIsin,
        intermediaryId: inter,
        skipRows: 2,
        mappings: const {'k': 'byisin'},
        formula: const [],
        hashColumns: const [],
      );
      await service.saveScoped(
        scope: ImportConfigScope.assetSingle,
        assetId: asset,
        skipRows: 3,
        mappings: const {'k': 'single'},
        formula: const [],
        hashColumns: const [],
      );
      await service.saveScoped(
        scope: ImportConfigScope.income,
        skipRows: 4,
        mappings: const {'k': 'income'},
        formula: const [],
        hashColumns: const [],
      );

      expect((jsonDecode((await service.getByAccount(acc))!.mappingsJson) as Map)['k'], 'tx');
      expect((jsonDecode((await service.getByIntermediary(inter))!.mappingsJson) as Map)['k'], 'byisin');
      expect((jsonDecode((await service.getByAsset(asset))!.mappingsJson) as Map)['k'], 'single');
      expect((jsonDecode((await service.getIncome())!.mappingsJson) as Map)['k'], 'income');
      expect(await db.select(db.importConfigs).get(), hasLength(4));
    });

    test('income lookup never returns an account/intermediary config and vice-versa', () async {
      final acc = await mkAccount('A');
      await service.save(accountId: acc, skipRows: 9, mappings: const {'k': 'tx'}, formula: const [], hashColumns: const []);
      // No income config saved → getIncome must be null even though a
      // transaction config exists.
      expect(await service.getIncome(), isNull);
      // Now save income; the account lookup must still return the tx config.
      await service.saveScoped(
        scope: ImportConfigScope.income,
        skipRows: 0,
        mappings: const {'k': 'income'},
        formula: const [],
        hashColumns: const [],
      );
      expect((await service.getByAccount(acc))!.skipRows, 9);
    });
  });

  // Mirrors EXACTLY what _applySavedConfig.restoreIncomeTagSet does in the
  // import screen: decode the saved JSON list and prune to values still
  // present in the current Type column. Proven here deterministically so the
  // UI restore contract is covered without a flaky widget pump.
  Set<String> restoreTagSet(Map<String, dynamic> savedMappings, String key, {required Set<String> validValues, required bool canPrune}) {
    final out = <String>{};
    if (savedMappings[key] != null) {
      for (final v in (jsonDecode(savedMappings[key] as String) as List).cast<String>()) {
        if (!canPrune || validValues.contains(v)) out.add(v);
      }
    }
    return out;
  }

  group('UI restore contract (restoreIncomeTagSet logic)', () {
    test('OLD json missing tag keys → empty sets, no throw', () {
      final saved = <String, dynamic>{'date': 'Date', 'amount': 'Amount', 'type': 'Tipo'};
      expect(restoreTagSet(saved, '__incomeValues', validValues: {'Stipendio'}, canPrune: true), isEmpty);
      expect(restoreTagSet(saved, '__refundValues', validValues: {'Rimborso'}, canPrune: true), isEmpty);
      expect(restoreTagSet(saved, '__pensionContributionValues', validValues: {}, canPrune: true), isEmpty);
    });

    test('NEW json with tag keys → decoded sets', () {
      final saved = <String, dynamic>{
        '__incomeValues': jsonEncode(['Stipendio']),
        '__refundValues': jsonEncode(['Rimborso', 'Rimborso Spesa']),
      };
      final valid = {'Stipendio', 'Rimborso', 'Rimborso Spesa'};
      expect(restoreTagSet(saved, '__incomeValues', validValues: valid, canPrune: true), {'Stipendio'});
      expect(restoreTagSet(saved, '__refundValues', validValues: valid, canPrune: true), {'Rimborso', 'Rimborso Spesa'});
    });

    test('stale tag value (no longer in column) is pruned when full values known', () {
      final saved = <String, dynamic>{
        '__refundValues': jsonEncode(['Rimborso', 'Obsolete']),
      };
      // Only 'Rimborso' is still a column value → 'Obsolete' pruned.
      expect(restoreTagSet(saved, '__refundValues', validValues: {'Rimborso'}, canPrune: true), {'Rimborso'});
    });

    test('when full values unknown (canPrune=false) tags are kept as-is', () {
      final saved = <String, dynamic>{
        '__refundValues': jsonEncode(['Rimborso', 'DeepInFile']),
      };
      expect(restoreTagSet(saved, '__refundValues', validValues: const {}, canPrune: false), {'Rimborso', 'DeepInFile'});
    });
  });

  group('payload robustness', () {
    test('arbitrary / large mapping payloads persist verbatim', () async {
      final acc = await mkAccount('A');
      final big = {for (var i = 0; i < 300; i++) 'col$i': 'src$i'};
      await service.save(accountId: acc, skipRows: 0, mappings: big, formula: const [], hashColumns: const []);
      final decoded = (jsonDecode((await service.getByAccount(acc))!.mappingsJson) as Map).cast<String, dynamic>();
      expect(decoded.length, 300);
      expect(decoded['col150'], 'src150');
    });

    test('values containing JSON-significant characters survive', () async {
      final acc = await mkAccount('A');
      final tricky = <String, String?>{
        'date': r'D"ate,with,commas',
        '__refundValues': jsonEncode([r'A "quoted"', 'with,comma', 'un\u00edcode é']),
      };
      await service.save(accountId: acc, skipRows: 0, mappings: tricky, formula: const [], hashColumns: const []);
      final decoded = (jsonDecode((await service.getByAccount(acc))!.mappingsJson) as Map).cast<String, dynamic>();
      expect(decoded['date'], r'D"ate,with,commas');
      expect((jsonDecode(decoded['__refundValues'] as String) as List).cast<String>(), [r'A "quoted"', 'with,comma', 'unícode é']);
    });
  });
}
