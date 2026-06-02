// Regression: restoring a Google Drive backup must not silently corrupt the
// database when the backup was taken by a different app version.
//
// Pinned bug: the ATTACH-based merge copied tables by column intersection
// with no schema-version check. A backup from an older/newer app version
// has a different table shape, so the intersection silently dropped or
// mis-filled columns — producing a database that passes inserts but holds
// semantically wrong rows. The merge now refuses on any version mismatch.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/db_transfer_service.dart';

void main() {
  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('fc_merge_');
  });

  tearDown(() async {
    await tmpDir.delete(recursive: true);
  });

  test('merges a backup taken at the same schema version', () async {
    // A "remote" backup DB at the current schema version, with one row.
    final remotePath = '${tmpDir.path}/remote.db';
    final remoteDb = AppDatabase.forTesting(NativeDatabase(File(remotePath)));
    await remoteDb
        .into(remoteDb.intermediaries)
        .insert(IntermediariesCompanion.insert(name: 'Broker From Backup'));
    await remoteDb.close();

    final localDb = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(localDb.close);

    await localDb.mergeFromAttachedDb(remotePath);

    final merged = await localDb.select(localDb.intermediaries).get();
    expect(merged.map((i) => i.name), contains('Broker From Backup'));
  });

  test(
    'refuses a backup whose schema version differs — local data survives',
    () async {
      // A real backup DB, then tamper its drift schema version to simulate a
      // backup taken by a different app version.
      final remotePath = '${tmpDir.path}/old_remote.db';
      final remoteDb = AppDatabase.forTesting(NativeDatabase(File(remotePath)));
      await remoteDb
          .into(remoteDb.intermediaries)
          .insert(IntermediariesCompanion.insert(name: 'Backup Broker'));
      await remoteDb.close();
      final raw = sqlite3.open(remotePath);
      raw.execute('PRAGMA user_version = 1');
      raw.dispose();

      final localDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(localDb.close);
      await localDb
          .into(localDb.intermediaries)
          .insert(IntermediariesCompanion.insert(name: 'Local Broker'));

      await expectLater(
        localDb.mergeFromAttachedDb(remotePath),
        throwsA(isA<SchemaVersionMismatchException>()),
      );

      // The gate must fire before any DELETE — local data untouched.
      final survivors = await localDb.select(localDb.intermediaries).get();
      expect(survivors.map((i) => i.name), ['Local Broker']);
    },
  );

  test(
    'local DB import merges via ATTACH without replacing the open DB file',
    () async {
      final importPath = '${tmpDir.path}/import.db';
      final importDb = AppDatabase.forTesting(NativeDatabase(File(importPath)));
      await importDb
          .into(importDb.intermediaries)
          .insert(IntermediariesCompanion.insert(name: 'Imported Broker'));
      await importDb.close();

      final localPath = '${tmpDir.path}/local.db';
      final localFile = File(localPath);
      final localDb = AppDatabase.forTesting(NativeDatabase(localFile));
      addTearDown(localDb.close);
      await localDb
          .into(localDb.intermediaries)
          .insert(IntermediariesCompanion.insert(name: 'Local Broker'));

      final emissions = <List<String>>[];
      final sub = localDb.select(localDb.intermediaries).watch().listen((rows) {
        emissions.add(rows.map((i) => i.name).toList());
      });
      addTearDown(sub.cancel);
      await Future<void>.delayed(Duration.zero);

      final source = await DbTransferService.importDbFromPath(
        localDb,
        importPath,
      );
      await Future<void>.delayed(Duration.zero);

      expect(source, importPath);
      final merged = await localDb.select(localDb.intermediaries).get();
      expect(merged.map((i) => i.name), ['Imported Broker']);
      expect(
        emissions,
        contains(equals(['Imported Broker'])),
        reason:
            'active Drift watchers should survive the import; direct file '
            'replacement would leave them attached to the old connection',
      );
    },
  );
}
