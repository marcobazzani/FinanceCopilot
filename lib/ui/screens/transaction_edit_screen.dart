import 'package:drift/drift.dart' as drift;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database.dart';
import '../../database/tables.dart';
import '../../services/providers/providers.dart';
import '../../utils/formatters.dart' as fmt;
import '../../utils/logger.dart';

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

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    final locale = ref.read(appLocaleProvider).value ?? Platform.localeName;
    final dateFmt = fmt.shortDateFormat(locale);

    _selectedDate = tx?.operationDate ?? DateTime.now();
    _dateCtrl = TextEditingController(text: dateFmt.format(_selectedDate));
    _amountCtrl = TextEditingController(text: tx?.amount.toString() ?? '');
    _descCtrl = TextEditingController(text: tx?.description ?? '');
    _descFullCtrl = TextEditingController(text: tx?.descriptionFull ?? '');
    _balanceCtrl = TextEditingController(text: tx?.balanceAfter?.toString() ?? '');
    _currencyCtrl = TextEditingController(text: tx?.currency ?? widget.account.currency);
    _status = tx?.status ?? TransactionStatus.settled;
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
                    items: TransactionStatus.values
                        .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                ),
              ],
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
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
        ),
      );
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
      );
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _confirmDelete() async {
    final s = ref.read(appStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteTransactionTitle),
        content: Text(s.cannotBeUndone),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _log.warning('deleting transaction id=${widget.transaction!.id}');
      await ref.read(transactionServiceProvider).delete(widget.transaction!.id);
      if (mounted) Navigator.pop(context);
    }
  }
}
