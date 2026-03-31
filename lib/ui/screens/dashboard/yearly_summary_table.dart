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
        '${y.savings >= 0 ? '+' : ''}${amtFmt.format(y.savings)} $sym',
        style: (style ?? const TextStyle()).copyWith(color: savingsColor, fontWeight: FontWeight.w600),
      )),
      DataCell(Text('${y.savingsRate >= 0 ? '+' : ''}${pctFmt.format(y.savingsRate)}', style: style?.copyWith(color: savingsColor))),
      DataCell(PrivacyText('${amtFmt.format(y.monthlyIncome)} $sym', style: style)),
      DataCell(PrivacyText('${amtFmt.format(y.monthlyExpenses)} $sym', style: style)),
      DataCell(PrivacyText('${amtFmt.format(y.dailyIncome)} $sym', style: style)),
      DataCell(PrivacyText('${amtFmt.format(y.dailyExpenses)} $sym', style: style)),
    ]);
  }

  DataRow _eoyRow(_YearBucket current, _YearBucket prev,
      NumberFormat amtFmt, NumberFormat pctFmt, String sym, ThemeData theme, AppStrings s) {
    final incD = _eoyDetails(current, prev);
    final expD = _eoyDetails(current, prev, expenses: true);
    final eoyInc = incD?.value;
    final eoyExp = expD?.value;
    final eoySav = (eoyInc != null && eoyExp != null) ? eoyInc - eoyExp : null;
    final eoyRate = (eoyInc != null && eoyInc > 0 && eoySav != null) ? eoySav / eoyInc : null;

    final style = TextStyle(
      fontStyle: FontStyle.italic,
      fontSize: 11,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
    );

    String fmt_(double? v) => v != null ? '~${amtFmt.format(v)} $sym' : '\u2014';

    return DataRow(cells: [
      DataCell(Builder(builder: (ctx) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(s.eoyLabel, style: style),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _showEoyExplanation(ctx, current, prev, incD, expD, eoyInc, eoyExp, eoySav, eoyRate, amtFmt, pctFmt, sym, s),
            child: Icon(Icons.info_outline, size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
          ),
        ],
      ))),
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

  void _showEoyExplanation(
    BuildContext context,
    _YearBucket current, _YearBucket prev,
    _EoyDetails? incD, _EoyDetails? expD,
    double? eoyInc, double? eoyExp, double? eoySav, double? eoyRate,
    NumberFormat amtFmt, NumberFormat pctFmt, String sym, AppStrings s,
  ) {
    final n = current.months.length;
    final monthRange = n == 1 ? 'Jan' : 'Jan–${_monthAbbr(n)}';
    final isIt = s.eoyFormula.contains('anno'); // detect language

    String describeMetric(String label, _EoyDetails? d, double? result) {
      if (d == null || result == null) return '';
      final prevPct = d.prevSame != 0 ? (d.currentTotal / d.prevSame * 100).toStringAsFixed(1) : '?';
      if (isIt) {
        return '━ $label\n'
            '  Nel ${prev.year}, il totale annuo è stato ${amtFmt.format(d.prevTotal)} $sym.\n'
            '  Nello stesso periodo ($monthRange) del ${prev.year}: ${amtFmt.format(d.prevSame)} $sym.\n'
            '  Nel ${current.year} ($monthRange) finora: ${amtFmt.format(d.currentTotal)} $sym ($prevPct% rispetto al ${prev.year}).\n'
            '  Proiezione: ${amtFmt.format(d.prevTotal)} × ${amtFmt.format(d.currentTotal)} ÷ ${amtFmt.format(d.prevSame)} = ~${amtFmt.format(result)} $sym\n';
      }
      return '━ $label\n'
          '  In ${prev.year}, the full-year total was ${amtFmt.format(d.prevTotal)} $sym.\n'
          '  Over the same period ($monthRange) in ${prev.year}: ${amtFmt.format(d.prevSame)} $sym.\n'
          '  In ${current.year} ($monthRange) so far: ${amtFmt.format(d.currentTotal)} $sym ($prevPct% vs ${prev.year}).\n'
          '  Projection: ${amtFmt.format(d.prevTotal)} × ${amtFmt.format(d.currentTotal)} ÷ ${amtFmt.format(d.prevSame)} = ~${amtFmt.format(result)} $sym\n';
    }

    final buf = StringBuffer();

    if (isIt) {
      buf.writeln('Previsione fine anno ${current.year}');
      buf.writeln('Basata sull\'andamento del ${prev.year} come riferimento stagionale.\n');
    } else {
      buf.writeln('End-of-year ${current.year} prediction');
      buf.writeln('Based on ${prev.year} as the seasonal reference.\n');
    }

    buf.write(describeMetric(s.colIncome, incD, eoyInc));
    buf.write(describeMetric(s.colExpenses, expD, eoyExp));

    if (eoySav != null) {
      buf.writeln('━ ${s.colSavings}');
      buf.writeln('  ~${amtFmt.format(eoyInc!)} $sym − ~${amtFmt.format(eoyExp!)} $sym = ~${amtFmt.format(eoySav)} $sym');
    }
    if (eoyRate != null) {
      buf.writeln('━ ${s.colRate}');
      buf.writeln('  ~${amtFmt.format(eoySav!)} ÷ ~${amtFmt.format(eoyInc!)} = ~${pctFmt.format(eoyRate)}');
    }

    buf.writeln('');
    buf.writeln(s.eoyFormula);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isIt ? 'Previsione fine anno' : 'End-of-year prediction'),
        content: SizedBox(
          width: 480,
          child: SelectableText(
            buf.toString(),
            style: const TextStyle(fontSize: 12, height: 1.6),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.close)),
        ],
      ),
    );
  }

  static String _monthAbbr(int month) {
    const abbrs = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return abbrs[(month - 1).clamp(0, 11)];
  }
}

class _EoyDetails {
  final double value;
  final double prevTotal;
  final double prevSame;
  final double currentTotal;
  final int months;
  const _EoyDetails({required this.value, required this.prevTotal, required this.prevSame, required this.currentTotal, required this.months});
}

_EoyDetails? _eoyDetails(_YearBucket current, _YearBucket prev, {bool expenses = false}) {
  if (current.months.isEmpty) return null;
  final n = current.months.length;
  final prevSame = prev.months
      .where((m) => m.month <= n)
      .fold(0.0, (s, m) => s + (expenses ? m.expenses : m.income));
  if (prevSame == 0) return null;
  final currentTotal = expenses ? current.expenses : current.income;
  final prevTotal = expenses ? prev.expenses : prev.income;
  return _EoyDetails(
    value: prevTotal * currentTotal / prevSame,
    prevTotal: prevTotal,
    prevSame: prevSame,
    currentTotal: currentTotal,
    months: n,
  );
}
