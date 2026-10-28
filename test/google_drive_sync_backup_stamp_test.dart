// A backup carries its stamp up in the upload request itself, so the stamp and
// the content it describes always belong together, and a lookup reads it back.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

import 'package:finance_copilot/services/app_settings.dart';
import 'package:finance_copilot/services/sync/google_drive_sync_service.dart';

/// The service refuses to run without `--dart-define=DB_FILE_NAME=…` (it keys
/// the remote backup by that name); CI always passes it.
const _dbFileName = String.fromEnvironment('DB_FILE_NAME');

const _pathProvider = MethodChannel('plugins.flutter.io/path_provider');

/// Drive's list and upload endpoints, answered in memory, keeping each
/// upload's request body.
class _FakeDrive {
  _FakeDrive({this.existing});

  /// Id of the existing remote backup, or null when there is none.
  final String? existing;
  final requests = <String>[];
  final uploads = <String>[];

  late final client = MockClient.streaming((request, body) async {
    final bytes = await body.toBytes();
    requests.add('${request.method} ${request.url.path}');
    if (request.method == 'GET') {
      return _json({
        'files': [
          if (existing != null)
            {
              'id': existing,
              'name': _dbFileName,
              'modifiedTime': '2026-10-28T09:00:00.000Z',
              'size': '6',
              'md5Checksum': 'abc',
              'appProperties': {'lastManualEdit': 'stamp-on-drive', 'contentMd5': 'abc', 'deviceName': 'Laptop'},
            },
        ],
      });
    }
    uploads.add(latin1.decode(bytes));
    return _json({
      'id': existing ?? 'created',
      'modifiedTime': '2026-10-28T10:00:00.000Z',
      'size': '6',
      'md5Checksum': 'uploaded-md5',
      'appProperties': {'lastManualEdit': 'stamp-1', 'contentMd5': 'uploaded-md5'},
    });
  });

  static http.StreamedResponse _json(Object body) =>
      http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(body))), 200, headers: {'content-type': 'application/json; charset=utf-8'});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fc_drive_stamp_');
    AppSettings.resetForTesting();
    AppSettings.testConfigDir = dir;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_pathProvider, (call) async => dir.path);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_pathProvider, null);
    AppSettings.resetForTesting();
    await dir.delete(recursive: true);
  });

  GoogleDriveSyncService service(_FakeDrive drive, {List<String>? described}) =>
      GoogleDriveSyncService(
          snapshotProperties: (path) async {
            described?.add(path);
            return {'lastManualEdit': 'stamp-1', 'contentMd5': 'uploaded-md5', 'stale': null};
          },
        )
        ..signInWithClientForTest(drive.client)
        ..createSnapshot = () async => (File(p.join(dir.path, 'snapshot.db'))..writeAsStringSync('SQLite')).path;

  group('GoogleDriveSyncService', skip: _dbFileName.isEmpty ? 'needs --dart-define=DB_FILE_NAME=<name>' : null, () {
    test('an update carries the snapshot description, deleting the keys it clears', () async {
      final drive = _FakeDrive(existing: 'remote-1');
      final described = <String>[];

      final info = await service(drive, described: described).backupToDrive();

      expect(drive.requests, ['GET /drive/v3/files', 'PATCH /upload/drive/v3/files/remote-1'], reason: 'no extra round trip');
      expect(described, hasLength(1), reason: 'the uploaded snapshot is the one described');
      final body = drive.uploads.single;
      expect(body, contains('"lastManualEdit":"stamp-1"'));
      expect(body, contains('"stale":null'));
      expect(body, contains('"deviceId":null'), reason: 'the old automatic sync left a device id behind');
      expect(info.md5Checksum, 'uploaded-md5');
      expect(info.appProperties, {'lastManualEdit': 'stamp-1', 'contentMd5': 'uploaded-md5'});
    });

    test('a first backup sends no keys to delete', () async {
      final drive = _FakeDrive();

      await service(drive).backupToDrive();

      expect(drive.requests, ['GET /drive/v3/files', 'POST /upload/drive/v3/files']);
      final body = drive.uploads.single;
      expect(body, contains('"lastManualEdit":"stamp-1"'));
      expect(body, isNot(contains('null')));
    });

    test('a lookup reads the stamp and the content checksum', () async {
      final info = await service(_FakeDrive(existing: 'remote-1')).getRemoteInfo();

      expect(info?.md5Checksum, 'abc');
      expect(info?.deviceName, 'Laptop');
      expect(info?.appProperties, {'lastManualEdit': 'stamp-on-drive', 'contentMd5': 'abc', 'deviceName': 'Laptop'});
    });
  });
}
