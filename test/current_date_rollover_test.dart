// Regression: the dashboard's "today's change" got stuck showing yesterday's
// movement when the app was left running past midnight.
//
// Pinned bug: currentDateProvider was a plain Provider that captured
// DateTime.now() on its first read (app startup) and only recomputed when the
// wayback override changed — never when the wall clock crossed midnight. So an
// app open across a day boundary kept treating the previous day as "today":
// the "Today" KPI (change since today-1) then reported the prior day's full
// price movement (e.g. +3227) instead of ~0 just after midnight, and a manual
// refresh (which only bumps priceRefreshCounter) never cleared it.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/services/providers/providers.dart';

void main() {
  test('currentDateProvider rolls over to the new day at midnight without a restart', () {
    fakeAsync((async) {
      var fakeNow = DateTime(2026, 7, 1, 23, 30); // 30 min before midnight
      final container = ProviderContainer(
        overrides: [nowProvider.overrideWithValue(() => fakeNow)],
      );

      // Before midnight: today = Jul 1.
      expect(container.read(currentDateProvider), DateTime(2026, 7, 1));

      // Wall clock advances past midnight; the self-scheduled timer fires.
      fakeNow = DateTime(2026, 7, 2, 0, 0, 30);
      async.elapse(const Duration(minutes: 31));

      // The provider recomputed itself: today is now Jul 2 (no restart needed).
      expect(container.read(currentDateProvider), DateTime(2026, 7, 2));

      container.dispose(); // cancels the pending rollover timer inside the zone
    });
  });

  test('rollover keeps firing across multiple day boundaries', () {
    fakeAsync((async) {
      var fakeNow = DateTime(2026, 7, 1, 12, 0);
      final container = ProviderContainer(
        overrides: [nowProvider.overrideWithValue(() => fakeNow)],
      );

      expect(container.read(currentDateProvider), DateTime(2026, 7, 1));

      fakeNow = DateTime(2026, 7, 2, 12, 0);
      async.elapse(const Duration(days: 1));
      expect(container.read(currentDateProvider), DateTime(2026, 7, 2));

      fakeNow = DateTime(2026, 7, 3, 12, 0);
      async.elapse(const Duration(days: 1));
      expect(container.read(currentDateProvider), DateTime(2026, 7, 3));

      container.dispose();
    });
  });

  test('wayback override pins the date and ignores the wall clock', () {
    fakeAsync((async) {
      var fakeNow = DateTime(2026, 7, 1, 23, 30);
      final container = ProviderContainer(
        overrides: [nowProvider.overrideWithValue(() => fakeNow)],
      );
      container.read(waybackDateProvider.notifier).state = DateTime(2020, 1, 15);

      expect(container.read(currentDateProvider), DateTime(2020, 1, 15));

      fakeNow = DateTime(2026, 7, 3, 0, 0, 30);
      async.elapse(const Duration(days: 2));

      // Still pinned to the wayback date.
      expect(container.read(currentDateProvider), DateTime(2020, 1, 15));

      container.dispose();
    });
  });

  test('clearing the wayback override returns to the live (rolling) date', () {
    fakeAsync((async) {
      var fakeNow = DateTime(2026, 7, 1, 12, 0);
      final container = ProviderContainer(
        overrides: [nowProvider.overrideWithValue(() => fakeNow)],
      );

      container.read(waybackDateProvider.notifier).state = DateTime(2020, 1, 15);
      expect(container.read(currentDateProvider), DateTime(2020, 1, 15));

      container.read(waybackDateProvider.notifier).state = null;
      expect(container.read(currentDateProvider), DateTime(2026, 7, 1));

      // ...and the live date still rolls over afterwards.
      fakeNow = DateTime(2026, 7, 2, 12, 0);
      async.elapse(const Duration(days: 1));
      expect(container.read(currentDateProvider), DateTime(2026, 7, 2));

      container.dispose();
    });
  });
}
