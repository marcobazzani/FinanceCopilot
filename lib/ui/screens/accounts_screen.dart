import 'package:drift/drift.dart' hide Column;
import 'dart:io';
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
import '../widgets/selection/selectable_item.dart';
import '../widgets/selection/selection_action_bar.dart';
import '../widgets/selection/selection_controller.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
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
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(s.noAccountsYet, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _showCreateDialog(context),
                    icon: const Icon(Icons.add),
                    label: Text(s.newAccountTitle),
                  ),
                ],
              ),
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

          return ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              for (final groupId in groupOrder)
                if (grouped[groupId]?.isNotEmpty ?? false)
                  _buildGroup(
                    context, s, groupId,
                    groupId == null ? null : intermediaries.firstWhere((i) => i.id == groupId),
                    grouped[groupId] ?? [],
                    stats, convertedStats, baseCurrency, locale,
                    intermediaries,
                  ),
            ],
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
                  onPressed: () => _showCreateDialog(context),
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
    AppStrings s,
    int? groupId,
    Intermediary? intermediary,
    List<Account> accounts,
    Map<int, AccountStats> stats,
    Map<int, double?> convertedStats,
    String baseCurrency,
    String locale,
    List<Intermediary> intermediaries,
  ) {
    final title = intermediary?.name ?? s.unassigned;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
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
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...accounts.map((account) {
          return SelectableItem<int>(
            key: ValueKey(account.id),
            controller: _selection,
            id: account.id,
            child: _AccountTile(
              account: account,
              stats: stats[account.id],
              convertedBalance: convertedStats[account.id],
              baseCurrency: baseCurrency,
              locale: locale,
              intermediaries: intermediaries,
              onMove: (newId) {
                if (newId != account.intermediaryId) {
                  ref.read(intermediaryServiceProvider).moveAccount(account.id, newId);
                }
              },
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AccountDetailScreen(account: account),
                ),
              ),
            ),
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
            textInputAction: TextInputAction.done,
            onChanged: (_) => setDialogState(() {}),
            onSubmitted: (_) async {
              if (nameCtrl.text.trim().isEmpty) return;
              final svc = ref.read(intermediaryServiceProvider);
              if (isEdit) {
                await svc.update(intermediary.id, IntermediariesCompanion(name: Value(nameCtrl.text.trim())));
              } else {
                await svc.create(name: nameCtrl.text.trim());
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
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

  Future<void> _showManageIntermediariesDialog(BuildContext context) async {
    final s = ref.read(appStringsProvider);

    await showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final intermediaries = ref.watch(intermediariesProvider).value ?? [];
          return AlertDialog(
            title: Text(s.intermediaries),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 350),
              child: SizedBox(
                height: 400,
                child: Column(
                  children: [
                    Expanded(
                      child: intermediaries.isEmpty
                          ? Center(child: Text(s.unassigned, style: TextStyle(color: Colors.grey)))
                          : ReorderableListView.builder(
                              shrinkWrap: true,
                              buildDefaultDragHandles: false,
                              itemCount: intermediaries.length,
                              onReorder: (oldIndex, newIndex) {
                                if (newIndex > oldIndex) newIndex--;
                                final reordered = List<Intermediary>.from(intermediaries);
                                final item = reordered.removeAt(oldIndex);
                                reordered.insert(newIndex, item);
                                ref.read(intermediaryServiceProvider)
                                    .reorder(reordered.map((i) => i.id).toList());
                              },
                              itemBuilder: (ctx, i) {
                                final inter = intermediaries[i];
                                return ListTile(
                                  key: ValueKey(inter.id),
                                  leading: ReorderableDragStartListener(
                                    index: i,
                                    child: const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
                                  ),
                                  title: Text(inter.name),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 18),
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _showIntermediaryDialog(context, intermediary: inter);
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 18),
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _confirmDeleteIntermediary(context, inter);
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showIntermediaryDialog(context);
                },
                child: Text(s.addIntermediary),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(s.close),
              ),
            ],
          );
        },
      ),
    );
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
            textInputAction: TextInputAction.done,
            onChanged: (_) => setDialogState(() {}),
            onSubmitted: (_) async {
              if (nameCtrl.text.trim().isEmpty) return;
              await ref.read(accountServiceProvider).create(
                    name: nameCtrl.text.trim(),
                    currency: ref.read(baseCurrencyProvider).value ?? 'EUR',
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            },
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
                  Text(s.inactive,
                      style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
                ],
              ],
            ),
            const SizedBox(width: 4),
            PopupMenuButton<int?>(
              icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
              tooltip: s.selectIntermediary,
              itemBuilder: (_) => <PopupMenuEntry<int?>>[
                PopupMenuItem<int?>(
                  enabled: false,
                  child: Text(
                    s.selectIntermediary,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                const PopupMenuDivider(),
                for (final i in intermediaries)
                  PopupMenuItem<int?>(
                    value: i.id,
                    child: Row(
                      children: [
                        const Icon(Icons.business, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(i.name)),
                        if (account.intermediaryId == i.id)
                          const Icon(Icons.check, size: 18),
                      ],
                    ),
                  ),
                PopupMenuItem<int?>(
                  value: null,
                  child: Row(
                    children: [
                      const Icon(Icons.folder_open, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(s.unassigned)),
                      if (account.intermediaryId == null)
                        const Icon(Icons.check, size: 18),
                    ],
                  ),
                ),
              ],
              onSelected: onMove,
            ),
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
    parts.add(TextSpan(text: '${stats!.count} ${s.transactions}', style: style));
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
