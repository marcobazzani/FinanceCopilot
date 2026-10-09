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
import 'package:finance_copilot/ui/widgets/edit_form_fields.dart';
import 'package:finance_copilot/ui/widgets/privacy_text.dart';
import 'package:finance_copilot/ui/widgets/raw_import_data_panel.dart';
import 'package:finance_copilot/utils/formatters.dart' as fmt;
import 'package:finance_copilot/utils/logger.dart';
import 'package:finance_copilot/utils/visualization_clock.dart' show dateOnly, editedDates;

final _log = getLogger('TransactionEditScreen');

/// Asks, then deletes [tx] — the service recomputes its account's balances —
/// and says whether it did. Behind the transaction's trashcan on this screen
/// and the ledger row's swipe.
Future<bool> confirmAndDeleteTransaction(BuildContext context, WidgetRef ref, Transaction tx) async {
  final s = ref.read(appStringsProvider);
  final transactions = ref.read(transactionServiceProvider);
  final confirmed = await showConfirmDialog(
    context,
    title: s.deleteTransactionTitle,
    content: s.cannotBeUndone,
    confirmLabel: s.delete,
    cancelLabel: s.cancel,
    confirmColor: Colors.red,
  );
  if (!confirmed) return false;
  _log.warning('deleting transaction id=${tx.id}');
  await transactions.delete(tx.id);
  return true;
}

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
  late TextEditingController _amountCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _descFullCtrl;
  late TextEditingController _balanceCtrl;
  late TextEditingController _currencyCtrl;
  late TransactionStatus _status;
  late DateTime _selectedDate;
  int? _categoryId;
  bool _createMerchantRule = false;
  bool _saving = false;

  /// Whether the account's balances are computed — asked of the ledger
  /// ([TransactionService.computesBalances]: its saved import config re-runs
  /// the running balance after every save, replacing a written one): 'Balance
  /// after' is then derived, so it is shown read-only and never sent. False
  /// until the answer has loaded, and for the accounts whose balances the
  /// ledger leaves as they are.
  bool _balanceComputed = false;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    final locale = ref.read(appLocaleProvider).value ?? Platform.localeName;

    // A new row defaults to today's calendar day, never the clock time.
    _selectedDate = tx?.valueDate ?? dateOnly(DateTime.now());
    // Every digit of the stored figures: an untouched field saves unchanged.
    final amtFmt = fmt.amountFormat(locale);
    _amountCtrl = TextEditingController(
      text: tx != null ? fmt.editableFigure(tx.amount, amtFmt, locale: locale) : '',
    );
    _descCtrl = TextEditingController(text: tx?.description ?? '');
    _descFullCtrl = TextEditingController(text: tx?.descriptionFull ?? '');
    _balanceCtrl = TextEditingController(
      text: tx?.balanceAfter != null ? fmt.editableFigure(tx!.balanceAfter!, amtFmt, locale: locale) : '',
    );
    _currencyCtrl = TextEditingController(text: tx?.currency ?? widget.account.currency);
    _status = tx?.status ?? TransactionStatus.settled;
    _categoryId = tx?.categoryId;
    _loadSimilarCount();
    _loadBalanceSetting();
  }

  @override
  void dispose() {
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
            DateFormField(
              date: _selectedDate,
              onPicked: (picked) => setState(() => _selectedDate = picked),
            ),
            const SizedBox(height: 12),

            // Amount
            TextFormField(
              controller: _amountCtrl,
              decoration: InputDecoration(
                labelText: '${s.amount} *',
                border: const OutlineInputBorder(),
                // An example the locale parser reads back: "-123,45" in it_IT.
                hintText: fmt.amountFormat(locale).format(-123.45),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              textInputAction: TextInputAction.next,
              validator: (v) => requiredNumberError(v, s, locale: locale),
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

            // Balance after: typed, unless the account's balance setting
            // computes it (see _balanceComputed) — then it is a read-only
            // position figure, masked in privacy mode.
            if (_balanceComputed)
              InputDecorator(
                decoration: InputDecoration(
                  labelText: s.balanceAfter,
                  border: const OutlineInputBorder(),
                  helperText: s.balanceAfterComputedHint,
                  helperMaxLines: 2,
                ),
                baseStyle: Theme.of(context).textTheme.bodyLarge,
                isEmpty: widget.transaction?.balanceAfter == null,
                child: PrivacyText(
                  widget.transaction?.balanceAfter == null ? '' : fmt.amountFormat(locale).format(widget.transaction!.balanceAfter!),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              )
            else
              TextFormField(
                controller: _balanceCtrl,
                decoration: InputDecoration(
                  labelText: s.balanceAfter,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                textInputAction: TextInputAction.done,
                // Optional, but a typed balance the locale cannot read must be
                // flagged, not silently dropped on save.
                validator: (v) => fmt.readOptionalNumber(v ?? '', locale: locale).invalid ? s.invalidNumber : null,
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
                    items: TransactionStatus.values
                        .map((status) => DropdownMenuItem(value: status, child: Text(s.transactionStatusName(status))))
                        .toList(),
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
            if (_isEditing && widget.transaction!.rawMetadata != null) RawImportDataPanel(widget.transaction!.rawMetadata!),

            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
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

  /// Reads whether the account's balances are computed (see [_balanceComputed]).
  Future<void> _loadBalanceSetting() async {
    final computed = await ref.read(transactionServiceProvider).computesBalances(widget.account.id);
    if (mounted && computed) setState(() => _balanceComputed = true);
  }

  Future<void> _save() async {
    // A second tap while the first save is in flight must not insert twice.
    if (_saving || !_formKey.currentState!.validate()) return;

    final amount = fmt.tryParseLocalized(_amountCtrl.text, locale: locale)!;
    // A computed balance is not sent: the ledger recomputes it after the save.
    final balance = _balanceComputed || _balanceCtrl.text.isEmpty ? null : fmt.tryParseLocalized(_balanceCtrl.text, locale: locale);
    final svc = ref.read(transactionServiceProvider);
    setState(() => _saving = true);
    try {
      if (_isEditing) {
        final tx = widget.transaction!;
        // The user sees one date: the value date. The booking date keys the
        // import dedup: see editedDates.
        final dates = editedDates(edited: _selectedDate, valueDate: tx.valueDate, bookingDate: tx.operationDate);
        _log.info('saving transaction id=${tx.id}');
        await svc.update(
          tx.id,
          TransactionsCompanion(
            operationDate: drift.Value.absentIfNull(dates.bookingDate),
            valueDate: drift.Value.absentIfNull(dates.valueDate),
            amount: drift.Value(amount),
            description: drift.Value(_descCtrl.text),
            descriptionFull: drift.Value(_descFullCtrl.text.isNotEmpty ? _descFullCtrl.text : null),
            balanceAfter: _balanceComputed ? const drift.Value.absent() : drift.Value(balance),
            currency: drift.Value(_currencyCtrl.text),
            status: drift.Value(_status),
            categoryId: drift.Value(_categoryId),
          ),
        );
        if (_createMerchantRule && _categoryId != null && tx.merchantKey != null) {
          await ref.read(ruleServiceProvider).create(matchType: RuleMatchType.merchantKey, pattern: tx.merchantKey!, categoryId: _categoryId!);
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
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    if (await confirmAndDeleteTransaction(context, ref, widget.transaction!) && mounted) Navigator.pop(context);
  }
}
