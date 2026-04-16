import '../database/tables.dart';

// ════════════════════════════════════════════════════
// Schedule date math — shared by CAPEX and Extraordinary Events.
// Pure functions; no DB/Drift dependency.
// ════════════════════════════════════════════════════

/// Advance a date by [months], clamping the day to the last day of the target month.
/// Example: Jan 31 + 1 month → Feb 28 (or Feb 29 in leap years).
DateTime addMonthsClamped(DateTime dt, int months) {
  final targetMonth = dt.month + months;
  final targetYear = dt.year + (targetMonth - 1) ~/ 12;
  final normalizedMonth = ((targetMonth - 1) % 12) + 1;
  final lastDay = DateTime(targetYear, normalizedMonth + 1, 0).day;
  return DateTime(targetYear, normalizedMonth, dt.day.clamp(1, lastDay));
}

DateTime advanceStep(DateTime current, StepFrequency freq) {
  return switch (freq) {
    StepFrequency.weekly => current.add(const Duration(days: 7)),
    StepFrequency.monthly => addMonthsClamped(current, 1),
    StepFrequency.quarterly => addMonthsClamped(current, 3),
    StepFrequency.yearly => addMonthsClamped(current, 12),
  };
}

DateTime retreatStep(DateTime current, StepFrequency freq) {
  return switch (freq) {
    StepFrequency.weekly => current.subtract(const Duration(days: 7)),
    StepFrequency.monthly => addMonthsClamped(current, -1),
    StepFrequency.quarterly => addMonthsClamped(current, -3),
    StepFrequency.yearly => addMonthsClamped(current, -12),
  };
}

/// All step dates from [start] to [end] inclusive, stepped by [freq].
List<DateTime> computeStepDates(DateTime start, DateTime end, StepFrequency freq) {
  final dates = <DateTime>[];
  var current = DateTime(start.year, start.month, start.day);
  final endNorm = DateTime(end.year, end.month, end.day);
  while (!current.isAfter(endNorm)) {
    dates.add(current);
    current = advanceStep(current, freq);
  }
  return dates;
}

DateTime computeEndDate(DateTime start, int stepCount, StepFrequency freq) {
  var current = DateTime(start.year, start.month, start.day);
  for (var i = 0; i < stepCount - 1; i++) {
    current = advanceStep(current, freq);
  }
  return current;
}

DateTime computeStartDate(DateTime end, int stepCount, StepFrequency freq) {
  var current = DateTime(end.year, end.month, end.day);
  for (var i = 0; i < stepCount - 1; i++) {
    current = retreatStep(current, freq);
  }
  return current;
}
