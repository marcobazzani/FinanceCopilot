part of 'dashboard_screen.dart';

// ════════════════════════════════════════════════════
// "Why is this figure what it is?" — the table behind a Cash Flow cell
// ════════════════════════════════════════════════════

/// The series of the Saving total as [explainCashFlowCell] reads them.
ExplainSeries _explainSeriesOf(ChartSeries s, Map<int, Account> accounts) {
  final key = parseSeriesKey(s.key);
  final id = key?.id ?? -1;
  final kind = switch (key?.type) {
    'account' => ExplainSeriesKind.account,
    'asset_invested' || 'asset_market' || 'asset_net' => ExplainSeriesKind.investment,
    _ => ExplainSeriesKind.adjustment,
  };
  return ExplainSeries(
    kind: kind,
    id: id,
    name: s.name,
    currency: kind == ExplainSeriesKind.account ? accounts[id]?.currency : null,
    spots: [for (final p in s.spots) (p.x, p.y)],
  );
}

/// Opens the table that justifies one Cash Flow figure: [cellValue], the
/// number shown in the cell for [year] ([month], a whole year when null).
/// [from]/[to] are the period the figure was measured over (the bucket's own).
/// Every row of the table opens what it is made of.
Future<void> _showCashFlowExplanation(
  BuildContext context,
  WidgetRef ref, {
  required _IncomeExpenseData data,
  required CashFlowField field,
  required int year,
  int? month,
  required DateTime from,
  required DateTime to,
  required double cellValue,
  required String locale,
}) async {
  final s = ref.read(appStringsProvider);
  final txs = await ref.read(allTransactionsProvider.future);
  final cats = await ref.read(allCategoriesProvider.future);
  final accounts = await ref.read(accountsProvider.future);
  final resolver = CachedRateResolver(ref.read(exchangeRateServiceProvider), data.baseCurrency);
  final accountById = {for (final a in accounts) a.id: a};
  final categories = {for (final c in cats) c.id: c};

  final explanation = await explainCashFlowCell(
    field: field,
    year: year,
    month: month,
    firstDate: data.firstDate,
    periodFrom: from,
    periodTo: to,
    baseCurrency: data.baseCurrency,
    series: [for (final cs in data.savingSeries) _explainSeriesOf(cs, accountById)],
    transactions: txs,
    categories: categories,
    income: data.incomeRecords,
    pension: data.pensionRecords,
    rate: resolver.getRate,
  );
  // The table and the cell are made of the same inputs; if they ever differ
  // the table says so rather than letting two numbers pass for one.
  final mismatch = explanation.total - cellValue;
  final differs = mismatch.abs() > 0.01;
  if (differs) {
    _allSeriesLog.warning(
      'cash-flow explanation ${field.name} $year/${month ?? '-'}: rows add up to ${explanation.total}, the cell shows $cellValue',
    );
  }
  if (!context.mounted) return;
  final period = month == null ? '$year' : '${monthAbbr(month, locale)} $year';
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _CashFlowExplainDialog(
      explanation: explanation,
      categories: categories,
      baseCurrency: data.baseCurrency,
      locale: locale,
      strings: s,
      period: period,
      cellValue: differs ? cellValue : null,
      onDrill: (line, label) => _drillInto(
        dialogContext,
        ref,
        line,
        title: '$label · $period',
        from: from,
        to: to,
        data: data,
        transactions: txs,
        locale: locale,
      ),
    ),
  );
}

/// What one row of the table is made of, opened over the table:
/// - a category / type / uncategorized row: its transactions, in the same
///   sheet as the Sankey's (biggest first, each one can be classified);
/// - an income or pension row: the records summed into it;
/// - an investment, adjustment or account row: the values it was read from
///   at both ends of the period, and an investment's events in the period.
Future<void> _drillInto(
  BuildContext context,
  WidgetRef ref,
  ExplainLine line, {
  required String title,
  required DateTime from,
  required DateTime to,
  required _IncomeExpenseData data,
  required List<Transaction> transactions,
  required String locale,
}) async {
  final s = ref.read(appStringsProvider);
  final amtFmt = fmt.amountFormat(locale);
  final dateFmt = fmt.shortDateFormat(locale);
  final sym = currencySymbol(data.baseCurrency);

  if (line.transactionIds.isNotEmpty && line.kind != ExplainLineKind.account) {
    await showTransactionsSheet(context, ids: ValueNotifier(line.transactionIds), title: title, locale: locale);
    return;
  }

  final rows = <Widget>[];
  if (line.recordIds.isNotEmpty) {
    final ids = line.recordIds.toSet();
    final records = [...data.incomeRecords, ...data.pensionRecords].where((r) => ids.contains(r.id)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    for (final r in records) {
      rows.add(_drillRow(dateFmt.format(r.date), '${amtFmt.format(r.amount)} $sym', key: ValueKey('cfRecord:${r.id}')));
    }
  } else {
    // The value the row was read from, at both ends of the period.
    if (line.valueFrom != null) rows.add(_drillRow(s.cfExplainBalanceFrom, '${amtFmt.format(line.valueFrom)} $sym'));
    if (line.valueTo != null) rows.add(_drillRow(s.cfExplainBalanceTo, '${amtFmt.format(line.valueTo)} $sym'));
    // An account entering the total: its first row, whose balance shows
    // what was already in it.
    final ids = line.transactionIds.toSet();
    for (final t in transactions.where((t) => ids.contains(t.id))) {
      rows
        ..add(_drillRow('${dateFmt.format(t.valueDate)} · ${t.description}', '${amtFmt.format(t.amount)} ${t.currency}'))
        ..add(_drillRow(s.balanceAfter, '${amtFmt.format(t.balanceAfter ?? 0)} ${t.currency}'));
    }
    rows.add(_drillRow(s.cfExplainChange, '${amtFmt.format(line.amount)} $sym', bold: true));
    if (line.seriesKind == ExplainSeriesKind.investment && line.seriesId != null) {
      // Events dated after the period's start day and up to its end day: the
      // same calendar days the value change was measured over.
      final startDay = DateTime(from.year, from.month, from.day + 1);
      final endDay = DateTime(to.year, to.month, to.day + 1);
      final events =
          (await ref.read(assetEventServiceProvider).getByAsset(line.seriesId!))
              .where((ev) => !ev.valueDate.isBefore(startDay) && ev.valueDate.isBefore(endDay))
              .toList()
            ..sort((a, b) => a.valueDate.compareTo(b.valueDate));
      rows
        ..add(const Divider(height: 20))
        ..add(
          Text(
            s.cfExplainEventsInPeriod,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        );
      if (events.isEmpty) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(s.cfExplainNoEventsInPeriod, style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
          ),
        );
      }
      for (final ev in events) {
        rows.add(
          _drillRow(
            '${dateFmt.format(ev.valueDate)} · ${s.eventTypeName(ev.type)}',
            '${amtFmt.format(ev.amount)} ${ev.currency}',
            key: ValueKey('cfEvent:${ev.id}'),
          ),
        );
      }
    }
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: rows),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.close))],
    ),
  );
}

/// One line of a drill-down: a readable label and an amount, which is
/// position size and masked in privacy mode.
Widget _drillRow(String label, String amount, {bool bold = false, Key? key}) {
  final style = TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w600 : null);
  return Padding(
    key: key,
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label, style: style)),
        PrivacyText(amount, style: style),
      ],
    ),
  );
}

class _CashFlowExplainDialog extends StatelessWidget {
  final CashFlowExplanation explanation;
  final Map<int, Category> categories;
  final String baseCurrency;
  final String locale;
  final AppStrings strings;
  final String period;

  /// The number in the cell, when the rows do not add up to it (never
  /// expected: both come from the same inputs). Shown, not hidden.
  final double? cellValue;

  /// Opens what a row is made of; [label] is the row's label.
  final void Function(ExplainLine line, String label) onDrill;
  const _CashFlowExplainDialog({
    required this.explanation,
    required this.categories,
    required this.baseCurrency,
    required this.locale,
    required this.strings,
    required this.period,
    this.cellValue,
    required this.onDrill,
  });

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final e = explanation;
    final amtFmt = fmt.amountFormat(locale);
    final sym = currencySymbol(baseCurrency);
    final dateFmt = fmt.shortDateFormat(locale);
    final theme = Theme.of(context);

    final figure = switch (e.field) {
      CashFlowField.income => s.colIncome,
      CashFlowField.savings => s.colSavings,
      CashFlowField.expenses => s.colExpenses,
    };
    final formula = switch (e.field) {
      CashFlowField.income => s.cfExplainFormulaIncome,
      CashFlowField.savings => s.cfExplainFormulaSavings,
      CashFlowField.expenses => s.cfExplainFormulaExpenses,
    };

    // Contributions to Income and Expenses read as plain figures; the rows of
    // Savings and Expenses carry a sign, because they add and subtract.
    String money(double v, {bool signed = true}) => '${signed && e.field != CashFlowField.income && v > 0 ? '+' : ''}${amtFmt.format(v)} $sym';

    Widget row(
      String label,
      double amount, {
      int count = 0,
      int indent = 0,
      bool bold = false,
      bool signed = true,
      Key? key,
      VoidCallback? onTap,
    }) {
      final style = TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w600 : null);
      final content = Padding(
        padding: EdgeInsets.fromLTRB(16.0 * indent, 3, 0, 3),
        child: Row(
          children: [
            Expanded(child: Text(label, style: style)),
            if (count > 0)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(s.transactionCount(count), style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
            // An amount is position size: masked in privacy mode. The label and the count are not.
            PrivacyText(money(amount, signed: signed), style: style),
            SizedBox(width: 20, child: onTap == null ? null : const Icon(Icons.chevron_right, size: 16, color: Colors.grey)),
          ],
        ),
      );
      return onTap == null ? KeyedSubtree(key: key, child: content) : InkWell(key: key, onTap: onTap, child: content);
    }

    String sectionTitle(ExplainSectionKind k) => switch (k) {
      ExplainSectionKind.incomeRecords => s.cfExplainSectionIncome,
      ExplainSectionKind.accountTransactions => s.cfExplainSectionTransactions,
      ExplainSectionKind.accountOpening => s.cfExplainSectionOpening,
      ExplainSectionKind.investments => s.cfExplainSectionInvestments,
      ExplainSectionKind.adjustments => s.cfExplainSectionAdjustments,
      ExplainSectionKind.pensionContributions => s.cfExplainSectionPension,
      ExplainSectionKind.unexplained => s.cfExplainSectionUnexplained,
    };

    String labelOf(ExplainLine l) => switch (l.kind) {
      ExplainLineKind.record => l.date == null ? '' : dateFmt.format(l.date!),
      ExplainLineKind.typeGroup => l.categoryType == null ? s.uncategorized : s.categoryTypeName(l.categoryType!),
      ExplainLineKind.category => categoryLabelFor(l.categoryId, categories, s),
      ExplainLineKind.uncategorized => s.uncategorized,
      ExplainLineKind.pension => s.cfExplainSectionPension,
      ExplainLineKind.account || ExplainLineKind.series || ExplainLineKind.unexplained => l.label,
    };

    List<Widget> lineWidgets(ExplainLine l, {int indent = 0}) {
      final label = labelOf(l);
      final drillable = l.transactionIds.isNotEmpty || l.recordIds.isNotEmpty || l.seriesKind != null;
      return [
        row(
          label,
          l.amount,
          // A count is of transactions: series, records and the pension row have none to show.
          count: switch (l.kind) {
            ExplainLineKind.typeGroup || ExplainLineKind.category || ExplainLineKind.uncategorized => l.count,
            _ => 0,
          },
          indent: indent,
          bold: l.children.isNotEmpty,
          key: ValueKey('cfLine:${l.kind.name}:${l.categoryType?.name}:${l.categoryId}:${l.seriesId}:${l.recordIds.join(',')}'),
          onTap: drillable ? () => onDrill(l, l.kind == ExplainLineKind.record ? s.cfExplainSectionIncome : label) : null,
        ),
        for (final c in l.children) ...lineWidgets(c, indent: indent + 1),
      ];
    }

    final body = <Widget>[
      Text(formula, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
      Text(s.cfExplainRowTapHint, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 12),
    ];
    final anyRow = e.sections.any((sec) => sec.lines.isNotEmpty);
    if (!anyRow) {
      body.add(Text(s.cfExplainNothing, key: const Key('cashFlowExplainNothing')));
    }
    for (final sec in e.sections) {
      final emptyIncome = sec.kind == ExplainSectionKind.incomeRecords && sec.lines.isEmpty;
      if (sec.lines.isEmpty && !emptyIncome) continue;
      body.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 2),
          child: Text(
            sectionTitle(sec.kind),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ),
      );
      if (emptyIncome) {
        body.add(
          Text(
            s.cfExplainNoIncomeRecords,
            key: const Key('cashFlowExplainNoIncome'),
            style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
          ),
        );
      }
      for (final l in sec.lines) {
        body.addAll(lineWidgets(l));
      }
    }
    body
      ..add(const Divider(height: 24))
      ..add(row(s.cfExplainTotal, e.total, bold: true, signed: false, key: const Key('cashFlowExplainTotal')));
    final shown = cellValue;
    if (shown != null) {
      body.add(
        Padding(
          key: const Key('cashFlowExplainMismatch'),
          padding: const EdgeInsets.only(top: 8),
          child: PrivacySentence(
            s.cfExplainMismatch(privacySlot(0)),
            figures: ['${amtFmt.format(shown)} $sym'],
            style: TextStyle(fontSize: 12, color: theme.colorScheme.error),
          ),
        ),
      );
    }

    return AlertDialog(
      title: Text(s.cfExplainTitle(period, figure)),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: body),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(s.close))],
    );
  }
}
