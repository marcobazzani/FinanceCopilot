import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/domain/account_service.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/utils/dialogs.dart';
import 'package:finance_copilot/utils/formatters.dart' as fmt;
import 'package:finance_copilot/ui/screens/accounts/account_detail_screen.dart';
import 'package:finance_copilot/ui/screens/accounts/capex_screen.dart' show AdjustmentsView;
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show currencySymbol;
import 'package:finance_copilot/ui/screens/accounts/income_screen.dart';
import 'package:finance_copilot/ui/screens/classification/categories_rules_screen.dart';
import 'package:finance_copilot/ui/widgets/empty_state.dart';
import 'package:finance_copilot/ui/widgets/global_app_bar_actions.dart';
import 'package:finance_copilot/ui/widgets/mobile_pull_to_refresh.dart';
import 'package:finance_copilot/ui/widgets/privacy_text.dart';
import 'package:finance_copilot/ui/widgets/selection/selectable_item.dart';
import 'package:finance_copilot/ui/widgets/selection/selection_action_bar.dart';
import 'package:finance_copilot/ui/widgets/selection/selection_controller.dart';
import 'package:finance_copilot/ui/widgets/swipe_to_delete.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final uncategorized = ref.watch(classificationProgressProvider(null)).value?.uncategorized ?? 0;
    final rulesDirty = ref.watch(rulesDirtyProvider);
    return Scaffold(
      appBar: AppBar(
        actions: globalAppBarActions(
          context,
          ref,
          local: [
            // The single classification entry point: the full-screen
            // Categories & rules view (wizard, rule runs, rules, categories).
            AppBarAction(
              icon: Icons.auto_fix_high,
              color: rulesDirty ? Theme.of(context).colorScheme.tertiary : null,
              tooltip: uncategorized > 0 ? s.reviewUncategorizedCount(uncategorized) : s.classificationWizardTitle,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CategoriesRulesScreen()),
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: s.navAccounts),
            Tab(text: s.navIncome),
            Tab(text: s.navAdjustments),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _AccountsListTab(),
          IncomeScreen(),
          AdjustmentsView(),
        ],
      ),
    );
  }
}

class _AccountsListTab extends ConsumerStatefulWidget {
  const _AccountsListTab();

  @override
  ConsumerState<_AccountsListTab> createState() => _AccountsListTabState();
}

class _AccountsListTabState extends ConsumerState<_AccountsListTab> {
  final _selection = SelectionController<int>();

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final statsAsync = ref.watch(accountStatsProvider);
    final intermediariesAsync = ref.watch(intermediariesProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider).value ?? 'EUR';
    final locale = ref.watch(appLocaleProvider).value ?? Platform.localeName;
    final convertedStats = ref.watch(convertedAccountStatsProvider).value ?? {};

    return ListenableBuilder(
      listenable: _selection,
      builder: (lbCtx, _) {
        // Build the id list in rendered order: grouped by intermediary, then
        // unassigned last. This matches what _buildGroup actually displays
        // and is what range-select on long-press needs.
        final accounts = accountsAsync.value ?? const <Account>[];
        final intermediaries = intermediariesAsync.value ?? const <Intermediary>[];
        final grouping = <int?, List<int>>{};
        for (final a in accounts) {
          (grouping[a.intermediaryId] ??= []).add(a.id);
        }
        final allAccountIds = <int>[
          for (final i in intermediaries) ...?grouping[i.id],
          ...?grouping[null],
        ];
        _selection.setOrderedIds(allAccountIds);
        return Scaffold(
          body: accountsAsync.when(
            data: (accounts) {
              if (accounts.isEmpty && (intermediariesAsync.value ?? []).isEmpty) {
                return EmptyState(
                  icon: Icons.account_balance,
                  message: s.noAccountsYet,
                  actionLabel: s.newAccountTitle,
                  onAction: () => showCreateAccountDialog(context),
                );
              }

              final stats = statsAsync.value ?? {};
              final intermediaries = intermediariesAsync.value ?? [];

              // Group accounts by intermediaryId
              final grouped = <int?, List<Account>>{};
              for (final account in accounts) {
                (grouped[account.intermediaryId] ??= []).add(account);
              }

              // Show ALL intermediaries (even empty ones) + unassigned
              final groupOrder = <int?>[
                ...intermediaries.map((i) => i.id),
                null, // always show unassigned
              ];

              return MobilePullToRefresh(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 80),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _AllAccountsTile(label: s.allAccounts, total: accounts.length),
                    for (final groupId in groupOrder)
                      if (grouped[groupId]?.isNotEmpty ?? false)
                        _buildGroup(
                          context,
                          groupId == null ? null : intermediaries.firstWhere((i) => i.id == groupId),
                          grouped[groupId] ?? [],
                          stats,
                          convertedStats,
                          baseCurrency,
                          locale,
                          intermediaries,
                        ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(s.error(e))),
          ),
          bottomNavigationBar: _selection.active
              ? SelectionActionBar<int>(
                  controller: _selection,
                  visibleIds: allAccountIds,
                  onDelete: (ids) => ref.read(accountServiceProvider).deleteMany(ids.toList()),
                )
              : null,
          floatingActionButton: _selection.active
              ? null
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'add_intermediary',
                      onPressed: () => _showManageIntermediariesDialog(context),
                      child: const Icon(Icons.business),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      heroTag: 'add_account',
                      onPressed: () => showCreateAccountDialog(context),
                      child: const Icon(Icons.add),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildGroup(
    BuildContext context,
    Intermediary? intermediary,
    List<Account> accounts,
    Map<int, AccountStats> stats,
    Map<int, double?> convertedStats,
    String baseCurrency,
    String locale,
    List<Intermediary> intermediaries,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntermediaryGroupHeader(intermediary: intermediary, count: accounts.length),
        ...accounts.map((account) {
          return SelectableItem<int>(
            key: ValueKey(account.id),
            controller: _selection,
            id: account.id,
            child: SwipeToDelete.custom(
              key: ValueKey('dismiss_account_${account.id}'),
              confirmAndDelete: () => confirmAndDeleteAccount(context, ref, account),
              child: _AccountTile(
                account: account,
                stats: stats[account.id],
                convertedBalance: convertedStats[account.id],
                baseCurrency: baseCurrency,
                locale: locale,
                intermediaries: intermediaries,
                onMove: (newId) => ref.read(intermediaryServiceProvider).moveAccount(account.id, newId),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AccountDetailScreen(account: account),
                  ),
                ),
              ),
            ),
          );
        }),
        const Divider(height: 1),
      ],
    );
  }

  Future<void> _showManageIntermediariesDialog(BuildContext context) => showManageIntermediariesDialog(context, ref);
}

/// Virtual top-level "All accounts" entry. Pinned at the top of the list.
/// Tapping pushes [AccountDetailScreen] in read-only mode showing the union
/// of every account's transactions.
class _AllAccountsTile extends ConsumerWidget {
  final String label;
  final int total;
  const _AllAccountsTile({required this.label, required this.total});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: ListTile(
        leading: const Icon(Icons.account_tree_outlined),
        title: Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text('$total'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AccountDetailScreen(account: buildAllAccountsVirtual(label)),
          ),
        ),
      ),
    );
  }
}

class _AccountTile extends ConsumerWidget {
  final Account account;
  final AccountStats? stats;
  final double? convertedBalance;
  final String baseCurrency;
  final String locale;
  final VoidCallback onTap;
  final List<Intermediary> intermediaries;
  final void Function(int? newIntermediaryId) onMove;

  const _AccountTile({
    required this.account,
    required this.stats,
    this.convertedBalance,
    required this.baseCurrency,
    required this.locale,
    required this.onTap,
    required this.intermediaries,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final balanceFormat = fmt.amountFormat(locale);
    final dateFormat = fmt.monthYearFormat(locale);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const SizedBox(width: 28),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: account.isActive ? theme.colorScheme.primaryContainer : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.account_balance,
                size: 20,
                color: account.isActive ? theme.colorScheme.onPrimaryContainer : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: account.isActive ? null : Colors.grey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  _buildStatsLine(context, dateFormat, s),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (stats?.balance != null) ...[
                  PrivacyText(
                    '${balanceFormat.format(stats!.balance!)} ${account.currency}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: account.isActive ? (stats!.balance! >= 0 ? theme.colorScheme.primary : theme.colorScheme.error) : Colors.grey,
                    ),
                  ),
                  if (account.currency != baseCurrency && convertedBalance != null) ...[
                    const SizedBox(height: 2),
                    PrivacyText(
                      '≈ ${balanceFormat.format(convertedBalance!)} ${currencySymbol(baseCurrency)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ] else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      account.currency,
                      style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                if (!account.isActive) ...[
                  const SizedBox(height: 2),
                  Text(s.inactive, style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
                ],
              ],
            ),
            const SizedBox(width: 4),
            IntermediaryMoveMenu(intermediaries: intermediaries, current: account.intermediaryId, allowUnassigned: true, onMove: onMove),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsLine(BuildContext context, DateFormat dateFormat, AppStrings s) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontSize: 12,
    );

    if (stats == null || stats!.count == 0) {
      return Text(s.noTransactionsYet, style: style);
    }

    final parts = <InlineSpan>[];
    parts.add(TextSpan(text: s.transactionCount(stats!.count), style: style));
    if (stats!.firstDate != null) {
      parts.add(TextSpan(text: '  ·  ${s.since(dateFormat.format(stats!.firstDate!))}', style: style));
    }
    if (stats!.lastDate != null) {
      parts.add(TextSpan(text: '  ·  ${s.lastRecord(dateFormat.format(stats!.lastDate!))}', style: style));
    }

    return RichText(
      text: TextSpan(children: parts),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}
