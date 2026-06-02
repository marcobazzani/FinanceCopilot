import 'dart:convert';
import 'dart:io';
import '../../utils/dialogs.dart';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../database/tables.dart';
import '../../services/providers/providers.dart';
import '../../utils/formatters.dart' as fmt;
import '../../utils/logger.dart';
import 'import/import_screen.dart';
import 'transaction_edit_screen.dart';
import '../../l10n/app_strings.dart';
import '../widgets/global_app_bar_actions.dart';
import '../widgets/mobile_pull_to_refresh.dart';
import '../widgets/privacy_text.dart';
import '../widgets/selection/selectable_item.dart';
import '../widgets/selection/selection_action_bar.dart';
import '../widgets/selection/selection_controller.dart';

part 'account_detail/entries.dart';
part 'account_detail/list_widgets.dart';
part 'account_detail/list_builders.dart';
part 'account_detail/transaction_actions.dart';
part 'account_detail/balance_dialog.dart';

final _log = getLogger('AccountDetailScreen');

/// Sentinel account id used by the virtual "All accounts" entry. The detail
/// screen detects this id and switches into a read-only, all-accounts mode.
const int kAllAccountsId = -1;

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
  String _searchQuery = '';
  final _selection = SelectionController<int>();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _selection.dispose();
    super.dispose();
  }

  bool get _isReadOnly => widget.account.id == kAllAccountsId;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final txStream = _isReadOnly ? ref.watch(allTransactionsProvider) : ref.watch(accountTransactionsProvider(widget.account.id));
    final locale = ref.watch(appLocaleProvider).value ?? Platform.localeName;
    final dateFmt = fmt.shortDateFormat(locale);
    final amtFmt = fmt.currencyFormat(locale, widget.account.currency);
    // Map accountId → name for the read-only All-accounts subtitle badge.
    final accountNameById = _isReadOnly
        ? {
            for (final a in (ref.watch(accountsProvider).value ?? const <Account>[])) a.id: a.name,
          }
        : const <int, String>{};

    return ListenableBuilder(
      listenable: _selection,
      builder: (lbCtx, _) {
        // Filtered ids snapshot for the action bar's "select all".
        List<int> visibleIds = const [];
        txStream.whenData((transactions) {
          final filtered = _searchQuery.isEmpty
              ? transactions
              : transactions.where((t) {
                  return t.description.toLowerCase().contains(_searchQuery) ||
                      (t.descriptionFull?.toLowerCase().contains(_searchQuery) ?? false) ||
                      t.amount.toString().contains(_searchQuery);
                }).toList();
          visibleIds = filtered.map((t) => t.id).toList();
        });
        _selection.setOrderedIds(visibleIds);

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.account.name),
            actions: globalAppBarActions(
              context,
              ref,
              local: [
                if (!_isReadOnly) ...[
                  IconButton(
                    icon: const Icon(Icons.file_upload),
                    tooltip: s.tooltipImportFile,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ImportScreen(preselectedAccountId: widget.account.id)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.account_balance_wallet),
                    tooltip: s.tooltipRecalcBalance,
                    onPressed: () => _showBalanceDialog(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: s.tooltipAddTransaction,
                    onPressed: () => _addTransaction(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: s.tooltipEditAccount,
                    onPressed: () => _editAccount(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep),
                    tooltip: s.tooltipWipeTransactions,
                    onPressed: () => _confirmWipeTransactions(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: s.tooltipDeleteAccount,
                    color: Colors.red,
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
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                ),
              ),
              // Transaction list
              Expanded(
                child: txStream.when(
                  data: (transactions) {
                    final filtered = _searchQuery.isEmpty
                        ? transactions
                        : transactions.where((t) {
                            return t.description.toLowerCase().contains(_searchQuery) ||
                                (t.descriptionFull?.toLowerCase().contains(_searchQuery) ?? false) ||
                                t.amount.toString().contains(_searchQuery);
                          }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          transactions.isEmpty ? s.noTransactionsImport : s.noMatchingTransactions,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    final dayHeaderFmt = fmt.fullDateFormat(locale);
                    final monthHeaderFmt = fmt.monthYearFormat(locale);
                    int dayKey(DateTime d) => DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
                    int monthKey(DateTime d) => d.year * 12 + (d.month - 1);

                    // In All-accounts mode, detect inter-account transfers:
                    // same day, same currency, equal & opposite amounts, on
                    // different accounts. The two legs collapse into one row and
                    // are excluded from income/expense totals.
                    final entries = _buildEntries(
                      filtered: filtered,
                      detectTransfers: _isReadOnly,
                      dayKey: dayKey,
                    );

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
                        accumulate(dayTotals, dayKey(e.tx.valueDate), e.tx.currency, e.tx.amount);
                        accumulate(monthTotals, monthKey(e.tx.valueDate), e.tx.currency, e.tx.amount);
                      }
                    }
                    return MobilePullToRefresh(
                      child: ListView.builder(
                        itemCount: entries.length,
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemBuilder: (ctx, i) {
                          final entry = entries[i];
                          final prevDate = i > 0 ? entries[i - 1].valueDate : null;
                          final showDayHeader = prevDate == null || dayKey(prevDate) != dayKey(entry.valueDate);
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
                            );
                          }

                          if (entry is _TransferEntry) {
                            body = _TransferTile(
                              entry: entry,
                              accountNameById: accountNameById,
                              locale: locale,
                              s: s,
                              legTileBuilder: buildSingleTxTile,
                            );
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
                                  totals: dayTotals[dayKey(entry.valueDate)] ?? const {},
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
                        '${transactions.length} ${s.transactions}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    );
                  }
                  // Use the last transaction in chronological order (latest date, then highest id)
                  // to match balance computation order.
                  final lastTx = transactions.reduce((a, b) {
                    final cmp = a.valueDate.compareTo(b.valueDate);
                    if (cmp != 0) return cmp > 0 ? a : b;
                    return a.id > b.id ? a : b;
                  });
                  final balance = lastTx.balanceAfter;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${transactions.length} ${s.transactions}', style: const TextStyle(fontSize: 13)),
                        PrivacyText(
                          balance != null
                              ? '${s.balance}: ${balance >= 0 ? '+' : ''}${amtFmt.format(balance)}'
                              : '${transactions.length} ${s.records}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: balance != null && balance >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
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
                )
              : null,
        );
      },
    );
  }

  /// Detects inter-account transfers in [filtered] (same day, same currency,
  /// equal & opposite amounts, different accounts) and returns a list of
  /// display entries where each transfer collapses its two legs into a single
  /// [_TransferEntry]. Non-transfer txs become [_TxEntry]s. Original order is
  /// preserved; transfers slot in at the position of whichever leg came first.
}

/// A row in the All-accounts list. Either a single transaction or an
/// inter-account transfer that collapses two opposing legs into one row.
