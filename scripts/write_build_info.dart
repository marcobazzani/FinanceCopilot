// Generates and places the build identifier for the current build.
//
// The identifier is either the git short SHA (clean working tree) or a local
// timestamp (`yyyymmdd_hhmmss`) fallback. Hard-capped at 16 characters.
//
// Destination depends on the target platform:
//   - android : writes android/app/src/main/assets/build_info.txt (PRE-build,
//               Gradle bundles it into the APK via Android's native asset system)
//   - macos   : writes build/macos/Build/Products/Release/FinanceCopilot.app/
//               Contents/Resources/build_info.txt (POST-build)
//   - windows : writes build/windows/x64/runner/Release/data/build_info.txt
//               (POST-build)
//   - linux   : writes build/linux/x64/release/bundle/data/build_info.txt
//               (POST-build)
//
// The build script for each platform calls this twice where necessary:
//   dart run scripts/write_build_info.dart android   # before `flutter build apk`
//   dart run scripts/write_build_info.dart macos     # after  `flutter build macos`
//   dart run scripts/write_build_info.dart windows   # after  `flutter build windows`
//
// Runs on any platform that has Dart + git (macOS, Linux, Windows).

import 'dart:io';

const _maxLen = 16;

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run scripts/write_build_info.dart <android|macos|windows|linux>');
    exit(2);
  }
  final target = args.first.toLowerCase();

  String id = await _computeId();
  if (id.length > _maxLen) id = id.substring(0, _maxLen);

  final dest = _destinationFor(target);
  if (dest == null) {
    stderr.writeln('unknown target "$target"; expected android|macos|windows|linux');
    exit(2);
  }

  final file = File(dest);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync('$id\n');
  stdout.writeln('build_info [$target]: $id -> $dest');
}

Future<String> _computeId() async {
  if (await _isWorkingTreeClean()) {
    final sha = await _shortSha();
    if (sha.isNotEmpty) return sha;
  }
  return _timestamp();
}

String _timestamp() {
  final now = DateTime.now();
  String p(int n, [int w = 2]) => n.toString().padLeft(w, '0');
  return '${p(now.year, 4)}${p(now.month)}${p(now.day)}_'
      '${p(now.hour)}${p(now.minute)}${p(now.second)}';
}

Future<String> _shortSha() async {
  try {
    final r = await Process.run('git', ['rev-parse', '--short=12', 'HEAD']);
    if (r.exitCode == 0) return (r.stdout as String).trim();
  } catch (_) {}
  return '';
}

Future<bool> _isWorkingTreeClean() async {
  try {
    final r = await Process.run('git', ['diff', '--quiet', 'HEAD']);
    return r.exitCode == 0;
  } catch (_) {
    return false;
  }
}

String? _destinationFor(String target) {
  switch (target) {
    case 'android':
      // Pre-build: Gradle bundles android/app/src/main/assets/ into the APK.
      return 'android/app/src/main/assets/build_info.txt';
    case 'macos':
      // Post-build: write into the compiled .app bundle's Contents/Resources/.
      return 'build/macos/Build/Products/Release/FinanceCopilot.app/Contents/Resources/build_info.txt';
    case 'windows':
      // Post-build: write next to flutter_assets inside the runner's data/ dir.
      return 'build/windows/x64/runner/Release/data/build_info.txt';
    case 'linux':
      return 'build/linux/x64/release/bundle/data/build_info.txt';
  }
  return null;
}
