// Pinned bug: log rotation called `flush()` and then `close()` on the log
// sink without awaiting either. Closing an IOSink while its flush is still
// pending throws "StreamSink is bound to a stream", so rotation blew up inside
// the logging listener; lines logged meanwhile could be lost, and renaming the
// still-open file fails on Windows. Rotation now awaits flush + close and
// holds back the lines logged while it runs, appending them to the new file.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:finance_copilot/utils/logger.dart';

void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fc_log_rotation_');
    path = p.join(dir.path, 'app.log');
  });
  tearDown(() => dir.delete(recursive: true));

  List<String> lines(String prefix) => [for (var i = 0; i < 20; i++) '$prefix $i'];

  test('lines logged while the file rotates are all kept, in order', () async {
    // A log already past the limit, as after a long session.
    final old = 'x' * 200;
    File(path).writeAsStringSync('$old\n');
    final log = RotatingLogFile(path);

    lines('before').forEach(log.writeln);
    final rotation = log.rotateIfLargerThan(100);
    // Records keep arriving while the old file is flushed and closed.
    lines('during').forEach(log.writeln);
    await rotation;
    lines('after').forEach(log.writeln);
    await log.close();

    expect(File('$path.1').readAsLinesSync(), [old, ...lines('before')]);
    final current = File(path).readAsLinesSync();
    expect(current.first, startsWith('--- Log rotated at '));
    expect(current.skip(1), [...lines('during'), ...lines('after')]);
  });

  test('a file under the limit is left in place', () async {
    final log = RotatingLogFile(path);
    lines('before').forEach(log.writeln);
    await log.rotateIfLargerThan(1 << 20);
    lines('after').forEach(log.writeln);
    await log.close();

    expect(File('$path.1').existsSync(), isFalse);
    expect(File(path).readAsLinesSync(), [...lines('before'), ...lines('after')]);
  });
}
