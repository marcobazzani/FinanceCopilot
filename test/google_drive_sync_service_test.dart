// Drive backup/restore session handling, against an in-memory Drive API.
//
// Pinned bugs:
//  * `_driveApi!` was re-read after awaits (snapshot, remote listing, local
//    path) while `signOut()` can null it meanwhile: the upload/download then
//    crashed on a null check instead of finishing on the session it started
//    with (or reporting a clean error).
//  * A new sign-in replaced the auth/HTTP client without closing the previous
//    one, and a mobile sign-out never closed it at all, leaking connections.
//  * A download broken mid-stream must surface its own error and leave no tmp
//    file behind (the tmp sink is now closed on failure too; the error closing
//    it must not mask the one that broke the download).

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

/// An HTTP client that records being closed but keeps answering, so a test can
/// both observe the close and let an operation already in flight finish.
class _RecordingClient extends http.BaseClient {
  _RecordingClient(this._inner);

  final http.Client _inner;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => _inner.send(request);

  @override
  void close() => closed = true;
}

/// The handful of Drive endpoints the service uses, answered in memory.
class _FakeDrive {
  _FakeDrive({this.remoteFileId, this.download, this.onList});

  /// Id of the existing remote backup, or null when there is none.
  final String? remoteFileId;

  /// Body of the backup download.
  final Stream<List<int>> Function()? download;

  /// Runs while the remote listing is being answered.
  final Future<void> Function()? onList;

  /// `METHOD path` of every request received, in order.
  final requests = <String>[];

  late final client = _RecordingClient(MockClient.streaming(_answer));

  static http.StreamedResponse _json(Object body) => http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(body))),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Map<String, Object?> _file(String id) => {
    'id': id,
    'name': _dbFileName,
    'modifiedTime': '2026-01-02T03:04:05.000Z',
    'size': '6',
    'appProperties': {'deviceId': 'another-device'},
  };

  Future<http.StreamedResponse> _answer(http.BaseRequest request, http.ByteStream body) async {
    await body.drain<void>();
    final url = request.url;
    requests.add('${request.method} ${url.path}');
    if (request.method == 'GET' && url.path.endsWith('/files')) {
      await onList?.call();
      return _json({
        'files': [if (remoteFileId != null) _file(remoteFileId!)],
      });
    }
    if (request.method == 'GET' && url.queryParameters['alt'] == 'media') {
      return http.StreamedResponse(download!(), 200, headers: {'content-type': 'application/octet-stream'});
    }
    if (request.method == 'PATCH') return _json(_file(url.pathSegments.last));
    if (request.method == 'POST') return _json(_file('created'));
    return http.StreamedResponse(const Stream.empty(), 404);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fc_drive_sync_');
    AppSettings.resetForTesting();
    AppSettings.testConfigDir = dir;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_pathProvider, (call) async => dir.path);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_pathProvider, null);
    AppSettings.resetForTesting();
    await dir.delete(recursive: true);
  });

  Future<String> writeSnapshot() async => (File(p.join(dir.path, 'snapshot.db'))..writeAsStringSync('SQLite')).path;

  group('GoogleDriveSyncService', skip: _dbFileName.isEmpty ? 'needs --dart-define=DB_FILE_NAME=<name>' : null, () {
    test('backup and restore refuse to run while signed out', () async {
      final service = GoogleDriveSyncService();
      final notSignedIn = throwsA(isA<StateError>().having((e) => e.message, 'message', 'not_signed_in'));

      await expectLater(service.backupToDrive(), notSignedIn);
      await expectLater(service.restoreFromDrive(), notSignedIn);
    });

    test('signing out while the backup snapshot is taken does not crash the upload', () async {
      final drive = _FakeDrive(remoteFileId: 'remote-1');
      final service = GoogleDriveSyncService()..signInWithClientForTest(drive.client);
      service.createSnapshot = () async {
        await service.signOut(); // the user signs out while VACUUM INTO runs
        return writeSnapshot();
      };

      final info = await service.backupToDrive();

      // The whole backup ran on the session it started with: it found the
      // existing remote file and updated it, instead of crashing on the
      // cleared session or creating a second backup.
      expect(info.fileId, 'remote-1');
      expect(drive.requests, ['GET /drive/v3/files', 'PATCH /upload/drive/v3/files/remote-1']);
      expect(service.isSignedIn, isFalse);
    });

    test('signing out while the remote backup is looked up does not crash the download', () async {
      late GoogleDriveSyncService service;
      final drive = _FakeDrive(
        remoteFileId: 'remote-1',
        download: () => Stream.value(utf8.encode('SQLite')),
        onList: () => service.signOut(),
      );
      service = GoogleDriveSyncService()..signInWithClientForTest(drive.client);
      final merged = <String>[];
      service.copyFromAttached = (tmpPath) async => merged.add(File(tmpPath).readAsStringSync());

      final restored = await service.restoreFromDrive();

      expect(restored?.fileId, 'remote-1');
      expect(merged, ['SQLite']);
      expect(drive.requests.last, 'GET /drive/v3/files/remote-1');
    });

    test('a new session closes the client it replaces, and signing out closes the last one', () async {
      final first = _FakeDrive().client;
      final second = _FakeDrive().client;
      final service = GoogleDriveSyncService()..signInWithClientForTest(first);

      service.signInWithClientForTest(second);
      expect(first.closed, isTrue);
      expect(second.closed, isFalse);

      await service.signOut();
      expect(second.closed, isTrue);
      expect(service.isSignedIn, isFalse);
    });

    test('a download broken mid-stream surfaces its own error and leaves no tmp file', () async {
      final drive = _FakeDrive(
        remoteFileId: 'remote-1',
        download: () async* {
          yield utf8.encode('SQLite format 3');
          throw http.ClientException('connection reset');
        },
      );
      final service = GoogleDriveSyncService()..signInWithClientForTest(drive.client);
      service.copyFromAttached = (_) async => fail('a broken download must never be merged');

      await expectLater(service.restoreFromDrive(), throwsA(isA<http.ClientException>()));
      expect(dir.listSync().map((e) => p.basename(e.path)).where((name) => name.endsWith('.tmp')), isEmpty);
    });
  });
}
