// The manual-edit stamp the backup sync indicator compares: which writes move
// it (a person's edits, whatever the API or SQL they go through) and which
// never do (opening and migrating the database, automatic jobs, provider
// data), and that it is written together with the edit it stamps.

import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/manual_edit_tracker.dart';
import 'package:finance_copilot/database/tables.dart';

void main() {
  late AppDatabase db;
  late ManualEditTracker tracker;
  late DateTime clock;

  setUp(() {
    clock = DateTime.utc(2026, 10, 28, 9);
    tracker = ManualEditTracker(now: () => clock, random: Random(7));
    db = AppDatabase.forTesting(NativeDatabase.memory(), manualEdits: tracker);
  });

  tearDown(() => db.close());

  Future<int> addBroker([String name = 'Broker']) => db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: name));

  test('opening, migrating and seeding a new database is no manual edit', () async {
    expect(await db.select(db.categories).get(), isNotEmpty, reason: 'the default categories were seeded');
    expect(await db.lastManualEdit(), isNull);
  });

  test('an insert stamps the time of the edit', () async {
    await addBroker();
    expect(manualEditTime((await db.lastManualEdit())!), DateTime.utc(2026, 10, 28, 9));
  });

  test('every edit moves the stamp, even within the same instant', () async {
    final id = await addBroker();
    final first = await db.lastManualEdit();
    await (db.update(db.intermediaries)..where((i) => i.id.equals(id))).write(const IntermediariesCompanion(name: Value('Renamed')));
    final second = await db.lastManualEdit();
    await (db.delete(db.intermediaries)..where((i) => i.id.equals(id))).go();
    final third = await db.lastManualEdit();
    expect({first, second, third}, hasLength(3));
  });

  test('custom SQL writes are edits; reads and pragmas are not', () async {
    await db.customSelect('SELECT COUNT(*) FROM accounts').get();
    await db.customStatement('PRAGMA foreign_keys = ON');
    expect(await db.lastManualEdit(), isNull);

    await db.customStatement("UPDATE app_configs SET value = '0.3' WHERE key = 'TAX_RATE'");
    expect(await db.lastManualEdit(), isNotNull);
  });

  test('batches are edits', () async {
    await db.batch((b) => b.insert(db.intermediaries, IntermediariesCompanion.insert(name: 'In a batch')));
    expect(await db.lastManualEdit(), isNotNull);
  });

  test('writes inside automaticWrites are not edits, through async calls, transactions and batches', () async {
    await automaticWrites(() async {
      await Future<void>.delayed(Duration.zero);
      await db.transaction(() async {
        await addBroker('Automatic');
        await db.batch((b) => b.insert(db.intermediaries, IntermediariesCompanion.insert(name: 'Automatic batch')));
      });
      await db.customStatement("UPDATE app_configs SET value = 'x' WHERE key = 'LOCALE'");
    });
    expect(await db.lastManualEdit(), isNull);
    expect(await db.select(db.intermediaries).get(), hasLength(2));
  });

  test('market prices and exchange rates are never edits, whoever writes them', () async {
    final brokerId = await automaticWrites(addBroker);
    final assetId = await automaticWrites(
      () => db
          .into(db.assets)
          .insert(
            AssetsCompanion.insert(
              name: 'Fund',
              assetType: AssetType.stockEtf,
              valuationMethod: ValuationMethod.marketPrice,
              intermediaryId: brokerId,
            ),
          ),
    );

    await db
        .into(db.marketPrices)
        .insert(MarketPricesCompanion.insert(assetId: assetId, date: DateTime(2026, 10, 1), closePrice: 10, currency: 'EUR'));
    await db.customStatement('DELETE FROM market_prices WHERE asset_id = ?', [assetId]);
    await db
        .into(db.exchangeRates)
        .insert(ExchangeRatesCompanion.insert(fromCurrency: 'EUR', toCurrency: 'USD', date: DateTime(2026, 10, 1), rate: 1.1));

    expect(await db.lastManualEdit(), isNull);
  });

  test('a transaction is stamped when it commits, and not when it rolls back', () async {
    await expectLater(
      db.transaction(() async {
        await addBroker('Rolled back');
        throw StateError('abandoned');
      }),
      throwsStateError,
    );
    expect(await db.lastManualEdit(), isNull);

    await db.transaction(() => addBroker('Committed'));
    expect(await db.lastManualEdit(), isNotNull);
  });

  test('edits announces committed manual edits only', () async {
    var announced = 0;
    final sub = tracker.edits.listen((_) => announced++);
    addTearDown(sub.cancel);

    await automaticWrites(addBroker);
    await pumpEventQueue();
    expect(announced, 0);

    await addBroker('By hand');
    await db.transaction(() => addBroker('By hand, in a transaction'));
    await pumpEventQueue();
    expect(announced, 2);
  });

  group('merging another database file', () {
    late Directory dir;

    setUp(() async => dir = await Directory.systemTemp.createTemp('fc_manual_edit_'));
    tearDown(() => dir.delete(recursive: true));

    /// A database file whose data was last edited by hand on [editedAt].
    Future<(String path, String? stamp)> backupFile(DateTime editedAt) async {
      final path = '${dir.path}/backup.db';
      final source = AppDatabase.forTesting(NativeDatabase(File(path)), manualEdits: ManualEditTracker(now: () => editedAt));
      await source.into(source.intermediaries).insert(IntermediariesCompanion.insert(name: 'From the backup'));
      final stamp = await source.lastManualEdit();
      await source.close();
      return (path, stamp);
    }

    test('a restore (automatic) takes over the stamp of the backup it copies', () async {
      final (path, stamp) = await backupFile(DateTime.utc(2026, 1, 1));
      await addBroker('Local');

      await automaticWrites(() => db.mergeFromAttachedDb(path));

      expect(await db.lastManualEdit(), stamp);
    });

    test('importing a file by hand is an edit made now', () async {
      final (path, _) = await backupFile(DateTime.utc(2026, 1, 1));
      clock = DateTime.utc(2026, 10, 29);

      await db.mergeFromAttachedDb(path);

      expect(manualEditTime((await db.lastManualEdit())!), DateTime.utc(2026, 10, 29));
      expect((await db.select(db.intermediaries).get()).map((i) => i.name), ['From the backup']);
    });

    test('readSnapshotFacts reads the stamp and schema version of a file', () async {
      final (path, stamp) = await backupFile(DateTime.utc(2026, 2, 3));
      final facts = AppDatabase.readSnapshotFacts(path);
      expect(facts.lastManualEdit, stamp);
      expect(facts.schemaVersion, db.schemaVersion);
    });
  });

  test('writtenTable names the table a statement writes, and only writes', () {
    expect(writtenTable('INSERT INTO "assets" ("name") VALUES (?)'), 'assets');
    expect(writtenTable('insert or replace into market_prices values (?)'), 'market_prices');
    expect(writtenTable('UPDATE "accounts" SET "name" = ? WHERE "id" = ?'), 'accounts');
    expect(writtenTable('DELETE FROM main."app_configs"'), 'app_configs');
    expect(writtenTable('REPLACE INTO categories VALUES (1)'), 'categories');
    expect(writtenTable('WITH t AS (SELECT 1)\nUPDATE assets SET name = 1'), 'assets');

    expect(writtenTable('SELECT * FROM assets'), isNull);
    expect(writtenTable('WITH t AS (SELECT 1) SELECT * FROM t'), isNull);
    expect(writtenTable('PRAGMA user_version'), isNull);
    expect(writtenTable("ATTACH DATABASE 'backup.db' AS src"), isNull);
    expect(writtenTable('CREATE TABLE x (a)'), isNull);
    expect(writtenTable('VACUUM'), isNull);
  });

  test('a stamp reads back its time; a value this app did not write has none', () {
    expect(manualEditTime(newManualEditStamp(DateTime.utc(2026, 5, 6, 7, 8), Random(1))), DateTime.utc(2026, 5, 6, 7, 8));
    expect(manualEditTime('not a stamp'), isNull);
  });
}
