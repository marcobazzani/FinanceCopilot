import 'dart:async';
import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../database/db_file_name.dart';
import '../utils/logger.dart';
import 'app_settings.dart';

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
  final String? deviceId;
  final String? deviceName;

  const DriveFileInfo({
    required this.fileId,
    required this.modifiedTime,
    required this.size,
    this.deviceId,
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

  // Mobile auth via Google Sign-In (uses Google Play Services)
  bool _mobileInitialized = false;
  GoogleSignInAccount? _mobileAccount;

  // Desktop auth via googleapis_auth (uses loopback redirect + client secret)
  auth.AuthClient? _desktopAuthClient;

  // Shared
  http.Client? _httpClient;
  drive.DriveApi? _driveApi;
  String? _userEmail;

  late final String _deviceId;

  GoogleDriveSyncService() {
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
    if (_isDesktop) {
      _desktopAuthClient?.close();
      _desktopAuthClient = null;
      await AppSettings.set('googleRefreshToken', '');
    } else {
      await GoogleSignIn.instance.signOut();
      _mobileAccount = null;
    }
    _httpClient = null;
    _driveApi = null;
    _userEmail = null;
    _log.info('Signed out');
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

    _desktopAuthClient = auth.autoRefreshingClient(_clientId, credentials, http.Client());
    _httpClient = _desktopAuthClient;
    _driveApi = drive.DriveApi(_desktopAuthClient!);

    final about = await _driveApi!.about.get($fields: 'user');
    _userEmail = about.user?.emailAddress;
    _log.info('Desktop silent sign-in successful: $_userEmail');
    return true;
  }

  Future<bool> _desktopSignIn() async {
    _desktopAuthClient = await auth.clientViaUserConsent(
      _clientId,
      [_driveScope],
      (url) {
        _log.info('Opening OAuth URL in browser');
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      },
    );

    _httpClient = _desktopAuthClient;
    _driveApi = drive.DriveApi(_desktopAuthClient!);

    final credentials = _desktopAuthClient!.credentials;
    if (credentials.refreshToken != null) {
      await AppSettings.set('googleRefreshToken', credentials.refreshToken!);
    }

    final about = await _driveApi!.about.get($fields: 'user');
    _userEmail = about.user?.emailAddress;
    _log.info('Desktop sign-in successful: $_userEmail');
    return true;
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
    _httpClient = authz.authClient(scopes: [_driveScope]);
    _driveApi = drive.DriveApi(_httpClient!);
    _userEmail = account.email;
    _log.info('Mobile sign-in successful: $_userEmail');
    return true;
  }

  // ── Sync ──────────────────────────────────────────

  Future<String> get _localDbPath async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, dbFileName);
  }

  /// Check what's on Google Drive.
  Future<DriveFileInfo?> getRemoteInfo() async {
    if (_driveApi == null) return null;
    try {
      final fileList = await _driveApi!.files.list(
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
        fileId: f.id!,
        modifiedTime: f.modifiedTime ?? DateTime(2000),
        size: int.tryParse(f.size ?? '0') ?? 0,
        deviceId: f.appProperties?['deviceId'],
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
      return null;
    }
  }

  /// Explicit "Backup to Drive": uploads the local DB, overwriting any
  /// existing remote file. Used by the manual Backup-to-Drive button.
  /// Throws on auth/network errors.
  Future<DriveFileInfo> backupToDrive() async {
    if (_driveApi == null) throw StateError('not_signed_in');
    final localPath = await _localDbPath;
    final file = File(localPath);
    if (!file.existsSync()) throw StateError('local_db_missing');

    final metadata = drive.File()
      ..name = dbFileName
      ..appProperties = {
        'deviceId': _deviceId,
        'deviceName': Platform.localHostname,
      };

    final existing = await getRemoteInfo();
    final media = drive.Media(file.openRead(), file.lengthSync());
    final drive.File uploaded;
    if (existing != null) {
      uploaded = await _driveApi!.files.update(
        metadata,
        existing.fileId,
        uploadMedia: media,
        $fields: 'id,modifiedTime,size,appProperties',
      );
      _log.info('backupToDrive: updated remote DB (${file.lengthSync()} bytes)');
    } else {
      metadata.parents = ['appDataFolder'];
      uploaded = await _driveApi!.files.create(
        metadata,
        uploadMedia: media,
        $fields: 'id,modifiedTime,size,appProperties',
      );
      _log.info('backupToDrive: created remote DB (${file.lengthSync()} bytes)');
    }

    final info = DriveFileInfo(
      fileId: uploaded.id!,
      modifiedTime: uploaded.modifiedTime ?? DateTime.now().toUtc(),
      size: int.tryParse(uploaded.size ?? '0') ?? file.lengthSync(),
      deviceId: uploaded.appProperties?['deviceId'],
      deviceName: uploaded.appProperties?['deviceName'],
    );
    // Track the actual remote modifiedTime, never local clock.
    await AppSettings.set('lastSyncTime', info.modifiedTime.toIso8601String());
    await AppSettings.set('syncDirty', 'false');
    return info;
  }

  /// Explicit "Restore from Drive": downloads the remote DB and merges it
  /// into the local DB via ATTACH. Returns the restored file info, or null
  /// if no remote backup exists. Throws on auth/network errors.
  Future<DriveFileInfo?> restoreFromDrive() async {
    if (_driveApi == null) throw StateError('not_signed_in');
    final remote = await getRemoteInfo();
    if (remote == null) return null;
    final localPath = await _localDbPath;
    await _download(localPath, remote.fileId);
    // Override the lastSyncTime that _download set with local clock —
    // store the actual remote modifiedTime so future comparisons are honest.
    await AppSettings.set('lastSyncTime', remote.modifiedTime.toIso8601String());
    return remote;
  }

  // ── Download ──────────────────────────────────────

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
  Future<void> _download(String localPath, String fileId) async {
    final tmpPath = '$localPath.tmp';
    final tmpFile = File(tmpPath);

    try {
      final t0 = DateTime.now();
      _log.info('download: phase 1 - fetching remote...');
      final response = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      if (tmpFile.existsSync()) await tmpFile.delete();
      final sink = tmpFile.openWrite();
      await response.stream.pipe(sink);
      final tmpSize = await tmpFile.length();
      _log.info('download: phase 1 done - fetched $tmpSize bytes in ${DateTime.now().difference(t0).inMilliseconds}ms');

      if (tmpSize == 0) {
        _log.warning('download: empty file received, aborting');
        await tmpFile.delete();
        return;
      }

      if (copyFromAttached == null) {
        throw StateError('copyFromAttached callback is not wired — cannot merge remote DB');
      }

      final tCopy = DateTime.now();
      _log.info('download: phase 2 - ATTACH + copy tables from tmp');
      await copyFromAttached!(tmpPath);
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
        try { await tmpFile.delete(); } catch (_) {}
      }
      rethrow;
    }
  }

  Future<DateTime?> get lastSyncTime async {
    final s = await AppSettings.get('lastSyncTime');
    return s != null ? DateTime.tryParse(s) : null;
  }
}
