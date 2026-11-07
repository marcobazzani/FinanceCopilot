part of 'dashboard_screen.dart';

/// Month by month, each year minus the year before. [field] is 'income',
/// 'expenses' or 'savings'. The year before each of [data]'s years is read
/// from [previous] when given (all years, while [data] holds only the picked
/// periods), else from [data].
class _YoYDiffTable extends ConsumerWidget {
  final _IncomeExpenseData data;
  final _IncomeExpenseData? previous;
  final String locale;
  final String language;
  final String field;
  const _YoYDiffTable({required this.data, this.previous, required this.locale, required this.language, this.field = 'income'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final amtFmt = fmt.amountFormat(locale);
    final theme = Theme.of(context);
    final sym = currencySymbol(data.baseCurrency);
    final before = {for (final y in (previous ?? data).years) y.year: y};

    // Pairs: (prevYear, curYear)
    final pairs = <(_YearBucket, _YearBucket)>[
      for (final y in data.years)
        if (before[y.year - 1] case final p?) (p, y),
    ];
    if (pairs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(s.needMoreYears, style: const TextStyle(color: Colors.grey)),
      );
    }

    double valueOf(_MonthBucket m) => field == 'savings' ? m.savings : m.expenses;

    // A month still in progress is set against the same share of the month a
    // year before (5/30 of it on 5 November); whole months against whole
    // months. A month without a bucket on either side has nothing to compare:
    // a dash, not a difference against zero. Income also needs income records
    // on both sides.
    double? diff(_MonthBucket? p, _MonthBucket? c) {
      if (p == null || c == null) return null;
      if (field == 'income') {
        return incomeYoYDiff(
          previousIncome: p.income * c.share,
          previousHasIncomeData: p.hasIncomeData,
          currentIncome: c.income,
          currentHasIncomeData: c.hasIncomeData,
        );
      }
      return valueOf(c) - valueOf(p) * c.share;
    }

    _MonthBucket? monthOf(_YearBucket y, int month) => y.months.where((m) => m.month == month).firstOrNull;

    // Sum of the monthly differences of the months shown in the later year.
    double? total(_YearBucket prev, _YearBucket cur) {
      if (field == 'income') {
        return incomeYoYTotal([
          for (final c in cur.months)
            () {
              final p = monthOf(prev, c.month);
              return (
                previousIncome: (p?.income ?? 0) * c.share,
                previousHasIncomeData: p?.hasIncomeData ?? false,
                currentIncome: c.income,
                currentHasIncomeData: c.hasIncomeData,
              );
            }(),
        ]);
      }
      double? sum;
      for (final c in cur.months) {
        final d = diff(monthOf(prev, c.month), c);
        if (d != null) sum = (sum ?? 0) + d;
      }
      return sum;
    }

    // More expenses than the year before is the bad direction.
    final upIsGood = field != 'expenses';

    final borderSide = BorderSide(color: theme.dividerColor, width: 0.5);
    final tableBorder = TableBorder(
      horizontalInside: borderSide,
      verticalInside: borderSide,
      bottom: borderSide,
    );

    Widget diffCell(double? v, {bool partial = false}) {
      if (v == null) {
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            '\u2014',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        );
      }
      final color = (v >= 0) == upIsGood ? Colors.green.shade700 : Colors.red.shade700;
      // A month in progress, set against a share of the other: marked, and
      // said in the footnote.
      final text = '${v >= 0 ? '+' : ''}${amtFmt.format(v)} $sym${partial ? '*' : ''}';
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: PrivacyText(
          text,
          style: TextStyle(fontSize: 12, color: color),
          textAlign: TextAlign.right,
        ),
      );
    }

    // The months still in progress, each with the month it is set against.
    final partial = [
      for (final (p, c) in pairs)
        for (final m in c.months)
          if (m.share < 1 && monthOf(p, m.month) != null) (current: m, base: monthOf(p, m.month)!),
    ];
    // A month against the same month of another year: by its name, never "this month".
    String monthLabel(_MonthBucket m) => monthYearLabel(m.year, m.month, language);

    final table = SingleChildScrollView(
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(s.colMonth, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              for (final p in pairs)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    '${p.$1.year}\u2192${p.$2.year}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    textAlign: TextAlign.right,
                  ),
                ),
            ],
          ),
          // Month rows
          for (int m = 1; m <= 12; m++)
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Text(monthAbbr(m, language), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                ),
                for (final p in pairs) diffCell(diff(monthOf(p.$1, m), monthOf(p.$2, m)), partial: (monthOf(p.$2, m)?.share ?? 1) < 1),
              ],
            ),
          // YoY row: sum of all monthly diffs for months available so far
          TableRow(
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Text(s.yoyRowLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              for (final p in pairs) diffCell(total(p.$1, p.$2)),
            ],
          ),
        ],
      ),
    );
    if (partial.isEmpty) return table;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        table,
        for (final (:current, :base) in partial)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Footnote(
              '* ${s.cfPartialMonth(monthLabel(current), current.daysCovered, current.daysInMonth, monthLabel(base))}',
              key: const Key('yoyPartialMonth'),
            ),
          ),
      ],
    );
  }
}
