// Drive session lifecycle and bounded waits, offline: the Drive and token
// endpoints are answered in memory, the browser launch is a test seam.
//
// Pinned bugs:
//  * A desktop silent sign-in adopted its client before the account lookup
//    that confirms it, so a failed lookup (revoked token, no network) left
//    `isSignedIn` true on a session that could not reach Drive — and a
//    sign-out landing during the lookup was undone by it.
//  * A backup upload or download that stalled kept Backup/Restore busy
//    forever: no timeout anywhere.
//  * An interactive desktop sign-in ignored whether the browser opened at all
//    and waited for the consent forever.

import 'dart:async';
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

const _json = {'content-type': 'application/json; charset=utf-8'};

http.Response _jsonResponse(Object body, [int status = 200]) => http.Response(jsonEncode(body), status, headers: _json);

/// The desktop auth transport: refreshes the stored token, then answers the
/// account lookup with [about].
http.Client _authTransport(Future<http.Response> Function() about) => MockClient((request) async {
  if (request.url.host == 'oauth2.googleapis.com') {
    return _jsonResponse({'access_token': 'fresh', 'token_type': 'Bearer', 'expires_in': 3600});
  }
  if (request.url.path.endsWith('/about')) return about();
  return http.Response('', 404);
});

Future<http.Response> _account() async => _jsonResponse({
  'user': {'emailAddress': 'me@example.com'},
});

Future<http.Response> _revoked() async => _jsonResponse({
  'error': {'code': 401, 'message': 'Invalid Credentials'},
}, 401);

/// A session transport answering the remote listing (one backup, `remote-1`)
/// and, for the backup itself, whatever [upload] / [download] give.
http.Client _driveTransport({Future<http.StreamedResponse> Function()? upload, Stream<List<int>> Function()? download}) =>
    MockClient.streaming((request, body) async {
      await body.drain<void>();
      final url = request.url;
      if (request.method == 'GET' && url.path.endsWith('/files')) {
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(
              jsonEncode({
                'files': [
                  {'id': 'remote-1', 'name': _dbFileName, 'modifiedTime': '2026-01-02T03:04:05.000Z', 'size': '6'},
                ],
              }),
            ),
          ),
          200,
          headers: _json,
        );
      }
      if (request.method == 'GET' && url.queryParameters['alt'] == 'media') {
        return http.StreamedResponse(download!(), 200, headers: {'content-type': 'application/octet-stream'});
      }
      if (request.method == 'PATCH') return upload!();
      return http.StreamedResponse(const Stream.empty(), 404);
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fc_drive_session_');
    AppSettings.resetForTesting();
    AppSettings.testConfigDir = dir;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_pathProvider, (call) async => dir.path);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_pathProvider, null);
    AppSettings.resetForTesting();
    await dir.delete(recursive: true);
  });

  final desktopOnly = !(Platform.isMacOS || Platform.isWindows || Platform.isLinux) ? 'desktop sign-in flow' : null;
  final skip = _dbFileName.isEmpty ? 'needs --dart-define=DB_FILE_NAME=<name>' : desktopOnly;

  group('desktop silent sign-in', skip: skip, () {
    setUp(() => AppSettings.set('googleRefreshToken', 'refresh-1'));

    test('a confirmed account becomes the session', () async {
      final service = GoogleDriveSyncService(httpClientFactory: () => _authTransport(_account));

      expect(await service.trySilentSignIn(), isTrue);
      expect(service.isSignedIn, isTrue);
      expect(service.userEmail, 'me@example.com');
    });

    test('an account lookup that fails leaves the service signed out', () async {
      final service = GoogleDriveSyncService(httpClientFactory: () => _authTransport(_revoked));

      expect(await service.trySilentSignIn(), isFalse);
      expect(service.isSignedIn, isFalse, reason: 'a session that cannot reach Drive is no session');
      expect(service.userEmail, isNull);
    });

    test('a sign-out landing during the account lookup wins over it', () async {
      final lookup = Completer<http.Response>();
      final looking = Completer<void>();
      final service = GoogleDriveSyncService(
        httpClientFactory: () => _authTransport(() {
          looking.complete();
          return lookup.future;
        }),
      );

      final signingIn = service.trySilentSignIn();
      await looking.future;
      await service.signOut();
      lookup.complete(await _account());

      expect(await signingIn, isFalse);
      expect(service.isSignedIn, isFalse);
      expect(service.userEmail, isNull);
    });
  });

  group('backup transfers are bounded', skip: _dbFileName.isEmpty ? 'needs --dart-define=DB_FILE_NAME=<name>' : null, () {
    const timeout = Duration(milliseconds: 200);

    test('a stalled upload fails with a timeout and removes its snapshot', () async {
      final service = GoogleDriveSyncService(transferTimeout: timeout)
        ..signInWithClientForTest(_driveTransport(upload: () => Completer<http.StreamedResponse>().future));
      final snapshot = File(p.join(dir.path, 'snapshot.db'));
      service.createSnapshot = () async => (snapshot..writeAsStringSync('SQLite')).path;

      await expectLater(service.backupToDrive(), throwsA(isA<TimeoutException>()));
      expect(snapshot.existsSync(), isFalse);
      expect(await AppSettings.get('lastSyncTime'), isNull, reason: 'nothing was backed up');
    });

    test('a download that stops sending fails with a timeout, merges nothing and leaves no tmp file', () async {
      final stalled = StreamController<List<int>>();
      addTearDown(stalled.close);
      final service = GoogleDriveSyncService(transferTimeout: timeout)
        ..signInWithClientForTest(
          _driveTransport(
            download: () {
              stalled.add(utf8.encode('SQLite format 3'));
              return stalled.stream;
            },
          ),
        );
      service.copyFromAttached = (_) async => fail('a stalled download must never be merged');

      await expectLater(service.restoreFromDrive(), throwsA(isA<TimeoutException>()));
      expect(dir.listSync().map((e) => p.basename(e.path)).where((name) => name.endsWith('.tmp')), isEmpty);
    });
  });

  group('desktop interactive sign-in', skip: skip, () {
    test('a browser that cannot be opened fails the sign-in', () async {
      final service = GoogleDriveSyncService(launchConsentUrl: (url) async => false);

      expect(await service.signIn().timeout(const Duration(seconds: 20)), isFalse);
      expect(service.isSignedIn, isFalse);
    });

    test('a launch that throws fails the sign-in the same way', () async {
      final service = GoogleDriveSyncService(launchConsentUrl: (url) async => throw PlatformException(code: 'no_browser'));

      expect(await service.signIn().timeout(const Duration(seconds: 20)), isFalse);
      expect(service.isSignedIn, isFalse);
    });

    test('a consent that never arrives ends the wait', () async {
      final service = GoogleDriveSyncService(
        consentTimeout: const Duration(seconds: 1),
        launchConsentUrl: (url) async => true, // the browser opened; the user just never answers
      );

      expect(await service.signIn().timeout(const Duration(seconds: 20)), isFalse);
      expect(service.isSignedIn, isFalse);
    });
  });
}
