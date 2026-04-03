import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

IOSink? _logSink;
String? logFilePath;

/// Initialize logging for the whole app. Call once in main().
/// Logs to `<app documents>`/FinanceCopilot/app.log (sandbox-safe)
/// and also to stderr for debug console visibility.
Future<void> initLogging() async {
  Logger.root.level = Level.ALL;

  // Open log file inside the app's sandboxed documents directory
  try {
    final docsDir = await getApplicationDocumentsDirectory();
    final logDir = Directory(p.join(docsDir.path, 'FinanceCopilot'));
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

  // Suppress repeated identical messages
  String? lastMsg;
  int repeatCount = 0;
  int lineCount = 0;

  Logger.root.onRecord.listen((record) {
    final level = switch (record.level) {
      Level.SEVERE => 'ERROR',
      Level.WARNING => 'WARN ',
      Level.INFO => 'INFO ',
      Level.FINE || Level.FINER || Level.FINEST => 'DEBUG',
      _ => record.level.name,
    };
    final ts = record.time.toIso8601String().substring(11, 23);
    final msg = '$ts $level [${record.loggerName}] ${record.message}';

    // Suppress repeated messages (e.g. network errors during suspend)
    final dedupKey = '${record.loggerName}:${record.message}';
    if (dedupKey == lastMsg) {
      repeatCount++;
      if (repeatCount == 5) {
        final suppressed = '$ts WARN  [Logger] Suppressing repeated: ${record.message.length > 60 ? record.message.substring(0, 60) : record.message}...';
        _logSink?.writeln(suppressed);
        stderr.writeln(suppressed);
      }
      if (repeatCount >= 5) return; // suppress after 5 repeats
    } else {
      if (repeatCount > 5) {
        final note = '$ts INFO  [Logger] (suppressed ${repeatCount - 5} repeats)';
        _logSink?.writeln(note);
      }
      lastMsg = dedupKey;
      repeatCount = 0;
    }

    final fullMsg = record.error != null ? '$msg\n  Error: ${record.error}' : msg;
    // Skip stack traces for warnings (DioException etc.) — just the message
    final withStack = record.stackTrace != null && record.level >= Level.SEVERE
        ? '$fullMsg\n  ${record.stackTrace}' : fullMsg;

    _logSink?.writeln(withStack);
    stderr.writeln(withStack);

    // Periodic rotation check (every 10000 lines)
    lineCount++;
    if (lineCount % 10000 == 0 && logFilePath != null) {
      final logFile = File(logFilePath!);
      if (logFile.existsSync() && logFile.lengthSync() > 10 * 1024 * 1024) {
        _logSink?.flush();
        _logSink?.close();
        final backup = File('${logFilePath!}.1');
        if (backup.existsSync()) backup.deleteSync();
        logFile.renameSync(backup.path);
        _logSink = logFile.openWrite(mode: FileMode.append);
        _logSink!.writeln('--- Log rotated at ${DateTime.now().toIso8601String()} ---');
      }
    }
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
