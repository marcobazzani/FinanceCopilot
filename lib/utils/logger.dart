import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

IOSink? _logSink;
String? logFilePath;

/// Initialize logging for the whole app. Call once in main().
/// Logs to <app documents>/AssetManager/app.log (sandbox-safe)
/// and also to stderr for debug console visibility.
Future<void> initLogging() async {
  Logger.root.level = Level.ALL;

  // Open log file inside the app's sandboxed documents directory
  try {
    final docsDir = await getApplicationDocumentsDirectory();
    final logDir = Directory(p.join(docsDir.path, 'AssetManager'));
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    final logFile = File(p.join(logDir.path, 'app.log'));
    logFilePath = logFile.path;

    // Rotate: if > 5MB, rename to app.log.1
    if (await logFile.exists() && await logFile.length() > 5 * 1024 * 1024) {
      final backup = File(p.join(logDir.path, 'app.log.1'));
      if (await backup.exists()) await backup.delete();
      await logFile.rename(backup.path);
    }

    _logSink = logFile.openWrite(mode: FileMode.append);
    _logSink!.writeln('\n--- App started at ${DateTime.now().toIso8601String()} ---');
  } catch (e) {
    stderr.writeln('Failed to open log file: $e');
  }

  Logger.root.onRecord.listen((record) {
    final level = switch (record.level) {
      Level.SEVERE => 'ERROR',
      Level.WARNING => 'WARN ',
      Level.INFO => 'INFO ',
      Level.FINE || Level.FINER || Level.FINEST => 'DEBUG',
      _ => record.level.name,
    };
    final ts = record.time.toIso8601String().substring(11, 23); // HH:mm:ss.SSS
    final msg = '$ts $level [${record.loggerName}] ${record.message}';
    final fullMsg = record.error != null ? '$msg\n  Error: ${record.error}' : msg;
    final withStack = record.stackTrace != null ? '$fullMsg\n  ${record.stackTrace}' : fullMsg;

    // Write to file
    _logSink?.writeln(withStack);

    // Also write to stderr (visible in flutter run / debug console)
    stderr.writeln(withStack);
  });
}

/// Flush and close the log file. Call on app shutdown if needed.
Future<void> closeLogging() async {
  await _logSink?.flush();
  await _logSink?.close();
  _logSink = null;
}

/// Create a named logger. Usage: `final _log = getLogger('MyClass');`
Logger getLogger(String name) => Logger(name);
