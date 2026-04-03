part of 'dashboard_screen.dart';

class _YoYDiffTable extends ConsumerWidget {
  final _IncomeExpenseData data;
  final String locale;
  final String language;
  const _YoYDiffTable({required this.data, required this.locale, required this.language});

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
    final years  = data.years;

    if (years.length < 2) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(s.needMoreYears, style: const TextStyle(color: Colors.grey)),
      );
    }

    // Pairs: (prevYear, curYear)
    final pairs = <(_YearBucket, _YearBucket)>[];
    for (int i = 1; i < years.length; i++) {
      pairs.add((years[i - 1], years[i]));
    }

    double? diff(_YearBucket prev, _YearBucket cur, int month) {
      final p = prev.months.where((m) => m.month == month).firstOrNull;
      final c = cur.months.where((m) => m.month == month).firstOrNull;
      if (p == null || c == null) return null;
      return c.income - p.income;
    }

    final borderSide = BorderSide(color: theme.dividerColor, width: 0.5);
    final tableBorder = TableBorder(
      horizontalInside: borderSide,
      verticalInside: borderSide,
      bottom: borderSide,
    );

    Widget diffCell(double? v) {
      if (v == null) return const Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: Text('\u2014', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: Colors.grey)));
      final color = v >= 0 ? Colors.green.shade700 : Colors.red.shade700;
      final text  = '${v >= 0 ? '+' : ''}${amtFmt.format(v)} $sym';
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: PrivacyText(text,
          style: TextStyle(fontSize: 12, color: color),
          textAlign: TextAlign.right,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Table(
        border: tableBorder,
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: [
          // Header
          TableRow(
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest),
            children: [
              Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Text(s.colMonth, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              for (final p in pairs)
                Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Text('${p.$1.year}\u2192${p.$2.year}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          textAlign: TextAlign.right)),
            ],
          ),
          // Month rows
          for (int m = 1; m <= 12; m++)
            TableRow(children: [
              Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: Text(_localizedMonths()[m - 1],
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
              for (final p in pairs)
                diffCell(diff(p.$1, p.$2, m)),
            ]),
          // YoY row: sum of all monthly diffs for months available so far
          TableRow(
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest),
            children: [
              Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            child: Text('YoY', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              for (final p in pairs) ...[
                Builder(builder: (ctx) {
                  final maxM = p.$2.months.length;
                  double sum = 0;
                  bool valid = false;
                  for (int m = 1; m <= maxM; m++) {
                    final d = diff(p.$1, p.$2, m);
                    if (d != null) { sum += d; valid = true; }
                  }
                  return diffCell(valid ? sum : null);
                }),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
