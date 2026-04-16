/// CI rewrites this constant from the tag name before building a release.
/// Local/dev builds keep "0.0.0-dev" — do not bump this by hand.
const appVersion = '0.0.0-dev';
const appChannel = String.fromEnvironment('CHANNEL', defaultValue: 'nightly');

/// Display version: "0.4.4" for stable releases, "0.4.4-dev" for nightly/local.
String get appVersionDisplay => appChannel == 'stable' ? appVersion : '$appVersion-dev';
