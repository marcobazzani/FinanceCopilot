part of 'dashboard_screen.dart';

class _MonthlyGrid extends ConsumerWidget {
  final _IncomeExpenseData data;
  final String locale;
  final String language;
  final String field; // 'income' or 'expenses'
  const _MonthlyGrid({required this.data, required this.locale,
                      required this.language, required this.field});

  List<String> _localizedMonths() {
    final f = DateFormat('MMM', language);
    return [for (int m = 1; m <= 12; m++) f.format(DateTime(2000, m))];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final amtFmt = fmt.amountFormat(locale);
    final theme  = Theme.of(context);
    final sym    = currencySymbol(data.baseCurrency);
    final now    = ref.watch(currentDateProvider);

    final years = data.years;
    final yearLabels = years.map((y) => y.year).toList();

    final borderSide = BorderSide(color: theme.dividerColor, width: 0.5);
    final headerBorder = TableBorder(
      horizontalInside: borderSide,
      verticalInside: borderSide,
      bottom: borderSide,
    );

    double value(_YearBucket y, int m) {
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
            ],
          ),
          // Month rows
          for (int m = 1; m <= 12; m++) ...[
            TableRow(children: [
              _td(_localizedMonths()[m - 1], bold: true),
              for (final y in years) ...[
                Builder(builder: (ctx) {
                  final v = value(y, m);
                  final isFuture = v.isNaN;
                  final isCurrent = y.year == now.year;
                  return _tdPrivacy(
                    isFuture ? '\u2014' : '${amtFmt.format(v)} $sym',
                    dimmed: isCurrent || isFuture,
                  );
                }),
              ],
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
