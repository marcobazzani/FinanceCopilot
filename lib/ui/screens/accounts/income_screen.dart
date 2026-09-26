import 'package:drift/drift.dart' hide Column;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/market/exchange_rate_service.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/utils/formatters.dart' as fmt;
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show currencySymbol;
import 'package:finance_copilot/ui/screens/import/import_screen.dart';
import 'package:finance_copilot/ui/widgets/mobile_pull_to_refresh.dart';
import 'package:finance_copilot/ui/widgets/privacy_text.dart';
import 'package:finance_copilot/ui/widgets/selection/selectable_item.dart';
import 'package:finance_copilot/ui/widgets/selection/selection_action_bar.dart';
import 'package:finance_copilot/ui/widgets/selection/selection_controller.dart';
import 'package:finance_copilot/utils/dialogs.dart';

class IncomeScreen extends ConsumerStatefulWidget {
  const IncomeScreen({super.key});

  @override
  ConsumerState<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends ConsumerState<IncomeScreen> {
  String get _locale => ref.read(appLocaleProvider).value ?? Platform.localeName;
  final _focusNode = FocusNode();
  final _selection = SelectionController<int>();

  @override
  void dispose() {
    _focusNode.dispose();
    _selection.dispose();
    super.dispose();
  }

  IconData _typeIcon(IncomeType type) {
    return switch (type) {
      IncomeType.income => Icons.payments,
      IncomeType.refund => Icons.replay,
      IncomeType.pensionContribution => Icons.savings,
    };
  }

  Color _typeColor(BuildContext context, IncomeType type) {
    return switch (type) {
      IncomeType.income => Theme.of(context).colorScheme.primaryContainer,
      IncomeType.refund => Colors.orange.shade100,
      IncomeType.pensionContribution => Colors.green.shade100,
    };
  }

  Color _typeIconColor(BuildContext context, IncomeType type) {
    return switch (type) {
      IncomeType.income => Theme.of(context).colorScheme.onPrimaryContainer,
      IncomeType.refund => Colors.orange.shade800,
      IncomeType.pensionContribution => Colors.green.shade800,
    };
  }

  /// Cmd/Ctrl+V opens the import wizard pre-targeted to Income. The wizard's
  /// "Paste from clipboard" button + column-mapping + type-tag chips give the
  /// SAME experience as a file import — no bespoke parsing or keyword type
  /// guessing here (that lived in a now-removed heuristic).
  void _handlePaste() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ImportScreen(preselectedTarget: ImportTarget.income)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final incomesAsync = ref.watch(incomesProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider).value ?? 'EUR';
    final locale = ref.watch(appLocaleProvider).value ?? Platform.localeName;
    final amtFormat = fmt.amountFormat(locale);
    final dateFmt = fmt.shortDateFormat(locale);

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyV &&
            (HardwareKeyboard.instance.isMetaPressed || HardwareKeyboard.instance.isControlPressed)) {
          _handlePaste();
        }
      },
      child: ListenableBuilder(
        listenable: _selection,
        builder: (ctx, _) {
          final incomes = incomesAsync.value ?? const <Income>[];
          _selection.setOrderedIds(incomes.map((i) => i.id).toList());
          return Scaffold(
            body: incomesAsync.when(
              data: (incomes) {
                if (incomes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.payments, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text(s.noIncomeYet, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => _showAddDialog(context, baseCurrency),
                          icon: const Icon(Icons.add),
                          label: Text(s.addIncomeTitle),
                        ),
                      ],
                    ),
                  );
                }

                return MobilePullToRefresh(
                  child: ListView.separated(
                    itemCount: incomes.length,
                    physics: const AlwaysScrollableScrollPhysics(),
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final income = incomes[i];
                      final sym = currencySymbol(income.currency);
                      return SelectableItem<int>(
                        controller: _selection,
                        id: income.id,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _typeColor(context, income.type),
                            child: Icon(
                              _typeIcon(income.type),
                              color: _typeIconColor(context, income.type),
                            ),
                          ),
                          title: PrivacyText(
                            '${amtFormat.format(income.amount)} $sym',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${dateFmt.format(income.valueDate)} · ${s.incomeTypeName(income.type)}',
                          ),
                          trailing: Text(income.currency, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                          onTap: () => _showEditDialog(context, income),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(s.error(e))),
            ),
            bottomNavigationBar: _selection.active
                ? SelectionActionBar<int>(
                    controller: _selection,
                    visibleIds: incomes.map((i) => i.id).toList(),
                    onDelete: (ids) => ref.read(incomeServiceProvider).deleteMany(ids.toList()),
                  )
                : null,
            floatingActionButton: _selection.active
                ? null
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'import',
                        tooltip: s.importFromFileTooltip,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ImportScreen(preselectedTarget: ImportTarget.income)),
                        ),
                        child: const Icon(Icons.file_upload),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: 'add',
                        onPressed: () => _showAddDialog(context, baseCurrency),
                        child: const Icon(Icons.add),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, String defaultCurrency) async {
    final s = ref.read(appStringsProvider);
    final result = await showDialog<_IncomeFormResult>(
      context: context,
      builder: (_) => _IncomeFormDialog(
        title: s.addIncomeTitle,
        confirmLabel: s.add,
        initialDate: fmt.shortDateFormat(_locale).format(DateTime.now()),
        initialAmount: '',
        initialType: IncomeType.income,
        initialCurrency: defaultCurrency,
      ),
    );
    if (result == null) return;

    final date = _tryParseDate(result.dateText);
    final amount = fmt.tryParseLocalized(result.amountText, locale: _locale);
    if (date == null || amount == null) {
      if (context.mounted) {
        showInfoSnack(context, s.invalidDateOrAmount);
      }
      return;
    }

    await ref
        .read(incomeServiceProvider)
        .create(
          date: date,
          amount: amount,
          type: result.type,
          currency: result.currency,
        );
  }

  Future<void> _showEditDialog(BuildContext context, Income income) async {
    final s = ref.read(appStringsProvider);
    final result = await showDialog<_IncomeFormResult>(
      context: context,
      builder: (_) => _IncomeFormDialog(
        title: s.editIncomeTitle,
        confirmLabel: s.save,
        // Display valueDate per CLAUDE.md convention (canonical "money moved" date).
        initialDate: fmt.shortDateFormat(_locale).format(income.valueDate),
        initialAmount: income.amount.toString(),
        initialType: income.type,
        initialCurrency: income.currency,
        canDelete: true,
      ),
    );
    if (result == null) return;

    if (result.delete) {
      if (context.mounted) {
        await _confirmDelete(context, income);
      }
      return;
    }

    final date = _tryParseDate(result.dateText);
    final amount = fmt.tryParseLocalized(result.amountText, locale: _locale);
    if (date == null || amount == null) {
      if (context.mounted) {
        showInfoSnack(context, s.invalidDateOrAmount);
      }
      return;
    }

    // Update both date and valueDate together — the user only sees one field
    // and editing it should not leave the two columns inconsistent.
    await ref
        .read(incomeServiceProvider)
        .update(
          income.id,
          IncomesCompanion(
            date: Value(date),
            valueDate: Value(date),
            amount: Value(amount),
            type: Value(result.type),
            currency: Value(result.currency),
          ),
        );
  }

  Future<void> _confirmDelete(BuildContext context, Income income) async {
    final s = ref.read(appStringsProvider);
    final amtFormat = fmt.amountFormat(_locale);
    final dateFmt = fmt.shortDateFormat(_locale);
    final confirmed = await showConfirmDialog(
      context,
      title: s.deleteIncomeTitle,
      content: s.deleteIncomeConfirm(amtFormat.format(income.amount), income.currency, dateFmt.format(income.valueDate)),
      confirmLabel: s.delete,
      cancelLabel: s.cancel,
      confirmColor: Colors.red,
    );

    if (confirmed) {
      await ref.read(incomeServiceProvider).delete(income.id);
    }
  }

  DateTime? _tryParseDate(String text) => fmt.parseFlexibleDate(text);
}

/// What the income form hands back: the raw field texts (parsed by the
/// caller, so unreadable input is reported instead of guessed) and the
/// picked type and currency. `delete` is the edit form's delete action.
typedef _IncomeFormResult = ({bool delete, String dateText, String amountText, IncomeType type, String currency});

/// The Add and Edit Income form. Owns its text controllers and disposes them
/// only once the dialog is fully gone: disposing them as soon as the dialog
/// returned broke the closing animation, which still rebuilds the fields.
class _IncomeFormDialog extends ConsumerStatefulWidget {
  const _IncomeFormDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialDate,
    required this.initialAmount,
    required this.initialType,
    required this.initialCurrency,
    this.canDelete = false,
  });

  final String title;
  final String confirmLabel;
  final String initialDate;
  final String initialAmount;
  final IncomeType initialType;
  final String initialCurrency;
  final bool canDelete;

  @override
  ConsumerState<_IncomeFormDialog> createState() => _IncomeFormDialogState();
}

class _IncomeFormDialogState extends ConsumerState<_IncomeFormDialog> {
  late final _dateCtl = TextEditingController(text: widget.initialDate);
  late final _amountCtl = TextEditingController(text: widget.initialAmount);
  late var _type = widget.initialType;
  late var _currency = widget.initialCurrency;

  @override
  void dispose() {
    _dateCtl.dispose();
    _amountCtl.dispose();
    super.dispose();
  }

  void _close({bool delete = false}) => Navigator.pop<_IncomeFormResult>(
    context,
    (delete: delete, dateText: _dateCtl.text, amountText: _amountCtl.text, type: _type, currency: _currency),
  );

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final cancel = TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel));
    final confirm = FilledButton(onPressed: _close, child: Text(widget.confirmLabel));
    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _dateCtl,
              decoration: InputDecoration(labelText: s.dateFormatHint),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtl,
              decoration: InputDecoration(labelText: s.amount),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _close(),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<IncomeType>(
              initialValue: _type,
              decoration: InputDecoration(labelText: s.incomeTypeLabel),
              items: IncomeType.values.map((t) => DropdownMenuItem(value: t, child: Text(s.incomeTypeName(t)))).toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _currency,
              decoration: InputDecoration(labelText: s.currency),
              items: ExchangeRateService.allCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _currency = v!),
            ),
          ],
        ),
      ),
      actions: widget.canDelete
          ? [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: s.delete,
                    onPressed: () => _close(delete: true),
                  ),
                  const Spacer(),
                  cancel,
                  const SizedBox(width: 8),
                  confirm,
                ],
              ),
            ]
          : [cancel, confirm],
    );
  }
}
