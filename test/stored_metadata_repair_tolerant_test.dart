// Stored-number normalization reads each account's saved import config. One
// config it could not read (not JSON, a formula or a balance mode of another
// shape) or one row whose raw statement data is not JSON aborted the whole
// run — for every account, again at every start-up. Such an account is now
// skipped (logged) and the others are repaired; such a row is left untouched.
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/import/stored_metadata_repair.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late int acct;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    acct = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
  });
  tearDown(() => db.close());

  Future<void> config(int account, String mappingsJson, {String formulaJson = '[]'}) => db
      .into(db.importConfigs)
      .insert(
        ImportConfigsCompanion.insert(
          accountId: Value(account),
          mappingsJson: Value(mappingsJson),
          formulaJson: Value(formulaJson),
          numberLocale: const Value('en_US'),
        ),
      );

  /// A row stored in Italian spelling: its amount reproduces under it_IT only.
  Future<int> row(int account, {String? raw, double? balance}) => db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          accountId: account,
          operationDate: DateTime(2025, 6, 30),
          valueDate: DateTime(2025, 6, 30),
          amount: -6.95,
          balanceAfter: Value(balance),
          rawMetadata: Value(raw ?? jsonEncode({'Importo': '-6,95', 'Saldo': '100,00'})),
        ),
      );

  Future<String?> rawOf(int id) async => (await (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle()).rawMetadata;

  test('pin: a config without a balance mode is not checked against the balance column (cumulative)', () async {
    await config(acct, '{"amount":"Importo","balanceAfter":"Saldo"}');
    // The stored balance is a running sum, not the bank's figure.
    final id = await row(acct, balance: 93.05);
    final report = await StoredMetadataRepair(db).run(appLocale: 'it_IT');
    expect(report.accounts.single.rewritten, 1);
    expect(jsonDecode((await rawOf(id))!), {'Importo': '-6.95', 'Saldo': '100'});
  });

  group('an account whose saved config cannot be read is skipped, the others are repaired', () {
    for (final (what, mappings, formula) in [
      ('mappings that are not JSON', '{"amount": ', '[]'),
      ('a balance mode that is not text', '{"amount":"Importo","__balanceMode":42}', '[]'),
      ('an amount formula that is not a list of terms', '{"amount":"Importo"}', '[{"operator":"+"}]'),
      ('a balance-difference column that is not text', '{"amount":"Importo","__balanceDiffColumn":["Saldo"]}', '[]'),
    ]) {
      test(what, () async {
        final other = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Other'));
        await config(acct, mappings, formulaJson: formula);
        await config(other, '{"amount":"Importo"}');
        final skipped = await row(acct);
        final repaired = await row(other);

        final report = await StoredMetadataRepair(db).run(appLocale: 'it_IT');
        expect(report.accounts.map((a) => a.accountId), [other]);
        expect(jsonDecode((await rawOf(repaired))!)['Importo'], '-6.95');
        expect(jsonDecode((await rawOf(skipped))!)['Importo'], '-6,95', reason: 'left as it was');
      });
    }
  });

  test('a row whose raw statement data is not JSON is left untouched', () async {
    await config(acct, '{"amount":"Importo"}');
    final bad = await row(acct, raw: '{"Importo": ');
    final good = await row(acct);
    final report = await StoredMetadataRepair(db).run(appLocale: 'it_IT');
    expect(report.accounts.single.rewritten, 1);
    expect(await rawOf(bad), '{"Importo": ');
    expect(jsonDecode((await rawOf(good))!)['Importo'], '-6.95');
  });
}
