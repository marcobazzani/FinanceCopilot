import 'package:drift/drift.dart' hide Column;
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:io';
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
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final statsAsync = ref.watch(accountStatsProvider);
    final intermediariesAsync = ref.watch(intermediariesProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider).value ?? 'EUR';
    final locale = ref.watch(appLocaleProvider).value ?? Platform.localeName;
    final convertedStats = ref.watch(convertedAccountStatsProvider).value ?? {};

    return Scaffold(
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty && (intermediariesAsync.value ?? []).isEmpty) {
            return Center(
              child: Text(s.noAccountsYet, textAlign: TextAlign.center),
            );
          }

          final stats = statsAsync.value ?? {};
          final intermediaries = intermediariesAsync.value ?? [];

          if (!_initialized) {
            _expandedGroups.addAll(intermediaries.map((i) => i.id));
            _expandedGroups.add(null);
            _initialized = true;
          }

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
                if (_isDragging || (grouped[groupId]?.isNotEmpty ?? false))
                  _buildGroup(
                    context, s, groupId,
                    groupId == null ? null : intermediaries.firstWhere((i) => i.id == groupId),
                    grouped[groupId] ?? [],
                    stats, convertedStats, baseCurrency, locale,
                  ),
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
  ) {
    final isExpanded = _expandedGroups.contains(groupId);
    final title = intermediary?.name ?? s.unassigned;

    return DragTarget<_DraggedAccount>(
      onWillAcceptWithDetails: (details) => details.data.currentIntermediaryId != groupId,
      onAcceptWithDetails: (details) {
        ref.read(intermediaryServiceProvider).moveAccount(details.data.accountId, groupId);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          color: isHovering ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
          child: Column(
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
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (intermediary != null)
                        PopupMenuButton<String>(
                          iconSize: 22,
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
                ...accounts.map((account) {
                  return LongPressDraggable<_DraggedAccount>(
                    delay: const Duration(milliseconds: 150),
                    data: _DraggedAccount(account.id, account.intermediaryId),
                    onDragStarted: () => setState(() => _isDragging = true),
                    onDragEnd: (_) => setState(() => _isDragging = false),
                    onDraggableCanceled: (_, __) => setState(() => _isDragging = false),
                    feedback: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(account.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.3,
                      child: _AccountTile(
                        account: account,
                        stats: stats[account.id],
                        convertedBalance: convertedStats[account.id],
                        baseCurrency: baseCurrency,
                        locale: locale,
                        onTap: () {},
                      ),
                    ),
                    child: _AccountTile(
                      key: ValueKey(account.id),
                      account: account,
                      stats: stats[account.id],
                      convertedBalance: convertedStats[account.id],
                      baseCurrency: baseCurrency,
                      locale: locale,
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
          ),
        );
      },
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
            content: SizedBox(
              width: 350,
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

class _DraggedAccount {
  final int accountId;
  final int? currentIntermediaryId;
  const _DraggedAccount(this.accountId, this.currentIntermediaryId);
}

class _AccountTile extends ConsumerWidget {
  final Account account;
  final AccountStats? stats;
  final double? convertedBalance;
  final String baseCurrency;
  final String locale;
  final VoidCallback onTap;

  const _AccountTile({
    super.key,
    required this.account,
    required this.stats,
    this.convertedBalance,
    required this.baseCurrency,
    required this.locale,
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
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
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
