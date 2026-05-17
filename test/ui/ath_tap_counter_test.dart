// Pure-function tests for the 6-tap easter-easter-egg counter used by
// `_SummaryTotalsTableState._onAthCellTap`. The math lives at top level
// in ath_celebration_overlay.dart so it can be exercised here without
// mounting the dashboard, the Riverpod tree, or a real overlay.

import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/ui/widgets/ath_celebration_overlay.dart';

void main() {
  group('AthTapCounter.next', () {
    final t0 = DateTime(2026, 5, 18, 12, 0, 0);

    test('first tap stores count=1, does not fire', () {
      final out = AthTapCounter.next(null, t0);
      expect(out.fire, isFalse);
      expect(out.state, isNotNull);
      expect(out.state!.count, 1);
      expect(out.state!.last, t0);
    });

    test('5 taps within window do not fire, count climbs', () {
      ({int count, DateTime last})? state;
      for (var i = 0; i < 5; i++) {
        final out = AthTapCounter.next(state, t0.add(Duration(milliseconds: 200 * i)));
        expect(out.fire, isFalse);
        state = out.state;
      }
      expect(state, isNotNull);
      expect(state!.count, 5);
    });

    test('6th rapid tap fires and clears state', () {
      ({int count, DateTime last})? state;
      bool fired = false;
      for (var i = 0; i < 6; i++) {
        final out = AthTapCounter.next(state, t0.add(Duration(milliseconds: 200 * i)));
        if (out.fire) fired = true;
        state = out.state;
      }
      expect(fired, isTrue, reason: 'threshold reached on the 6th tap');
      expect(state, isNull, reason: 'fire returns null state so caller resets');
    });

    test('tap after the window resets the streak', () {
      ({int count, DateTime last})? state;
      // Three fast taps.
      for (var i = 0; i < 3; i++) {
        state = AthTapCounter.next(state, t0.add(Duration(milliseconds: 200 * i))).state;
      }
      expect(state!.count, 3);

      // 4th tap > window (1.5s) after the last → resets to count=1.
      final out = AthTapCounter.next(state, state.last.add(const Duration(milliseconds: 1600)));
      expect(out.fire, isFalse);
      expect(out.state!.count, 1);
    });

    test('tap exactly at the window boundary still counts (≤ window)', () {
      final state = AthTapCounter.next(null, t0).state;
      final boundary = state!.last.add(AthTapCounter.window);
      final out = AthTapCounter.next(state, boundary);
      expect(out.fire, isFalse);
      expect(out.state!.count, 2, reason: 'inclusive boundary keeps the streak');
    });

    test('one tap above the window boundary resets', () {
      final state = AthTapCounter.next(null, t0).state;
      final justOver = state!.last.add(AthTapCounter.window + const Duration(milliseconds: 1));
      final out = AthTapCounter.next(state, justOver);
      expect(out.state!.count, 1);
    });
  });
}
