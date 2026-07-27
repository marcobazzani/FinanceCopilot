import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/tables.dart';
import '../../services/providers/providers.dart';
import '../../utils/formatters.dart' as fmt;
import '../../utils/income_split.dart';

/// Ask the user how a single inflow splits across [IncomeType]s.
///
/// Returns the non-zero slices, or `null` when cancelled. The dialog only
/// returns a balanced plan: the confirm button stays disabled until the slices
/// add up to [total] to the cent, so no part of the inflow is ever silently
/// dropped or invented.
Future<List<IncomeSplitEntry>?> showIncomeSplitDialog(
  BuildContext context, {
  required String title,
  required double total,
  required String currency,
  String confirmLabel = '',
}) {
  return showDialog<List<IncomeSplitEntry>>(
    context: context,
    builder: (_) => IncomeSplitDialog(
      title: title,
      total: total,
      currency: currency,
      confirmLabel: confirmLabel.isEmpty ? null : confirmLabel,
    ),
  );
}

/// Amount-per-[IncomeType] editor with a live remainder readout.
class IncomeSplitDialog extends ConsumerStatefulWidget {
  const IncomeSplitDialog({
    super.key,
    required this.title,
    required this.total,
    required this.currency,
    this.confirmLabel,
  });

  final String title;

  /// The full inflow amount that must be allocated (positive).
  final double total;
  final String currency;
  final String? confirmLabel;

  @override
  ConsumerState<IncomeSplitDialog> createState() => _IncomeSplitDialogState();
}

class _IncomeSplitDialogState extends ConsumerState<IncomeSplitDialog> {
  late final Map<IncomeType, TextEditingController> _controllers;
  late final String _locale;

  @override
  void initState() {
    super.initState();
    _locale = ref.read(appLocaleProvider).value ?? Platform.localeName;
    // Pre-fill the whole amount as plain Income: the common case stays a
    // two-tap confirm, exactly like the previous single-type dialog.
    _controllers = {
      for (final type in IncomeType.values)
        type: TextEditingController(
          text: type == IncomeType.income ? fmt.amountFormat(_locale).format(widget.total) : '',
        ),
    };
    for (final c in _controllers.values) {
      c.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.removeListener(_onChanged);
      c.dispose();
    }
    super.dispose();
  }

  void _onChanged() => setState(() {});

  /// Parsed slices. A field whose text cannot be parsed maps to `null` while
  /// [_hasInvalidText] flags it, so an unreadable amount blocks the save
  /// instead of being read as zero.
  Map<IncomeType, double?> get _parts => {
    for (final entry in _controllers.entries) entry.key: fmt.tryParseLocalized(entry.value.text, locale: _locale),
  };

  bool get _hasInvalidText => _controllers.values.any(
    (c) => c.text.trim().isNotEmpty && fmt.tryParseLocalized(c.text, locale: _locale) == null,
  );

  void _assignRemainder(IncomeType type, IncomeSplitPlan plan) {
    final current = fmt.tryParseLocalized(_controllers[type]!.text, locale: _locale) ?? 0;
    final next = current + plan.remainder;
    _controllers[type]!.text = next == 0 ? '' : fmt.amountFormat(_locale).format(next);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final amtFmt = fmt.currencyFormat(_locale, widget.currency);
    final plan = planIncomeSplit(total: widget.total, parts: _parts);
    final canSave = plan.isValid && !_hasInvalidText;

    final String statusText;
    final Color statusColor;
    if (_hasInvalidText) {
      statusText = s.incomeSplitInvalidAmount;
      statusColor = Theme.of(context).colorScheme.error;
    } else if (plan.remainderCents > 0) {
      statusText = '${s.remaining}${amtFmt.format(plan.remainder)}';
      statusColor = Colors.orange.shade800;
    } else if (plan.remainderCents < 0) {
      statusText = '${s.incomeSplitOverAllocated}${amtFmt.format(-plan.remainder)}';
      statusColor = Theme.of(context).colorScheme.error;
    } else {
      statusText = '${s.remaining}${amtFmt.format(0)}';
      statusColor = Colors.green.shade700;
    }

    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${s.totalLabel}: ${amtFmt.format(widget.total)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                s.incomeSplitHint,
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              for (final type in IncomeType.values) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controllers[type],
                        decoration: InputDecoration(
                          labelText: s.incomeTypeName(type),
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.playlist_add, size: 18),
                      tooltip: s.incomeSplitAssignRemainder,
                      onPressed: plan.isBalanced ? null : () => _assignRemainder(type, plan),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Text(
                statusText,
                style: TextStyle(fontWeight: FontWeight.w600, color: statusColor),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          onPressed: canSave ? () => Navigator.pop(context, plan.entries) : null,
          child: Text(widget.confirmLabel ?? s.add),
        ),
      ],
    );
  }
}
