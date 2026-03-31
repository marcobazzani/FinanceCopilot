import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../database/database.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/providers/providers.dart';
import '../../l10n/app_strings.dart';
import '../../utils/formatters.dart' as fmt;
import 'dashboard/dashboard_screen.dart' show currencySymbol;

class _Expense {
  final int? id; // null = new
  DateTime date;
  double amount;
  String description;
  _Expense({this.id, required this.date, required this.amount, this.description = ''});
}

class IncomeAdjEditScreen extends ConsumerStatefulWidget {
  final IncomeAdjustment? adjustment;
  const IncomeAdjEditScreen({super.key, this.adjustment});

  @override
  ConsumerState<IncomeAdjEditScreen> createState() => _IncomeAdjEditScreenState();
}

class _IncomeAdjEditScreenState extends ConsumerState<IncomeAdjEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late String _currency;
  late DateTime _incomeDate;
  final _expenses = <_Expense>[];
  final _deletedExpenseIds = <int>[];
  bool _loadedExisting = false;

  bool get _isEditing => widget.adjustment != null;
  String get _baseCurrency => ref.read(baseCurrencyProvider).value ?? 'EUR';

  double get _totalSpent => _expenses.fold(0.0, (sum, e) => sum + e.amount);

  @override
  void initState() {
    super.initState();
    final a = widget.adjustment;
    _nameCtrl = TextEditingController(text: a?.name ?? '');
    _amountCtrl = TextEditingController(text: a != null ? a.totalAmount.toString() : '');
    _currency = a?.currency ?? _baseCurrency;
    _incomeDate = a?.incomeDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _loadExistingExpenses(List<IncomeAdjustmentExpense> expenses) {
    if (_loadedExisting) return;
    _loadedExisting = true;
    for (final e in expenses) {
      _expenses.add(_Expense(
        id: e.id,
        date: e.date,
        amount: e.amount,
        description: e.description,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(appLocaleProvider).value ?? 'en_US';
    final dateFmt = fmt.shortDateFormat(locale);
    final sym = currencySymbol(_currency);

    // Load existing expenses
    if (_isEditing) {
      final expAsync = ref.watch(incomeAdjustmentExpensesProvider(widget.adjustment!.id));
      expAsync.whenData((exps) => _loadExistingExpenses(exps));
    }

    final totalAmount = fmt.tryParseLocalized(_amountCtrl.text, locale: locale) ?? 0;
    final remaining = totalAmount - _totalSpent;

    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? s.editIncomeAdjTitle : s.newIncomeAdjTitle),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                await ref.read(incomeAdjustmentServiceProvider).delete(widget.adjustment!.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: s.name, hintText: s.incomeAdjNameHint),
              validator: (v) => v == null || v.trim().isEmpty ? s.required : null,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _amountCtrl,
                    decoration: InputDecoration(labelText: s.totalAmount),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || fmt.tryParseLocalized(v, locale: locale) == null) return s.invalid;
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _currency,
                    decoration: InputDecoration(labelText: s.currency),
                    items: ExchangeRateService.allCurrencies
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _currency = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _DateField(
              label: s.incomeDateHelp,
              value: _incomeDate,
              format: dateFmt,
              onPicked: (d) => setState(() => _incomeDate = d),
            ),
            const SizedBox(height: 16),

            // Summary
            if (totalAmount > 0) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Text(s.remaining, style: const TextStyle(fontSize: 13)),
                      Text(
                        '${remaining.toStringAsFixed(2)} $sym',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: remaining > 0 ? Colors.orange : Colors.green,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        s.spentOf('${_totalSpent.toStringAsFixed(2)} $sym', '${totalAmount.toStringAsFixed(2)} $sym'),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Expenses
            Row(
              children: [
                Text(s.expensesLabel, style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(s.add),
                  onPressed: _addExpense,
                ),
              ],
            ),
            if (_expenses.isNotEmpty)
              for (var i = 0; i < _expenses.length; i++)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.shopping_cart_outlined, color: Colors.orange, size: 18),
                  title: Text(
                    '${dateFmt.format(_expenses[i].date)} — '
                    '${_expenses[i].description.isNotEmpty ? _expenses[i].description : s.expense}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_expenses[i].amount.toStringAsFixed(2)} $sym',
                        style: const TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.w600),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          final removed = _expenses.removeAt(i);
                          if (removed.id != null) _deletedExpenseIds.add(removed.id!);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  onTap: () => _editExpense(i),
                ),

            if (_expenses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(s.noExpensesYet,
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ),

            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(_isEditing ? s.update : s.create),
            ),
          ],
        ),
      ),
    );
  }

  Future<_Expense?> _showExpenseDialog({_Expense? existing}) async {
    final s = ref.read(appStringsProvider);
    final amountCtrl = TextEditingController(text: existing?.amount.toString() ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    var date = existing?.date ?? DateTime.now();
    final locale = ref.read(appLocaleProvider).value ?? 'en_US';
    final dateFmt = fmt.shortDateFormat(locale);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing != null ? s.editExpenseTitle : s.addExpenseTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountCtrl,
                decoration: InputDecoration(labelText: s.amount),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: descCtrl,
                decoration: InputDecoration(labelText: s.description, hintText: s.expenseHint),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.datePrefix(dateFmt.format(date))),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2050),
                  );
                  if (picked != null) setDialogState(() => date = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(existing != null ? s.update : s.add)),
          ],
        ),
      ),
    );

    if (confirmed != true) return null;
    final amount = fmt.tryParseLocalized(amountCtrl.text, locale: locale);
    if (amount == null || amount <= 0) return null;
    return _Expense(
      id: existing?.id,
      date: date,
      amount: amount,
      description: descCtrl.text.trim(),
    );
  }

  void _addExpense() async {
    final result = await _showExpenseDialog();
    if (result != null) setState(() => _expenses.add(result));
  }

  void _editExpense(int index) async {
    final result = await _showExpenseDialog(existing: _expenses[index]);
    if (result != null) setState(() => _expenses[index] = result);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final service = ref.read(incomeAdjustmentServiceProvider);

    if (_isEditing) {
      final id = widget.adjustment!.id;
      await service.update(id, IncomeAdjustmentsCompanion(
        name: Value(_nameCtrl.text.trim()),
        totalAmount: Value(fmt.tryParseLocalized(_amountCtrl.text, locale: locale)!),
        currency: Value(_currency),
        incomeDate: Value(_incomeDate),
      ));

      // Delete removed expenses
      for (final expId in _deletedExpenseIds) {
        await service.deleteExpense(expId);
      }

      // Add new or update existing expenses
      for (final exp in _expenses) {
        if (exp.id == null) {
          await service.addExpense(
            adjustmentId: id,
            date: exp.date,
            amount: exp.amount,
            description: exp.description,
          );
        } else {
          await service.updateExpense(exp.id!, IncomeAdjustmentExpensesCompanion(
            date: Value(exp.date),
            amount: Value(exp.amount),
            description: Value(exp.description),
          ));
        }
      }

      if (mounted) Navigator.pop(context);
    } else {
      final id = await service.create(
        name: _nameCtrl.text.trim(),
        totalAmount: fmt.tryParseLocalized(_amountCtrl.text, locale: locale)!,
        currency: _currency,
        incomeDate: _incomeDate,
      );

      for (final exp in _expenses) {
        await service.addExpense(
          adjustmentId: id,
          date: exp.date,
          amount: exp.amount,
          description: exp.description,
        );
      }

      if (mounted) Navigator.pop(context);
    }
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final DateFormat format;
  final ValueChanged<DateTime> onPicked;

  const _DateField({
    required this.label,
    required this.value,
    required this.format,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      controller: TextEditingController(text: format.format(value)),
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_today, size: 18),
      ),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2000),
          lastDate: DateTime(2050),
        );
        if (picked != null) onPicked(picked);
      },
    );
  }
}
