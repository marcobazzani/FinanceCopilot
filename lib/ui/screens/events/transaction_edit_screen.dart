import 'package:drift/drift.dart' as drift;
import 'dart:io';
import 'package:finance_copilot/utils/dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/classification/ledger_roles.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/widgets/category_ui.dart';
import 'package:finance_copilot/utils/formatters.dart' as fmt;
import 'package:finance_copilot/utils/logger.dart';

final _log = getLogger('TransactionEditScreen');

/// Edit an existing transaction or create a new one.
class TransactionEditScreen extends ConsumerStatefulWidget {
  final Transaction? transaction; // null = create new
  final Account account;

  const TransactionEditScreen({
    super.key,
    this.transaction,
    required this.account,
  });

  @override
  ConsumerState<TransactionEditScreen> createState() => _TransactionEditScreenState();
}

class _TransactionEditScreenState extends ConsumerState<TransactionEditScreen> {
  String get locale => ref.read(appLocaleProvider).value ?? Platform.localeName;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _dateCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _descFullCtrl;
  late TextEditingController _balanceCtrl;
  late TextEditingController _currencyCtrl;
  late TransactionStatus _status;
  late DateTime _selectedDate;
  int? _categoryId;
  bool _createMerchantRule = false;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    final locale = ref.read(appLocaleProvider).value ?? Platform.localeName;
    final dateFmt = fmt.shortDateFormat(locale);

    _selectedDate = tx?.valueDate ?? DateTime.now();
    _dateCtrl = TextEditingController(text: dateFmt.format(_selectedDate));
    _amountCtrl = TextEditingController(
      text: tx != null ? fmt.amountFormat(locale).format(tx.amount) : '',
    );
    _descCtrl = TextEditingController(text: tx?.description ?? '');
    _descFullCtrl = TextEditingController(text: tx?.descriptionFull ?? '');
    _balanceCtrl = TextEditingController(
      text: tx?.balanceAfter != null ? fmt.amountFormat(locale).format(tx!.balanceAfter!) : '',
    );
    _currencyCtrl = TextEditingController(text: tx?.currency ?? widget.account.currency);
    _status = tx?.status ?? TransactionStatus.settled;
    _categoryId = tx?.categoryId;
    _loadSimilarCount();
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _descFullCtrl.dispose();
    _balanceCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }

  LedgerRole? get _ledgerRole {
    final tx = widget.transaction;
    if (tx == null) return null;
    return ref.watch(ledgerRolesProvider).value?[tx.id];
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? s.editTransactionTitle : s.newTransactionTitle),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: s.delete,
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Date picker
            TextFormField(
              controller: _dateCtrl,
              decoration: InputDecoration(
                labelText: s.dateRequired,
                suffixIcon: const Icon(Icons.calendar_today),
                border: const OutlineInputBorder(),
              ),
              readOnly: true,
              onTap: _pickDate,
              validator: (v) => (v == null || v.isEmpty) ? s.required : null,
            ),
            const SizedBox(height: 12),

            // Amount
            TextFormField(
              controller: _amountCtrl,
              decoration: InputDecoration(
                labelText: '${s.amount} *',
                border: const OutlineInputBorder(),
                hintText: '-123.45',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.isEmpty) return s.required;
                if (fmt.tryParseLocalized(v, locale: locale) == null) return s.invalidNumber;
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Description
            TextFormField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: s.description,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              maxLines: 1,
            ),
            const SizedBox(height: 12),

            // Full description
            TextFormField(
              controller: _descFullCtrl,
              decoration: InputDecoration(
                labelText: s.fullDescription,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              maxLines: 3,
            ),
            const SizedBox(height: 12),

            // Balance after
            TextFormField(
              controller: _balanceCtrl,
              decoration: InputDecoration(
                labelText: s.balanceAfter,
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 12),

            // Currency + Status row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _currencyCtrl,
                    decoration: InputDecoration(
                      labelText: s.currency,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<TransactionStatus>(
                    initialValue: _status,
                    decoration: InputDecoration(
                      labelText: s.statusLabel,
                      border: const OutlineInputBorder(),
                    ),
                    items: TransactionStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Category (+ optional merchant rule so future classifier runs
            // reproduce this choice for the same counterparty). Rows the
            // ledger explains structurally are not categorizable.
            if (_ledgerRole != null)
              ListTile(
                key: const Key('notCategorizableNote'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline),
                title: Text(s.notCategorizableBecause(s.ledgerRoleName(_ledgerRole!))),
              )
            else
              CategoryField(
                value: _categoryId,
                onChanged: (v) => setState(() {
                  _categoryId = v;
                  if (v == null) _createMerchantRule = false;
                }),
                helperText: _merchantHelper(s),
              ),
            if (_ledgerRole == null && _categoryId != null && _isEditing && widget.transaction!.merchantKey != null)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                value: _createMerchantRule,
                onChanged: (v) => setState(() => _createMerchantRule = v ?? false),
                title: Text(s.createRuleForMerchant),
                subtitle: Text(
                  s.createRuleForMerchantHint(
                    widget.transaction!.counterparty ?? widget.transaction!.merchantKey!,
                    _similarCount,
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // Raw metadata (read-only if imported)
            if (_isEditing && widget.transaction!.rawMetadata != null) ...[
              const Divider(),
              Text(s.rawImportData, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.transaction!.rawMetadata!,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
            ],

            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Text(_isEditing ? s.saveChanges : s.createTransaction),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper line under the category field: recognized merchant + entry kind.
  String? _merchantHelper(AppStrings s) {
    final tx = widget.transaction;
    if (tx == null) return null;
    final parts = <String>[];
    if (tx.counterparty != null) parts.add('${s.merchant}: ${tx.counterparty}');
    if (tx.entryKind != null && tx.entryKind != BankEntryKind.unknown) parts.add(s.entryKindName(tx.entryKind!));
    return parts.isEmpty ? null : parts.join(' · ');
  }

  int _similarCount = 0;

  Future<void> _loadSimilarCount() async {
    final key = widget.transaction?.merchantKey;
    if (key == null) return;
    final ids = await ref.read(transactionClassifierServiceProvider).uncategorizedIdsOf(key);
    if (mounted) setState(() => _similarCount = ids.where((id) => id != widget.transaction!.id).length);
  }

  Future<void> _pickDate() async {
    final picked = await pickDate(context, _selectedDate);
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateCtrl.text = fmt.shortDateFormat(ref.read(appLocaleProvider).value ?? Platform.localeName).format(picked);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = fmt.tryParseLocalized(_amountCtrl.text, locale: locale)!;
    final balance = _balanceCtrl.text.isNotEmpty ? fmt.tryParseLocalized(_balanceCtrl.text, locale: locale) : null;
    final svc = ref.read(transactionServiceProvider);

    if (_isEditing) {
      _log.info('saving transaction id=${widget.transaction!.id}');
      await svc.update(
        widget.transaction!.id,
        TransactionsCompanion(
          operationDate: drift.Value(_selectedDate),
          valueDate: drift.Value(_selectedDate),
          amount: drift.Value(amount),
          description: drift.Value(_descCtrl.text),
          descriptionFull: drift.Value(_descFullCtrl.text.isNotEmpty ? _descFullCtrl.text : null),
          balanceAfter: drift.Value(balance),
          currency: drift.Value(_currencyCtrl.text),
          status: drift.Value(_status),
          categoryId: drift.Value(_categoryId),
        ),
      );
      if (_createMerchantRule && _categoryId != null && widget.transaction!.merchantKey != null) {
        await ref
            .read(ruleServiceProvider)
            .create(matchType: RuleMatchType.merchantKey, pattern: widget.transaction!.merchantKey!, categoryId: _categoryId!);
        ref.read(rulesDirtyProvider.notifier).state = true;
      }
    } else {
      _log.info('creating transaction for account=${widget.account.id}');
      await svc.create(
        accountId: widget.account.id,
        operationDate: _selectedDate,
        amount: amount,
        description: _descCtrl.text,
        descriptionFull: _descFullCtrl.text.isNotEmpty ? _descFullCtrl.text : null,
        balanceAfter: balance,
        currency: _currencyCtrl.text,
        status: _status,
        categoryId: _categoryId,
      );
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _confirmDelete() async {
    final s = ref.read(appStringsProvider);
    final confirmed = await showConfirmDialog(
      context,
      title: s.deleteTransactionTitle,
      content: s.cannotBeUndone,
      confirmLabel: s.delete,
      cancelLabel: s.cancel,
      confirmColor: Colors.red,
    );
    if (confirmed) {
      _log.warning('deleting transaction id=${widget.transaction!.id}');
      await ref.read(transactionServiceProvider).delete(widget.transaction!.id);
      if (mounted) Navigator.pop(context);
    }
  }
}
