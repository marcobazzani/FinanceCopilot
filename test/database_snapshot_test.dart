// Regression: exporting/backing up the database must never read the live
// `.db` file directly — a raw file copy can capture a torn snapshot mid
// write (background price sync, an in-progress import, etc.), silently
// producing an inconsistent export/backup that overwrites a good one.
// `AppDatabase.vacuumInto`/`snapshotToTempFile` use SQLite's `VACUUM INTO`
// to produce a transactionally-consistent, standalone copy instead.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('fc_snapshot_');
  });

  tearDown(() async {
    await tmpDir.delete(recursive: true);
  });

  test('vacuumInto produces a standalone, independently-openable copy', () async {
    final dbPath = '${tmpDir.path}/live.db';
    final destPath = '${tmpDir.path}/snapshot.db';
    final db = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
    await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'Fund',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: 1,
          ),
        );

    await db.vacuumInto(destPath);

    expect(File(destPath).existsSync(), isTrue);

    // Independently openable via a raw sqlite3 connection, with no
    // dependency on the live drift connection still being open.
    final raw = sqlite3.open(destPath);
    try {
      final rows = raw.select('SELECT name FROM intermediaries');
      expect(rows.map((r) => r['name']), ['Broker']);
      final assetRows = raw.select('SELECT name FROM assets');
      expect(assetRows.map((r) => r['name']), ['Fund']);
    } finally {
      raw.dispose();
    }

    await db.close();
  });

  test('the live database remains fully usable after taking a snapshot', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final destPath = '${tmpDir.path}/snapshot.db';
    await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Before'));

    await db.vacuumInto(destPath);

    // Live connection keeps working: further writes succeed and are
    // naturally NOT present in the already-taken snapshot.
    await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'After'));
    final live = await db.select(db.intermediaries).get();
    expect(live.map((i) => i.name).toSet(), {'Before', 'After'});

    final raw = sqlite3.open(destPath);
    final snapshotNames = raw.select('SELECT name FROM intermediaries').map((r) => r['name'] as String).toSet();
    raw.dispose();
    expect(snapshotNames, {'Before'}, reason: 'the snapshot is frozen at the moment it was taken');

    await db.close();
  });

  test('vacuumInto refuses to overwrite an existing destination file', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final dest = '${tmpDir.path}/dest.db';
    File(dest).writeAsStringSync('not a database');

    await expectLater(db.vacuumInto(dest), throwsA(anything));

    await db.close();
  });

  test('snapshotToTempFile delegates to vacuumInto with a fresh path inside the temp directory', () async {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getTemporaryDirectory') return tmpDir.path;
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));

    final first = await db.snapshotToTempFile();
    final second = await db.snapshotToTempFile();
    addTearDown(() => File(first).delete());
    addTearDown(() => File(second).delete());

    expect(first, isNot(second), reason: 'each snapshot must get a fresh, non-colliding path');
    expect(p.dirname(first), tmpDir.path);
    final raw = sqlite3.open(first);
    expect(raw.select('SELECT name FROM intermediaries').map((r) => r['name']), ['Broker']);
    raw.dispose();

    await db.close();
  });
}
