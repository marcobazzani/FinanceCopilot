import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../database/database.dart';
import '../../services/account_service.dart';
import '../../l10n/app_strings.dart';
import '../../services/providers.dart';
import '../../utils/formatters.dart' as fmt;
import 'account_detail_screen.dart';
import 'dashboard_screen.dart' show currencySymbol;
import '../widgets/privacy_text.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final statsAsync = ref.watch(accountStatsProvider);
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

          return ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: accounts.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex--;
              final reordered = List<Account>.from(accounts);
              final item = reordered.removeAt(oldIndex);
              reordered.insert(newIndex, item);
              ref
                  .read(accountServiceProvider)
                  .reorder(reordered.map((a) => a.id).toList());
            },
            itemBuilder: (ctx, i) {
              final account = accounts[i] as Account;
              final stat = stats[account.id];

              return _AccountTile(
                key: ValueKey(account.id),
                account: account,
                stats: stat,
                convertedBalance: convertedStats[account.id],
                baseCurrency: baseCurrency,
                locale: locale,
                index: i,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AccountDetailScreen(account: account),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(s.error(e))),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
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
  final int index;
  final VoidCallback onTap;

  const _AccountTile({
    super.key,
    required this.account,
    required this.stats,
    this.convertedBalance,
    required this.baseCurrency,
    required this.locale,
    required this.index,
    required this.onTap,
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
            // Drag handle
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.drag_handle, color: Colors.grey, size: 20),
              ),
            ),
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
                  // Name + currency badge
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
                      if (account.institution.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          account.institution,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Stats line
                  _buildStatsLine(context, dateFormat, s),
                ],
              ),
            ),
            // Balance + currency + chevron
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
                  // Show converted balance if currency differs from base
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
            const SizedBox(width: 4),
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
