part of 'dashboard_screen.dart';

// ════════════════════════════════════════════════════
// Income/Expense table widgets
// ════════════════════════════════════════════════════

class _YearlySummaryTable extends ConsumerWidget {
  final _IncomeExpenseData data;
  final String locale;
  const _YearlySummaryTable({required this.data, required this.locale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final amtFmt = fmt.amountFormat(locale);
    final pctFmt = NumberFormat('0.0%');
    final theme  = Theme.of(context);
    final sym    = currencySymbol(data.baseCurrency);
    final now    = DateTime.now();

    final years = data.years.reversed.toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 52,
        columnSpacing: 20,
        columns: [
          DataColumn(label: Text(s.colYear,        style: const TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text(s.colIncome,      style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text(s.colExpenses,    style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text(s.colSavings,     style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text(s.colRate,        style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text(s.colAvgMonthInc, style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text(s.colAvgMonthExp, style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text(s.colDailyInc,    style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text(s.colDailyExp,    style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
        ],
        rows: [
          for (int i = 0; i < years.length; i++) ...[
            _yearRow(years[i], i == 0 && years[i].year == now.year,
                     amtFmt, pctFmt, sym, theme),
            // EOY prediction row for current (partial) year
            if (i == 0 && years[i].year == now.year && years.length > 1)
              _eoyRow(years[i], years[i + 1], amtFmt, pctFmt, sym, theme, s),
          ],
        ],
      ),
    );
  }

  DataRow _yearRow(_YearBucket y, bool isCurrent,
      NumberFormat amtFmt, NumberFormat pctFmt, String sym, ThemeData theme) {
    TextStyle? style = isCurrent
        ? TextStyle(fontStyle: FontStyle.italic, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))
        : null;

    Color savingsColor = y.savings >= 0 ? Colors.green.shade700 : Colors.red.shade700;

    return DataRow(cells: [
      DataCell(Text(isCurrent ? '${y.year}*' : '${y.year}', style: style?.copyWith(fontWeight: FontWeight.w600))),
      DataCell(PrivacyText('${amtFmt.format(y.income)} $sym', style: style)),
      DataCell(PrivacyText('${amtFmt.format(y.expenses)} $sym', style: style)),
      DataCell(PrivacyText(
        '${amtFmt.format(y.savings)} $sym',
        style: (style ?? const TextStyle()).copyWith(color: savingsColor, fontWeight: FontWeight.w600),
      )),
      DataCell(Text(pctFmt.format(y.savingsRate), style: style?.copyWith(color: savingsColor))),
      DataCell(PrivacyText('${amtFmt.format(y.monthlyIncome)} $sym', style: style)),
      DataCell(PrivacyText('${amtFmt.format(y.monthlyExpenses)} $sym', style: style)),
      DataCell(PrivacyText('${amtFmt.format(y.dailyIncome)} $sym', style: style)),
      DataCell(PrivacyText('${amtFmt.format(y.dailyExpenses)} $sym', style: style)),
    ]);
  }

  DataRow _eoyRow(_YearBucket current, _YearBucket prev,
      NumberFormat amtFmt, NumberFormat pctFmt, String sym, ThemeData theme, AppStrings s) {
    final eoyInc = _eoyPrediction(current, prev);
    final eoyExp = _eoyPrediction(current, prev, expenses: true);
    final eoySav = (eoyInc != null && eoyExp != null) ? eoyInc - eoyExp : null;
    final eoyRate = (eoyInc != null && eoyInc > 0 && eoySav != null) ? eoySav / eoyInc : null;

    final style = TextStyle(
      fontStyle: FontStyle.italic,
      fontSize: 11,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
    );

    String fmt_(double? v) => v != null ? '~${amtFmt.format(v)} $sym' : '\u2014';

    return DataRow(cells: [
      DataCell(Text(s.eoyLabel, style: style)),
      DataCell(PrivacyText(fmt_(eoyInc), style: style)),
      DataCell(PrivacyText(fmt_(eoyExp), style: style)),
      DataCell(PrivacyText(fmt_(eoySav), style: style)),
      DataCell(Text(eoyRate != null ? '~${pctFmt.format(eoyRate)}' : '\u2014', style: style)),
      DataCell(const Text('')),
      DataCell(const Text('')),
      DataCell(const Text('')),
      DataCell(const Text('')),
    ]);
  }
}
