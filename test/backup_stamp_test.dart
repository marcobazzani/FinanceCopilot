// A backup is stamped with what the indicator needs to compare it (its last
// manual edit and schema version), bound to its content by a checksum: an
// app version that does not stamp leaves the old stamp on a new upload, and
// the checksum then no longer matches.

import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/manual_edit_tracker.dart';
import 'package:finance_copilot/services/sync/backup_stamp.dart';
import 'package:finance_copilot/services/sync/google_drive_sync_service.dart';

void main() {
  late Directory dir;
  late AppDatabase db;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fc_backup_stamp_');
    db = AppDatabase.forTesting(NativeDatabase.memory(), manualEdits: ManualEditTracker(random: Random(3)));
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  Future<String> snapshot() async {
    final path = '${dir.path}/snapshot.db';
    await db.vacuumInto(path);
    return path;
  }

  /// The Drive file a stamped upload of [properties] produced, with content
  /// checksum [md5].
  DriveFileInfo uploaded(Map<String, String?> properties, {required String? md5}) => DriveFileInfo(
    fileId: 'f1',
    modifiedTime: DateTime.utc(2026, 10, 28),
    size: 1,
    md5Checksum: md5,
    appProperties: {for (final MapEntry(:key, :value) in properties.entries) key: ?value},
  );

  test('a snapshot is described by its last manual edit, schema version and checksum', () async {
    await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    final path = await snapshot();

    final properties = await describeBackupSnapshot(path);

    expect(
      properties,
      backupStampProperties(
        lastManualEdit: await db.lastManualEdit(),
        schemaVersion: db.schemaVersion,
        contentMd5: '${md5.convert(File(path).readAsBytesSync())}',
      ),
    );
  });

  test('a snapshot never edited by hand clears any stamp left on the backup', () async {
    final properties = await describeBackupSnapshot(await snapshot());
    expect(properties.containsKey('lastManualEdit'), isTrue);
    expect(properties['lastManualEdit'], isNull, reason: 'a null value deletes the key on Drive');
  });

  test('a snapshot that cannot be read goes up unstamped', () async {
    final notADatabase = File('${dir.path}/garbage.db')..writeAsStringSync('not sqlite');
    expect(await describeBackupSnapshot(notADatabase.path), isEmpty);
  });

  group('reading a stamp back', () {
    final stamp = backupStampProperties(lastManualEdit: '2026-10-28T09:00:00.000Z#00aa', schemaVersion: 50, contentMd5: 'abc');

    test('it counts while it matches the content', () {
      final facts = RemoteBackupFacts.of(uploaded(stamp, md5: 'abc'));
      expect(
        (facts.exists, facts.stamped, facts.lastManualEdit, facts.schemaVersion, facts.md5),
        (true, true, '2026-10-28T09:00:00.000Z#00aa', 50, 'abc'),
      );
    });

    test('a new upload by an app version that does not stamp no longer matches it', () {
      final facts = RemoteBackupFacts.of(uploaded(stamp, md5: 'other content'));
      expect((facts.exists, facts.stamped, facts.lastManualEdit, facts.schemaVersion), (true, false, null, null));
    });

    test('a backup never stamped, or without a checksum, is unstamped', () {
      expect(RemoteBackupFacts.of(uploaded(const {'deviceName': 'Laptop'}, md5: 'abc')).stamped, isFalse);
      expect(RemoteBackupFacts.of(uploaded(stamp, md5: null)).stamped, isFalse);
    });

    test('a stamp of a backup never edited by hand reads as no edit', () {
      final never = backupStampProperties(lastManualEdit: null, schemaVersion: 50, contentMd5: 'abc');
      final facts = RemoteBackupFacts.of(uploaded(never, md5: 'abc'));
      expect((facts.stamped, facts.lastManualEdit), (true, null));
    });
  });

  test('marking writes automatic keeps the stamp out of the snapshot', () async {
    await automaticWrites(() => db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Seeded')));
    expect((await describeBackupSnapshot(await snapshot()))['lastManualEdit'], isNull);
    expect(await db.select(db.intermediaries).get(), isNotEmpty);
    expect(await db.lastManualEdit(), isNull);
  });
}
