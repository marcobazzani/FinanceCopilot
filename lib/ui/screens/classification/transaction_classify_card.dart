import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/rule_service.dart';
import 'package:finance_copilot/services/classification/transaction_classifier_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/widgets/category_edit_dialog.dart';
import 'package:finance_copilot/ui/widgets/category_ui.dart';
import 'package:finance_copilot/ui/widgets/privacy_text.dart';
import 'package:finance_copilot/utils/dialogs.dart';
import 'package:finance_copilot/utils/formatters.dart' as fmt;
import 'package:finance_copilot/utils/logger.dart';

final _log = getLogger('TransactionClassifyCard');

enum _RuleScope { merchant, contains, entryKind, onlyThis }

/// One applied classification, kept for exact undo.
class ClassifyStep {
  final int? ruleId;
  final Set<int> changedIds;
  const ClassifyStep({required this.ruleId, required this.changedIds});
}

/// The classification card: one transaction of a merchant [group] (the
/// first of [samples]), category choice, rule scope, Skip / Apply. The single
/// implementation used by the classification wizard and by every other place
/// that classifies a transaction.
///
/// Give it a key per group: its inputs reset when a new state is created.
class TransactionClassifyCard extends ConsumerStatefulWidget {
  final MerchantGroup group;

  /// The rows the group stands for, the one shown first.
  final List<Transaction> samples;

  /// Scope of the surrounding screen (enables "this account only").
  final int? accountId;
  final VoidCallback? onSkip;
  final ValueChanged<ClassifyStep>? onApplied;
  final ValueChanged<bool>? onBusyChanged;

  const TransactionClassifyCard({
    super.key,
    required this.group,
    required this.samples,
    this.accountId,
    this.onSkip,
    this.onApplied,
    this.onBusyChanged,
  });

  @override
  ConsumerState<TransactionClassifyCard> createState() => _TransactionClassifyCardState();
}

class _TransactionClassifyCardState extends ConsumerState<TransactionClassifyCard> {
  final _containsCtrl = TextEditingController();

  int? _categoryId;
  late _RuleScope _scope;
  bool _thisAccountOnly = false;
  bool _busy = false;
  RuleMatchCount? _containsPreview;

  @override
  void initState() {
    super.initState();
    _scope = widget.group.merchantKey.isEmpty ? _RuleScope.onlyThis : _RuleScope.merchant;
    _containsCtrl.text = widget.group.counterparty ?? '';
  }

  @override
  void dispose() {
    _containsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final g = widget.group;
    final theme = Theme.of(context);
    final locale = ref.watch(appLocaleProvider).value ?? Platform.localeName;
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final accountName = {for (final a in accounts) a.id: a.name};
    final samples = widget.samples;
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
                if (g.merchantKey.isNotEmpty)
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
                  onPressed: _busy ? null : widget.onSkip,
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
      direction: _direction(categoryId),
      amountMin: null,
      amountMax: null,
    );
  }

  /// The shown transaction's direction (see [RuleService.directionFor]).
  RuleDirection _direction(int categoryId) {
    final amount = widget.samples.firstOrNull?.amount ?? -1;
    final cat = ref.read(categoriesByIdProvider)[categoryId == 0 ? _categoryId : categoryId];
    return RuleService.directionFor(amount, cat?.type);
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

  void _setBusy(bool v) {
    setState(() => _busy = v);
    widget.onBusyChanged?.call(v);
  }

  Future<void> _apply(MerchantGroup g, Transaction tx) async {
    final s = ref.read(appStringsProvider);
    final cat = _categoryId!;
    final clf = ref.read(transactionClassifierServiceProvider);
    // An already categorized row being re-classified: rows sharing its
    // category are moved too (classifyAll only fills uncategorized rows).
    final from = tx.categoryId;
    _setBusy(true);
    try {
      if (_scope == _RuleScope.onlyThis) {
        await clf.setCategory([tx.id], cat);
        widget.onApplied?.call(ClassifyStep(ruleId: null, changedIds: {tx.id}));
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
          direction: draft.direction,
        );
        final ruleId = await ruleSvc.create(
          matchType: draft.matchType,
          pattern: draft.pattern,
          categoryId: cat,
          accountId: draft.accountId,
          direction: draft.direction,
        );
        final result = await clf.classifyAll(overwrite: false);
        final after = await clf.uncategorizedIds();
        final changed = before.difference(after);
        if (from != null && from != cat) {
          changed.addAll(await clf.recategorizeMatching(CompiledRule(draft.copyWith(id: ruleId)), fromCategoryId: from));
        }
        // Undo deletes the rule only if this step created it.
        widget.onApplied?.call(ClassifyStep(ruleId: reused == null ? ruleId : null, changedIds: changed));
        _log.info('wizard: rule $ruleId (${draft.matchType.name}="${draft.pattern}") → $result');
        if (mounted) showInfoSnack(context, s.wizardApplied(changed.length));
      }
    } finally {
      if (mounted) _setBusy(false);
    }
  }
}
