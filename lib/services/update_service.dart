import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../utils/logger.dart';
import '../version.dart';

final _log = getLogger('UpdateService');

/// Result of an update check.
class UpdateInfo {
  final bool available;
  final String? latestVersion;
  final String? latestCommit;
  final String? downloadUrl;
  final String? releaseUrl;
  final String? releaseNotes;

  const UpdateInfo({
    this.available = false,
    this.latestVersion,
    this.latestCommit,
    this.downloadUrl,
    this.releaseUrl,
    this.releaseNotes,
  });
}

class UpdateService {
  static const _apiBase = 'https://api.github.com/repos/marcobazzani/FinanceCopilot/releases';
  final Dio _dio;

  UpdateService({Dio? dio}) : _dio = dio ?? Dio();

  /// Check for updates based on the configured channel.
  Future<UpdateInfo> checkForUpdate(String channel) async {
    try {
      return channel == 'nightly' ? await _checkNightly() : await _checkStable();
    } catch (e) {
      _log.warning('checkForUpdate: failed - $e');
      return const UpdateInfo();
    }
  }

  Future<UpdateInfo> _checkNightly() async {
    _log.info('checkNightly: current commit=$appCommit');
    final response = await _dio.get(
      '$_apiBase/tags/latest',
      options: Options(headers: {'Accept': 'application/vnd.github+json'}),
    );
    final data = response.data as Map<String, dynamic>;
    final notes = (data['body'] as String?) ?? '';
    final tagName = (data['tag_name'] as String?) ?? '';

    final commitMatch = RegExp(r'Commit:\s*([a-f0-9]{40})').firstMatch(notes);
    final latestCommit = commitMatch?.group(1);
    if (latestCommit == null) return const UpdateInfo();

    final isNew = appCommit == 'dev' || !latestCommit.startsWith(appCommit);
    _log.info('checkNightly: latest=$latestCommit, current=$appCommit, update=$isNew');
    if (!isNew) return const UpdateInfo();

    return UpdateInfo(
      available: true,
      latestVersion: tagName,
      latestCommit: latestCommit,
      downloadUrl: _findPlatformAsset(data['assets'] as List?),
      releaseUrl: data['html_url'] as String?,
      releaseNotes: notes,
    );
  }

  Future<UpdateInfo> _checkStable() async {
    _log.info('checkStable: current version=$appVersion');
    final response = await _dio.get(
      _apiBase,
      queryParameters: {'per_page': 10},
      options: Options(headers: {'Accept': 'application/vnd.github+json'}),
    );
    for (final r in (response.data as List)) {
      final release = r as Map<String, dynamic>;
      if (release['prerelease'] == true || release['draft'] == true) continue;

      final tagName = (release['tag_name'] as String?) ?? '';
      final versionStr = tagName.startsWith('v') ? tagName.substring(1) : tagName;

      if (_isNewerVersion(versionStr, appVersion)) {
        _log.info('checkStable: found $tagName (current: $appVersion)');
        return UpdateInfo(
          available: true,
          latestVersion: tagName,
          downloadUrl: _findPlatformAsset(release['assets'] as List?),
          releaseUrl: release['html_url'] as String?,
          releaseNotes: release['body'] as String?,
        );
      }
    }
    _log.info('checkStable: up to date');
    return const UpdateInfo();
  }

  /// Fetch commit titles between current commit and latest.
  Future<List<String>> getChangelog(String? latestCommit) async {
    if (appCommit == 'dev' || latestCommit == null) return [];
    try {
      final response = await _dio.get(
        'https://api.github.com/repos/marcobazzani/FinanceCopilot/compare/$appCommit...$latestCommit',
        options: Options(headers: {'Accept': 'application/vnd.github+json'}),
      );
      final commits = (response.data as Map<String, dynamic>)['commits'] as List? ?? [];
      return commits.map((c) {
        final msg = ((c as Map)['commit'] as Map)['message'] as String? ?? '';
        return msg.split('\n').first; // first line only
      }).toList();
    } catch (e) {
      _log.warning('getChangelog: failed - $e');
      return [];
    }
  }

  /// Download, extract, replace current app, and restart.
  Future<void> applyUpdate(UpdateInfo info, {void Function(double)? onProgress}) async {
    if (info.downloadUrl == null) throw StateError('No download URL');

    final tempDir = Directory.systemTemp.createTempSync('fc_update_');
    try {
      // Download
      final fileName = info.downloadUrl!.split('/').last;
      final downloadPath = p.join(tempDir.path, fileName);
      _log.info('applyUpdate: downloading $fileName...');
      await _dio.download(
        info.downloadUrl!,
        downloadPath,
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress?.call(received / total);
        },
      );

      if (Platform.isMacOS) {
        await _applyMacOS(downloadPath, tempDir.path);
      } else if (Platform.isWindows) {
        await _applyWindows(downloadPath, tempDir.path);
      } else {
        throw UnsupportedError('Auto-update not supported on this platform');
      }
    } catch (e) {
      _log.severe('applyUpdate: failed - $e');
      rethrow;
    }
    // tempDir cleanup happens on next launch or OS cleanup
  }

  /// macOS: mount DMG, copy .app over current, restart.
  Future<void> _applyMacOS(String dmgPath, String tempDir) async {
    final mountPoint = p.join(tempDir, 'mnt');
    await Directory(mountPoint).create();

    // Mount DMG
    _log.info('applyUpdate macOS: mounting DMG...');
    var result = await Process.run('hdiutil', ['attach', dmgPath, '-mountpoint', mountPoint, '-nobrowse', '-quiet']);
    if (result.exitCode != 0) throw StateError('Failed to mount DMG: ${result.stderr}');

    try {
      // Find the .app inside
      final appDir = Directory(mountPoint).listSync().whereType<Directory>().firstWhere(
        (d) => d.path.endsWith('.app'),
        orElse: () => throw StateError('No .app found in DMG'),
      );

      // Get current app path
      final currentApp = _currentAppPath();
      _log.info('applyUpdate macOS: replacing $currentApp...');

      // Remove old and copy new
      await Process.run('rm', ['-rf', currentApp]);
      result = await Process.run('cp', ['-R', appDir.path, currentApp]);
      if (result.exitCode != 0) throw StateError('Failed to copy app: ${result.stderr}');

      // Re-sign ad-hoc (required for macOS to launch)
      await Process.run('codesign', ['--force', '--deep', '--sign', '-', currentApp]);
    } finally {
      // Unmount
      await Process.run('hdiutil', ['detach', mountPoint, '-quiet']);
    }

    // Restart
    _log.info('applyUpdate macOS: restarting...');
    final currentApp = _currentAppPath();
    await Process.start('open', ['-n', currentApp], mode: ProcessStartMode.detached);
    exit(0);
  }

  /// Windows: extract ZIP, replace files via hidden PowerShell script, restart.
  Future<void> _applyWindows(String zipPath, String tempDir) async {
    final extractDir = p.join(tempDir, 'extracted');
    await Directory(extractDir).create();

    // Extract ZIP using PowerShell
    _log.info('applyUpdate Windows: extracting ZIP...');
    var result = await Process.run('powershell', [
      '-Command',
      'Expand-Archive -Path "$zipPath" -DestinationPath "$extractDir" -Force',
    ]);
    if (result.exitCode != 0) throw StateError('Failed to extract ZIP: ${result.stderr}');

    // Current exe directory
    final currentDir = p.dirname(Platform.resolvedExecutable);
    final currentExe = Platform.resolvedExecutable;
    final scriptPath = p.join(tempDir, 'update.ps1');

    // Write a PowerShell script that waits for this process to exit, copies files, and relaunches
    _log.info('applyUpdate Windows: writing update script...');
    final currentPid = pid;
    final ps1 = '''
# Wait for this specific process to exit
try { Wait-Process -Id $currentPid -ErrorAction SilentlyContinue } catch {}
# Copy new files over the old ones
Copy-Item -Path "$extractDir\\*" -Destination "$currentDir\\" -Recurse -Force
# Relaunch the app
Start-Process "$currentExe"
# Clean up this script
Remove-Item -Path \$MyInvocation.MyCommand.Source -Force
''';
    await File(scriptPath).writeAsString(ps1);

    // Launch PowerShell hidden and exit
    _log.info('applyUpdate Windows: launching update script and exiting...');
    await Process.start(
      'powershell',
      ['-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass', '-File', scriptPath],
      mode: ProcessStartMode.detached,
    );
    exit(0);
  }

  /// Get the current .app bundle path on macOS.
  String _currentAppPath() {
    // Platform.resolvedExecutable is like:
    // /path/to/FinanceCopilot.app/Contents/MacOS/FinanceCopilot
    final exe = Platform.resolvedExecutable;
    final parts = exe.split('/');
    final appIdx = parts.lastIndexWhere((p) => p.endsWith('.app'));
    if (appIdx < 0) throw StateError('Cannot determine .app path from $exe');
    return parts.sublist(0, appIdx + 1).join('/');
  }

  String? _findPlatformAsset(List? assets) {
    if (assets == null) return null;
    final key = Platform.isMacOS ? 'macos' : Platform.isWindows ? 'windows' : null;
    if (key == null) return null;
    for (final a in assets) {
      final name = ((a as Map)['name'] as String?) ?? '';
      if (name.toLowerCase().contains(key)) return a['browser_download_url'] as String?;
    }
    return null;
  }

  bool _isNewerVersion(String candidate, String current) {
    final cParts = candidate.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final curParts = current.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final c = i < cParts.length ? cParts[i] : 0;
      final cur = i < curParts.length ? curParts[i] : 0;
      if (c > cur) return true;
      if (c < cur) return false;
    }
    return false;
  }
}
