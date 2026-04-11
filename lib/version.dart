const appVersion = '0.5.0';
const appChannel = String.fromEnvironment('CHANNEL', defaultValue: 'nightly');

/// Display version: "0.4.4" for stable releases, "0.4.4-dev" for nightly/local.
String get appVersionDisplay => appChannel == 'stable' ? appVersion : '$appVersion-dev';
