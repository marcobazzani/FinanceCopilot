const appVersion = '0.4.2';
const _commitSha = String.fromEnvironment('COMMIT_SHA');
const appCommit = _commitSha.length > 0 ? _commitSha : _buildTimestamp;
const appChannel = String.fromEnvironment('CHANNEL', defaultValue: 'nightly');

/// Filled at build time via --dart-define; falls back to empty string for CI builds.
const _buildTimestamp = String.fromEnvironment('BUILD_TS');

/// Whether this is a local (non-CI) build.
bool get isLocalBuild => _commitSha.isEmpty;
