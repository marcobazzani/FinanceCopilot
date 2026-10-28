import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:finance_copilot/utils/logger.dart';

final _log = getLogger('BackupCheckScheduler');

/// Runs the backup check on its own: once when started, whenever the app
/// comes back to the foreground (at most every [resumeGap]), and every
/// [interval] while it runs. Skipped while offline.
class BackupCheckScheduler {
  BackupCheckScheduler({
    required Future<void> Function() check,
    required bool Function() online,
    this.interval = const Duration(minutes: 15),
    this.resumeGap = const Duration(minutes: 2),
    DateTime Function()? now,
  }) : _check = check,
       _online = online,
       _now = now ?? DateTime.now;

  final Duration interval;
  final Duration resumeGap;
  final Future<void> Function() _check;
  final bool Function() _online;
  final DateTime Function() _now;

  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  DateTime? _lastRun;

  bool get isRunning => _timer != null;

  /// Starts checking, with a first check right away. Starting again does
  /// nothing.
  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(interval, (_) => runNow());
    _lifecycle = AppLifecycleListener(onResume: _resumed);
    runNow();
  }

  /// Checks now, unless offline.
  void runNow() {
    if (!_online()) return;
    _lastRun = _now();
    unawaited(_check().then((_) {}, onError: (Object e, StackTrace st) => _log.warning('Backup check failed', e, st)));
  }

  void _resumed() {
    final last = _lastRun;
    if (last == null || _now().difference(last) >= resumeGap) runNow();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }
}
