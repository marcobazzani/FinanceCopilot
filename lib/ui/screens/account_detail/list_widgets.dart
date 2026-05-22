part of '../account_detail_screen.dart';

class _PeriodHeader extends StatelessWidget {
  final String label;
  final Map<String, ({double income, double expense})> totals;
  final String locale;
  final bool isMonth;
  const _PeriodHeader({
    required this.label,
    required this.totals,
    required this.locale,
    required this.isMonth,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Sort currencies for stable display; primary first by total absolute flow.
    final entries = totals.entries.toList()
      ..sort((a, b) {
        final fa = a.value.income - a.value.expense; // expense is negative
        final fb = b.value.income - b.value.expense;
        return fb.abs().compareTo(fa.abs());
      });
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isMonth ? 8 : 6,
      ),
      color: isMonth
          ? scheme.surfaceContainerHigh
          : scheme.surfaceContainerHighest,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: isMonth ? FontWeight.w700 : FontWeight.w600,
                    fontSize: isMonth ? 13 : null,
                  ),
            ),
          ),
          if (entries.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final e in entries)
                  _TotalsChip(
                    income: e.value.income,
                    expense: e.value.expense,
                    currency: e.key,
                    locale: locale,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TotalsChip extends StatelessWidget {
  final double income;
  final double expense;
  final String currency;
  final String locale;
  const _TotalsChip({
    required this.income,
    required this.expense,
    required this.currency,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final f = fmt.currencyFormat(locale, currency);
    final net = income + expense; // expense is negative
    if (income == 0 && expense == 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    const numStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w600);
    final parts = <Widget>[];
    if (income > 0) {
      parts.add(PrivacyText(
        '+${f.format(income)}',
        style: numStyle.copyWith(color: Colors.green.shade700),
      ));
    }
    if (expense < 0) {
      if (parts.isNotEmpty) parts.add(const SizedBox(width: 6));
      parts.add(PrivacyText(
        f.format(expense),
        style: numStyle.copyWith(color: Colors.red.shade700),
      ));
    }
    // Consolidated net — always shown so each row carries a definitive total.
    if (parts.isNotEmpty) parts.add(const SizedBox(width: 8));
    parts.add(PrivacyText(
      '= ${net >= 0 ? '+' : ''}${f.format(net)}',
      style: numStyle.copyWith(
        color: net >= 0 ? Colors.green.shade700 : Colors.red.shade700,
        fontWeight: FontWeight.w700,
        decoration: TextDecoration.underline,
        decorationColor: scheme.onSurfaceVariant.withValues(alpha: 0.35),
      ),
    ));
    return Row(mainAxisSize: MainAxisSize.min, children: parts);
  }
}
