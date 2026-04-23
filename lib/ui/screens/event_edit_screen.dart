import 'package:drift/drift.dart' hide Column;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database.dart';
import '../../database/tables.dart';
import '../../l10n/app_strings.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/providers/providers.dart';
import '../../utils/formatters.dart' as fmt;
import '../../utils/schedule_math.dart' as schedule_math;
import 'dashboard/dashboard_screen.dart' show currencySymbol;

/// Create / edit an ExtraordinaryEvent. Handles all four quadrants of the
/// direction × treatment matrix via two segmented controls at the top.
///
/// For treatment=spread the three legacy CAPEX spread modes are preserved:
///   backward:   spread from [spreadStart] → eventDate (save before purchase)
///   forward:    spread from eventDate → [spreadEnd] (pay off after purchase)
///   startSteps: spread from [spreadStart] for N steps
enum _SpreadMode { backward, forward, startSteps }

class EventEditScreen extends ConsumerStatefulWidget {
  final ExtraordinaryEvent? event;
  const EventEditScreen({super.key, this.event});

  @override
  ConsumerState<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends ConsumerState<EventEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _stepsCtrl;
  late final TextEditingController _notesCtrl;

  late EventDirection _direction;
  late EventTreatment _treatment;
  late String _currency;
  late StepFrequency _stepFrequency;
  late DateTime _eventDate;
  late DateTime _boundaryDate;
  late _SpreadMode _spreadMode;

  bool get _isEditing => widget.event != null;
  String get _baseCurrency => ref.read(baseCurrencyProvider).value ?? 'EUR';

  DateTime get _spreadStart => switch (_spreadMode) {
        _SpreadMode.backward => _boundaryDate,
        _SpreadMode.startSteps => _boundaryDate,
        _SpreadMode.forward => _eventDate,
      };

  DateTime get _spreadEnd => switch (_spreadMode) {
        _SpreadMode.backward => _eventDate,
        _SpreadMode.forward => _boundaryDate,
        _SpreadMode.startSteps => () {
            final steps = int.tryParse(_stepsCtrl.text);
            if (steps == null || steps < 1) return _boundaryDate;
            return schedule_math.computeEndDate(_boundaryDate, steps, _stepFrequency);
          }(),
      };

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    final initLocale = ref.read(appLocaleProvider).value ?? Platform.localeName;
    _amountCtrl = TextEditingController(
      text: e != null ? fmt.amountFormat(initLocale).format(e.totalAmount) : '',
    );
    _stepsCtrl = TextEditingController(text: '12');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _currency = e?.currency ?? _baseCurrency;
    _direction = e?.direction ?? EventDirection.outflow;
    _treatment = e?.treatment ?? EventTreatment.instant;
    _stepFrequency = e?.stepFrequency ?? StepFrequency.monthly;
    _eventDate = e?.eventDate ?? DateTime.now();

    // Infer spread mode from stored spread window (when editing spread events).
    if (e != null && e.treatment == EventTreatment.spread &&
        e.spreadStart != null && e.spreadEnd != null) {
      final evNorm = DateTime(e.eventDate.year, e.eventDate.month, e.eventDate.day);
      final startNorm = DateTime(e.spreadStart!.year, e.spreadStart!.month, e.spreadStart!.day);
      final endNorm = DateTime(e.spreadEnd!.year, e.spreadEnd!.month, e.spreadEnd!.day);
      if (startNorm == evNorm) {
        _spreadMode = _SpreadMode.forward;
        _boundaryDate = e.spreadEnd!;
      } else if (endNorm == evNorm) {
        _spreadMode = _SpreadMode.backward;
        _boundaryDate = e.spreadStart!;
      } else {
        _spreadMode = _SpreadMode.startSteps;
        _boundaryDate = e.spreadStart!;
        _stepsCtrl.text = schedule_math.computeStepDates(
          e.spreadStart!, e.spreadEnd!, e.stepFrequency!
        ).length.toString();
      }
    } else {
      _spreadMode = _SpreadMode.forward;
      _boundaryDate = DateTime.now().add(const Duration(days: 365));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _stepsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  List<DateTime> get _previewDates {
    if (_treatment != EventTreatment.spread) return const [];
    return schedule_math.computeStepDates(_spreadStart, _spreadEnd, _stepFrequency);
  }

  double? _parsedAmount(String loc) => fmt.tryParseLocalized(_amountCtrl.text, locale: loc);

  double? _perStep(String loc) {
    final amount = _parsedAmount(loc);
    final dates = _previewDates;
    if (amount == null || amount <= 0 || dates.isEmpty) return null;
    return amount / dates.length;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final locale = ref.read(appLocaleProvider).value ?? Platform.localeName;
    final amount = _parsedAmount(locale);
    if (amount == null) return;
    final svc = ref.read(extraordinaryEventServiceProvider);

    if (_isEditing) {
      await svc.update(
        widget.event!.id,
        ExtraordinaryEventsCompanion(
          name: Value(_nameCtrl.text.trim()),
          direction: Value(_direction),
          treatment: Value(_treatment),
          totalAmount: Value(amount),
          currency: Value(_currency),
          eventDate: Value(_eventDate),
          stepFrequency: Value(_treatment == EventTreatment.spread ? _stepFrequency : null),
          spreadStart: Value(_treatment == EventTreatment.spread ? _spreadStart : null),
          spreadEnd: Value(_treatment == EventTreatment.spread ? _spreadEnd : null),
          notes: Value(_notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim()),
        ),
      );
    } else {
      await svc.create(
        name: _nameCtrl.text.trim(),
        direction: _direction,
        treatment: _treatment,
        totalAmount: amount,
        currency: _currency,
        eventDate: _eventDate,
        stepFrequency: _treatment == EventTreatment.spread ? _stepFrequency : null,
        spreadStart: _treatment == EventTreatment.spread ? _spreadStart : null,
        spreadEnd: _treatment == EventTreatment.spread ? _spreadEnd : null,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final s = ref.read(appStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.delete),
        content: Text(s.deleteAdjustmentConfirm(widget.event!.name)),
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
      await ref.read(extraordinaryEventServiceProvider).delete(widget.event!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _pickDate(DateTime initial, void Function(DateTime) onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => onPicked(picked));
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(appLocaleProvider).value ?? Platform.localeName;
    final dateFmt = fmt.shortDateFormat(locale);
    final amtFmt = fmt.amountFormat(locale);
    final sym = currencySymbol(_currency);
    final s = ref.watch(appStringsProvider);

    final previewDates = _previewDates;
    final perStep = _perStep(locale);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? s.editAdjustmentTitle : s.newAdjustmentTitle),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Direction & Treatment toggles ──
            _SectionCard(
              title: s.eventKindSection,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.eventDirectionLabel, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  SegmentedButton<EventDirection>(
                    segments: [
                      ButtonSegment(value: EventDirection.outflow, label: Text(s.eventDirectionOutflow), icon: const Icon(Icons.trending_down)),
                      ButtonSegment(value: EventDirection.inflow, label: Text(s.eventDirectionInflow), icon: const Icon(Icons.trending_up)),
                    ],
                    selected: {_direction},
                    onSelectionChanged: (set) => setState(() => _direction = set.first),
                  ),
                  const SizedBox(height: 12),
                  Text(s.eventTreatmentLabel, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  SegmentedButton<EventTreatment>(
                    segments: [
                      ButtonSegment(value: EventTreatment.instant, label: Text(s.eventTreatmentInstant), icon: const Icon(Icons.flash_on)),
                      ButtonSegment(value: EventTreatment.spread, label: Text(s.eventTreatmentSpread), icon: const Icon(Icons.timeline)),
                    ],
                    selected: {_treatment},
                    onSelectionChanged: (set) => setState(() => _treatment = set.first),
                  ),
                ],
              ),
            ),

            // ── Basics: name, amount, currency ──
            _SectionCard(
              title: s.eventBasicsSection,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(labelText: s.name),
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty) ? s.required : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _amountCtrl,
                          decoration: InputDecoration(labelText: s.amount, suffixText: sym),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            final parsed = fmt.tryParseLocalized(v ?? '', locale: locale);
                            return parsed == null ? s.required : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          initialValue: _currency,
                          decoration: InputDecoration(labelText: s.currency),
                          items: ExchangeRateService.allCurrencies
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) => setState(() => _currency = v ?? _baseCurrency),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => _pickDate(_eventDate, (d) => _eventDate = d),
                    child: InputDecorator(
                      decoration: InputDecoration(labelText: s.eventDateLabel),
                      child: Text(dateFmt.format(_eventDate)),
                    ),
                  ),
                ],
              ),
            ),

            // ── Spread configuration (conditional) ──
            if (_treatment == EventTreatment.spread)
              _SectionCard(
                title: s.eventSpreadSection,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<StepFrequency>(
                      initialValue: _stepFrequency,
                      decoration: InputDecoration(labelText: s.stepFrequencyLabel),
                      items: StepFrequency.values
                          .map((f) => DropdownMenuItem(value: f, child: Text(_freqLabel(s, f))))
                          .toList(),
                      onChanged: (v) => setState(() => _stepFrequency = v ?? StepFrequency.monthly),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<_SpreadMode>(
                      segments: [
                        ButtonSegment(value: _SpreadMode.backward, label: Text(s.spreadModeBackward)),
                        ButtonSegment(value: _SpreadMode.forward, label: Text(s.spreadModeForward)),
                        ButtonSegment(value: _SpreadMode.startSteps, label: Text(s.spreadModeStartSteps)),
                      ],
                      selected: {_spreadMode},
                      onSelectionChanged: (set) => setState(() => _spreadMode = set.first),
                    ),
                    const SizedBox(height: 12),
                    if (_spreadMode == _SpreadMode.backward || _spreadMode == _SpreadMode.startSteps)
                      InkWell(
                        onTap: () => _pickDate(_boundaryDate, (d) => _boundaryDate = d),
                        child: InputDecorator(
                          decoration: InputDecoration(labelText: s.spreadStartLabel),
                          child: Text(dateFmt.format(_boundaryDate)),
                        ),
                      ),
                    if (_spreadMode == _SpreadMode.forward)
                      InkWell(
                        onTap: () => _pickDate(_boundaryDate, (d) => _boundaryDate = d),
                        child: InputDecorator(
                          decoration: InputDecoration(labelText: s.spreadEndLabel),
                          child: Text(dateFmt.format(_boundaryDate)),
                        ),
                      ),
                    if (_spreadMode == _SpreadMode.startSteps) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _stepsCtrl,
                        decoration: InputDecoration(labelText: s.stepCountLabel),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                    // Preview
                    if (previewDates.isNotEmpty && perStep != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        s.spreadPreview(previewDates.length, '${amtFmt.format(perStep)} $sym'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${dateFmt.format(_spreadStart)} → ${dateFmt.format(_spreadEnd)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),

            // ── Notes ──
            _SectionCard(
              title: s.eventNotesSection,
              child: TextFormField(
                controller: _notesCtrl,
                decoration: InputDecoration(labelText: s.notesOptional),
                maxLines: 2,
              ),
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(s.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: Text(_isEditing ? s.save : s.create),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _freqLabel(AppStrings s, StepFrequency f) => switch (f) {
        StepFrequency.weekly => s.freqWeekly,
        StepFrequency.monthly => s.freqMonthly,
        StepFrequency.quarterly => s.freqQuarterly,
        StepFrequency.yearly => s.freqYearly,
      };
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

