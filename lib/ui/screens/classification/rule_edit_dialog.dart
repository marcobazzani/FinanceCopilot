import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/rule_service.dart';
import 'package:finance_copilot/services/classification/transaction_classifier_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/widgets/category_ui.dart';
import 'package:finance_copilot/utils/dialogs.dart';
import 'package:finance_copilot/utils/formatters.dart' as fmt;

/// Create/edit a categorization rule. Returns true when something was saved
/// or deleted (caller marks the rule set dirty).
Future<bool> showRuleEditDialog(
  BuildContext context, {
  AutoCategorizationRule? rule,
  RuleMatchType? initialMatchType,
  String? initialPattern,
  int? initialCategoryId,
  int? initialAccountId,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => _RuleEditDialog(
      rule: rule,
      initialMatchType: initialMatchType,
      initialPattern: initialPattern,
      initialCategoryId: initialCategoryId,
      initialAccountId: initialAccountId,
    ),
  );
  return r == true;
}

class _RuleEditDialog extends ConsumerStatefulWidget {
  final AutoCategorizationRule? rule;
  final RuleMatchType? initialMatchType;
  final String? initialPattern;
  final int? initialCategoryId;
  final int? initialAccountId;

  const _RuleEditDialog({
    this.rule,
    this.initialMatchType,
    this.initialPattern,
    this.initialCategoryId,
    this.initialAccountId,
  });

  @override
  ConsumerState<_RuleEditDialog> createState() => _RuleEditDialogState();
}

class _RuleEditDialogState extends ConsumerState<_RuleEditDialog> {
  late RuleMatchType _type;
  late final TextEditingController _patternCtrl;
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  int? _categoryId;
  int? _accountId;
  late RuleDirection _direction;
  late bool _active;
  RuleMatchCount? _preview;
  Timer? _debounce;
  bool _saving = false;

  String get _locale => ref.read(appLocaleProvider).value ?? Platform.localeName;

  @override
  void initState() {
    super.initState();
    final r = widget.rule;
    _type = r?.matchType ?? widget.initialMatchType ?? RuleMatchType.merchantKey;
    _patternCtrl = TextEditingController(text: r?.pattern ?? widget.initialPattern ?? '');
    _categoryId = r?.categoryId ?? widget.initialCategoryId;
    _accountId = r?.accountId ?? widget.initialAccountId;
    _direction = r?.direction ?? RuleDirection.any;
    _active = r?.isActive ?? true;
    final amt = fmt.amountFormat(_locale);
    _minCtrl = TextEditingController(text: r?.amountMin == null ? '' : amt.format(r!.amountMin!));
    _maxCtrl = TextEditingController(text: r?.amountMax == null ? '' : amt.format(r!.amountMax!));
    _schedulePreview();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _patternCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  bool get _patternValid => RuleService.isValidPattern(_type, _patternCtrl.text);

  double? _parseAmount(String t) => t.trim().isEmpty ? null : fmt.tryParseLocalized(t, locale: _locale);

  AutoCategorizationRule _draft() => AutoCategorizationRule(
    id: widget.rule?.id ?? -1,
    pattern: RuleService.normalizePattern(_type, _patternCtrl.text),
    categoryId: _categoryId ?? -1,
    priority: widget.rule?.priority ?? 0,
    isActive: _active,
    createdAt: widget.rule?.createdAt ?? DateTime.now(),
    matchType: _type,
    accountId: _accountId,
    direction: _direction,
    amountMin: _parseAmount(_minCtrl.text),
    amountMax: _parseAmount(_maxCtrl.text),
  );

  void _schedulePreview() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      if (!_patternValid) {
        if (mounted) setState(() => _preview = null);
        return;
      }
      final draft = _draft();
      final count = await ref.read(transactionClassifierServiceProvider).countMatches(CompiledRule(draft));
      if (mounted && draft.pattern == RuleService.normalizePattern(_type, _patternCtrl.text)) {
        setState(() => _preview = count);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final isEdit = widget.rule != null;
    final canSave = _patternValid && _categoryId != null && !_saving;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(isEdit ? s.editRule : s.newRule)),
          if (isEdit)
            IconButton(
              key: const Key('ruleDeleteButton'),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: s.delete,
              onPressed: _delete,
            ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<RuleMatchType>(
                key: const Key('ruleMatchType'),
                initialValue: _type,
                decoration: InputDecoration(labelText: s.ruleMatchType, border: const OutlineInputBorder()),
                items: [for (final t in RuleMatchType.values) DropdownMenuItem(value: t, child: Text(s.ruleMatchTypeName(t)))],
                onChanged: (v) => setState(() {
                  _type = v!;
                  if (_type == RuleMatchType.entryKind && !_patternValid) _patternCtrl.text = BankEntryKind.cardPayment.name;
                  _schedulePreview();
                }),
              ),
              const SizedBox(height: 12),
              if (_type == RuleMatchType.entryKind)
                DropdownButtonFormField<BankEntryKind>(
                  key: const Key('ruleEntryKind'),
                  initialValue: BankEntryKind.values.where((k) => k.name == _patternCtrl.text).firstOrNull,
                  decoration: InputDecoration(labelText: s.entryType, border: const OutlineInputBorder()),
                  items: [for (final k in BankEntryKind.values) DropdownMenuItem(value: k, child: Text(s.entryKindName(k)))],
                  onChanged: (v) => setState(() {
                    _patternCtrl.text = v!.name;
                    _schedulePreview();
                  }),
                )
              else
                TextField(
                  key: const Key('rulePattern'),
                  controller: _patternCtrl,
                  autofocus: !isEdit,
                  decoration: InputDecoration(
                    labelText: s.rulePattern,
                    border: const OutlineInputBorder(),
                    errorText: _patternCtrl.text.isEmpty || _patternValid ? null : s.invalidPattern,
                    helperText: _preview == null ? null : s.ruleMatchesPreview(_preview!.total, _preview!.uncategorized),
                  ),
                  onChanged: (_) => setState(_schedulePreview),
                ),
              if (_type == RuleMatchType.entryKind && _preview != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 12),
                  child: Text(
                    s.ruleMatchesPreview(_preview!.total, _preview!.uncategorized),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 12),
              CategoryField(value: _categoryId, onChanged: (v) => setState(() => _categoryId = v)),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                key: const Key('ruleAccount'),
                initialValue: accounts.any((a) => a.id == _accountId) ? _accountId : null,
                decoration: InputDecoration(labelText: s.ruleAccountScope, border: const OutlineInputBorder()),
                items: [
                  DropdownMenuItem<int?>(value: null, child: Text(s.allAccounts)),
                  for (final a in accounts) DropdownMenuItem<int?>(value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => setState(() {
                  _accountId = v;
                  _schedulePreview();
                }),
              ),
              const SizedBox(height: 12),
              Text(s.ruleDirection, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              SegmentedButton<RuleDirection>(
                showSelectedIcon: false,
                segments: [for (final d in RuleDirection.values) ButtonSegment(value: d, label: Text(s.ruleDirectionName(d)))],
                selected: {_direction},
                onSelectionChanged: (v) => setState(() {
                  _direction = v.first;
                  _schedulePreview();
                }),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minCtrl,
                      decoration: InputDecoration(labelText: s.amountMin, border: const OutlineInputBorder(), isDense: true),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _schedulePreview(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _maxCtrl,
                      decoration: InputDecoration(labelText: s.amountMax, border: const OutlineInputBorder(), isDense: true),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _schedulePreview(),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(s.ruleActive),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
        FilledButton(key: const Key('ruleSave'), onPressed: canSave ? _save : null, child: Text(s.save)),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final svc = ref.read(ruleServiceProvider);
    final d = _draft();
    try {
      if (widget.rule == null) {
        await svc.create(
          matchType: d.matchType,
          pattern: d.pattern,
          categoryId: d.categoryId,
          accountId: d.accountId,
          direction: d.direction,
          amountMin: d.amountMin,
          amountMax: d.amountMax,
          isActive: d.isActive,
        );
      } else {
        await svc.update(
          widget.rule!.id,
          AutoCategorizationRulesCompanion(
            matchType: Value(d.matchType),
            pattern: Value(d.pattern),
            categoryId: Value(d.categoryId),
            accountId: Value(d.accountId),
            direction: Value(d.direction),
            amountMin: Value(d.amountMin),
            amountMax: Value(d.amountMax),
            isActive: Value(d.isActive),
          ),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final s = ref.read(appStringsProvider);
    final ok = await showConfirmDialog(
      context,
      title: s.delete,
      content: s.cannotBeUndone,
      confirmLabel: s.delete,
      cancelLabel: s.cancel,
      confirmColor: Colors.red,
    );
    if (!ok) return;
    await ref.read(ruleServiceProvider).delete(widget.rule!.id);
    if (mounted) Navigator.pop(context, true);
  }
}
