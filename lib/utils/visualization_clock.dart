DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

/// The date columns an edit form writes when the user sets the one date it
/// shows — the value date, when the money moved — to [edited]; null means
/// "leave the column as it is".
///
/// The booking date ([bookingDate]: `transactions.operationDate`,
/// `asset_events.date`, `incomes.date`) only keys the import dedup. An edit
/// that keeps the day writes neither column. A moved day updates the value
/// date, and carries the booking date along only when it equalled the old
/// [valueDate] (a manually created row): a distinct booking date is the
/// bank's or the broker's and stays.
({DateTime? valueDate, DateTime? bookingDate}) editedDates({
  required DateTime edited,
  required DateTime valueDate,
  required DateTime bookingDate,
}) {
  final moved = edited.year != valueDate.year || edited.month != valueDate.month || edited.day != valueDate.day;
  if (!moved) return (valueDate: null, bookingDate: null);
  return (valueDate: edited, bookingDate: bookingDate == valueDate ? edited : null);
}

/// Local midnight at the start of the calendar day after [value].
///
/// Built from the calendar fields, never as midnight + `Duration(days: 1)`:
/// that is 24 hours of elapsed time, and a day is 23 or 25 hours long on a
/// daylight-saving change, so the sum lands an hour past or before the next
/// midnight.
DateTime startOfNextDay(DateTime value) => DateTime(value.year, value.month, value.day + 1);

/// Exclusive upper bound of an "as of [through]" read: the start of the day
/// after [through], so every instant of that day is included and none of the
/// next. Null (no bound) when [through] is null.
DateTime? throughEndExclusive(DateTime? through) => through == null ? null : startOfNextDay(through);

/// Duration from [now] until just after the next local midnight.
///
/// Used to schedule the "today" rollover so day-boundary-sensitive views
/// (today's price change, YTD, chart cutoffs) refresh on their own instead of
/// showing a stale figure until the app is restarted. The extra second
/// guarantees the timer fires just *after* the boundary, never a hair before.
Duration durationUntilNextDay(DateTime now) => startOfNextDay(now).difference(now) + const Duration(seconds: 1);

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
