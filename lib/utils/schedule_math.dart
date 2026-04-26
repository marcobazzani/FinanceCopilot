import '../database/tables.dart';

// ════════════════════════════════════════════════════
// Schedule date math — shared by CAPEX and Extraordinary Events.
// Pure functions; no DB/Drift dependency.
// ════════════════════════════════════════════════════

/// Advance a date by [months], clamping the day to the last day of the target month.
/// Example: Jan 31 + 1 month → Feb 28 (or Feb 29 in leap years).
///
/// Year carry uses floor semantics so that negative [months] crossing January
/// land in the previous year (Dart's `~/` truncates toward zero, which would
/// keep the year unchanged for those cases).
DateTime addMonthsClamped(DateTime dt, int months) {
  final zeroBased = dt.month - 1 + months;
  final yearDelta = zeroBased >= 0 ? zeroBased ~/ 12 : -((-zeroBased + 11) ~/ 12);
  final targetYear = dt.year + yearDelta;
  final normalizedMonth = zeroBased - yearDelta * 12 + 1;
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

/// Months to advance per step for monthly/quarterly/yearly. Returns 0 for
/// weekly (which uses day-based stepping instead).
int _monthsPerStep(StepFrequency freq) => switch (freq) {
      StepFrequency.weekly => 0,
      StepFrequency.monthly => 1,
      StepFrequency.quarterly => 3,
      StepFrequency.yearly => 12,
    };

/// Compute step [n] (0-based) from [anchor]. For monthly/quarterly/yearly
/// this re-anchors each step on [anchor.day] instead of compounding the
/// previous step's clamped day, so a "31st of every month" schedule does
/// not drift to the 29th after crossing February.
DateTime _stepN(DateTime anchor, int n, StepFrequency freq) {
  if (freq == StepFrequency.weekly) {
    return anchor.add(Duration(days: 7 * n));
  }
  return addMonthsClamped(anchor, n * _monthsPerStep(freq));
}

/// All step dates from [start] to [end] inclusive, stepped by [freq].
List<DateTime> computeStepDates(DateTime start, DateTime end, StepFrequency freq) {
  final anchor = DateTime(start.year, start.month, start.day);
  final endNorm = DateTime(end.year, end.month, end.day);
  final dates = <DateTime>[];
  for (var i = 0;; i++) {
    final d = _stepN(anchor, i, freq);
    if (d.isAfter(endNorm)) break;
    dates.add(d);
  }
  return dates;
}

DateTime computeEndDate(DateTime start, int stepCount, StepFrequency freq) {
  final anchor = DateTime(start.year, start.month, start.day);
  return _stepN(anchor, stepCount - 1, freq);
}

DateTime computeStartDate(DateTime end, int stepCount, StepFrequency freq) {
  final anchor = DateTime(end.year, end.month, end.day);
  return _stepN(anchor, -(stepCount - 1), freq);
}
