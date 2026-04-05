import 'dart:async';
import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/logger.dart';
import 'app_settings.dart';

final _log = getLogger('GoogleDriveSync');

const _driveScope = 'https://www.googleapis.com/auth/drive.appdata';
const _dbFileName = 'finance_copilot.db';

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
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [_driveScope],
    // Desktop (macOS/Windows) requires explicit clientId; Android uses Info.plist/google-services.json
    clientId: Platform.isMacOS || Platform.isWindows || Platform.isLinux
        ? '975988851156-vgpd3o05ifs51nar6chu3vv42876d01m.apps.googleusercontent.com'
        : null,
  );
  drive.DriveApi? _driveApi;
  Timer? _debounceTimer;
  bool _uploading = false;
  bool _syncing = false;
  StreamSubscription? _tableUpdateSub;

  // Device identification for conflict detection
  late final String _deviceId;

  GoogleDriveSyncService() {
    _deviceId = _computeDeviceId();
  }

  String _computeDeviceId() {
    // Use platform + hostname as a stable device identifier
    final host = Platform.localHostname;
    final os = Platform.operatingSystem;
    return '$os-$host';
  }

  // ── Auth ──────────────────────────────────────────

  bool get isSignedIn => _googleSignIn.currentUser != null && _driveApi != null;

  String? get userEmail => _googleSignIn.currentUser?.email;

  /// Try to restore a previous sign-in session silently.
  Future<bool> trySilentSignIn() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) return false;
      return await _initDriveApi();
    } catch (e) {
      _log.warning('trySilentSignIn failed: $e');
      return false;
    }
  }

  /// Interactive sign-in (opens browser/system UI).
  Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return false; // user cancelled
      return await _initDriveApi();
    } catch (e) {
      _log.severe('signIn failed: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    stopAutoSync();
    await _googleSignIn.signOut();
    _driveApi = null;
    _log.info('Signed out');
  }

  Future<bool> _initDriveApi() async {
    try {
      final httpClient = await _googleSignIn.authenticatedClient();
      if (httpClient == null) return false;
      _driveApi = drive.DriveApi(httpClient);
      _log.info('Drive API initialized for ${_googleSignIn.currentUser?.email}');
      return true;
    } catch (e) {
      _log.severe('Failed to init Drive API: $e');
      return false;
    }
  }

  // ── Sync ──────────────────────────────────────────

  /// Get the internal DB file path.
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
  /// Call this on startup BEFORE showing UI.
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
        // If local has dirty flag, push now
        final dirty = await AppSettings.get('syncDirty');
        if (dirty == 'true' && localFile.existsSync()) {
          await _upload(localPath);
        }
        return false;
      }

      _log.info('pullIfNewer: local=${localMtime.toIso8601String()} remote=${remote.modifiedTime.toIso8601String()} remoteDevice=${remote.deviceId}');

      // Check for conflict: remote was modified by different device AND we have local unsaved changes
      final dirty = await AppSettings.get('syncDirty');
      if (dirty == 'true' && remote.deviceId != _deviceId && remote.modifiedTime.isAfter(localMtime)) {
        // Conflict — caller should show dialog. For now, prefer remote (last-write-wins).
        _log.warning('pullIfNewer: CONFLICT detected - remote from ${remote.deviceName}, local dirty. Using remote.');
      }

      if (remote.modifiedTime.isAfter(localMtime)) {
        _log.info('pullIfNewer: remote is newer, downloading...');
        await _download(localPath, remote.fileId);
        await AppSettings.set('syncDirty', 'false');
        return true;
      } else {
        _log.info('pullIfNewer: local is current');
        // If local is dirty, push to Drive
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
    AppSettings.set('syncDirty', 'true');
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 10), () {
      if (!_uploading && !_syncing && _driveApi != null) {
        _localDbPath.then((path) => _upload(path));
      }
    });
  }

  // ── Upload / Download ─────────────────────────────

  Future<void> _upload(String localPath) async {
    if (_driveApi == null || _uploading) return;
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

      // Check if file already exists on Drive
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
      // Keep dirty flag so we retry later
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

      // Write to temp file first (atomic)
      final tmpPath = '$localPath.tmp';
      final tmpFile = File(tmpPath);
      final sink = tmpFile.openWrite();
      await response.stream.pipe(sink);

      // Verify temp file is valid
      final tmpSize = await tmpFile.length();
      if (tmpSize == 0) {
        _log.warning('download: empty file received, aborting');
        await tmpFile.delete();
        return;
      }

      // Atomic replace: rename tmp over local
      final localFile = File(localPath);
      if (localFile.existsSync()) await localFile.delete();
      await tmpFile.rename(localPath);

      await AppSettings.set('lastSyncTime', DateTime.now().toIso8601String());
      _log.info('download: replaced local DB ($tmpSize bytes)');
    } catch (e) {
      // Clean up temp file on failure
      final tmpFile = File('$localPath.tmp');
      if (tmpFile.existsSync()) await tmpFile.delete();
      _log.severe('download failed: $e');
      rethrow;
    }
  }

  /// Get the last sync timestamp (for display in settings).
  Future<DateTime?> get lastSyncTime async {
    final s = await AppSettings.get('lastSyncTime');
    return s != null ? DateTime.tryParse(s) : null;
  }
}
