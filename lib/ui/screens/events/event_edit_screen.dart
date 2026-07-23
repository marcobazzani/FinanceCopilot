import 'package:drift/drift.dart' hide Column;
import 'dart:io';
import 'package:finance_copilot/utils/dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/market/exchange_rate_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/utils/formatters.dart' as fmt;
import 'package:finance_copilot/utils/schedule_math.dart' as schedule_math;
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show currencySymbol;

/// Create / edit an ExtraordinaryEvent. Handles all four quadrants of the
/// direction × treatment matrix via two segmented controls at the top.
///
/// For treatment=spread the schedule is defined by a frequency + step count.
/// The window always ENDS on [eventDate] and starts `stepCount` steps earlier
/// (frequency × steps, going backwards) — i.e. the amount is amortized over
/// the N periods leading up to the event. Example: 12 monthly steps → the
/// spread starts one year before the event date.
class EventEditScreen extends ConsumerStatefulWidget {
  final ExtraordinaryEvent? event;

  // Optional seeds for new-event creation (all ignored when [event] is set).
  final String? seedName;
  final double? seedAmount;
  final String? seedCurrency;
  final DateTime? seedDate;
  final EventDirection? seedDirection;
  final EventTreatment? seedTreatment;

  const EventEditScreen({
    super.key,
    this.event,
    this.seedName,
    this.seedAmount,
    this.seedCurrency,
    this.seedDate,
    this.seedDirection,
    this.seedTreatment,
  });

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
  late bool _isEphemeral;

  bool get _canBeEphemeral => _direction == EventDirection.inflow && _treatment == EventTreatment.instant;

  bool get _isEditing => widget.event != null;
  String get _baseCurrency => ref.read(baseCurrencyProvider).value ?? 'EUR';

  /// Parsed step count, clamped to at least 1.
  int get _stepCount {
    final n = int.tryParse(_stepsCtrl.text);
    return (n == null || n < 1) ? 1 : n;
  }

  /// The spread window covers the [_stepCount] periods immediately BEFORE the
  /// event: it starts `stepCount` steps back (frequency × steps) and the final
  /// step lands one period before the event date. Example: 12 monthly steps →
  /// starts one year before the event, 12 entries in total.
  DateTime get _spreadStart => schedule_math.stepBack(_eventDate, _stepCount, _stepFrequency);
  DateTime get _spreadEnd => schedule_math.stepBack(_eventDate, 1, _stepFrequency);

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    final initLocale = ref.read(appLocaleProvider).value ?? Platform.localeName;
    // When creating a new event the optional seed params pre-populate the form
    // (e.g. when launched from "Spread spending" on a transaction). Seeds are
    // ignored entirely when editing an existing event.
    final seedName = e == null ? widget.seedName : null;
    final seedAmount = e == null ? widget.seedAmount : null;
    _nameCtrl = TextEditingController(text: e?.name ?? seedName ?? '');
    _amountCtrl = TextEditingController(
      text: e != null
          ? fmt.amountFormat(initLocale).format(e.totalAmount)
          : seedAmount != null
          ? fmt.amountFormat(initLocale).format(seedAmount)
          : '',
    );
    _stepsCtrl = TextEditingController(text: '12');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _currency = e?.currency ?? widget.seedCurrency ?? _baseCurrency;
    _direction = e?.direction ?? widget.seedDirection ?? EventDirection.outflow;
    _treatment = e?.treatment ?? widget.seedTreatment ?? EventTreatment.instant;
    _stepFrequency = e?.stepFrequency ?? StepFrequency.monthly;
    _eventDate = e?.eventDate ?? widget.seedDate ?? DateTime.now();
    _isEphemeral = e?.isEphemeral ?? false;

    // When editing a spread event, reconstruct the step count from the stored
    // window so the UI shows the same number of steps (the window is otherwise
    // recomputed from eventDate + frequency × steps on save).
    if (e != null && e.treatment == EventTreatment.spread && e.spreadStart != null && e.spreadEnd != null && e.stepFrequency != null) {
      final n = schedule_math.computeStepDates(e.spreadStart!, e.spreadEnd!, e.stepFrequency!).length;
      if (n > 0) _stepsCtrl.text = n.toString();
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
    final ephemeral = _canBeEphemeral && _isEphemeral;

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
          isEphemeral: Value(ephemeral),
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
        isEphemeral: ephemeral,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final s = ref.read(appStringsProvider);
    final confirmed = await showConfirmDialog(
      context,
      title: s.delete,
      content: s.deleteAdjustmentConfirm(widget.event!.name),
      confirmLabel: s.delete,
      cancelLabel: s.cancel,
      confirmColor: Colors.red,
    );
    if (confirmed) {
      await ref.read(extraordinaryEventServiceProvider).delete(widget.event!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _pickDate(DateTime initial, void Function(DateTime) onPicked) async {
    final picked = await pickDate(context, initial, firstYear: 2000);
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
                  if (_canBeEphemeral) ...[
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.eventEphemeralLabel),
                      subtitle: Text(
                        s.eventEphemeralHelp,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      value: _isEphemeral,
                      onChanged: (v) => setState(() => _isEphemeral = v),
                    ),
                  ],
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
                          items: ExchangeRateService.allCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
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
                      items: StepFrequency.values.map((f) => DropdownMenuItem(value: f, child: Text(s.freqLabel(f)))).toList(),
                      onChanged: (v) => setState(() => _stepFrequency = v ?? StepFrequency.monthly),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _stepsCtrl,
                      decoration: InputDecoration(labelText: s.stepCountLabel),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
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
