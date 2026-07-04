DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

/// Duration from [now] until just after the next local midnight.
///
/// Used to schedule the "today" rollover so day-boundary-sensitive views
/// (today's price change, YTD, chart cutoffs) refresh on their own instead of
/// showing a stale figure until the app is restarted. The extra second
/// guarantees the timer fires just *after* the boundary, never a hair before.
Duration durationUntilNextDay(DateTime now) {
  final nextMidnight = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  return nextMidnight.difference(now) + const Duration(seconds: 1);
}

DateTime lastCompletedMonthEnd(DateTime today) {
  final d = dateOnly(today);
  return DateTime(d.year, d.month, 0);
}

DateTime lastCompletedYearEnd(DateTime today) {
  final d = dateOnly(today);
  return DateTime(d.year, 1, 0);
}

/// End of the current month — the next upcoming month-end (used by the wayback
/// machine's "wayforward" shortcut to project to the end of this month).
DateTime nextMonthEnd(DateTime today) {
  final d = dateOnly(today);
  return DateTime(d.year, d.month + 1, 0);
}

/// End of the current year (Dec 31) — the next upcoming year-end, for the
/// wayforward shortcut.
DateTime nextYearEnd(DateTime today) {
  final d = dateOnly(today);
  return DateTime(d.year, 12, 31);
}
