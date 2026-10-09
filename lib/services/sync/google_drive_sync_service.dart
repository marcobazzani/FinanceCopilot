import 'dart:async';
import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:finance_copilot/database/db_file_name.dart';
import 'package:finance_copilot/utils/logger.dart';
import 'package:finance_copilot/services/app_settings.dart';

final _log = getLogger('GoogleDriveSync');

const _driveScope = 'https://www.googleapis.com/auth/drive.appdata';

// OAuth credentials injected via --dart-define at build time
const _googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
const _googleClientSecret = String.fromEnvironment('GOOGLE_CLIENT_SECRET');
const _googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
final _clientId = auth.ClientId(_googleClientId, _googleClientSecret);

/// Metadata about the remote DB file on Google Drive.
class DriveFileInfo {
  final String fileId;
  final DateTime modifiedTime;
  final int size;
  final String? deviceName;

  const DriveFileInfo({
    required this.fileId,
    required this.modifiedTime,
    required this.size,
    this.deviceName,
  });
}

/// Manual Google Drive backup/restore for the app database.
///
/// - Sign-in is restored silently on startup (so Backup/Restore work
///   without an interactive prompt every time).
/// - Backup and Restore are explicit user actions in Import/Export.
/// - All-or-nothing: entire DB file, never partial.
class GoogleDriveSyncService {
  static final bool _isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  /// How long one backup transfer may take: the whole upload, and on a
  /// download the response and then each wait for more data. Generous — the
  /// whole database crosses the wire, on any link — it only keeps a stalled
  /// transfer from leaving Backup/Restore busy forever.
  static const _defaultTransferTimeout = Duration(minutes: 10);

  /// How long an interactive desktop sign-in waits for the consent given in
  /// the browser (account choice, password, second factor).
  static const _defaultConsentTimeout = Duration(minutes: 5);

  /// Bound on the account lookup that confirms a new session.
  static const _lookupTimeout = Duration(seconds: 30);

  static Future<bool> _openInBrowser(Uri url) => launchUrl(url, mode: LaunchMode.externalApplication);

  // Mobile auth via Google Sign-In (uses Google Play Services)
  bool _mobileInitialized = false;
  GoogleSignInAccount? _mobileAccount;

  // Shared. The session's authenticated client: the desktop auth client
  // (googleapis_auth, loopback redirect + client secret) or the mobile
  // authorized client.
  http.Client? _httpClient;
  drive.DriveApi? _driveApi;
  String? _userEmail;

  late final String _deviceId;

  /// The transport under a desktop session's auth client.
  final http.Client Function() _newHttpClient;

  /// Opens the consent page of an interactive desktop sign-in; false when
  /// nothing could open it.
  final Future<bool> Function(Uri url) _launchConsentUrl;

  final Duration _transferTimeout;
  final Duration _consentTimeout;

  /// [httpClientFactory], [launchConsentUrl], [transferTimeout] and
  /// [consentTimeout] are test seams (the desktop auth transport, the browser
  /// launch and the two waits below); production uses the defaults.
  GoogleDriveSyncService({
    @visibleForTesting http.Client Function()? httpClientFactory,
    @visibleForTesting Future<bool> Function(Uri url)? launchConsentUrl,
    @visibleForTesting Duration transferTimeout = _defaultTransferTimeout,
    @visibleForTesting Duration consentTimeout = _defaultConsentTimeout,
  }) : _newHttpClient = httpClientFactory ?? http.Client.new,
       _launchConsentUrl = launchConsentUrl ?? _openInBrowser,
       _transferTimeout = transferTimeout,
       _consentTimeout = consentTimeout {
    _deviceId = _computeDeviceId();
    // Fail fast if DB_FILE_NAME dart-define is missing, so dev builds can't
    // silently read or overwrite the prod Drive backup.
    dbFileName;
  }

  String _computeDeviceId() {
    final host = Platform.localHostname;
    final os = Platform.operatingSystem;
    return '$os-$host';
  }

  // ── Auth ──────────────────────────────────────────

  bool get isSignedIn => _driveApi != null;

  String? get userEmail => _userEmail;

  /// True when the user was previously signed in but the session could not be
  /// restored (e.g. after a library upgrade that changed the auth flow).
  /// The UI should prompt the user to re-authenticate.
  bool get needsReauth => _needsReauth;
  bool _needsReauth = false;

  /// Try to restore a previous sign-in session.
  Future<bool> trySilentSignIn() async {
    bool result;
    try {
      if (_isDesktop) {
        result = await _desktopSilentSignIn();
      } else {
        result = await _mobileSilentSignIn();
      }
    } catch (e) {
      _log.warning('trySilentSignIn failed: $e');
      result = false;
    }
    // On mobile only: if silent sign-in failed but the user was previously
    // signed in, flag that a re-auth prompt is needed (v6->v7 migration
    // breaks the session). Desktop auth is unchanged and doesn't need this.
    if (!result && !_isDesktop) {
      final lastSync = await AppSettings.get('lastSyncTime');
      if (lastSync != null && lastSync.isNotEmpty) {
        _needsReauth = true;
        _log.info('trySilentSignIn: user was previously signed in, needs re-auth');
      }
    }
    return result;
  }

  /// Interactive sign-in.
  Future<bool> signIn() async {
    try {
      bool result;
      if (_isDesktop) {
        result = await _desktopSignIn();
      } else {
        result = await _mobileInteractiveSignIn();
      }
      if (result) _needsReauth = false;
      return result;
    } catch (e) {
      _log.severe('signIn failed: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    _signOuts++;
    _closeClient();
    if (_isDesktop) {
      await AppSettings.set('googleRefreshToken', '');
    } else {
      await GoogleSignIn.instance.signOut();
      _mobileAccount = null;
    }
    _userEmail = null;
    _log.info('Signed out');
  }

  /// Sign-outs so far: a sign-in still confirming its account must not
  /// revive a session the user ended meanwhile.
  int _signOuts = 0;

  /// Make [client] the session's transport, closing the one it replaces: a
  /// dropped auth client keeps its connections (and, on desktop, its token
  /// refresh) alive.
  drive.DriveApi _useClient(http.Client client) {
    final previous = _httpClient;
    _httpClient = client;
    if (!identical(previous, client)) previous?.close();
    return _driveApi = drive.DriveApi(client);
  }

  /// End the session: close its client and forget it.
  void _closeClient() {
    final client = _httpClient;
    _httpClient = null;
    _driveApi = null;
    client?.close();
  }

  /// Make [client] the session once the account behind it answered, with that
  /// account's email. Until then nothing changes: a lookup that fails
  /// (revoked token, no network) must not leave [isSignedIn] reporting a
  /// session that cannot reach Drive, and a sign-out landing meanwhile wins.
  /// Returns whether [client] became the session; if not, it is closed and a
  /// failed lookup rethrown.
  Future<bool> _adoptSession(http.Client client) async {
    final signOuts = _signOuts;
    final String? email;
    try {
      final about = await drive.DriveApi(client).about.get($fields: 'user').timeout(_lookupTimeout);
      email = about.user?.emailAddress;
    } catch (_) {
      client.close();
      rethrow;
    }
    if (signOuts != _signOuts) {
      client.close();
      return false;
    }
    _useClient(client);
    _userEmail = email;
    return true;
  }

  // ── Desktop auth (loopback OAuth) ─────────────────

  Future<bool> _desktopSilentSignIn() async {
    final refreshToken = await AppSettings.get('googleRefreshToken');
    if (refreshToken == null || refreshToken.isEmpty) return false;

    final credentials = auth.AccessCredentials(
      auth.AccessToken('Bearer', '', DateTime.now().subtract(const Duration(hours: 1)).toUtc()),
      refreshToken,
      [_driveScope],
    );

    if (!await _adoptSession(auth.autoRefreshingClient(_clientId, credentials, _newHttpClient()))) return false;
    _log.info('Desktop silent sign-in successful: $_userEmail');
    return true;
  }

  Future<bool> _desktopSignIn() async {
    final client = await _userConsentClient();
    if (client == null) return false;

    try {
      final refreshToken = client.credentials.refreshToken;
      if (refreshToken != null) await AppSettings.set('googleRefreshToken', refreshToken);
    } catch (_) {
      client.close();
      rethrow;
    }

    if (!await _adoptSession(client)) return false;
    _log.info('Desktop sign-in successful: $_userEmail');
    return true;
  }

  /// The browser half of an interactive desktop sign-in: opens the consent
  /// page and waits for the redirect it sends to the loopback listener. Null
  /// when the browser could not be opened or no consent came within
  /// [_consentTimeout]; a consent given in the browser afterwards is
  /// discarded.
  Future<auth.AutoRefreshingAuthClient?> _userConsentClient() async {
    final launchFailed = Completer<void>();
    final consent = auth.clientViaUserConsent(_clientId, [_driveScope], (url) {
      _log.info('Opening OAuth URL in browser');
      // The prompt callback is synchronous: the launch reports back through
      // [launchFailed], which the wait below races against the consent.
      unawaited(
        _launchConsentUrl(Uri.parse(url)).then(
          (opened) {
            if (!opened) launchFailed.complete();
          },
          onError: (Object e) {
            _log.warning('Opening the OAuth URL failed: $e');
            launchFailed.complete();
          },
        ),
      );
    });

    final client = await Future.any<auth.AutoRefreshingAuthClient?>([
      consent,
      launchFailed.future.then((_) => null),
    ]).timeout(_consentTimeout, onTimeout: () => null);
    if (client != null) return client;

    _log.warning(
      launchFailed.isCompleted
          ? 'Desktop sign-in: no browser could open the consent page'
          : 'Desktop sign-in: no consent within ${_consentTimeout.inSeconds}s',
    );
    // Whatever the abandoned flow still produces is discarded: a consent
    // finished in the browser from now on must not sign in behind the user.
    // Its loopback listener is left to it: an ephemeral port, and a retry
    // opens a flow of its own.
    unawaited(consent.then((abandoned) => abandoned.close(), onError: (Object _) {}));
    return null;
  }

  // ── Mobile auth (Google Play Services) ────────────

  Future<void> _ensureMobileInitialized() async {
    if (!_mobileInitialized) {
      await GoogleSignIn.instance.initialize(
        serverClientId: _googleWebClientId.isNotEmpty ? _googleWebClientId : null,
      );
      _mobileInitialized = true;
    }
  }

  Future<bool> _mobileSilentSignIn() async {
    await _ensureMobileInitialized();
    final account = await GoogleSignIn.instance.attemptLightweightAuthentication();
    if (account == null) {
      _log.info('mobileSilentSignIn: no previous session');
      return false;
    }
    _mobileAccount = account;
    return await _initMobileDriveApi();
  }

  Future<bool> _mobileInteractiveSignIn() async {
    await _ensureMobileInitialized();
    try {
      _mobileAccount = await GoogleSignIn.instance.authenticate(scopeHint: [_driveScope]);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      rethrow;
    }
    return await _initMobileDriveApi();
  }

  Future<bool> _initMobileDriveApi() async {
    final account = _mobileAccount;
    if (account == null) return false;
    final authz = await account.authorizationClient.authorizeScopes([_driveScope]);
    _useClient(authz.authClient(scopes: [_driveScope]));
    _userEmail = account.email;
    _log.info('Mobile sign-in successful: $_userEmail');
    return true;
  }

  /// Test seam: signs in over [client] (e.g. a mock HTTP client) instead of
  /// an OAuth flow, handing the session over exactly like a real sign-in.
  @visibleForTesting
  void signInWithClientForTest(http.Client client, {String? email}) {
    _useClient(client);
    _userEmail = email;
  }

  // ── Sync ──────────────────────────────────────────

  Future<String> get _localDbPath async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, dbFileName);
  }

  /// Check what's on Google Drive: the backup, or null when there is none (or
  /// no session to look with). Throws when the lookup fails (auth/network):
  /// an unanswered lookup is no "no backup".
  Future<DriveFileInfo?> getRemoteInfo() {
    final api = _driveApi;
    if (api == null) return Future.value();
    return _remoteInfo(api);
  }

  /// The backup on [api]'s Drive, or null when there is none. A lookup that
  /// fails rethrows: answering null would make Backup create a second remote
  /// file next to the existing one, and Restore report there is none.
  Future<DriveFileInfo?> _remoteInfo(drive.DriveApi api) async {
    try {
      final fileList = await api.files.list(
        spaces: 'appDataFolder',
        q: "name = '$dbFileName'",
        $fields: 'files(id, name, modifiedTime, size, appProperties)',
        orderBy: 'modifiedTime desc',
        pageSize: 1,
      );
      final files = fileList.files;
      if (files == null || files.isEmpty) return null;
      final f = files.first;
      return DriveFileInfo(
        fileId: f.id ?? (throw StateError('Drive listed the backup without an id')),
        modifiedTime: f.modifiedTime ?? DateTime(2000),
        size: int.tryParse(f.size ?? '0') ?? 0,
        deviceName: f.appProperties?['deviceName'],
      );
    } catch (e) {
      _log.warning('getRemoteInfo failed: $e');
      // Detect token-invalid errors and flag re-auth so the UI can prompt.
      // Silent sign-in returns success with stale cached creds; the failure
      // only surfaces here on the first real API call.
      final msg = e.toString().toLowerCase();
      if (msg.contains('invalid_token') || msg.contains('unauthorized') || msg.contains('access was denied')) {
        _needsReauth = true;
      }
      rethrow;
    }
  }

  /// Explicit "Backup to Drive": uploads the local DB, overwriting any
  /// existing remote file. Used by the manual Backup-to-Drive button.
  /// Throws on auth/network errors.
  ///
  /// Uploads a `VACUUM INTO` snapshot (via [createSnapshot]) rather than
  /// the live DB file: streaming the live file directly could capture a
  /// torn copy mid-write (background price sync, an in-progress import,
  /// etc.) — the upload "succeeds" but silently replaces a good remote
  /// backup with an inconsistent one.
  Future<DriveFileInfo> backupToDrive() async {
    // Read the session once: signOut() can clear it while this awaits, and
    // every call below must go to the account the backup started on.
    final api = _driveApi;
    if (api == null) throw StateError('not_signed_in');
    final snapshot = createSnapshot;
    if (snapshot == null) {
      throw StateError('createSnapshot callback is not wired — cannot back up safely');
    }
    final snapshotPath = await snapshot();
    final file = File(snapshotPath);
    try {
      if (!file.existsSync()) throw StateError('snapshot_missing');

      final metadata = drive.File()
        ..name = dbFileName
        ..appProperties = {
          'deviceId': _deviceId,
          'deviceName': Platform.localHostname,
        };

      // Throws when the lookup fails: a backup that could not be seen must
      // not get a second one created next to it.
      final existing = await _remoteInfo(api);
      final media = drive.Media(file.openRead(), file.lengthSync());
      final drive.File uploaded;
      if (existing != null) {
        uploaded = await api.files
            .update(
              metadata,
              existing.fileId,
              uploadMedia: media,
              $fields: 'id,modifiedTime,size,appProperties',
            )
            .timeout(_transferTimeout);
        _log.info('backupToDrive: updated remote DB (${file.lengthSync()} bytes)');
      } else {
        metadata.parents = ['appDataFolder'];
        uploaded = await api.files
            .create(
              metadata,
              uploadMedia: media,
              $fields: 'id,modifiedTime,size,appProperties',
            )
            .timeout(_transferTimeout);
        _log.info('backupToDrive: created remote DB (${file.lengthSync()} bytes)');
      }

      final info = DriveFileInfo(
        fileId: uploaded.id ?? (throw StateError('Drive answered the upload without a file id')),
        modifiedTime: uploaded.modifiedTime ?? DateTime.now().toUtc(),
        size: int.tryParse(uploaded.size ?? '0') ?? file.lengthSync(),
        deviceName: uploaded.appProperties?['deviceName'],
      );
      // Track the actual remote modifiedTime, never local clock.
      await AppSettings.set('lastSyncTime', info.modifiedTime.toIso8601String());
      await AppSettings.set('syncDirty', 'false');
      return info;
    } finally {
      try {
        await file.delete();
      } catch (e) {
        _log.warning('backupToDrive: failed to delete snapshot tmp file (harmless): $e');
      }
    }
  }

  /// Explicit "Restore from Drive": downloads the remote DB and merges it
  /// into the local DB via ATTACH. Returns the restored file info, or null
  /// if no remote backup exists. Throws on auth/network errors.
  Future<DriveFileInfo?> restoreFromDrive() async {
    // Read the session once (see backupToDrive).
    final api = _driveApi;
    if (api == null) throw StateError('not_signed_in');
    final remote = await _remoteInfo(api);
    if (remote == null) return null;
    final localPath = await _localDbPath;
    await _download(api, localPath, remote.fileId);
    // Override the lastSyncTime that _download set with local clock —
    // store the actual remote modifiedTime so future comparisons are honest.
    await AppSettings.set('lastSyncTime', remote.modifiedTime.toIso8601String());
    return remote;
  }

  // ── Download ──────────────────────────────────────

  /// Create a transactionally-consistent snapshot of the local DB at a
  /// fresh temp path (via SQLite `VACUUM INTO`) and return that path. The
  /// app shell wires this to `AppDatabase.snapshotToTempFile` — mirrors
  /// [copyFromAttached] so this service doesn't need a direct database
  /// dependency. Used by [backupToDrive] so the upload never reads the
  /// live DB file directly.
  Future<String> Function()? createSnapshot;

  /// Copy the contents of the downloaded tmp database into the currently open
  /// drift instance via `ATTACH DATABASE`. The app shell wires this up with
  /// access to the drift connection. Cross-platform, no file swap, no close —
  /// side-steps all the Windows file-lock and drift-close race issues.
  ///
  /// Must run the copy in a transaction. If anything throws, drift rolls back
  /// and the local data is untouched.
  Future<void> Function(String tmpPath)? copyFromAttached;

  /// Called when the local DB was replaced by a remote download.
  /// The app shell should reload the DB and refresh the UI.
  void Function()? onDbReplaced;

  /// Download the remote DB and merge its contents into the currently open
  /// drift instance via `ATTACH DATABASE`. No file swap, no drift close.
  ///
  /// Why ATTACH:
  ///   - Windows refuses to delete/rename any file held by an open handle.
  ///     Drift's close() takes seconds (or hangs) when active stream
  ///     subscribers are listening — and even if close does complete, the
  ///     Riverpod-cached reference is stale and subsequent queries break.
  ///   - ATTACH lets SQLite copy rows between two databases while the primary
  ///     one stays open. One transaction wraps the copy → atomic, rolled back
  ///     on any error → local data is never lost.
  ///   - All drift stream subscribers re-query automatically after the
  ///     transaction commits, so the UI refreshes without any special
  ///     plumbing.
  ///
  /// Phases:
  ///   1. stream remote file to `<localPath>.tmp`
  ///   2. delegate to `copyFromAttached` (wired by the app shell) which runs
  ///      ATTACH + per-table INSERT FROM SELECT inside a drift transaction
  ///   3. delete the tmp file
  Future<void> _download(drive.DriveApi api, String localPath, String fileId) async {
    final tmpPath = '$localPath.tmp';
    final tmpFile = File(tmpPath);

    try {
      final t0 = DateTime.now();
      _log.info('download: phase 1 - fetching remote...');
      final response =
          await api.files
                  .get(
                    fileId,
                    downloadOptions: drive.DownloadOptions.fullMedia,
                  )
                  .timeout(_transferTimeout)
              as drive.Media;
      if (tmpFile.existsSync()) await tmpFile.delete();
      final sink = tmpFile.openWrite();
      try {
        // Bounded per wait for more data, not overall: a slow link still
        // finishes, a stalled one fails (and its stream is cancelled).
        await response.stream.timeout(_transferTimeout).pipe(sink);
      } finally {
        // pipe() closes the sink only when the stream completes. Close it when
        // the download breaks too, so the tmp file is released before the
        // cleanup below deletes it; that close failing must not mask the error
        // that broke the download.
        try {
          await sink.close();
        } catch (e) {
          _log.fine('download: closing tmp file failed: $e');
        }
      }
      final tmpSize = await tmpFile.length();
      _log.info('download: phase 1 done - fetched $tmpSize bytes in ${DateTime.now().difference(t0).inMilliseconds}ms');

      if (tmpSize == 0) {
        _log.warning('download: empty file received, aborting');
        await tmpFile.delete();
        return;
      }

      final copy = copyFromAttached;
      if (copy == null) {
        throw StateError('copyFromAttached callback is not wired — cannot merge remote DB');
      }

      final tCopy = DateTime.now();
      _log.info('download: phase 2 - ATTACH + copy tables from tmp');
      await copy(tmpPath);
      _log.info('download: phase 2 done in ${DateTime.now().difference(tCopy).inMilliseconds}ms');

      // Phase 3: cleanup tmp file
      try {
        await tmpFile.delete();
      } catch (e) {
        _log.warning('download: failed to delete tmp (harmless): $e');
      }

      // Note: lastSyncTime is set by the caller (restoreFromDrive) to the
      // actual remote modifiedTime. _download intentionally does NOT use
      // DateTime.now() here — that was the bug that stranded the desktop.
      _log.info('download: merged remote DB ($tmpSize bytes) total ${DateTime.now().difference(t0).inMilliseconds}ms');
    } catch (e, stack) {
      _log.severe('download failed: $e\n$stack');
      if (tmpFile.existsSync()) {
        try {
          await tmpFile.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<DateTime?> get lastSyncTime async {
    final s = await AppSettings.get('lastSyncTime');
    return s != null ? DateTime.tryParse(s) : null;
  }
}
