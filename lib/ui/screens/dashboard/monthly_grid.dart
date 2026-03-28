part of 'dashboard_screen.dart';

class _MonthlyGrid extends ConsumerWidget {
  final _IncomeExpenseData data;
  final String locale;
  final String field; // 'income' or 'expenses'
  final int? maxYears;
  const _MonthlyGrid({required this.data, required this.locale,
                      required this.field, this.maxYears});

  static const _monthNames = ['Jan','Feb','Mar','Apr','May','Jun',
                               'Jul','Aug','Sep','Oct','Nov','Dec'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final amtFmt = fmt.amountFormat(locale);
    final theme  = Theme.of(context);
    final sym    = currencySymbol(data.baseCurrency);
    final now    = DateTime.now();

    var years = data.years;
    if (maxYears != null && years.length > maxYears!) {
      years = years.sublist(years.length - maxYears!);
    }
    final yearLabels = years.map((y) => y.year).toList();

    // avg column: average per year for each month
    final borderSide = BorderSide(color: theme.dividerColor, width: 0.5);
    final headerBorder = TableBorder(
      horizontalInside: borderSide,
      verticalInside: borderSide,
      bottom: borderSide,
    );

    double _value(_YearBucket y, int m) {
      final mb = y.months.where((b) => b.month == m).firstOrNull;
      return mb == null ? double.nan : (field == 'income' ? mb.income : mb.expenses);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Table(
        border: headerBorder,
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: [
          // Header row
          TableRow(
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest),
            children: [
              _th(s.colMonth),
              for (final y in yearLabels)
                _th('$y${y == now.year ? "*" : ""}'),
              _th(s.colAvg),
            ],
          ),
          // Month rows
          for (int m = 1; m <= 12; m++) ...[
            TableRow(children: [
              _td(_monthNames[m - 1], bold: true),
              for (final y in years) ...[
                Builder(builder: (ctx) {
                  final v = _value(y, m);
                  final isFuture = v.isNaN;
                  final isCurrent = y.year == now.year;
                  return _tdPrivacy(
                    isFuture ? '\u2014' : '${amtFmt.format(v)} $sym',
                    dimmed: isCurrent || isFuture,
                  );
                }),
              ],
              Builder(builder: (ctx) {
                final vals = years.map((y) => _value(y, m)).where((v) => !v.isNaN).toList();
                final avg = vals.isEmpty ? null : vals.reduce((a, b) => a + b) / vals.length;
                return _tdPrivacy(avg == null ? '\u2014' : '${amtFmt.format(avg)} $sym');
              }),
            ]),
          ],
          // Total row
          TableRow(
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest),
            children: [
              _td(s.colTotal, bold: true),
              for (final y in years) ...[
                Builder(builder: (ctx) {
                  final v = field == 'income' ? y.income : y.expenses;
                  return _tdPrivacy('${amtFmt.format(v)} $sym',
                    dimmed: y.year == now.year, bold: true);
                }),
              ],
              Builder(builder: (ctx) {
                final vals = years.map((y) => field == 'income' ? y.income : y.expenses).toList();
                final avg = vals.isEmpty ? null : vals.reduce((a, b) => a + b) / vals.length;
                return _tdPrivacy(avg == null ? '\u2014' : '${amtFmt.format(avg)} $sym', bold: true);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _th(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                textAlign: TextAlign.right),
  );

  Widget _td(String text, {bool bold = false, bool dimmed = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    child: Text(text,
      style: TextStyle(fontWeight: bold ? FontWeight.w600 : null,
                       fontSize: 12, color: dimmed ? Colors.grey : null),
      textAlign: TextAlign.right),
  );

  Widget _tdPrivacy(String text, {bool bold = false, bool dimmed = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: PrivacyText(text,
        style: TextStyle(fontWeight: bold ? FontWeight.w600 : null,
                         fontSize: 12, color: dimmed ? Colors.grey : null),
        textAlign: TextAlign.right,
      ),
    );
}
