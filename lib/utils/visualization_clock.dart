DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime lastCompletedMonthEnd(DateTime today) {
  final d = dateOnly(today);
  return DateTime(d.year, d.month, 0);
}

DateTime lastCompletedYearEnd(DateTime today) {
  final d = dateOnly(today);
  return DateTime(d.year, 1, 0);
}
