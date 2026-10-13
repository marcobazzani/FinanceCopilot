const _rawDbFileName = String.fromEnvironment('DB_FILE_NAME');

/// Filename used for both the local DB file (in getApplicationSupportDirectory)
/// and the Google Drive backup (in appDataFolder). Injected at build time via
/// `--dart-define=DB_FILE_NAME=<name>`; hard-fails if the define is missing so
/// a dev build can never accidentally read or clobber the production DB.
String get dbFileName {
  if (_rawDbFileName.isEmpty) {
    throw StateError(
      'DB_FILE_NAME dart-define is required: pass --dart-define=DB_FILE_NAME=<name> '
      'to flutter build/test/run - finance_copilot.db for release builds, '
      'finance_copilot_dev.db for local builds, finance_copilot_test.db for tests.',
    );
  }
  return _rawDbFileName;
}
