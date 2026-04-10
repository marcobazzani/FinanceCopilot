import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the build identifier (short git SHA or local timestamp) produced
/// by `scripts/write_build_info.dart` during the build.
///
/// **Desktop (macOS/Windows/Linux)**: reads a plain text file from the
///   compiled app bundle — written post-build by the deploy script.
///   - macOS: `<FinanceCopilot.app>/Contents/Resources/build_info.txt`
///   - Windows/Linux: `<exe dir>/data/build_info.txt`
///
/// **Android**: reads via a platform-channel that calls
///   `applicationContext.assets.open("build_info.txt")` on the native side.
///   The file is written to `android/app/src/main/assets/` before
///   `flutter build apk` runs so Gradle bundles it into the APK.
///
/// Hard-capped at 16 characters regardless of source.
class BuildInfoService {
  static const _maxLen = 16;
  static const _channel = MethodChannel('app/build_info');

  static String _cached = '';
  static bool _loaded = false;

  /// Cached value after [load]. Empty string until [load] completes.
  static String get value => _cached;

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      String raw;
      if (Platform.isAndroid) {
        raw = (await _channel.invokeMethod<String>('get')) ?? '';
      } else {
        raw = _readDesktop();
      }
      raw = raw.trim();
      if (raw.length > _maxLen) raw = raw.substring(0, _maxLen);
      _cached = raw;
    } catch (_) {
      _cached = '';
    }
  }

  static String _readDesktop() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final path = Platform.isMacOS
        // exe lives in `.app/Contents/MacOS/FinanceCopilot`; Resources is a sibling of MacOS/
        ? '$exeDir/../Resources/build_info.txt'
        // Windows/Linux: `data/` sits next to the exe
        : '$exeDir${Platform.pathSeparator}data${Platform.pathSeparator}build_info.txt';
    final f = File(path);
    return f.existsSync() ? f.readAsStringSync() : '';
  }
}
