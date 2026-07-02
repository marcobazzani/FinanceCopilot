DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

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
