import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/classification/rule_service.dart';
import 'package:finance_copilot/services/classification/transaction_classifier_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/widgets/category_edit_dialog.dart';
import 'package:finance_copilot/ui/widgets/category_ui.dart';
import 'package:finance_copilot/ui/widgets/global_app_bar_actions.dart';
import 'package:finance_copilot/ui/widgets/mobile_pull_to_refresh.dart';
import 'package:finance_copilot/ui/widgets/privacy_text.dart';
import 'package:finance_copilot/utils/dialogs.dart';
import 'package:finance_copilot/utils/formatters.dart' as fmt;
import 'package:finance_copilot/utils/logger.dart';

final _log = getLogger('ClassificationWizard');

/// Samples (newest first) of the uncategorized rows of one merchant group.
final _groupSamplesProvider = FutureProvider.autoDispose.family<List<Transaction>, ({String key, int? accountId})>((
  ref,
  arg,
) {
  // Re-fetch whenever the ledger changes (progress stream ticks on writes).
  ref.watch(classificationProgressProvider(arg.accountId));
  return ref.read(transactionClassifierServiceProvider).uncategorizedOf(arg.key, accountId: arg.accountId, limit: 4);
});

enum _RuleScope { merchant, contains, entryKind, onlyThis }

/// One applied wizard step, kept for exact undo.
class _WizardStep {
  final int? ruleId;
  final Set<int> changedIds;
  const _WizardStep({required this.ruleId, required this.changedIds});
}

/// Walks the user through uncategorized transactions one merchant group at a
/// time (biggest first). Every answer becomes a rule that is applied to the
/// whole ledger immediately, so the queue shrinks with each step.
class ClassificationWizardScreen extends ConsumerStatefulWidget {
  /// Restrict the queue to one account; null = whole ledger.
  final int? accountId;
  const ClassificationWizardScreen({super.key, this.accountId});

  @override
  ConsumerState<ClassificationWizardScreen> createState() => _ClassificationWizardScreenState();
}

class _ClassificationWizardScreenState extends ConsumerState<ClassificationWizardScreen> {
  final _skipped = <String>{};
  final _history = <_WizardStep>[];
  final _containsCtrl = TextEditingController();

  int? _categoryId;
  _RuleScope _scope = _RuleScope.merchant;
  bool _thisAccountOnly = false;
  String? _currentKey;
  bool _busy = false;
  RuleMatchCount? _containsPreview;

  @override
  void dispose() {
    _containsCtrl.dispose();
    super.dispose();
  }

  /// Reset per-group inputs when the wizard moves to another group.
  void _syncGroup(MerchantGroup g) {
    if (_currentKey == g.merchantKey) return;
    _currentKey = g.merchantKey;
    _categoryId = null;
    _scope = _RuleScope.merchant;
    _containsCtrl.text = g.counterparty ?? '';
    _containsPreview = null;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final groupsAsync = ref.watch(uncategorizedGroupsProvider(widget.accountId));
    final progress = ref.watch(classificationProgressProvider(widget.accountId)).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.classificationWizardTitle),
        actions: globalAppBarActions(
          context,
          ref,
          local: [
            AppBarAction(
              icon: Icons.undo,
              tooltip: s.wizardUndo,
              onPressed: _history.isEmpty || _busy ? null : _undo,
            ),
          ],
        ),
      ),
      body: MobilePullToRefresh(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (progress != null)
                    _ProgressHeader(
                      progress: progress,
                      s: s,
                      amountFmt: fmt.amountFormat(ref.watch(appLocaleProvider).value ?? Platform.localeName),
                    ),
                  const SizedBox(height: 16),
                  groupsAsync.when(
                    loading: () => const Center(
                      child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Text('$e'),
                    data: (groups) {
                      final pending = groups.where((g) => !_skipped.contains(g.merchantKey)).toList();
                      if (groups.isEmpty) return _DoneCard(s: s);
                      if (pending.isEmpty) return _AllSkippedCard(s: s, onRestart: () => setState(_skipped.clear));
                      final g = pending.first;
                      _syncGroup(g);
                      return _buildGroupCard(context, s, g);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context, AppStrings s, MerchantGroup g) {
    final theme = Theme.of(context);
    final locale = ref.watch(appLocaleProvider).value ?? Platform.localeName;
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final accountName = {for (final a in accounts) a.id: a.name};
    final samples = ref.watch(_groupSamplesProvider((key: g.merchantKey, accountId: widget.accountId))).value ?? const [];
    final tx = samples.firstOrNull;
    // Every category used at least once (by a rule or on a row), most
    // recently used first — the user's own working set, never truncated.
    final recent = ref.watch(usedCategoryIdsProvider).value ?? const <int>[];
    final byId = ref.watch(categoriesByIdProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider).value;
    final dateFmt = fmt.fullDateFormat(locale);
    final amtFmt = fmt.amountFormat(locale);

    return Card(
      key: ValueKey('wizardGroup_${g.merchantKey}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── The transaction ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.counterparty ?? g.merchantKey,
                        style: theme.textTheme.titleLarge,
                        key: const Key('wizardCounterparty'),
                      ),
                      // The computed merchant key — what a "This merchant" rule
                      // will match on. Shown so a bad extraction is visible.
                      Text(
                        '${s.merchant}: ${g.merchantKey}',
                        key: const Key('wizardMerchantKey'),
                        style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (g.entryKind != null && g.entryKind != BankEntryKind.unknown)
                            Chip(
                              label: Text(s.entryKindName(g.entryKind!)),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          Text(
                            '${s.wizardAccountsLabel}: ${g.accountIds.map((id) => accountName[id] ?? '#$id').join(', ')}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (tx != null)
                  PrivacyText(
                    '${amtFmt.format(tx.amount)} ${tx.currency}',
                    key: const Key('wizardAmount'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: tx.amount >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (tx != null) ...[
              Text(dateFmt.format(tx.valueDate), style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              SelectableText(tx.description, style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace', fontSize: 12)),
            ],
            const SizedBox(height: 8),
            Text(
              g.count > 1 ? s.wizardSimilarCount(g.count - 1) : s.wizardNoSimilar,
              key: const Key('wizardSimilar'),
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            // How much money this decision explains: the group's total per
            // currency (position size → masked in privacy mode).
            Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PrivacyText(
                  s.wizardGroupTotal(g.count, g.totalByCurrency.entries.map((e) => '${amtFmt.format(e.value)} ${e.key}').join(' + ')),
                  key: const Key('wizardGroupTotal'),
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (g.totalByCurrency.length > 1 && baseCurrency != null && g.baseTotal > 0)
                  PrivacyText('≈ ${amtFmt.format(g.baseTotal)} $baseCurrency', style: theme.textTheme.bodySmall),
                if (g.fxMissing > 0)
                  Text(s.wizardGroupFxMissing(g.fxMissing), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
              ],
            ),
            if (samples.length > 1) ...[
              const SizedBox(height: 4),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                dense: true,
                title: Text(s.wizardSamples, style: theme.textTheme.bodySmall),
                children: [
                  for (final t in samples.skip(1))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(t.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                      subtitle: Text(dateFmt.format(t.valueDate), style: const TextStyle(fontSize: 11)),
                      trailing: PrivacyText('${amtFmt.format(t.amount)} ${t.currency}', style: const TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ],
            const Divider(height: 24),

            // ── Category ──
            Text(s.category, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final id in recent)
                  if (byId[id] != null)
                    ChoiceChip(
                      key: ValueKey('recentCat_$id'),
                      avatar: Icon(categoryIcon(byId[id]!), size: 16, color: categoryPaint(byId[id]!, theme.colorScheme)),
                      label: Text(categoryLabel(byId[id]!, s)),
                      selected: _categoryId == id,
                      onSelected: (_) => setState(() => _categoryId = id),
                    ),
                ActionChip(
                  key: const Key('wizardPickCategory'),
                  avatar: const Icon(Icons.search, size: 16),
                  label: Text(_categoryId == null || byId[_categoryId] == null ? s.wizardPickCategory : categoryLabel(byId[_categoryId]!, s)),
                  onPressed: () async {
                    final pick = await showCategoryPicker(context, selected: _categoryId, allowNone: false, recentIds: recent);
                    if (pick != null && pick.categoryId != null) setState(() => _categoryId = pick.categoryId);
                  },
                ),
                ActionChip(
                  key: const Key('wizardNewCategory'),
                  avatar: const Icon(Icons.add, size: 16),
                  label: Text(s.newCategory),
                  onPressed: () async {
                    final id = await showCategoryEditDialog(context);
                    if (id != null) setState(() => _categoryId = id);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Rule scope ──
            Text(s.wizardRuleScope, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<_RuleScope>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: _RuleScope.merchant, label: Text(s.wizardScopeMerchant), icon: const Icon(Icons.storefront, size: 16)),
                ButtonSegment(value: _RuleScope.contains, label: Text(s.wizardScopeContains), icon: const Icon(Icons.text_fields, size: 16)),
                if (g.entryKind != null && g.entryKind != BankEntryKind.unknown)
                  ButtonSegment(value: _RuleScope.entryKind, label: Text(s.wizardScopeEntryKind), icon: const Icon(Icons.category, size: 16)),
                ButtonSegment(value: _RuleScope.onlyThis, label: Text(s.wizardScopeOnlyThis), icon: const Icon(Icons.looks_one, size: 16)),
              ],
              selected: {_scope},
              onSelectionChanged: (v) => setState(() {
                _scope = v.first;
                if (_scope == _RuleScope.contains) _refreshContainsPreview(g);
              }),
            ),
            if (_scope == _RuleScope.contains) ...[
              const SizedBox(height: 8),
              TextField(
                key: const Key('wizardContainsField'),
                controller: _containsCtrl,
                decoration: InputDecoration(
                  labelText: s.wizardScopeContains,
                  border: const OutlineInputBorder(),
                  isDense: true,
                  helperText: _containsPreview == null ? null : s.ruleMatchesPreview(_containsPreview!.total, _containsPreview!.uncategorized),
                ),
                onChanged: (_) => _refreshContainsPreview(g),
              ),
            ],
            if (_scope == _RuleScope.entryKind && g.entryKind != null) ...[
              const SizedBox(height: 8),
              Text('${s.entryType}: ${s.entryKindName(g.entryKind!)}', style: theme.textTheme.bodySmall),
            ],
            if (widget.accountId != null && _scope != _RuleScope.onlyThis) ...[
              const SizedBox(height: 4),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(_thisAccountOnly ? s.wizardScopeThisAccount : s.wizardScopeAllAccounts),
                value: !_thisAccountOnly,
                onChanged: (v) => setState(() => _thisAccountOnly = !v),
              ),
            ],
            const SizedBox(height: 16),

            // ── Actions ──
            Row(
              children: [
                OutlinedButton.icon(
                  key: const Key('wizardSkip'),
                  onPressed: _busy ? null : () => setState(() => _skipped.add(g.merchantKey)),
                  icon: const Icon(Icons.skip_next),
                  label: Text(s.wizardSkip),
                ),
                const Spacer(),
                FilledButton.icon(
                  key: const Key('wizardApply'),
                  onPressed: _busy || _categoryId == null || tx == null ? null : () => _apply(g, tx),
                  icon: _busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check),
                  label: Text(s.wizardApply),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  AutoCategorizationRule _draftRule(MerchantGroup g, int categoryId) {
    final (type, pattern) = switch (_scope) {
      _RuleScope.merchant => (RuleMatchType.merchantKey, g.merchantKey),
      _RuleScope.contains => (RuleMatchType.contains, _containsCtrl.text),
      _RuleScope.entryKind => (RuleMatchType.entryKind, g.entryKind!.name),
      _RuleScope.onlyThis => throw StateError('no rule for onlyThis'),
    };
    return AutoCategorizationRule(
      id: -1,
      pattern: RuleService.normalizePattern(type, pattern),
      categoryId: categoryId,
      priority: 0,
      isActive: true,
      createdAt: DateTime.now(),
      matchType: type,
      accountId: _thisAccountOnly ? widget.accountId : null,
      direction: RuleDirection.any,
      amountMin: null,
      amountMax: null,
    );
  }

  Future<void> _refreshContainsPreview(MerchantGroup g) async {
    final text = _containsCtrl.text;
    if (!RuleService.isValidPattern(RuleMatchType.contains, text)) {
      setState(() => _containsPreview = null);
      return;
    }
    final count = await ref.read(transactionClassifierServiceProvider).countMatches(CompiledRule(_draftRule(g, 0)));
    if (mounted && _containsCtrl.text == text) setState(() => _containsPreview = count);
  }

  Future<void> _apply(MerchantGroup g, Transaction tx) async {
    final s = ref.read(appStringsProvider);
    final cat = _categoryId!;
    final clf = ref.read(transactionClassifierServiceProvider);
    setState(() => _busy = true);
    try {
      if (_scope == _RuleScope.onlyThis) {
        await clf.setCategory([tx.id], cat);
        _history.add(_WizardStep(ruleId: null, changedIds: {tx.id}));
        if (mounted) showInfoSnack(context, s.setCategoryCount(1));
      } else {
        final draft = _draftRule(g, cat);
        if (!RuleService.isValidPattern(draft.matchType, draft.pattern)) {
          if (mounted) showInfoSnack(context, s.invalidPattern);
          return;
        }
        final before = await clf.uncategorizedIds();
        final ruleSvc = ref.read(ruleServiceProvider);
        final reused = await ruleSvc.findEquivalent(
          matchType: draft.matchType,
          pattern: draft.pattern,
          categoryId: cat,
          accountId: draft.accountId,
        );
        final ruleId = await ruleSvc.create(
          matchType: draft.matchType,
          pattern: draft.pattern,
          categoryId: cat,
          accountId: draft.accountId,
        );
        final result = await clf.classifyAll(overwrite: false);
        final after = await clf.uncategorizedIds();
        final changed = before.difference(after);
        // Undo deletes the rule only if this step created it.
        _history.add(_WizardStep(ruleId: reused == null ? ruleId : null, changedIds: changed));
        _log.info('wizard: rule $ruleId (${draft.matchType.name}="${draft.pattern}") → $result');
        if (mounted) showInfoSnack(context, s.wizardApplied(changed.length));
      }
      _skipped.remove(g.merchantKey);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _undo() async {
    if (_history.isEmpty) return;
    final s = ref.read(appStringsProvider);
    final step = _history.removeLast();
    setState(() => _busy = true);
    try {
      if (step.ruleId != null) await ref.read(ruleServiceProvider).delete(step.ruleId!);
      await ref.read(transactionClassifierServiceProvider).setCategory(step.changedIds, null);
      if (mounted) showInfoSnack(context, s.wizardUndone);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ProgressHeader extends StatelessWidget {
  final ClassificationProgress progress;
  final AppStrings s;
  final NumberFormat amountFmt;
  const _ProgressHeader({required this.progress, required this.s, required this.amountFmt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = (progress.fraction * 100).round();
    final amounts = progress.totalAmount != null && progress.baseCurrency != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Progress is money explained, not rows ticked: the header leads with
        // the amounts (masked in privacy mode) and keeps the row count as a
        // secondary line.
        if (amounts)
          PrivacyText(
            s.wizardProgressAmount(
              amountFmt.format(progress.categorizedAmount),
              amountFmt.format(progress.totalAmount),
              progress.baseCurrency!,
              pct,
            ),
            key: const Key('wizardProgress'),
            style: theme.textTheme.titleMedium,
          )
        else
          Text(
            s.wizardProgress(progress.categorized, progress.total, pct),
            key: const Key('wizardProgress'),
            style: theme.textTheme.titleMedium,
          ),
        if (amounts)
          Text(
            s.wizardProgressRows(progress.categorized, progress.total),
            key: const Key('wizardProgressRows'),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: progress.fraction, minHeight: 8),
        ),
        if (progress.excluded > 0) ...[
          const SizedBox(height: 4),
          Text(
            s.wizardExcludedNote(progress.excluded),
            key: const Key('wizardExcludedNote'),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
        if (progress.fxExcluded > 0) ...[
          const SizedBox(height: 2),
          Text(
            s.wizardFxExcludedNote(progress.fxExcluded),
            key: const Key('wizardFxExcludedNote'),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _DoneCard extends StatelessWidget {
  final AppStrings s;
  const _DoneCard({required this.s});

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('wizardDone'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green.shade600),
            const SizedBox(height: 16),
            Text(s.wizardAllDone, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(s.wizardAllDoneSubtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _AllSkippedCard extends StatelessWidget {
  final AppStrings s;
  final VoidCallback onRestart;
  const _AllSkippedCard({required this.s, required this.onRestart});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.skip_next, size: 48),
            const SizedBox(height: 16),
            Text(s.wizardNothingLeftInScope, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: onRestart, icon: const Icon(Icons.replay), label: Text(s.wizardRestart)),
          ],
        ),
      ),
    );
  }
}
