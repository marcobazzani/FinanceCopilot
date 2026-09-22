import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/widgets/category_edit_dialog.dart';
import 'package:finance_copilot/ui/screens/classification/classification_wizard_screen.dart';
import 'package:finance_copilot/ui/screens/classification/rule_edit_dialog.dart';
import 'package:finance_copilot/ui/widgets/category_ui.dart';
import 'package:finance_copilot/ui/widgets/global_app_bar_actions.dart';
import 'package:finance_copilot/ui/widgets/mobile_pull_to_refresh.dart';
import 'package:finance_copilot/utils/dialogs.dart';

/// Settings → Categories & rules. Two tabs: the category list and the rule
/// list, plus the two classifier actions.
class CategoriesRulesScreen extends ConsumerStatefulWidget {
  const CategoriesRulesScreen({super.key});

  @override
  ConsumerState<CategoriesRulesScreen> createState() => _CategoriesRulesScreenState();
}

class _CategoriesRulesScreenState extends ConsumerState<CategoriesRulesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  bool _showArchived = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // The "+" app-bar action depends on the active tab.
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.categoriesAndRules),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(key: const Key('tabRules'), text: s.rules),
            Tab(key: const Key('tabCategories'), text: s.categories),
          ],
        ),
        actions: globalAppBarActions(
          context,
          ref,
          local: [
            AppBarAction(
              icon: Icons.add,
              tooltip: _tabs.index == 0 ? s.newRule : s.newCategory,
              onPressed: () async {
                if (_tabs.index == 0) {
                  if (await showRuleEditDialog(context)) _markDirty();
                } else {
                  await showCategoryEditDialog(context);
                }
              },
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _RulesTab(busy: _busy, onRun: _run),
          _CategoriesTab(showArchived: _showArchived, onToggleArchived: (v) => setState(() => _showArchived = v)),
        ],
      ),
    );
  }

  void _markDirty() => ref.read(rulesDirtyProvider.notifier).state = true;

  Future<void> _run({required bool overwrite}) async {
    final s = ref.read(appStringsProvider);
    if (overwrite) {
      final ok = await showConfirmDialog(
        context,
        title: s.reclassifyEverythingTitle,
        content: s.reclassifyEverythingBody,
        confirmLabel: s.reclassifyEverything,
        cancelLabel: s.cancel,
      );
      if (!ok) return;
    }
    setState(() => _busy = true);
    try {
      final r = await ref.read(transactionClassifierServiceProvider).classifyAll(overwrite: overwrite);
      ref.read(rulesDirtyProvider.notifier).state = false;
      if (mounted) showInfoSnack(context, s.classifyResultSnack(r.changed, r.uncategorizedAfter));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// ── Rules ──

class _RulesTab extends ConsumerWidget {
  final bool busy;
  final Future<void> Function({required bool overwrite}) onRun;
  const _RulesTab({required this.busy, required this.onRun});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final rules = ref.watch(categorizationRulesProvider).value ?? const <AutoCategorizationRule>[];
    final byId = ref.watch(categoriesByIdProvider);
    final accounts = {for (final a in ref.watch(accountsProvider).value ?? const <Account>[]) a.id: a.name};
    final dirty = ref.watch(rulesDirtyProvider);
    final progress = ref.watch(classificationProgressProvider(null)).value;

    return MobilePullToRefresh(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          if (dirty)
            Card(
              key: const Key('rulesDirtyBanner'),
              color: theme.colorScheme.tertiaryContainer,
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(s.rulesChangedBanner),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (progress != null && progress.uncategorized > 0)
                FilledButton.icon(
                  key: const Key('openWizard'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClassificationWizardScreen())),
                  icon: const Icon(Icons.auto_fix_high),
                  label: Text(s.reviewUncategorizedCount(progress.uncategorized)),
                ),
              FilledButton.tonalIcon(
                key: const Key('classifyUncategorized'),
                onPressed: busy ? null : () => onRun(overwrite: false),
                icon: const Icon(Icons.play_arrow),
                label: Text(s.classifyUncategorized),
              ),
              OutlinedButton.icon(
                key: const Key('reclassifyEverything'),
                onPressed: busy ? null : () => onRun(overwrite: true),
                icon: const Icon(Icons.replay),
                label: Text(s.reclassifyEverything),
              ),
              if (busy) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          if (progress != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                s.wizardProgress(progress.categorized, progress.total, (progress.fraction * 100).round()),
                style: theme.textTheme.bodySmall,
              ),
            ),
          const Divider(),
          if (rules.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(s.noRulesYet, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: rules.length,
              // onReorderItem already delivers the post-removal target index.
              onReorderItem: (from, to) async {
                final ids = rules.map((r) => r.id).toList();
                final moved = ids.removeAt(from);
                ids.insert(to, moved);
                await ref.read(ruleServiceProvider).reorder(ids);
                ref.read(rulesDirtyProvider.notifier).state = true;
              },
              itemBuilder: (ctx, i) {
                final r = rules[i];
                return _RuleTile(
                  key: ValueKey('rule_${r.id}'),
                  index: i,
                  rule: r,
                  category: byId[r.categoryId],
                  accountName: r.accountId == null ? null : (accounts[r.accountId] ?? '#${r.accountId}'),
                  s: s,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _RuleTile extends ConsumerWidget {
  final int index;
  final AutoCategorizationRule rule;
  final Category? category;
  final String? accountName;
  final AppStrings s;
  const _RuleTile({super.key, required this.index, required this.rule, required this.category, required this.accountName, required this.s});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scope = <String>[
      ?accountName,
      if (rule.direction != RuleDirection.any) s.ruleDirectionName(rule.direction),
      if (rule.amountMin != null) '≥ ${rule.amountMin}',
      if (rule.amountMax != null) '≤ ${rule.amountMax}',
    ];
    final patternLabel = rule.matchType == RuleMatchType.entryKind
        ? s.entryKindName(BankEntryKind.values.firstWhere((k) => k.name == rule.pattern, orElse: () => BankEntryKind.unknown))
        : rule.pattern;

    return Dismissible(
      key: ValueKey('dismiss_rule_${rule.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      confirmDismiss: (_) => showConfirmDialog(
        context,
        title: s.delete,
        content: s.cannotBeUndone,
        confirmLabel: s.delete,
        cancelLabel: s.cancel,
        confirmColor: Colors.red,
      ),
      onDismissed: (_) async {
        await ref.read(ruleServiceProvider).delete(rule.id);
        ref.read(rulesDirtyProvider.notifier).state = true;
      },
      child: ListTile(
        leading: ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle)),
        title: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${s.ruleMatchTypeName(rule.matchType)}: ', style: theme.textTheme.bodySmall),
              TextSpan(
                text: patternLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Flexible(child: CategoryChip(category: category)),
            if (scope.isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(scope.join(' · '), style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
              ),
            ],
          ],
        ),
        trailing: Switch(
          value: rule.isActive,
          onChanged: (v) async {
            await ref.read(ruleServiceProvider).setActive(rule.id, v);
            ref.read(rulesDirtyProvider.notifier).state = true;
          },
        ),
        onTap: () async {
          if (await showRuleEditDialog(context, rule: rule)) ref.read(rulesDirtyProvider.notifier).state = true;
        },
      ),
    );
  }
}

// ── Categories ──

class _CategoriesTab extends ConsumerWidget {
  final bool showArchived;
  final ValueChanged<bool> onToggleArchived;
  const _CategoriesTab({required this.showArchived, required this.onToggleArchived});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final all = ref.watch(allCategoriesProvider).value ?? const <Category>[];
    final cats = showArchived ? all : all.where((c) => !c.isArchived).toList();

    return MobilePullToRefresh(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.showArchived),
                  value: showArchived,
                  onChanged: onToggleArchived,
                ),
              ),
              TextButton.icon(
                key: const Key('restoreDefaults'),
                onPressed: () async {
                  final n = await ref.read(categoryServiceProvider).restoreDefaults();
                  if (context.mounted) showInfoSnack(context, s.restoredCategories(n));
                },
                icon: const Icon(Icons.restore, size: 18),
                label: Text(s.restoreDefaultCategories),
              ),
            ],
          ),
          const Divider(),
          if (cats.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(s.noCategoriesYet, textAlign: TextAlign.center),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: cats.length,
              onReorderItem: (from, to) async {
                final ids = cats.map((c) => c.id).toList();
                final moved = ids.removeAt(from);
                ids.insert(to, moved);
                // Keep hidden archived rows after the visible ones.
                final hidden = all.where((c) => !ids.contains(c.id)).map((c) => c.id);
                await ref.read(categoryServiceProvider).reorder([...ids, ...hidden]);
              },
              itemBuilder: (ctx, i) {
                final c = cats[i];
                final color = categoryPaint(c, theme.colorScheme);
                return Dismissible(
                  key: ValueKey('dismiss_cat_${c.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: theme.colorScheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
                  ),
                  confirmDismiss: (_) => confirmAndDeleteCategory(context, ref, c),
                  child: ListTile(
                    key: ValueKey('cat_${c.id}'),
                    leading: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
                    title: Row(
                      children: [
                        Icon(categoryIcon(c), color: color, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            categoryLabel(c, s),
                            style: c.isArchived ? TextStyle(color: theme.disabledColor, decoration: TextDecoration.lineThrough) : null,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (c.isEssential) ...[const SizedBox(width: 6), Icon(Icons.star, size: 14, color: theme.colorScheme.tertiary)],
                      ],
                    ),
                    subtitle: Text(
                      [s.categoryTypeName(c.type), if (c.isArchived) s.archived].join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showCategoryEditDialog(context, category: c),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
