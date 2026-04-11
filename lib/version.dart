import 'services/build_info_service.dart';

const appVersion = '0.4.4';
const appChannel = String.fromEnvironment('CHANNEL', defaultValue: 'nightly');

/// Build identifier loaded at startup by [BuildInfoService.load].
/// Either a git short SHA (clean checkout) or a timestamp (dirty / no git).
/// Hard-capped at 16 characters by the service.
///
/// Empty string until `BuildInfoService.load()` has been awaited in `main()`.
String get appCommit => BuildInfoService.value;
