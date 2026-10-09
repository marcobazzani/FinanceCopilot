// The remote-backup lookup that Backup and Restore start with, against an
// in-memory Drive API.
//
// Pinned bug: the lookup swallowed its errors and answered "no backup" (null).
// A lookup that failed (server error, no network, a listing without a file id)
// then made Backup create a SECOND remote backup next to the existing one, and
// made Restore report that there was nothing to restore. A failed lookup now
// fails the operation with its own error, and nothing is uploaded or merged.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

import 'package:finance_copilot/services/app_settings.dart';
import 'package:finance_copilot/services/sync/google_drive_sync_service.dart';

/// The service refuses to run without `--dart-define=DB_FILE_NAME=…` (it keys
/// the remote backup by that name); CI always passes it.
const _dbFileName = String.fromEnvironment('DB_FILE_NAME');

const _pathProvider = MethodChannel('plugins.flutter.io/path_provider');

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

http.StreamedResponse _json(Object body, [int status = 200]) =>
    http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(body))), status, headers: _jsonHeaders);

/// The Drive endpoints Backup and Restore use, answered in memory; the remote
/// listing is answered by [listing].
class _FakeDrive {
  _FakeDrive(this.listing);

  final Future<http.StreamedResponse> Function() listing;

  /// `METHOD path` of every request received, in order.
  final requests = <String>[];

  late final client = MockClient.streaming((request, body) async {
    await body.drain<void>();
    final url = request.url;
    requests.add('${request.method} ${url.path}');
    if (request.method == 'GET' && url.path.endsWith('/files')) return listing();
    if (request.method == 'GET' && url.queryParameters['alt'] == 'media') {
      return http.StreamedResponse(Stream.value(utf8.encode('SQLite')), 200, headers: {'content-type': 'application/octet-stream'});
    }
    if (request.method == 'PATCH') return _json(_file(url.pathSegments.last));
    if (request.method == 'POST') return _json(_file('created'));
    return http.StreamedResponse(const Stream.empty(), 404);
  });

  static Map<String, Object?> _file(String? id) => {
    'id': ?id,
    'name': _dbFileName,
    'modifiedTime': '2026-01-02T03:04:05.000Z',
    'size': '6',
  };

  static Future<http.StreamedResponse> serverError() async => _json({
    'error': {'code': 500, 'message': 'Backend Error'},
  }, 500);

  static Future<http.StreamedResponse> offline() async => throw http.ClientException('network is unreachable');

  static Future<http.StreamedResponse> noBackup() async => _json({'files': <Object>[]});

  static Future<http.StreamedResponse> backupWithoutId() async => _json({
    'files': [_file(null)],
  });

  static Future<http.StreamedResponse> oneBackup() async => _json({
    'files': [_file('remote-1')],
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late File snapshot;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fc_drive_lookup_');
    snapshot = File(p.join(dir.path, 'snapshot.db'));
    AppSettings.resetForTesting();
    AppSettings.testConfigDir = dir;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_pathProvider, (call) async => dir.path);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_pathProvider, null);
    AppSettings.resetForTesting();
    await dir.delete(recursive: true);
  });

  /// A signed-in service on [fake], its snapshot callback writing [snapshot].
  GoogleDriveSyncService signedIn(_FakeDrive fake) => GoogleDriveSyncService()
    ..signInWithClientForTest(fake.client)
    ..createSnapshot = () async => (snapshot..writeAsStringSync('SQLite')).path;

  group('Drive backup lookup', skip: _dbFileName.isEmpty ? 'needs --dart-define=DB_FILE_NAME=<name>' : null, () {
    group('a failed lookup aborts the backup: nothing is uploaded, no second backup is created', () {
      for (final (name, listing, error) in [
        ('a server error', _FakeDrive.serverError, isA<drive.DetailedApiRequestError>().having((e) => e.status, 'status', 500)),
        ('no network', _FakeDrive.offline, isA<http.ClientException>()),
        ('a listed backup without an id', _FakeDrive.backupWithoutId, isA<StateError>()),
      ]) {
        test(name, () async {
          final fake = _FakeDrive(listing);
          final service = signedIn(fake);

          await expectLater(service.backupToDrive(), throwsA(error));

          expect(fake.requests, ['GET /drive/v3/files'], reason: 'only the lookup: no create, no update');
          expect(snapshot.existsSync(), isFalse, reason: 'the snapshot is still cleaned up');
          expect(await AppSettings.get('lastSyncTime'), isNull, reason: 'nothing was backed up');
        });
      }
    });

    test('getRemoteInfo reports a failed lookup instead of answering "no backup"', () async {
      await expectLater(signedIn(_FakeDrive(_FakeDrive.serverError)).getRemoteInfo(), throwsA(isA<drive.DetailedApiRequestError>()));
      await expectLater(signedIn(_FakeDrive(_FakeDrive.offline)).getRemoteInfo(), throwsA(isA<http.ClientException>()));
    });

    test('pin: no backup on Drive is still null, and without a session there is nothing to look up', () async {
      final fake = _FakeDrive(_FakeDrive.noBackup);
      expect(await signedIn(fake).getRemoteInfo(), isNull);
      expect(await GoogleDriveSyncService().getRemoteInfo(), isNull);
      expect(fake.requests, ['GET /drive/v3/files']);
    });

    test('pin: with no backup on Drive the backup creates the first one', () async {
      final fake = _FakeDrive(_FakeDrive.noBackup);

      final info = await signedIn(fake).backupToDrive();

      expect(info.fileId, 'created');
      expect(fake.requests, ['GET /drive/v3/files', 'POST /upload/drive/v3/files']);
      expect(await AppSettings.get('lastSyncTime'), isNotNull);
    });

    test('pin: an existing backup is updated in place', () async {
      final fake = _FakeDrive(_FakeDrive.oneBackup);

      final info = await signedIn(fake).backupToDrive();

      expect(info.fileId, 'remote-1');
      expect(fake.requests, ['GET /drive/v3/files', 'PATCH /upload/drive/v3/files/remote-1']);
    });

    test('a failed lookup fails the restore: nothing is downloaded or merged', () async {
      final fake = _FakeDrive(_FakeDrive.serverError);
      final service = signedIn(fake);
      service.copyFromAttached = (_) async => fail('nothing may be merged after a failed lookup');

      await expectLater(service.restoreFromDrive(), throwsA(isA<drive.DetailedApiRequestError>()));

      expect(fake.requests, ['GET /drive/v3/files'], reason: 'no download');
      expect(await AppSettings.get('lastSyncTime'), isNull);
    });
  });
}
