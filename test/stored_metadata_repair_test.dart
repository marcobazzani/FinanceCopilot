// Stored-number normalization: cells in `raw_metadata` are rewritten to the
// account's saved locale only when re-parsing them reproduces the stored
// amount exactly; everything else is left alone and reported.
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/import/import_config_service.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/services/import/stored_metadata_repair.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late int acct;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    acct = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Fineco'));
  });
  tearDown(() => db.close());

  /// A row as an older/newer app version would have stored it: the amount is
  /// the truth; the metadata spelling varies.
  Future<int> row(DateTime d, double amount, {String entrate = '', String uscite = '', String? saldo}) => db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          accountId: acct,
          operationDate: d,
          valueDate: d,
          amount: amount,
          description: const Value('x'),
          balanceAfter: Value(saldo == null ? null : double.parse(saldo.replaceAll(',', '.'))),
          rawMetadata: Value(jsonEncode({'Data': '01/01/2024', 'Entrate': entrate, 'Uscite': uscite, 'Note': 'keep 1.234,56 as is'})),
        ),
      );

  Future<void> saveFinecoConfig({String? locale}) => ImportConfigService(db).save(
    accountId: acct,
    skipRows: 12,
    mappings: {'date': 'Data', 'description': 'Note', '__balanceMode': 'cumulative'},
    formula: const [
      {'operator': '+', 'sourceColumn': 'Entrate'},
      {'operator': '+', 'sourceColumn': 'Uscite'},
    ],
    hashColumns: const [],
    numberLocale: locale,
  );

  test('mixed spellings are normalized to the target locale, verified against the stored amount', () async {
    await saveFinecoConfig(); // no saved locale → app locale becomes the target
    final a = await row(DateTime(2022, 5, 3), 3674.52, entrate: '3674.52'); // old app: toString()
    final b = await row(DateTime(2022, 5, 18), -5107.84, uscite: '-5107.84');
    final c = await row(DateTime(2025, 6, 30), -6.95, uscite: '-6,95'); // newer app: it_IT
    final d = await row(DateTime(2025, 7, 31), 5318.28, entrate: '5.318,28');
    final e = await row(DateTime(2022, 4, 19), 5000, entrate: '5000'); // integer: same under both
    final f = await row(DateTime(2023, 1, 1), 42, entrate: '99'); // reproduces under neither → untouched

    final dry = await StoredMetadataRepair(db).run(appLocale: 'it_IT', dryRun: true);
    expect(dry.dryRun, isTrue);
    expect(dry.accounts.single.rewritten, 2, reason: 'a, b need re-spelling; c, d already Italian, e reads the same either way');
    expect(dry.accounts.single.consistent, 3);
    expect(dry.accounts.single.unresolvedIds, [f]);
    // Dry run wrote nothing.
    expect((await ImportConfigService(db).getByAccount(acct))!.numberLocale, isNull);
    expect(jsonDecode((await get(db, a)).rawMetadata!)['Entrate'], '3674.52');

    final report = await StoredMetadataRepair(db).run(appLocale: 'it_IT');
    final r = report.accounts.single;
    expect(r.targetLocale, 'it_IT', reason: 'mixed account: app locale');
    expect(r.rewritten, 2);
    expect(r.localePersisted, isTrue);
    expect((await ImportConfigService(db).getByAccount(acct))!.numberLocale, 'it_IT');

    Future<Map<String, dynamic>> m(int id) async => jsonDecode((await get(db, id)).rawMetadata!) as Map<String, dynamic>;
    expect((await m(a))['Entrate'], '3674,52');
    expect((await m(b))['Uscite'], '-5107,84');
    expect((await m(c))['Uscite'], '-6,95');
    expect((await m(d))['Entrate'], '5.318,28', reason: 'already reads right under the target: original text kept');
    expect((await m(e))['Entrate'], '5000');
    expect((await m(f))['Entrate'], '99', reason: 'unresolved rows are never touched');
    // Non-numeric columns are never touched, whatever they contain.
    expect((await m(a))['Note'], 'keep 1.234,56 as is');
    // Amounts and balances are never touched.
    expect((await get(db, a)).amount, 3674.52);

    // Every row now re-parses under the saved locale to its stored amount: the account is re-runnable.
    final importer = ImportService(db);
    final stored = (await importer.previewFromStoredRows(acct, numberLocale: 'it_IT'))!;
    final preview = await importer.previewTransactionImport(
      preview: stored,
      mappings: const [
        ColumnMapping(sourceColumn: 'Data', targetField: 'date'),
        ColumnMapping(
          targetField: 'amount',
          formulaTerms: [
            FormulaTerm(operator: '+', sourceColumn: 'Entrate'),
            FormulaTerm(operator: '+', sourceColumn: 'Uscite'),
          ],
        ),
      ],
      accountId: acct,
      numberLocale: 'it_IT',
    );
    // 3674.52 − 5107.84 − 6.95 + 5318.28 + 5000 + 99(unresolved, stays 99) = 8977.01
    expect(preview.importSum, closeTo(8977.01, 1e-6));
  });

  test('a saved locale wins over the app locale and is not rewritten', () async {
    await saveFinecoConfig(locale: 'en_US');
    final a = await row(DateTime(2025, 6, 30), -6.95, uscite: '-6,95');
    final r = (await StoredMetadataRepair(db).run(appLocale: 'it_IT')).accounts.single;
    expect(r.targetLocale, 'en_US');
    expect(r.rewritten, 1);
    expect(jsonDecode((await get(db, a)).rawMetadata!)['Uscite'], '-6.95');
    expect((await ImportConfigService(db).getByAccount(acct))!.numberLocale, 'en_US');
  });

  test('uniform accounts keep their original text; balance-diff verifies through the running balance, both first-row rules', () async {
    await ImportConfigService(db).save(
      accountId: acct,
      skipRows: 0,
      mappings: {'date': 'Data', 'balanceAfter': 'Saldo', '__balanceDiffColumn': 'Saldo', '__balanceMode': 'column'},
      formula: const [],
      hashColumns: const [],
      numberLocale: null,
    );
    Future<int> bal(DateTime d, double amount, String saldo, double stored) => db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: acct,
            operationDate: d,
            valueDate: d,
            amount: amount,
            balanceAfter: Value(stored),
            description: const Value('x'),
            rawMetadata: Value(jsonEncode({'Data': 'd', 'Saldo': saldo})),
          ),
        );
    final a = await bal(DateTime(2017, 2, 20), 2000, '2,000.00', 2000); // opening deposit rule (amount = balance)
    final b = await bal(DateTime(2017, 2, 24), 0.05, '2,000.05', 2000.05);
    final c = await bal(DateTime(2022, 5, 11), -2000.05, '0.00', 0);
    // App locale is Italian, but the account is uniformly dot-decimal bank
    // text: that format is kept and persisted; nothing is rewritten.
    final r = (await StoredMetadataRepair(db).run(appLocale: 'it_IT')).accounts.single;
    expect(r.unresolvedIds, isEmpty);
    expect(r.targetLocale, 'en_US');
    expect(r.rewritten, 0);
    expect(r.consistent, 3);
    expect(jsonDecode((await get(db, a)).rawMetadata!)['Saldo'], '2,000.00');
    expect(jsonDecode((await get(db, b)).rawMetadata!)['Saldo'], '2,000.05');
    expect(jsonDecode((await get(db, c)).rawMetadata!)['Saldo'], '0.00');
    expect((await ImportConfigService(db).getByAccount(acct))!.numberLocale, 'en_US');
  });

  test('an integers-only account (both formats fit) persists the app locale itself', () async {
    await saveFinecoConfig();
    await row(DateTime(2022, 5, 3), 5000, entrate: '5000');
    final r = (await StoredMetadataRepair(db).run(appLocale: 'de_DE')).accounts.single;
    expect(r.targetLocale, 'de_DE');
    expect(r.rewritten, 0);
    expect((await ImportConfigService(db).getByAccount(acct))!.numberLocale, 'de_DE');
  });

  test('runIfNeeded runs once per database and records the version', () async {
    await saveFinecoConfig();
    await row(DateTime(2022, 5, 3), 3674.52, entrate: '3674.52');
    await row(DateTime(2025, 6, 30), -6.95, uscite: '-6,95'); // mixed → rewrite needed
    final repair = StoredMetadataRepair(db);
    final first = await repair.runIfNeeded(appLocale: 'it_IT');
    expect(first, isNotNull);
    expect(first!.rewritten, 1);
    final flag = await (db.select(db.appConfigs)..where((c) => c.key.equals(kRawMetadataLocaleVersionKey))).getSingle();
    expect(flag.value, kRawMetadataLocaleVersion.toString());
    expect(await repair.runIfNeeded(appLocale: 'it_IT'), isNull, reason: 'already applied');
  });

  test('accounts without numeric mappings, orphan configs and manual rows are skipped', () async {
    await ImportConfigService(db).save(accountId: acct, skipRows: 0, mappings: {'date': 'Data'}, formula: const [], hashColumns: const []);
    await row(DateTime(2022, 5, 3), 1, entrate: '1,5');
    // Orphan config (account deleted).
    await db
        .into(db.importConfigs)
        .insert(ImportConfigsCompanion.insert(accountId: const Value(999), mappingsJson: const Value('{"amount":"X"}')));
    // Manual row (no metadata) never participates.
    await db
        .into(db.transactions)
        .insert(TransactionsCompanion.insert(accountId: acct, operationDate: DateTime(2022, 1, 1), valueDate: DateTime(2022, 1, 1), amount: -3));
    final report = await StoredMetadataRepair(db).run(appLocale: 'it_IT');
    expect(report.accounts, isEmpty);
  });
}

Future<Transaction> get(AppDatabase db, int id) => (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();
