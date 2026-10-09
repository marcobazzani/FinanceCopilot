import 'dart:convert';
import 'dart:io';
import 'package:finance_copilot/utils/dialogs.dart';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/services/classification/ledger_roles.dart' show ledgerDayKey;
import 'package:finance_copilot/services/domain/entry_pairing.dart';
import 'package:finance_copilot/services/domain/adjustment_items.dart';
import 'package:finance_copilot/services/import/stored_import_data.dart';
import 'package:finance_copilot/ui/screens/accounts/transaction_filter.dart';
import 'package:finance_copilot/utils/formatters.dart' as fmt;
import 'package:finance_copilot/utils/logger.dart';
import 'package:finance_copilot/ui/screens/import/import_screen.dart';
import 'package:finance_copilot/ui/screens/events/transaction_edit_screen.dart';
import 'package:finance_copilot/ui/screens/events/event_edit_screen.dart';
import 'package:finance_copilot/ui/screens/classification/classification_wizard_screen.dart';
import 'package:finance_copilot/ui/widgets/category_ui.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/ui/widgets/empty_state.dart';
import 'package:finance_copilot/ui/widgets/global_app_bar_actions.dart';
import 'package:finance_copilot/ui/widgets/income_split_dialog.dart';
import 'package:finance_copilot/ui/widgets/mobile_pull_to_refresh.dart';
import 'package:finance_copilot/ui/widgets/privacy_text.dart';
import 'package:finance_copilot/ui/widgets/selection/selectable_item.dart';
import 'package:finance_copilot/ui/widgets/selection/selection_action_bar.dart';
import 'package:finance_copilot/ui/widgets/selection/selection_controller.dart';
import 'package:finance_copilot/ui/widgets/swipe_to_delete.dart';

part 'entries.dart';
part 'list_widgets.dart';
part 'list_builders.dart';
part 'transaction_actions.dart';
part 'balance_dialog.dart';
part 'filter_bar.dart';

final _log = getLogger('AccountDetailScreen');

/// Sentinel account id used by the virtual "All accounts" entry. The detail
/// screen detects this id and switches into a read-only, all-accounts mode.
const int kAllAccountsId = -1;

/// The rendered ledger (see `_composeEntries`): its rows once searched and
/// filtered, the transactions shown as adjustments (id → badge), and whether
/// the ledger holds no row at all — before any search or filter.
typedef _ComposedLedger = ({List<_Entry> entries, Map<int, String> annotatedTxIds, bool ledgerEmpty});

/// Builds the virtual Account row used by the "All accounts" parent entry.
/// id == [kAllAccountsId]. Currency is intentionally a placeholder — the
/// detail screen formats each row in its own currency in this mode.
Account buildAllAccountsVirtual(String label) => Account(
  id: kAllAccountsId,
  name: label,
  type: AccountType.bank,
  currency: 'EUR',
  institution: '',
  intermediaryId: null,
  isActive: true,
  includeInNetWorth: true,
  sortOrder: -1,
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
);

/// Shows transactions for a single account, with search/filter and edit/delete.
class AccountDetailScreen extends ConsumerStatefulWidget {
  final Account account;
  const AccountDetailScreen({super.key, required this.account});

  @override
  ConsumerState<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  final _searchCtrl = TextEditingController();
  TransactionFilter _filter = TransactionFilter.none;
  final _selection = SelectionController<int>();

  // Memoized result of the (pure) entry pipeline. _composeEntries is O(n) over
  // the transactions and runs on every build — and the build runs on every
  // selection change too. On large accounts (10k+ rows) recomputing twice per
  // frame janks the UI, so we cache by the identity of the inputs that affect
  // the result and only recompute when one of them actually changes. The
  // filter (search text + structured filter) lives entirely in _filter now, so
  // a change always yields a new instance and busts the cache by identity.
  List<Transaction>? _memoTxns;
  TransactionFilter? _memoFilter;
  AdjustmentInputs? _memoAdj;
  _ComposedLedger? _memoComposed;

  _ComposedLedger _composeEntriesCached(
    List<Transaction> transactions, {
    required AdjustmentInputs? adjInputs,
    required AppStrings s,
  }) {
    if (_memoComposed != null && identical(_memoTxns, transactions) && identical(_memoFilter, _filter) && identical(_memoAdj, adjInputs)) {
      return _memoComposed!;
    }
    final result = _composeEntries(transactions, adjInputs: adjInputs, s: s);
    _memoTxns = transactions;
    _memoFilter = _filter;
    _memoAdj = adjInputs;
    _memoComposed = result;
    return result;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _selection.dispose();
    super.dispose();
  }

  bool get _isReadOnly => widget.account.id == kAllAccountsId;

  /// Account scope for classification providers: null = whole ledger.
  int? get _scopeAccountId => _isReadOnly ? null : widget.account.id;

  /// This account's live row in [accounts], not the snapshot the screen was
  /// opened with: an edit made here shows at once, and the next edit starts
  /// from it instead of reverting it.
  Account _liveAccount(List<Account>? accounts) => accounts?.where((a) => a.id == widget.account.id).firstOrNull ?? widget.account;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final txStream = _isReadOnly ? ref.watch(allTransactionsProvider) : ref.watch(accountTransactionsProvider(widget.account.id));
    final locale = ref.watch(appLocaleProvider).value ?? Platform.localeName;
    final dateFmt = fmt.shortDateFormat(locale);
    final accounts = ref.watch(accountsProvider).value;
    final account = _liveAccount(accounts);
    final amtFmt = fmt.currencyFormat(locale, account.currency);
    // Map accountId → name for the read-only All-accounts subtitle badge.
    final accountNameById = _isReadOnly
        ? {
            for (final a in (accounts ?? const <Account>[])) a.id: a.name,
          }
        : const <int, String>{};

    // Adjustment inputs (extraordinary events). Used in BOTH views: anchor /
    // reimbursement / financed adjustments are tied to real transactions
    // (which belong to a specific account), so they annotate matching rows in
    // single-account view too. Synthetic "Saving for X" spread rows have no
    // account and are materialized ONLY in the merged All-accounts view.
    final adjInputs = ref.watch(adjustmentInputsProvider).value;

    return ListenableBuilder(
      listenable: _selection,
      builder: (lbCtx, _) {
        // Ids eligible for selection ("select all" in the action bar). Only
        // meaningful in single-account view (read-only mode has no selection).
        // Derived from the SAME composed entry list that drives the rendered
        // list, so selection never includes hidden or collapsed rows. Only
        // standalone transaction rows render as selectable items.
        List<int> visibleIds = const [];
        txStream.whenData((transactions) {
          final composed = _composeEntriesCached(transactions, adjInputs: adjInputs, s: s);
          visibleIds = [
            for (final e in composed.entries)
              if (e is _TxEntry) e.tx.id,
          ];
        });
        _selection.setOrderedIds(visibleIds);

        return Scaffold(
          appBar: AppBar(
            title: Text(account.name),
            actions: globalAppBarActions(
              context,
              ref,
              local: [
                if (!_isReadOnly) ...[
                  AppBarAction(
                    icon: Icons.file_upload,
                    tooltip: s.tooltipImportFile,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ImportScreen(preselectedAccountId: widget.account.id)),
                    ),
                  ),
                  AppBarAction(
                    icon: Icons.history,
                    tooltip: s.rerunImportFromStored,
                    onPressed: () => _rerunImportFromStored(context),
                  ),
                  AppBarAction(
                    icon: Icons.account_balance_wallet,
                    tooltip: s.tooltipRecalcBalance,
                    onPressed: () => _showBalanceDialog(context),
                  ),
                  AppBarAction(
                    icon: Icons.add,
                    tooltip: s.tooltipAddTransaction,
                    onPressed: () => _addTransaction(),
                  ),
                  AppBarAction(
                    icon: Icons.edit,
                    tooltip: s.tooltipEditAccount,
                    onPressed: () => _editAccount(context),
                  ),
                  AppBarAction(
                    icon: Icons.delete_sweep,
                    tooltip: s.tooltipWipeTransactions,
                    onPressed: () => _confirmWipeTransactions(context),
                  ),
                  AppBarAction(
                    icon: Icons.delete_outline,
                    color: Colors.red,
                    tooltip: s.tooltipDeleteAccount,
                    onPressed: () => _confirmDeleteAccount(context),
                  ),
                ],
              ],
            ),
          ),
          body: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: s.searchTransactions,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: _filter.containsText.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _filter = _filter.copyWith(containsText: ''));
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _filter = _filter.copyWith(containsText: v)),
                ),
              ),
              // Structured filter bar: kind chips + date range + amount range.
              // Transfer/Adjustment chips only in the merged All-accounts view.
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _LedgerFilterBar(
                  filter: _filter,
                  showTransfer: _isReadOnly,
                  showAdjustment: (adjInputs?.events.isNotEmpty ?? false),
                  locale: locale,
                  s: s,
                  categories: ref.watch(categoriesProvider).value ?? const [],
                  uncategorizedCount: ref.watch(classificationProgressProvider(_scopeAccountId)).value?.uncategorized ?? 0,
                  onReviewUncategorized: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ClassificationWizardScreen(accountId: _scopeAccountId)),
                  ),
                  onChanged: (f) => setState(() {
                    _filter = f;
                    // Keep the search box in sync when contains-text is changed
                    // from the sheet, a pill removal, or clear-all.
                    if (_searchCtrl.text != f.containsText) {
                      _searchCtrl.text = f.containsText;
                    }
                  }),
                ),
              ),
              // Transaction list
              Expanded(
                child: txStream.when(
                  data: (transactions) {
                    final dayHeaderFmt = fmt.fullDateFormat(locale);
                    final monthHeaderFmt = fmt.monthYearFormat(locale);
                    int monthKey(DateTime d) => d.year * 12 + (d.month - 1);

                    // Single source of truth: search + collapse + adjustments +
                    // structured filter (see _composeEntries). Cached so it runs
                    // at most once per (txns, query, filter, adjInputs) change —
                    // not twice per build, and not on selection-only rebuilds.
                    final composed = _composeEntriesCached(transactions, adjInputs: adjInputs, s: s);
                    final entries = composed.entries;
                    final annotatedTxIds = composed.annotatedTxIds;

                    // Nothing to list: either the ledger holds no row at all
                    // (the All-accounts view lists its synthetic saving rows
                    // even before any account holds a transaction), or the
                    // search and filters match none of its rows.
                    if (entries.isEmpty) {
                      return composed.ledgerEmpty
                          ? EmptyState(icon: Icons.receipt_long, message: s.noTransactionsImport)
                          : EmptyState(icon: Icons.search_off, message: s.noMatchingTransactions);
                    }

                    // Pre-compute per-day/per-month income/expense totals, grouped
                    // by currency so mixed-currency views can show one line per
                    // currency. Transfer legs are skipped.
                    final Map<int, Map<String, ({double income, double expense})>> dayTotals = {};
                    final Map<int, Map<String, ({double income, double expense})>> monthTotals = {};
                    void accumulate(
                      Map<int, Map<String, ({double income, double expense})>> bucket,
                      int k,
                      String ccy,
                      double amt,
                    ) {
                      final byCcy = bucket.putIfAbsent(k, () => {});
                      final cur = byCcy[ccy] ?? (income: 0.0, expense: 0.0);
                      byCcy[ccy] = amt >= 0
                          ? (income: cur.income + amt, expense: cur.expense)
                          : (income: cur.income, expense: cur.expense + amt);
                    }

                    for (final e in entries) {
                      if (e is _TxEntry) {
                        // Cancelled transactions never moved money — show them
                        // (struck-through) but exclude from income/expense totals.
                        if (e.tx.status == TransactionStatus.cancelled) continue;
                        // Adjustment-linked transactions (anchor / reimbursement)
                        // are accounted for via the adjustment mechanism (NAV),
                        // not as cashflow — show but exclude from totals.
                        if (annotatedTxIds.containsKey(e.tx.id)) continue;
                        accumulate(dayTotals, ledgerDayKey(e.tx.valueDate), e.tx.currency, e.tx.amount);
                        accumulate(monthTotals, monthKey(e.tx.valueDate), e.tx.currency, e.tx.amount);
                      } else if (e is _AdjustmentEntry) {
                        // Synthetic "Saving for X" rows DO count, mirroring NAV's
                        // distribution of the spread over time, in the spread
                        // event's currency.
                        accumulate(dayTotals, ledgerDayKey(e.valueDate), e.currency, e.amount);
                        accumulate(monthTotals, monthKey(e.valueDate), e.currency, e.amount);
                      }
                    }
                    return MobilePullToRefresh(
                      child: ListView.builder(
                        itemCount: entries.length,
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemBuilder: (ctx, i) {
                          final entry = entries[i];
                          final prevDate = i > 0 ? entries[i - 1].valueDate : null;
                          final showDayHeader = prevDate == null || ledgerDayKey(prevDate) != ledgerDayKey(entry.valueDate);
                          final showMonthHeader = prevDate == null || monthKey(prevDate) != monthKey(entry.valueDate);

                          Widget body;
                          Widget buildSingleTxTile(Transaction tx) {
                            final isPositive = tx.amount >= 0;
                            final rowAmtFmt = _isReadOnly ? fmt.currencyFormat(locale, tx.currency) : amtFmt;
                            return _buildTxTile(
                              context: ctx,
                              tx: tx,
                              isPositive: isPositive,
                              rowAmtFmt: rowAmtFmt,
                              dateFmt: dateFmt,
                              accountNameById: accountNameById,
                              s: s,
                              adjustedLabel: annotatedTxIds[tx.id],
                            );
                          }

                          if (entry is _PairEntry) {
                            body = _PairTile(
                              // The expanded state belongs to the pair: without
                              // a key it stayed with the list position, and a
                              // search or refresh expanded another pair.
                              key: ValueKey(('pair', entry.outflow.id, entry.inflow.id)),
                              entry: entry,
                              accountNameById: accountNameById,
                              locale: locale,
                              s: s,
                              legTileBuilder: buildSingleTxTile,
                            );
                          } else if (entry is _AdjustmentEntry) {
                            body = _AdjustmentTile(entry: entry, locale: locale, s: s);
                          } else {
                            body = buildSingleTxTile((entry as _TxEntry).tx);
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (showMonthHeader)
                                _PeriodHeader(
                                  label: monthHeaderFmt.format(entry.valueDate),
                                  totals: monthTotals[monthKey(entry.valueDate)] ?? const {},
                                  locale: locale,
                                  isMonth: true,
                                ),
                              if (showDayHeader)
                                _PeriodHeader(
                                  label: dayHeaderFmt.format(entry.valueDate),
                                  totals: dayTotals[ledgerDayKey(entry.valueDate)] ?? const {},
                                  locale: locale,
                                  isMonth: false,
                                )
                              else
                                const Divider(height: 1),
                              body,
                            ],
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text(s.error(e))),
                ),
              ),
              // Summary bar
              txStream.when(
                data: (transactions) {
                  if (transactions.isEmpty) return const SizedBox();
                  if (_isReadOnly) {
                    // Mixed-currency union — balance is meaningless. Show count only.
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
                      ),
                      child: Text(
                        s.transactionCount(transactions.length),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    );
                  }
                  // The account's balance by the accounts list's rule
                  // (AccountService): the latest row — by value date, then
                  // highest id — among those that HAVE a balance, so a
                  // hand-entered row without one does not hide it.
                  final balance = transactions.where((t) => t.balanceAfter != null).fold<Transaction?>(null, (latest, t) {
                    if (latest == null) return t;
                    final cmp = t.valueDate.compareTo(latest.valueDate);
                    return cmp > 0 || (cmp == 0 && t.id > latest.id) ? t : latest;
                  })?.balanceAfter;
                  final summaryStyle = TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: balance != null && balance >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                  );
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(s.transactionCount(transactions.length), style: const TextStyle(fontSize: 13)),
                        if (balance != null)
                          PrivacyText('${s.balance}: ${balance >= 0 ? '+' : ''}${amtFmt.format(balance)}', style: summaryStyle)
                        else
                          // No balance to show, just a count of records: shape, not magnitude.
                          Text(s.recordCount(transactions.length), style: summaryStyle),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox(),
                error: (_, _) => const SizedBox(),
              ),
            ],
          ),
          bottomNavigationBar: (!_isReadOnly && _selection.active)
              ? SelectionActionBar<int>(
                  controller: _selection,
                  visibleIds: visibleIds,
                  onDelete: (ids) => ref.read(transactionServiceProvider).deleteMany(ids.toList()),
                  extraActions: [
                    IconButton(
                      key: const Key('bulkSetCategory'),
                      icon: const Icon(Icons.label_outline),
                      tooltip: s.setCategory,
                      onPressed: () => _bulkSetCategory(context),
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }
}

/// A row in the All-accounts list. Either a single transaction or an
/// inter-account transfer that collapses two opposing legs into one row.
