import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/utils/dialogs.dart';
import 'package:finance_copilot/utils/formatters.dart' as fmt;

/// The read-only date field of a form: [date], spelled in the display
/// locale's short date format. A tap opens the date picker on it (from
/// [firstYear]) and hands the picked day to [onPicked]; the caller keeps the
/// date and passes the picked one back, which the field then shows.
class DateFormField extends ConsumerStatefulWidget {
  final DateTime date;
  final ValueChanged<DateTime> onPicked;

  /// The field's label; [AppStrings.dateRequired] when null.
  final String? label;

  /// The first year the picker offers.
  final int firstYear;

  /// Outlined, like the other fields of the transaction and asset-event edit
  /// screens; false in a form whose fields keep the default underline.
  final bool outlined;

  const DateFormField({
    super.key,
    required this.date,
    required this.onPicked,
    this.label,
    this.firstYear = 1990,
    this.outlined = true,
  });

  @override
  ConsumerState<DateFormField> createState() => _DateFormFieldState();
}

class _DateFormFieldState extends ConsumerState<DateFormField> {
  /// The spelled [DateFormField.date]; never typed (the field is read-only).
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _spell();
    // The display locale can load, or change, while the field is shown.
    ref.listenManual(appLocaleProvider, (_, _) => _spell());
  }

  @override
  void didUpdateWidget(DateFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Spelled once this frame is built: a new text rebuilds the enclosing
    // Form, which must not happen in the middle of its build.
    if (widget.date != oldWidget.date) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _spell();
      });
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _spell() {
    final text = fmt.shortDateFormat(ref.read(appLocaleProvider).value ?? Platform.localeName).format(widget.date);
    if (_text.text != text) _text.text = text;
  }

  Future<void> _pick() async {
    final picked = await pickDate(context, widget.date, firstYear: widget.firstYear);
    if (picked != null && mounted) widget.onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    return TextFormField(
      controller: _text,
      readOnly: true,
      decoration: InputDecoration(
        labelText: widget.label ?? s.dateRequired,
        suffixIcon: const Icon(Icons.calendar_today),
        border: widget.outlined ? const OutlineInputBorder() : null,
      ),
      onTap: _pick,
    );
  }
}

/// The error of a required number field: [AppStrings.required] when [value]
/// is empty, [AppStrings.invalidNumber] when [locale] cannot read it, else
/// null.
String? requiredNumberError(String? value, AppStrings s, {required String locale}) {
  if (value == null || value.isEmpty) return s.required;
  if (fmt.tryParseLocalized(value, locale: locale) == null) return s.invalidNumber;
  return null;
}
