// The automatic backup checks: at start, every interval, and when the app
// comes back to the foreground, but not twice within the gap, and never
// while offline.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/services/sync/backup_check_scheduler.dart';

void main() {
  late int checks;
  late DateTime now;
  late bool online;

  BackupCheckScheduler scheduler({Future<void> Function()? check}) => BackupCheckScheduler(
    check: check ?? () async => checks++,
    online: () => online,
    now: () => now,
  );

  setUp(() {
    checks = 0;
    now = DateTime(2026, 10, 28, 9);
    online = true;
  });

  void resume(WidgetTester tester) {
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }

  testWidgets('checks at once, then every interval, until disposed', (tester) async {
    final s = scheduler()..start();
    expect(checks, 1);
    expect(s.isRunning, isTrue);

    s.start();
    expect(checks, 1, reason: 'starting again does nothing');

    await tester.pump(const Duration(minutes: 15));
    expect(checks, 2);

    s.dispose();
    expect(s.isRunning, isFalse);
    await tester.pump(const Duration(minutes: 30));
    expect(checks, 2);
  });

  testWidgets('back in the foreground: checks again, once the gap has passed', (tester) async {
    final s = scheduler()..start();
    try {
      expect(checks, 1);

      now = now.add(const Duration(minutes: 1));
      resume(tester);
      expect(checks, 1, reason: 'too soon after the last check');

      now = now.add(const Duration(minutes: 2));
      resume(tester);
      expect(checks, 2);
    } finally {
      s.dispose();
    }
  });

  testWidgets('offline: no check', (tester) async {
    online = false;
    final s = scheduler()..start();
    try {
      s.runNow();
      expect(checks, 0);
    } finally {
      s.dispose();
    }
  });

  testWidgets('a failing check is logged, not thrown', (tester) async {
    final s = scheduler(check: () async => throw StateError('lookup failed'))..start();
    try {
      await tester.pump();
      expect(tester.takeException(), isNull);
    } finally {
      s.dispose();
    }
  });
}
