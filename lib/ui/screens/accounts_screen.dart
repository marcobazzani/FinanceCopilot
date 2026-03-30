import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../database/database.dart';
import '../../services/account_service.dart';
import '../../l10n/app_strings.dart';
import '../../services/providers/providers.dart';
import '../../utils/formatters.dart' as fmt;
import 'account_detail_screen.dart';
import 'dashboard/dashboard_screen.dart' show currencySymbol;
import '../widgets/privacy_text.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  final _expandedGroups = <int?>{};
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final statsAsync = ref.watch(accountStatsProvider);
    final intermediariesAsync = ref.watch(intermediariesProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider).value ?? 'EUR';
    final locale = ref.watch(appLocaleProvider).value ?? 'en_US';
    final convertedStats = ref.watch(convertedAccountStatsProvider).value ?? {};

    return Scaffold(
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return Center(
              child: Text(s.noAccountsYet, textAlign: TextAlign.center),
            );
          }

          final stats = statsAsync.value ?? {};
          final intermediaries = intermediariesAsync.value ?? [];

          // Auto-expand all groups on first build
          if (!_initialized) {
            _expandedGroups.addAll(intermediaries.map((i) => i.id));
            _expandedGroups.add(null); // unassigned group
            _initialized = true;
          }

          // Group accounts by intermediaryId
          final grouped = <int?, List<Account>>{};
          for (final account in accounts) {
            (grouped[account.intermediaryId] ??= []).add(account);
          }

          // Build ordered groups: intermediaries first (by sortOrder), then unassigned
          final groupOrder = <int?>[
            ...intermediaries.map((i) => i.id),
            if (grouped.containsKey(null)) null,
          ];

          return ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              for (final groupId in groupOrder) ...[
                if (grouped.containsKey(groupId))
                  _buildGroup(
                    context, s, groupId,
                    groupId == null ? null : intermediaries.firstWhere((i) => i.id == groupId),
                    grouped[groupId]!,
                    stats, convertedStats, baseCurrency, locale,
                    intermediaries,
                  ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(s.error(e))),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'add_intermediary',
            onPressed: () => _showIntermediaryDialog(context),
            child: const Icon(Icons.business),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'add_account',
            onPressed: () => _showCreateDialog(context),
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(
    BuildContext context,
    AppStrings s,
    int? groupId,
    Intermediary? intermediary,
    List<Account> accounts,
    Map<int, AccountStats> stats,
    Map<int, double?> convertedStats,
    String baseCurrency,
    String locale,
    List<Intermediary> allIntermediaries,
  ) {
    final isExpanded = _expandedGroups.contains(groupId);
    final title = intermediary?.name ?? s.unassigned;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() {
            if (isExpanded) {
              _expandedGroups.remove(groupId);
            } else {
              _expandedGroups.add(groupId);
            }
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                Icon(
                  intermediary != null ? Icons.business : Icons.folder_open,
                  size: 18,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$title (${accounts.length})',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
                if (intermediary != null)
                  PopupMenuButton<String>(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'edit', child: Text(s.editIntermediary)),
                      PopupMenuItem(value: 'delete', child: Text(s.deleteIntermediary)),
                    ],
                    onSelected: (v) {
                      if (v == 'edit') _showIntermediaryDialog(context, intermediary: intermediary);
                      if (v == 'delete') _confirmDeleteIntermediary(context, intermediary);
                    },
                  ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          ...accounts.asMap().entries.map((entry) {
            final account = entry.value;
            return _AccountTile(
              key: ValueKey(account.id),
              account: account,
              stats: stats[account.id],
              convertedBalance: convertedStats[account.id],
              baseCurrency: baseCurrency,
              locale: locale,
              allIntermediaries: allIntermediaries,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AccountDetailScreen(account: account),
                ),
              ),
              onMoveToIntermediary: (intId) {
                ref.read(intermediaryServiceProvider).moveAccount(account.id, intId);
              },
            );
          }),
        const Divider(height: 1),
      ],
    );
  }

  Future<void> _showIntermediaryDialog(BuildContext context, {Intermediary? intermediary}) async {
    final s = ref.read(appStringsProvider);
    final nameCtrl = TextEditingController(text: intermediary?.name ?? '');
    final isEdit = intermediary != null;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? s.editIntermediary : s.addIntermediary),
          content: TextField(
            controller: nameCtrl,
            decoration: InputDecoration(labelText: s.intermediaryName),
            autofocus: true,
            onChanged: (_) => setDialogState(() {}),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
            FilledButton(
              onPressed: nameCtrl.text.trim().isNotEmpty
                  ? () async {
                      final svc = ref.read(intermediaryServiceProvider);
                      if (isEdit) {
                        await svc.update(intermediary.id, IntermediariesCompanion(name: Value(nameCtrl.text.trim())));
                      } else {
                        await svc.create(name: nameCtrl.text.trim());
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  : null,
              child: Text(isEdit ? s.save : s.create),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteIntermediary(BuildContext context, Intermediary intermediary) async {
    final s = ref.read(appStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteIntermediary),
        content: Text(s.deleteIntermediaryConfirm(intermediary.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(intermediaryServiceProvider).delete(intermediary.id);
    }
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final s = ref.read(appStringsProvider);
    final nameCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(s.newAccountTitle),
          content: TextField(
            controller: nameCtrl,
            decoration: InputDecoration(
                labelText: s.name, hintText: s.accountNameHint),
            autofocus: true,
            onChanged: (_) => setDialogState(() {}),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(s.cancel)),
            FilledButton(
              onPressed: nameCtrl.text.trim().isNotEmpty
                  ? () async {
                      await ref.read(accountServiceProvider).create(
                            name: nameCtrl.text.trim(),
                            currency: ref.read(baseCurrencyProvider).value ?? 'EUR',
                          );
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  : null,
              child: Text(s.create),
            ),
          ],
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
  final List<Intermediary> allIntermediaries;
  final VoidCallback onTap;
  final void Function(int?) onMoveToIntermediary;

  const _AccountTile({
    super.key,
    required this.account,
    required this.stats,
    this.convertedBalance,
    required this.baseCurrency,
    required this.locale,
    required this.allIntermediaries,
    required this.onTap,
    required this.onMoveToIntermediary,
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
            const SizedBox(width: 28), // indent under group header
            // Account icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: account.isActive
                    ? theme.colorScheme.primaryContainer
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.account_balance,
                size: 20,
                color: account.isActive
                    ? theme.colorScheme.onPrimaryContainer
                    : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          account.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: account.isActive ? null : Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  _buildStatsLine(context, dateFormat, s),
                ],
              ),
            ),
            // Balance + currency
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (stats?.balance != null) ...[
                  PrivacyText(
                    '${balanceFormat.format(stats!.balance!)} ${account.currency}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: account.isActive
                          ? (stats!.balance! >= 0
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error)
                          : Colors.grey,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      account.currency,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (!account.isActive) ...[
                  const SizedBox(height: 2),
                  Text(s.inactive,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: Colors.grey)),
                ],
              ],
            ),
            // Move menu
            PopupMenuButton<int?>(
              iconSize: 18,
              padding: EdgeInsets.zero,
              tooltip: s.selectIntermediary,
              itemBuilder: (_) => [
                ...allIntermediaries
                    .where((i) => i.id != account.intermediaryId)
                    .map((i) => PopupMenuItem(value: i.id, child: Text(i.name))),
                if (account.intermediaryId != null)
                  PopupMenuItem(value: null, child: Text(s.unassigned)),
              ],
              onSelected: onMoveToIntermediary,
            ),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsLine(BuildContext context, DateFormat dateFormat, AppStrings s) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: Colors.grey.shade600,
      fontSize: 12,
    );

    if (stats == null || stats!.count == 0) {
      return Text(s.noTransactionsYet, style: style);
    }

    final parts = <InlineSpan>[];

    parts.add(TextSpan(
      text: '${stats!.count} ${s.transactions}',
      style: style,
    ));

    if (stats!.firstDate != null) {
      parts.add(TextSpan(
        text: '  ·  ${s.since(dateFormat.format(stats!.firstDate!))}',
        style: style,
      ));
    }
    if (stats!.lastDate != null) {
      parts.add(TextSpan(
        text: '  ·  ${s.lastRecord(dateFormat.format(stats!.lastDate!))}',
        style: style,
      ));
    }

    return RichText(
      text: TextSpan(children: parts),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}
