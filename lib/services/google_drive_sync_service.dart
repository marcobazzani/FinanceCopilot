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

import '../utils/logger.dart';
import 'app_settings.dart';

final _log = getLogger('GoogleDriveSync');

const _driveScope = 'https://www.googleapis.com/auth/drive.appdata';
const _dbFileName = 'finance_copilot.db';

// OAuth credentials injected via --dart-define at build time
const _googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
const _googleClientSecret = String.fromEnvironment('GOOGLE_CLIENT_SECRET');
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

/// Automatic Google Drive sync for the app database.
///
/// - On startup: pull if remote is newer (blocking)
/// - On every DB change: push after 10s debounce (background)
/// - All-or-nothing: entire DB file, never partial
class GoogleDriveSyncService {
  static final bool _isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  // Mobile auth via Google Sign-In (uses Google Play Services)
  GoogleSignIn? _googleSignIn;
  GoogleSignIn get _mobileSignIn => _googleSignIn ??= GoogleSignIn(scopes: [_driveScope]);

  // Desktop auth via googleapis_auth (uses loopback redirect + client secret)
  auth.AuthClient? _desktopAuthClient;

  // Shared
  http.Client? _httpClient;
  drive.DriveApi? _driveApi;
  Timer? _debounceTimer;
  bool _uploading = false;
  bool _syncing = false;
  StreamSubscription? _tableUpdateSub;
  String? _userEmail;

  late final String _deviceId;

  GoogleDriveSyncService() {
    _deviceId = _computeDeviceId();
  }

  String _computeDeviceId() {
    final host = Platform.localHostname;
    final os = Platform.operatingSystem;
    return '$os-$host';
  }

  // ── Auth ──────────────────────────────────────────

  bool get isSignedIn => _driveApi != null;

  String? get userEmail => _userEmail;

  /// Try to restore a previous sign-in session.
  Future<bool> trySilentSignIn() async {
    try {
      if (_isDesktop) {
        return await _desktopSilentSignIn();
      } else {
        return await _mobileSilentSignIn();
      }
    } catch (e) {
      _log.warning('trySilentSignIn failed: $e');
      return false;
    }
  }

  /// Interactive sign-in.
  Future<bool> signIn() async {
    try {
      if (_isDesktop) {
        return await _desktopSignIn();
      } else {
        return await _mobileInteractiveSignIn();
      }
    } catch (e) {
      _log.severe('signIn failed: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    stopAutoSync();
    if (_isDesktop) {
      _desktopAuthClient?.close();
      _desktopAuthClient = null;
      await AppSettings.set('googleRefreshToken', '');
    } else {
      await _mobileSignIn.signOut();
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

  Future<bool> _mobileSilentSignIn() async {
    final account = await _mobileSignIn.signInSilently();
    if (account == null) return false;
    return await _initMobileDriveApi();
  }

  Future<bool> _mobileInteractiveSignIn() async {
    final account = await _mobileSignIn.signIn();
    if (account == null) return false;
    return await _initMobileDriveApi();
  }

  Future<bool> _initMobileDriveApi() async {
    _httpClient = await _mobileSignIn.authenticatedClient();
    if (_httpClient == null) return false;
    _driveApi = drive.DriveApi(_httpClient!);
    _userEmail = _mobileSignIn.currentUser?.email;
    _log.info('Mobile sign-in successful: $_userEmail');
    return true;
  }

  // ── Sync ──────────────────────────────────────────

  Future<String> get _localDbPath async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, _dbFileName);
  }

  /// Check what's on Google Drive.
  Future<DriveFileInfo?> getRemoteInfo() async {
    if (_driveApi == null) return null;
    try {
      final fileList = await _driveApi!.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_dbFileName'",
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
      return null;
    }
  }

  /// Pull remote DB if it's newer than local. Returns true if DB was replaced.
  Future<bool> pullIfNewerOnStartup() async {
    if (_driveApi == null) return false;
    _syncing = true;
    try {
      final localPath = await _localDbPath;
      final localFile = File(localPath);
      final localMtime = localFile.existsSync() ? localFile.lastModifiedSync() : DateTime(2000);

      final remote = await getRemoteInfo();
      if (remote == null) {
        _log.info('pullIfNewer: no remote DB found');
        final dirty = await AppSettings.get('syncDirty');
        if (dirty == 'true' && localFile.existsSync()) {
          await _upload(localPath);
        }
        return false;
      }

      _log.info('pullIfNewer: local=${localMtime.toIso8601String()} remote=${remote.modifiedTime.toIso8601String()} remoteDevice=${remote.deviceId}');

      final dirty = await AppSettings.get('syncDirty');
      if (dirty == 'true' && remote.deviceId != _deviceId && remote.modifiedTime.isAfter(localMtime)) {
        _log.warning('pullIfNewer: CONFLICT detected - remote from ${remote.deviceName}, local dirty. Using remote.');
      }

      if (remote.modifiedTime.isAfter(localMtime)) {
        _log.info('pullIfNewer: remote is newer, downloading...');
        await _download(localPath, remote.fileId);
        await AppSettings.set('syncDirty', 'false');
        return true;
      } else {
        _log.info('pullIfNewer: local is current');
        if (dirty == 'true') {
          await _upload(localPath);
        }
        return false;
      }
    } catch (e) {
      _log.warning('pullIfNewer failed: $e');
      return false;
    } finally {
      _syncing = false;
    }
  }

  /// Start listening to DB changes and auto-push after debounce.
  void startAutoSync(Stream<void> tableUpdates) {
    _tableUpdateSub?.cancel();
    _tableUpdateSub = tableUpdates.listen((_) {
      _markDirty();
    });
    _log.info('Auto-sync started (device=$_deviceId)');
  }

  void stopAutoSync() {
    _debounceTimer?.cancel();
    _tableUpdateSub?.cancel();
    _tableUpdateSub = null;
    _log.info('Auto-sync stopped');
  }

  void _markDirty() {
    _hasUserData = true;
    AppSettings.set('syncDirty', 'true');
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 10), () {
      if (!_uploading && !_syncing && _driveApi != null) {
        _localDbPath.then((path) => _upload(path));
      }
    });
  }

  // ── Upload / Download ─────────────────────────────

  /// Check if the local DB has actual user data.
  bool _hasUserData = false;
  void setHasUserData(bool value) => _hasUserData = value;

  Future<void> _upload(String localPath) async {
    if (_driveApi == null || _uploading) return;
    if (!_hasUserData) {
      _log.info('upload: skipping - local DB has no user data');
      return;
    }
    _uploading = true;
    try {
      final file = File(localPath);
      if (!file.existsSync()) {
        _log.warning('upload: local DB not found at $localPath');
        return;
      }

      final media = drive.Media(file.openRead(), file.lengthSync());
      final metadata = drive.File()
        ..name = _dbFileName
        ..appProperties = {
          'deviceId': _deviceId,
          'deviceName': Platform.localHostname,
        };

      final existing = await getRemoteInfo();
      if (existing != null) {
        await _driveApi!.files.update(metadata, existing.fileId, uploadMedia: media);
        _log.info('upload: updated remote DB (${file.lengthSync()} bytes)');
      } else {
        metadata.parents = ['appDataFolder'];
        await _driveApi!.files.create(metadata, uploadMedia: media);
        _log.info('upload: created remote DB (${file.lengthSync()} bytes)');
      }

      await AppSettings.set('syncDirty', 'false');
      await AppSettings.set('lastSyncTime', DateTime.now().toIso8601String());
    } catch (e) {
      _log.warning('upload failed: $e');
    } finally {
      _uploading = false;
    }
  }

  Future<void> _download(String localPath, String fileId) async {
    try {
      final response = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final tmpPath = '$localPath.tmp';
      final tmpFile = File(tmpPath);
      final sink = tmpFile.openWrite();
      await response.stream.pipe(sink);

      final tmpSize = await tmpFile.length();
      if (tmpSize == 0) {
        _log.warning('download: empty file received, aborting');
        await tmpFile.delete();
        return;
      }

      final localFile = File(localPath);
      if (localFile.existsSync()) await localFile.delete();
      await tmpFile.rename(localPath);

      await AppSettings.set('lastSyncTime', DateTime.now().toIso8601String());
      _log.info('download: replaced local DB ($tmpSize bytes)');
    } catch (e) {
      final tmpFile = File('$localPath.tmp');
      if (tmpFile.existsSync()) await tmpFile.delete();
      _log.severe('download failed: $e');
      rethrow;
    }
  }

  Future<DateTime?> get lastSyncTime async {
    final s = await AppSettings.get('lastSyncTime');
    return s != null ? DateTime.tryParse(s) : null;
  }
}
