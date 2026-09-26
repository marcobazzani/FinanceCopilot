import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;

/// UUIDv7: 48-bit Unix-ms timestamp + 12-bit sequence + 62-bit random.
/// Time-ordered for cross-device merge stability without a new dependency.
class UuidV7 {
  UuidV7._();

  static final Random _rng = Random.secure();
  static int _lastMs = 0;
  static int _seq = 0;

  static String generate() => generateAt(DateTime.now().millisecondsSinceEpoch);

  /// [generate] for an explicit wall-clock reading, so tests can freeze the
  /// clock or step it back instead of racing real time.
  @visibleForTesting
  static String generateAt(int clockMs) {
    var nowMs = clockMs;
    if (nowMs <= _lastMs) {
      // Same millisecond as the last id — or the clock reads earlier than it
      // (a sequence overflow moved the last id ahead, or the wall clock
      // stepped back): stay on the last timestamp and count up, so ids always
      // sort in creation order.
      nowMs = _lastMs;
      _seq = (_seq + 1) & 0xfff;
      if (_seq == 0) {
        // Sequence exhausted for this millisecond: move on to the next one.
        nowMs = _lastMs + 1;
      }
    } else {
      _seq = _rng.nextInt(0x1000);
    }
    _lastMs = nowMs;

    final tsHigh = (nowMs >> 16) & 0xffffffff;
    final tsLow = nowMs & 0xffff;
    final verAndSeq = 0x7000 | _seq; // version 7
    final r1 = _rng.nextInt(0x10000);
    final r2 = _rng.nextInt(0x10000);
    final r3 = _rng.nextInt(0x10000);
    final r4 = _rng.nextInt(0x10000);
    final variantAndR1 = (0x8000 | (r1 & 0x3fff)); // RFC 4122 variant 10xx

    String h(int v, int width) => v.toRadixString(16).padLeft(width, '0');

    return '${h(tsHigh, 8)}-${h(tsLow, 4)}-${h(verAndSeq, 4)}-${h(variantAndR1, 4)}-${h(r2, 4)}${h(r3, 4)}${h(r4, 4)}';
  }
}
