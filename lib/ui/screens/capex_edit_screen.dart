import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../database/database.dart';
import '../../database/tables.dart';
import '../../services/capex_service.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/providers.dart';
import '../../utils/formatters.dart' as fmt;
import '../../utils/logger.dart';
import 'dashboard_screen.dart' show currencySymbol;

final _log = getLogger('CapexEditScreen');

/// Backward: spread from start date → expense date (savings before purchase).
/// Forward: spread from expense date → end date (paying off after purchase).
/// StartSteps: spread from start date for N steps → end date auto-calculated.
enum _SpreadMode { backward, forward, startSteps }

class _Reimbursement {
  final int? id; // null = new, non-null = existing from DB
  DateTime date;
  double amount;
  String description;
  _Reimbursement({this.id, required this.date, required this.amount, this.description = ''});
}

class CapexEditScreen extends ConsumerStatefulWidget {
  final DepreciationSchedule? schedule;
  const CapexEditScreen({super.key, this.schedule});

  @override
  ConsumerState<CapexEditScreen> createState() => _CapexEditScreenState();
}

class _CapexEditScreenState extends ConsumerState<CapexEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _exchangeRateCtrl;
  late final TextEditingController _stepsCtrl;

  late String _currency;
  late StepFrequency _stepFrequency;
  late DateTime _expenseDate;
  late DateTime _boundaryDate;
  late _SpreadMode _spreadMode;
  final _reimbursements = <_Reimbursement>[];
  final _deletedReimbursementIds = <int>[];
  bool _loadedExisting = false;

  bool get _isEditing => widget.schedule != null;
  String get _baseCurrency => ref.read(baseCurrencyProvider).valueOrNull ?? 'EUR';
  bool get _needsConversion => _currency != _baseCurrency;

  DateTime get _startDate {
    switch (_spreadMode) {
      case _SpreadMode.backward:
      case _SpreadMode.startSteps:
        return _boundaryDate;
      case _SpreadMode.forward:
        return _expenseDate;
    }
  }

  DateTime get _endDate {
    switch (_spreadMode) {
      case _SpreadMode.backward:
        return _expenseDate;
      case _SpreadMode.forward:
        return _boundaryDate;
      case _SpreadMode.startSteps:
        final steps = int.tryParse(_stepsCtrl.text);
        if (steps == null || steps < 1) return _boundaryDate;
        return CapexService.computeEndDate(_boundaryDate, steps, _stepFrequency);
    }
  }

  double get _totalReimbursed => _reimbursements.fold(0.0, (sum, r) => sum + r.amount);
  double? get _effectiveAmount {
    final total = double.tryParse(_amountCtrl.text);
    if (total == null) return null;
    return total - _totalReimbursed;
  }

  @override
  void initState() {
    super.initState();
    final s = widget.schedule;
    _nameCtrl = TextEditingController(text: s?.assetName ?? '');
    _amountCtrl = TextEditingController(text: s != null ? s.totalAmount.toString() : '');
    _exchangeRateCtrl = TextEditingController();
    _stepsCtrl = TextEditingController(text: '12');
    _currency = s?.currency ?? _baseCurrency;
    _stepFrequency = s?.stepFrequency ?? StepFrequency.monthly;
    _expenseDate = s?.expenseDate ?? DateTime.now();

    if (s != null && s.expenseDate != null) {
      final expNorm = DateTime(s.expenseDate!.year, s.expenseDate!.month, s.expenseDate!.day);
      final startNorm = DateTime(s.startDate.year, s.startDate.month, s.startDate.day);
      final endNorm = DateTime(s.endDate.year, s.endDate.month, s.endDate.day);

      if (startNorm == expNorm) {
        // Forward: spread starts at expense date
        _spreadMode = _SpreadMode.forward;
        _boundaryDate = s.endDate;
      } else if (endNorm == expNorm) {
        // Backward: spread ends at expense date
        _spreadMode = _SpreadMode.backward;
        _boundaryDate = s.startDate;
      } else {
        // StartSteps: neither start nor end matches expense
        _spreadMode = _SpreadMode.startSteps;
        _boundaryDate = s.startDate;
        final steps = CapexService.computeStepDates(s.startDate, s.endDate, s.stepFrequency).length;
        _stepsCtrl.text = steps.toString();
      }
    } else if (s != null) {
      // No expense date — infer forward
      _spreadMode = _SpreadMode.forward;
      _boundaryDate = s.endDate;
    } else {
      _spreadMode = _SpreadMode.forward;
      _boundaryDate = DateTime.now().add(const Duration(days: 365));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _exchangeRateCtrl.dispose();
    _stepsCtrl.dispose();
    super.dispose();
  }

  /// Load existing reimbursements when editing
  void _loadExistingReimbursements(List<BufferTransaction> txns) {
    if (_loadedExisting) return;
    _loadedExisting = true;
    for (final t in txns) {
      if (t.isReimbursement) {
        _reimbursements.add(_Reimbursement(
          id: t.id,
          date: t.operationDate,
          amount: t.amount.abs(),
          description: t.description,
        ));
      }
    }
  }

  List<DateTime> get _previewDates {
    return CapexService.computeStepDates(_startDate, _endDate, _stepFrequency);
  }

  double? get _perStepAmount {
    final effective = _effectiveAmount;
    final dates = _previewDates;
    if (effective == null || effective <= 0 || dates.isEmpty) return null;
    return effective / dates.length;
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(appLocaleProvider).valueOrNull ?? 'en_US';
    final dateFmt = fmt.shortDateFormat(locale);
    final sym = currencySymbol(_currency);

    // Load existing reimbursements BEFORE computing preview values
    if (_isEditing && widget.schedule!.bufferId != null) {
      final txnAsync = ref.watch(bufferTransactionsProvider(widget.schedule!.bufferId!));
      txnAsync.whenData((txns) => _loadExistingReimbursements(txns));
    }

    final previewDates = _previewDates;
    final perStep = _perStepAmount;
    final effective = _effectiveAmount;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Adjustment' : 'New Adjustment'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                await ref.read(capexServiceProvider).delete(widget.schedule!.id);
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
            // Name
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Car, Kitchen renovation'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            // Amount + Currency
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _amountCtrl,
                    decoration: const InputDecoration(labelText: 'Total Amount'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || double.tryParse(v) == null) return 'Invalid';
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _currency,
                    decoration: const InputDecoration(labelText: 'Currency'),
                    items: ExchangeRateService.allCurrencies
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _currency = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_needsConversion)
              TextFormField(
                controller: _exchangeRateCtrl,
                decoration: InputDecoration(
                  labelText: 'Rate $_baseCurrency/$_currency',
                  hintText: 'e.g. 1.08',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            if (_needsConversion) const SizedBox(height: 12),

            // Expense date
            _DateField(
              label: 'Expense Date (when money left)',
              value: _expenseDate,
              format: dateFmt,
              onPicked: (d) => setState(() => _expenseDate = d),
            ),
            const SizedBox(height: 16),

            // ── Reimbursements ──
            Row(
              children: [
                Text('Reimbursements', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                  onPressed: _addReimbursement,
                ),
              ],
            ),
            if (_reimbursements.isNotEmpty) ...[
              for (var i = 0; i < _reimbursements.length; i++)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.arrow_back, color: Colors.green, size: 18),
                  title: Text(
                    '${dateFmt.format(_reimbursements[i].date)} — '
                    '${_reimbursements[i].description.isNotEmpty ? _reimbursements[i].description : "Reimbursement"}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '+${_reimbursements[i].amount.toStringAsFixed(2)} $sym',
                        style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          final removed = _reimbursements.removeAt(i);
                          if (removed.id != null) _deletedReimbursementIds.add(removed.id!);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  onTap: () => _editReimbursement(i),
                ),
              if (_totalReimbursed > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Effective amount to spread: ${effective?.toStringAsFixed(2) ?? '?'} $sym',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
            const Divider(),
            const SizedBox(height: 8),

            // Step frequency
            DropdownButtonFormField<StepFrequency>(
              value: _stepFrequency,
              decoration: const InputDecoration(labelText: 'Step Frequency'),
              items: StepFrequency.values
                  .map((f) => DropdownMenuItem(value: f, child: Text(f.name)))
                  .toList(),
              onChanged: (v) => setState(() => _stepFrequency = v!),
            ),
            const SizedBox(height: 12),

            // Spread mode
            SegmentedButton<_SpreadMode>(
              segments: const [
                ButtonSegment(
                  value: _SpreadMode.backward,
                  label: Text('Backward'),
                  icon: Icon(Icons.arrow_back, size: 16),
                ),
                ButtonSegment(
                  value: _SpreadMode.forward,
                  label: Text('Forward'),
                  icon: Icon(Icons.arrow_forward, size: 16),
                ),
                ButtonSegment(
                  value: _SpreadMode.startSteps,
                  label: Text('Start + Steps'),
                  icon: Icon(Icons.pin, size: 16),
                ),
              ],
              selected: {_spreadMode},
              onSelectionChanged: (v) => setState(() {
                _spreadMode = v.first;
                switch (_spreadMode) {
                  case _SpreadMode.backward:
                    _boundaryDate = _expenseDate.subtract(const Duration(days: 365));
                  case _SpreadMode.forward:
                    _boundaryDate = _expenseDate.add(const Duration(days: 365));
                  case _SpreadMode.startSteps:
                    _boundaryDate = _expenseDate;
                    _stepsCtrl.text = '12';
                }
              }),
            ),
            const SizedBox(height: 4),
            Text(
              switch (_spreadMode) {
                _SpreadMode.backward => 'Spread savings from start date up to expense date',
                _SpreadMode.forward => 'Spread cost from expense date to end date',
                _SpreadMode.startSteps => 'Spread from start date for N steps',
              },
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),

            // Mode-specific fields
            ..._buildModeFields(dateFmt),

            const SizedBox(height: 4),
            Text(
              '${previewDates.length} steps from ${dateFmt.format(_startDate)} to ${dateFmt.format(_endDate)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),

            const SizedBox(height: 16),

            // Preview
            if (perStep != null && previewDates.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Preview', style: Theme.of(context).textTheme.titleSmall),
                          const Spacer(),
                          Text(
                            '${previewDates.length} × ${perStep.toStringAsFixed(2)} $sym',
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: previewDates.length,
                          itemBuilder: (_, i) {
                            final date = previewDates[i];
                            final cumulative = perStep * (i + 1);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 28,
                                    child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ),
                                  Text(dateFmt.format(date), style: const TextStyle(fontSize: 13)),
                                  const Spacer(),
                                  Text(
                                    '-${perStep.toStringAsFixed(2)} $sym',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(width: 16),
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      '${cumulative.toStringAsFixed(0)} / ${effective?.toStringAsFixed(0) ?? '?'}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      textAlign: TextAlign.right,
                                    ),
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
              const SizedBox(height: 16),
            ],

            // Save buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _save(andAddAnother: false),
                    icon: const Icon(Icons.save),
                    label: Text(_isEditing ? 'Update' : 'Create'),
                  ),
                ),
                if (!_isEditing) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => _save(andAddAnother: true),
                      child: const Text('Save & Add Another'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildModeFields(DateFormat dateFmt) {
    switch (_spreadMode) {
      case _SpreadMode.backward:
        return [
          _DateField(
            label: 'Start Date',
            value: _boundaryDate,
            format: dateFmt,
            onPicked: (d) => setState(() => _boundaryDate = d),
          ),
        ];
      case _SpreadMode.forward:
        return [
          _DateField(
            label: 'End Date',
            value: _boundaryDate,
            format: dateFmt,
            onPicked: (d) => setState(() => _boundaryDate = d),
          ),
        ];
      case _SpreadMode.startSteps:
        return [
          _DateField(
            label: 'Start Date',
            value: _boundaryDate,
            format: dateFmt,
            onPicked: (d) => setState(() => _boundaryDate = d),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _stepsCtrl,
            decoration: const InputDecoration(labelText: 'Number of Steps'),
            keyboardType: TextInputType.number,
            validator: (v) {
              final n = int.tryParse(v ?? '');
              if (n == null || n < 1) return 'Min 1';
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
        ];
    }
  }

  Future<_Reimbursement?> _showReimbursementDialog({_Reimbursement? existing}) async {
    final amountCtrl = TextEditingController(text: existing?.amount.toString() ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    var date = existing?.date ?? DateTime.now();
    final locale = ref.read(appLocaleProvider).valueOrNull ?? 'en_US';
    final dateFmt = fmt.shortDateFormat(locale);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing != null ? 'Edit Reimbursement' : 'Add Reimbursement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountCtrl,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description', hintText: 'e.g. From John'),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Date: ${dateFmt.format(date)}'),
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
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(existing != null ? 'Update' : 'Add')),
          ],
        ),
      ),
    );

    if (confirmed != true) return null;
    final amount = double.tryParse(amountCtrl.text);
    if (amount == null || amount <= 0) return null;
    return _Reimbursement(
      id: existing?.id,
      date: date,
      amount: amount,
      description: descCtrl.text.trim(),
    );
  }

  void _addReimbursement() async {
    final result = await _showReimbursementDialog();
    if (result != null) setState(() => _reimbursements.add(result));
  }

  void _editReimbursement(int index) async {
    final result = await _showReimbursementDialog(existing: _reimbursements[index]);
    if (result != null) setState(() => _reimbursements[index] = result);
  }

  Future<void> _save({required bool andAddAnother}) async {
    if (!_formKey.currentState!.validate()) return;
    final service = ref.read(capexServiceProvider);
    final bufferService = ref.read(bufferServiceProvider);

    if (_isEditing) {
      final scheduleId = widget.schedule!.id;
      _log.info('updating schedule id=$scheduleId');
      await service.update(
        scheduleId,
        DepreciationSchedulesCompanion(
          assetName: Value(_nameCtrl.text.trim()),
          totalAmount: Value(double.parse(_amountCtrl.text)),
          currency: Value(_currency),
          expenseDate: Value(_expenseDate),
          startDate: Value(_startDate),
          endDate: Value(_endDate),
          stepFrequency: Value(_stepFrequency),
        ),
      );

      // Handle reimbursement changes
      var bufferId = widget.schedule!.bufferId;
      final hasReimbursements = _reimbursements.isNotEmpty || _deletedReimbursementIds.isNotEmpty;

      if (hasReimbursements && bufferId == null) {
        bufferId = await service.createLinkedBuffer(scheduleId);
      }

      // Delete removed reimbursements
      for (final id in _deletedReimbursementIds) {
        await bufferService.deleteTransaction(id);
      }

      // Add new or update existing reimbursements
      for (final r in _reimbursements) {
        if (r.id == null) {
          await bufferService.createTransaction(
            bufferId: bufferId!,
            operationDate: r.date,
            amount: r.amount,
            description: r.description,
            currency: _currency,
            isReimbursement: true,
          );
        } else {
          await bufferService.updateTransaction(
            r.id!,
            BufferTransactionsCompanion(
              operationDate: Value(r.date),
              valueDate: Value(r.date),
              amount: Value(r.amount),
              description: Value(r.description),
            ),
          );
        }
      }

      // Regenerate entries (reimbursements or dates may have changed)
      await service.generateEntries(scheduleId);

      if (mounted) Navigator.pop(context);
    } else {
      _log.info('creating new schedule: ${_nameCtrl.text.trim()}');
      final scheduleId = await service.create(
        name: _nameCtrl.text.trim(),
        totalAmount: double.parse(_amountCtrl.text),
        currency: _currency,
        expenseDate: _expenseDate,
        startDate: _startDate,
        endDate: _endDate,
        stepFrequency: _stepFrequency,
      );

      if (_reimbursements.isNotEmpty) {
        final bufferId = await service.createLinkedBuffer(scheduleId);
        for (final r in _reimbursements) {
          await bufferService.createTransaction(
            bufferId: bufferId,
            operationDate: r.date,
            amount: r.amount,
            description: r.description,
            currency: _currency,
            isReimbursement: true,
          );
        }
        await service.generateEntries(scheduleId);
      }

      if (andAddAnother) {
        _nameCtrl.clear();
        _amountCtrl.clear();
        _reimbursements.clear();
        _deletedReimbursementIds.clear();
        _loadedExisting = false;
        _formKey.currentState!.reset();
        setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved! Add another.'), duration: Duration(seconds: 1)),
          );
        }
      } else {
        if (mounted) Navigator.pop(context);
      }
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
