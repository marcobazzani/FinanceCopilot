import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/classification/spending_by_category.dart';

/// Role of a node in the yearly cash-flow Sankey.
enum CashFlowNodeKind {
  /// The year's income (Income records, same figure as the yearly chart).
  income,

  /// Categorized spending the yearly figures do not explain: money that
  /// came in without an Income record.
  untrackedIncome,

  /// Savings went down in the year: the drop funded part of the expenses.
  fromSavings,

  /// Everything available in the year: income plus what came out of savings.
  total,
  essential,
  discretionary,

  /// Ledger spending without a category: tracked, not yet classified.
  uncategorized,

  /// Expenses the ledger does not contain at all (cash, accounts never
  /// imported): yearly expenses − ledger spending.
  untrackedExpenses,

  /// Savings went up in the year.
  saved,

  /// An expense category (categorized ledger spending).
  expense,
}

class CashFlowNode {
  final String id;
  final CashFlowNodeKind kind;

  /// Column, left to right: 0 sources, 1 total, 2 groups, 3 expense categories.
  final int layer;
  final double value;
  final int? categoryId;
  const CashFlowNode({required this.id, required this.kind, required this.layer, required this.value, this.categoryId});

  @override
  String toString() => '$id=$value';
}

class CashFlowLink {
  final String from;
  final String to;
  final double value;
  const CashFlowLink(this.from, this.to, this.value);

  @override
  String toString() => '$from->$to=$value';
}

/// One year of cash flow as a Sankey graph:
/// income (+ untracked income, + from savings) → available → essential /
/// discretionary / uncategorized / untracked expenses / saved → expense
/// categories.
///
/// [income], [savings] and [expenses] are the yearly Income/Expense/Savings
/// figures (expenses = income − savings), so both charts always agree. The
/// ledger splits the expenses into categorized and uncategorized spending
/// (tracked either way), and the gap between ledger spending and the yearly
/// expenses is always shown explicitly, never spread or dropped:
/// ledger < expenses → the rest is "untracked expenses" (not in the ledger);
/// ledger > expenses → the excess is "untracked income" (money spent that no
/// Income record accounts for).
class CashFlowSankey {
  /// In layer order; within a layer, top to bottom.
  final List<CashFlowNode> nodes;
  final List<CashFlowLink> links;
  final double income;
  final double savings;

  /// Categorized ledger spending of the year (named categories only).
  final double categorized;

  /// Ledger spending of the year without a category.
  final double uncategorized;

  const CashFlowSankey({
    required this.nodes,
    required this.links,
    required this.income,
    required this.savings,
    required this.categorized,
    required this.uncategorized,
  });

  /// All spending the ledger holds for the year.
  double get ledgerSpending => categorized + uncategorized;

  double get expenses => income - savings;

  /// Ledger spending above the yearly expenses.
  double get untrackedIncome => ledgerSpending > expenses ? ledgerSpending - expenses : 0;

  /// Yearly expenses the ledger does not contain.
  double get untrackedExpenses => expenses > ledgerSpending ? expenses - ledgerSpending : 0;
  bool get isEmpty => nodes.isEmpty;

  /// Share of income saved; null without income (same as the yearly chart's
  /// definition, which only reports it when income > 0).
  double? get savingsRate => income > 0 ? savings / income : null;

  /// The value every column is measured against (the total node).
  double get scaleTotal => income + untrackedIncome + (savings < 0 ? -savings : 0);
}

const _eps = 0.005;

String cashFlowExpenseNodeId(int categoryId) => 'out:$categoryId';

/// [income] and [savings] come from the yearly Income/Expense/Savings bucket
/// of [year]; [spending] supplies the category split of the expenses.
CashFlowSankey buildCashFlowSankey({
  required int year,
  required double income,
  required double savings,
  required SpendingByCategoryData spending,
  required Map<int, Category> categories,
}) {
  final named =
      <MapEntry<int, double>>[
        for (final e in (spending.byYear[year] ?? const <int?, double>{}).entries)
          if (e.key != null && e.value >= _eps) MapEntry(e.key!, e.value),
      ]..sort((a, b) {
        final c = b.value.compareTo(a.value);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
  final categorized = named.fold(0.0, (a, e) => a + e.value);
  final uncategorized = spending.amount(year, null);
  final expenses = income - savings;

  CashFlowSankey result(List<CashFlowNode> nodes, List<CashFlowLink> links) =>
      CashFlowSankey(nodes: nodes, links: links, income: income, savings: savings, categorized: categorized, uncategorized: uncategorized);

  if (income.abs() < _eps && savings.abs() < _eps && categorized + uncategorized < _eps) return result(const [], const []);
  final untrackedIncome = categorized + uncategorized - expenses;

  final nodes = <CashFlowNode>[];
  final links = <CashFlowLink>[];
  const total = 'total';

  // Layer 0: sources.
  if (income >= _eps) {
    nodes.add(CashFlowNode(id: 'income', kind: CashFlowNodeKind.income, layer: 0, value: income));
    links.add(CashFlowLink('income', total, income));
  }
  if (untrackedIncome >= _eps) {
    nodes.add(CashFlowNode(id: 'untrackedIncome', kind: CashFlowNodeKind.untrackedIncome, layer: 0, value: untrackedIncome));
    links.add(CashFlowLink('untrackedIncome', total, untrackedIncome));
  }
  if (savings <= -_eps) {
    nodes.add(CashFlowNode(id: 'fromSavings', kind: CashFlowNodeKind.fromSavings, layer: 0, value: -savings));
    links.add(CashFlowLink('fromSavings', total, -savings));
  }

  // Layer 1: total.
  final available = income + (untrackedIncome > 0 ? untrackedIncome : 0) + (savings < 0 ? -savings : 0);
  nodes.add(CashFlowNode(id: total, kind: CashFlowNodeKind.total, layer: 1, value: available));

  // Layers 2-3: where it went.
  final categoryNodes = <CashFlowNode>[];
  void group(String id, CashFlowNodeKind kind, List<MapEntry<int, double>> cats) {
    if (cats.isEmpty) return;
    final sum = cats.fold(0.0, (a, e) => a + e.value);
    nodes.add(CashFlowNode(id: id, kind: kind, layer: 2, value: sum));
    links.add(CashFlowLink(total, id, sum));
    for (final e in cats) {
      final cid = cashFlowExpenseNodeId(e.key);
      categoryNodes.add(CashFlowNode(id: cid, kind: CashFlowNodeKind.expense, layer: 3, value: e.value, categoryId: e.key));
      links.add(CashFlowLink(id, cid, e.value));
    }
  }

  group('grp:essential', CashFlowNodeKind.essential, [
    for (final e in named)
      if (categories[e.key]?.isEssential == true) e,
  ]);
  group('grp:discretionary', CashFlowNodeKind.discretionary, [
    for (final e in named)
      if (categories[e.key]?.isEssential != true) e,
  ]);
  if (uncategorized >= _eps) {
    nodes.add(CashFlowNode(id: 'grp:uncategorized', kind: CashFlowNodeKind.uncategorized, layer: 2, value: uncategorized));
    links.add(CashFlowLink(total, 'grp:uncategorized', uncategorized));
  }
  if (-untrackedIncome >= _eps) {
    nodes.add(CashFlowNode(id: 'grp:untracked', kind: CashFlowNodeKind.untrackedExpenses, layer: 2, value: -untrackedIncome));
    links.add(CashFlowLink(total, 'grp:untracked', -untrackedIncome));
  }
  if (savings >= _eps) {
    nodes.add(CashFlowNode(id: 'saved', kind: CashFlowNodeKind.saved, layer: 2, value: savings));
    links.add(CashFlowLink(total, 'saved', savings));
  }
  nodes.addAll(categoryNodes);
  return result(nodes, links);
}
