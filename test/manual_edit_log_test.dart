// The tracker records, with every manual edit, which kind of change it made
// to which area and how many rows: the edit log the change lists read.

import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/edit_log.dart';
import 'package:finance_copilot/database/manual_edit_tracker.dart';
import 'package:finance_copilot/database/tables.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory(), manualEdits: ManualEditTracker()));
  tearDown(() => db.close());

  Future<EditLog> log() => db.manualEditLog();
  Future<Set<EditChange>> editedSince(EditLog before) async => (await log()).editedSince(before);
  Future<int> addBroker([String name = 'Broker']) => db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: name));

  test('nothing edited yet: an empty log', () async {
    expect(await log(), EditLog.empty);
  });

  test('an insert records its area as added, one row', () async {
    await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Current'));
    final after = await log();
    expect(after.tokens.keys, [(EditArea.accounts, EditKind.added)]);
    expect(after.changes, 1);
  });

  test('an update counts the rows it changed, a no-op update none', () async {
    for (final name in ['A', 'B', 'C']) {
      await addBroker(name);
    }
    final before = await log();

    await db.update(db.intermediaries).write(const IntermediariesCompanion(sortOrder: Value(5)));
    expect(await editedSince(before), {(EditArea.intermediaries, EditKind.changed)});
    expect((await log()).changes, before.changes + 3);

    final afterUpdate = await log();
    await (db.update(db.intermediaries)..where((i) => i.id.equals(999))).write(const IntermediariesCompanion(sortOrder: Value(1)));
    expect((await log()).changes, afterUpdate.changes);
  });

  test('a delete records its area as deleted', () async {
    final id = await addBroker();
    final before = await log();
    await (db.delete(db.intermediaries)..where((i) => i.id.equals(id))).go();
    expect(await editedSince(before), {(EditArea.intermediaries, EditKind.deleted)});
  });

  test('a batch counts each row; a transaction records everything once it commits', () async {
    final accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Current'));
    final before = await log();

    await db.batch((b) {
      for (var day = 1; day <= 5; day++) {
        b.insert(
          db.transactions,
          TransactionsCompanion.insert(
            accountId: accountId,
            operationDate: DateTime(2026, 10, day),
            valueDate: DateTime(2026, 10, day),
            amount: -day.toDouble(),
          ),
        );
      }
    });
    expect(await editedSince(before), {(EditArea.transactions, EditKind.added)});
    expect((await log()).changes, before.changes + 5);

    final beforeTransaction = await log();
    await db.transaction(() async {
      await addBroker();
      await db.update(db.transactions).write(const TransactionsCompanion(description: Value('Edited')));
    });
    expect(await editedSince(beforeTransaction), {(EditArea.intermediaries, EditKind.added), (EditArea.transactions, EditKind.changed)});
    expect((await log()).changes, beforeTransaction.changes + 1 + 5);
  });

  test('a rolled back transaction records nothing', () async {
    await expectLater(
      db.transaction(() async {
        await addBroker();
        throw StateError('abandoned');
      }),
      throwsStateError,
    );
    expect(await log(), EditLog.empty);
  });

  test('saving a setting changes the settings area', () async {
    await db.into(db.appConfigs).insertOnConflictUpdate(AppConfigsCompanion.insert(key: 'TAX_RATE', value: '0.3'));
    expect((await log()).tokens.keys, [(EditArea.settings, EditKind.changed)]);
  });

  test('every edit of the same kind renews its token', () async {
    await addBroker('First');
    final first = await log();
    await addBroker('Second');
    expect(await editedSince(first), {(EditArea.intermediaries, EditKind.added)});
  });

  test('automatic writes and provider data record nothing', () async {
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
    expect(await log(), EditLog.empty);
  });

  group('across database files', () {
    late Directory dir;

    setUp(() async => dir = await Directory.systemTemp.createTemp('fc_edit_log_'));
    tearDown(() => dir.delete(recursive: true));

    Future<(String, EditLog)> backupFile() async {
      final path = '${dir.path}/backup.db';
      final source = AppDatabase.forTesting(NativeDatabase(File(path)), manualEdits: ManualEditTracker());
      await source.into(source.accounts).insert(AccountsCompanion.insert(name: 'From the backup'));
      final sourceLog = await source.manualEditLog();
      await source.close();
      return (path, sourceLog);
    }

    test('a snapshot carries the log, and a restore takes it over', () async {
      final (path, sourceLog) = await backupFile();
      expect(AppDatabase.readSnapshotFacts(path).editLog, sourceLog);

      await addBroker('Local');
      await automaticWrites(() => db.mergeFromAttachedDb(path));

      expect(await log(), sourceLog);
    });

    test('importing a file by hand records everything it replaced', () async {
      final (path, sourceLog) = await backupFile();
      await db.mergeFromAttachedDb(path);
      final edited = (await log()).editedSince(sourceLog);
      expect(edited, containsAll([(EditArea.accounts, EditKind.added), (EditArea.accounts, EditKind.deleted)]));
    });
  });
}
