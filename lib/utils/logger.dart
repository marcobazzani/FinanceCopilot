import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

RotatingLogFile? _logFile;
String? logFilePath;

/// The app log file: appends lines and, on request, moves the file aside to
/// `<path>.1` once it has grown past a size limit.
///
/// Rotation is asynchronous: the sink must be flushed and closed before the
/// file can be renamed (Windows refuses to rename an open file, and an IOSink
/// rejects both close() and writes while a flush is pending). Lines written
/// meanwhile are held back and appended, in order, to the fresh file.
@visibleForTesting
class RotatingLogFile {
  RotatingLogFile(this.path) : _sink = File(path).openWrite(mode: FileMode.append);

  final String path;
  IOSink _sink;

  /// Lines logged while a rotation is in flight; null otherwise.
  List<String>? _held;
  Future<void>? _rotation;

  void writeln(String line) {
    final held = _held;
    if (held != null) {
      held.add(line);
    } else {
      _sink.writeln(line);
    }
  }

  /// Rotate when the file on disk is larger than [maxBytes]. A rotation
  /// already in flight is joined rather than started twice.
  Future<void> rotateIfLargerThan(int maxBytes) {
    final inFlight = _rotation;
    if (inFlight != null) return inFlight;
    final logFile = File(path);
    if (!logFile.existsSync() || logFile.lengthSync() <= maxBytes) return Future.value();
    return _rotation = _rotate().whenComplete(() => _rotation = null);
  }

  Future<void> _rotate() async {
    final held = _held = <String>[];
    var rotated = false;
    try {
      await _sink.flush();
      await _sink.close();
      final backup = File('$path.1');
      if (backup.existsSync()) backup.deleteSync();
      File(path).renameSync(backup.path);
      rotated = true;
    } catch (e) {
      // Keep appending to the current file rather than losing lines.
      _debugLog('Log rotation failed: $e');
    }
    _sink = File(path).openWrite(mode: FileMode.append);
    if (rotated) _sink.writeln('--- Log rotated at ${DateTime.now().toIso8601String()} ---');
    _held = null;
    for (final line in held) {
      _sink.writeln(line);
    }
  }

  /// Flush and close the file, after any rotation in flight.
  Future<void> close() async {
    await _rotation;
    await _sink.flush();
    await _sink.close();
  }
}

/// Resolve the configured minimum log level from `--dart-define=LOG_LEVEL`.
/// Defaults to INFO. DEBUG/TRACE map to FINE/FINEST; ALL captures everything.
Level _configuredLevel() {
  const raw = String.fromEnvironment('LOG_LEVEL', defaultValue: 'INFO');
  final v = raw.trim().toUpperCase();
  switch (v) {
    case 'ALL':
      return Level.ALL;
    case 'TRACE':
    case 'FINEST':
      return Level.FINEST;
    case 'FINER':
      return Level.FINER;
    case 'DEBUG':
    case 'FINE':
      return Level.FINE;
    case 'INFO':
      return Level.INFO;
    case 'WARNING':
    case 'WARN':
      return Level.WARNING;
    case 'SEVERE':
    case 'ERROR':
      return Level.SEVERE;
    default:
      return Level.INFO;
  }
}

/// Write a log line to the debug console (logcat on Android, Xcode on iOS, stderr on desktop).
void _debugLog(String msg) {
  if (Platform.isAndroid || Platform.isIOS) {
    debugPrint(msg);
  } else {
    stderr.writeln(msg);
  }
}

/// Initialize logging for the whole app. Call once in main().
/// Logs to `<app documents>`/FinanceCopilot/app.log (sandbox-safe)
/// and also to stderr for debug console visibility.
///
/// The minimum captured level is controlled by `--dart-define=LOG_LEVEL=...`
/// (INFO by default; set to FINE/DEBUG/ALL to capture DEBUG diagnostics like
/// the import column-mapping dump). Accepts both Dart level names (FINE,
/// FINER, FINEST, INFO, …) and the friendly aliases DEBUG/TRACE/ALL.
Future<void> initLogging() async {
  Logger.root.level = _configuredLevel();

  // Open log file inside the app's Application Support directory
  try {
    final appDir = await getApplicationSupportDirectory();
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    final logFile = File(p.join(appDir.path, 'app.log'));
    logFilePath = logFile.path;

    // Session rotation: save previous session log for bug reports
    if (await logFile.exists()) {
      final prevSession = File(p.join(appDir.path, 'previous_session.log'));
      try {
        if (await prevSession.exists()) await prevSession.delete();
        await logFile.copy(prevSession.path);
      } catch (_) {}
      // Size-based rotation: if > 5MB, truncate
      if (await logFile.length() > 5 * 1024 * 1024) {
        await logFile.delete();
      }
    }

    final sessionLog = _logFile = RotatingLogFile(logFile.path);
    sessionLog.writeln('\n--- App started at ${DateTime.now().toIso8601String()} ---');
  } catch (e) {
    _debugLog('Failed to open log file: $e');
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
        final suppressed =
            '$ts WARN  [Logger] Suppressing repeated: ${record.message.length > 60 ? record.message.substring(0, 60) : record.message}...';
        _logFile?.writeln(suppressed);
        _debugLog(suppressed);
      }
      if (repeatCount >= 5) return; // suppress after 5 repeats
    } else {
      if (repeatCount > 5) {
        final note = '$ts INFO  [Logger] (suppressed ${repeatCount - 5} repeats)';
        _logFile?.writeln(note);
      }
      lastMsg = dedupKey;
      repeatCount = 0;
    }

    final fullMsg = record.error != null ? '$msg\n  Error: ${record.error}' : msg;
    // Skip stack traces for warnings (DioException etc.) — just the message
    final withStack = record.stackTrace != null && record.level >= Level.SEVERE ? '$fullMsg\n  ${record.stackTrace}' : fullMsg;

    _logFile?.writeln(withStack);
    _debugLog(withStack);
    developer.log(record.message, name: record.loggerName, level: record.level.value);

    // Periodic rotation check (every 10000 lines). Not awaited: a log call
    // never waits on the file; lines logged meanwhile are held and replayed.
    lineCount++;
    if (lineCount % 10000 == 0) {
      unawaited(_logFile?.rotateIfLargerThan(10 * 1024 * 1024));
    }
  });
}

/// Create a named logger. Usage: `final _log = getLogger('MyClass');`
Logger getLogger(String name) => Logger(name);
