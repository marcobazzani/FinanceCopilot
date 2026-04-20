const _rawDbFileName = String.fromEnvironment('DB_FILE_NAME');

/// Filename used for both the local DB file (in getApplicationSupportDirectory)
/// and the Google Drive backup (in appDataFolder). Injected at build time via
/// `--dart-define=DB_FILE_NAME=<name>`; hard-fails if the define is missing so
/// a dev build can never accidentally read or clobber the production DB.
String get dbFileName {
  if (_rawDbFileName.isEmpty) {
    throw StateError(
      'DB_FILE_NAME dart-define is required. '
      'Pass --dart-define=DB_FILE_NAME=<name> to flutter build/test/run. '
      'See CLAUDE.md for per-channel values.',
    );
  }
  return _rawDbFileName;
}
