double? incomeYoYDiff({
  required double previousIncome,
  required bool previousHasIncomeData,
  required double currentIncome,
  required bool currentHasIncomeData,
}) {
  if (!previousHasIncomeData || !currentHasIncomeData) return null;
  return currentIncome - previousIncome;
}

double? incomeYoYTotal(
  Iterable<
    ({
      double previousIncome,
      bool previousHasIncomeData,
      double currentIncome,
      bool currentHasIncomeData,
    })
  > months,
) {
  double sum = 0;
  var hasComparableMonth = false;
  for (final month in months) {
    final diff = incomeYoYDiff(
      previousIncome: month.previousIncome,
      previousHasIncomeData: month.previousHasIncomeData,
      currentIncome: month.currentIncome,
      currentHasIncomeData: month.currentHasIncomeData,
    );
    if (diff == null) continue;
    sum += diff;
    hasComparableMonth = true;
  }
  return hasComparableMonth ? sum : null;
}
