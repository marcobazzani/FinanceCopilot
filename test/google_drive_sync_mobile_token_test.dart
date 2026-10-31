// A mobile Drive session renews its access token before every lookup, backup
// and restore (it used to keep the one from sign-in, which expires after
// about an hour, so every Drive call failed until the app restarted). A token
// Drive refuses is renewed and the lookup retried once; when Google needs the
// user to sign in again, the operation says so.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

import 'package:finance_copilot/services/app_settings.dart';
import 'package:finance_copilot/services/sync/google_drive_sync_service.dart';
import 'package:finance_copilot/services/sync/mobile_drive_client.dart';

const _dbFileName = String.fromEnvironment('DB_FILE_NAME');
const _pathProvider = MethodChannel('plugins.flutter.io/path_provider');

class _Tokens implements DriveTokenSource {
  _Tokens(Iterable<String?> next) : _next = [...next];

  final List<String?> _next;
  final discarded = <String>[];

  @override
  Future<String?> fetch() async => _next.isEmpty ? null : _next.removeAt(0);

  @override
  Future<void> discard(String token) async => discarded.add(token);
}

/// Drive's list and upload endpoints, refusing the tokens in [refused].
class _Drive {
  _Drive({this.refused = const {}});

  final Set<String> refused;

  /// `METHOD path token` of every request.
  final requests = <String>[];

  late final client = MockClient.streaming((request, body) async {
    await body.drain<void>();
    final token = (request.headers['Authorization'] ?? '').replaceFirst('Bearer ', '');
    requests.add('${request.method} ${request.url.path} $token');
    if (refused.contains(token)) {
      return _json({
        'error': {'code': 401, 'message': 'Request had invalid authentication credentials.'},
      }, 401);
    }
    if (request.method == 'GET') {
      return _json({
        'files': [
          {'id': 'remote-1', 'name': _dbFileName, 'modifiedTime': '2026-10-30T20:00:00.000Z', 'size': '6'},
        ],
      });
    }
    return _json({'id': 'remote-1', 'modifiedTime': '2026-10-30T21:00:00.000Z', 'size': '6'});
  });

  static http.StreamedResponse _json(Object body, [int status = 200]) =>
      http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(body))), status, headers: {'content-type': 'application/json; charset=utf-8'});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fc_drive_mobile_token_');
    AppSettings.resetForTesting();
    AppSettings.testConfigDir = dir;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_pathProvider, (call) async => dir.path);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_pathProvider, null);
    AppSettings.resetForTesting();
    await dir.delete(recursive: true);
  });

  GoogleDriveSyncService signedIn(_Tokens tokens, _Drive drive) => GoogleDriveSyncService()
    ..signInWithTokensForTest(tokens, drive.client, email: 'me@example.com')
    ..createSnapshot = () async => (File(p.join(dir.path, 'snapshot.db'))..writeAsStringSync('SQLite')).path;

  group('GoogleDriveSyncService on a mobile session', skip: _dbFileName.isEmpty ? 'needs --dart-define=DB_FILE_NAME=<name>' : null, () {
    test('every operation renews the token first, an hour after sign-in included', () async {
      final drive = _Drive();
      final sync = signedIn(_Tokens(['t1', 't2', 't3']), drive);

      await sync.getRemoteInfo();
      await sync.getRemoteInfo();
      await sync.backupToDrive();

      expect(drive.requests, [
        'GET /drive/v3/files t1',
        'GET /drive/v3/files t2',
        'GET /drive/v3/files t3',
        'PATCH /upload/drive/v3/files/remote-1 t3',
      ]);
      expect(sync.needsReauth, isFalse);
    });

    test('a token Drive refuses is dropped, renewed and the lookup retried once', () async {
      final tokens = _Tokens(['stale', 'fresh']);
      final drive = _Drive(refused: {'stale'});
      final sync = signedIn(tokens, drive);

      final backup = await sync.getRemoteInfo();

      expect(backup?.fileId, 'remote-1');
      expect(tokens.discarded, ['stale']);
      expect(drive.requests, ['GET /drive/v3/files stale', 'GET /drive/v3/files fresh']);
    });

    test('Google needs a new sign-in: the operation says so, and nothing is sent', () async {
      final drive = _Drive();
      final sync = signedIn(_Tokens([]), drive);

      await expectLater(sync.backupToDrive(), throwsA(isA<DriveSignInExpired>()));
      expect(sync.needsReauth, isTrue);
      expect(drive.requests, isEmpty);
    });

    test('a token still refused once renewed asks for a new sign-in', () async {
      final drive = _Drive(refused: {'t1', 't2'});
      final sync = signedIn(_Tokens(['t1', 't2']), drive);

      await expectLater(sync.restoreFromDrive(), throwsA(isA<DriveSignInExpired>()));
      expect(drive.requests, hasLength(2), reason: 'one retry, no more');
      expect(sync.needsReauth, isTrue);
    });
  });
}
