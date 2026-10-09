import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/category_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/widgets/category_ui.dart';
import 'package:finance_copilot/utils/dialogs.dart';

const _palette = <String>[
  'FF2E7D32', 'FF388E3C', 'FF43A047', 'FF00897B', 'FF607D8B', 'FF455A64', 'FFF57C00', 'FFE64A19', //
  'FF1976D2', 'FF1565C0', 'FF6D4C41', 'FFFBC02D', 'FFD32F2F', 'FF5D4037', 'FF8E24AA', 'FF7B1FA2', //
  'FF0288D1', 'FF00796B', 'FFC2185B', 'FF616161', 'FF757575', 'FF9E9E9E', 'FFBDBDBD', 'FF3949AB',
];

/// Create/edit a category. Returns the id of the created/updated category,
/// or null when the dialog was dismissed or the category was deleted.
/// [initialName] pre-fills the name for the create path (e.g. from a picker
/// search that found nothing).
Future<int?> showCategoryEditDialog(BuildContext context, {Category? category, String? initialName}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _CategoryEditDialog(category: category, initialName: initialName),
  );
}

class _CategoryEditDialog extends ConsumerStatefulWidget {
  final Category? category;
  final String? initialName;
  const _CategoryEditDialog({this.category, this.initialName});

  @override
  ConsumerState<_CategoryEditDialog> createState() => _CategoryEditDialogState();
}

class _CategoryEditDialogState extends ConsumerState<_CategoryEditDialog> {
  late final TextEditingController _nameCtrl;
  late CategoryType _type;
  late String _icon;
  late String _color;
  late bool _essential;
  late bool _archived;
  bool _saving = false;

  Category? get _c => widget.category;

  @override
  void initState() {
    super.initState();
    final s = ref.read(appStringsProvider);
    final c = _c;
    _nameCtrl = TextEditingController(text: c == null ? (widget.initialName ?? '') : categoryLabel(c, s));
    _type = c?.type ?? CategoryType.expense;
    _icon = c?.icon ?? 'label';
    _color = c?.color ?? _palette[(c?.id ?? 0) % _palette.length];
    _essential = c?.isEssential ?? false;
    _archived = c?.isArchived ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final isEdit = _c != null;
    final color = Color(int.parse(_color, radix: 16));
    final canSave = _nameCtrl.text.trim().isNotEmpty && !_saving;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(isEdit ? s.editCategory : s.newCategory)),
          if (isEdit)
            IconButton(
              key: const Key('categoryDeleteButton'),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: s.delete,
              onPressed: () async {
                final done = await confirmAndDeleteCategory(context, ref, _c!);
                if (done && context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('categoryNameField'),
                controller: _nameCtrl,
                autofocus: !isEdit,
                decoration: InputDecoration(labelText: s.categoryName, border: const OutlineInputBorder()),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => canSave ? _save() : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CategoryType>(
                key: const Key('categoryTypeField'),
                initialValue: _type,
                decoration: InputDecoration(labelText: s.categoryTypeLabel, border: const OutlineInputBorder()),
                items: [for (final t in CategoryType.values) DropdownMenuItem(value: t, child: Text(s.categoryTypeName(t)))],
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final hex in _palette)
                    InkWell(
                      onTap: () => setState(() => _color = hex),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(int.parse(hex, radix: 16)),
                          shape: BoxShape.circle,
                          border: Border.all(color: hex == _color ? Theme.of(context).colorScheme.onSurface : Colors.transparent, width: 2),
                        ),
                        child: hex == _color ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final name in categoryIconNames)
                    IconButton(
                      isSelected: name == _icon,
                      selectedIcon: Icon(_iconFor(name), color: color),
                      icon: Icon(_iconFor(name)),
                      onPressed: () => setState(() => _icon = name),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(s.essentialExpense),
                value: _essential,
                onChanged: (v) => setState(() => _essential = v),
              ),
              if (isEdit)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(s.archived),
                  value: _archived,
                  onChanged: (v) => setState(() => _archived = v),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(key: const Key('categorySave'), onPressed: canSave ? _save : null, child: Text(s.save)),
      ],
    );
  }

  IconData _iconFor(String name) => categoryIconByName(name);

  Future<void> _save() async {
    setState(() => _saving = true);
    final svc = ref.read(categoryServiceProvider);
    final s = ref.read(appStringsProvider);
    final name = _nameCtrl.text.trim();
    try {
      final int id;
      if (_c == null) {
        id = await svc.create(name: name, type: _type, icon: _icon, color: _color, isEssential: _essential);
      } else {
        final c = _c!;
        id = c.id;
        // Only a real rename drops the l10n key; re-saving the localized
        // default name keeps the category translatable.
        final renamed = name != categoryLabel(c, s);
        await svc.update(
          c.id,
          CategoriesCompanion(
            name: renamed ? Value(name) : const Value.absent(),
            key: renamed ? const Value(null) : const Value.absent(),
            type: Value(_type),
            icon: Value(_icon),
            color: Value(_color),
            isEssential: Value(_essential),
            isArchived: Value(_archived),
          ),
        );
      }
      if (mounted) Navigator.pop(context, id);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// Confirm and delete a category, offering to move its transactions/rules
/// to another category. Returns true when deleted.
Future<bool> confirmAndDeleteCategory(BuildContext context, WidgetRef ref, Category category) async {
  final s = ref.read(appStringsProvider);
  final svc = ref.read(categoryServiceProvider);
  final usage = await svc.usage(category.id);
  if (!context.mounted) return false;

  if (usage.isEmpty) {
    final ok = await showConfirmDialog(
      context,
      title: s.deleteCategoryTitle,
      content: s.cannotBeUndone,
      confirmLabel: s.delete,
      cancelLabel: s.cancel,
      confirmColor: Colors.red,
    );
    if (!ok) return false;
    await svc.delete(category.id);
    return true;
  }

  final others = (ref.read(allCategoriesProvider).value ?? const <Category>[]).where((c) => c.id != category.id).toList();
  final choice = await showDialog<_ReassignChoice>(
    context: context,
    builder: (ctx) => _ReassignDialog(category: category, usage: usage, others: others),
  );
  if (choice == null) return false;
  await svc.delete(category.id, reassignTo: choice.targetId);
  return true;
}

class _ReassignChoice {
  final int? targetId;
  const _ReassignChoice(this.targetId);
}

class _ReassignDialog extends ConsumerStatefulWidget {
  final Category category;
  final CategoryUsage usage;
  final List<Category> others;
  const _ReassignDialog({required this.category, required this.usage, required this.others});

  @override
  ConsumerState<_ReassignDialog> createState() => _ReassignDialogState();
}

class _ReassignDialogState extends ConsumerState<_ReassignDialog> {
  int? _target;
  bool _leave = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    return AlertDialog(
      title: Text(s.deleteCategoryTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.deleteCategoryBody(widget.usage.transactions, widget.usage.rules)),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              key: const Key('reassignTarget'),
              initialValue: _target,
              decoration: InputDecoration(labelText: s.reassignTo, border: const OutlineInputBorder()),
              items: [for (final c in widget.others) DropdownMenuItem<int?>(value: c.id, child: Text(categoryLabel(c, s)))],
              onChanged: _leave ? null : (v) => setState(() => _target = v),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(s.leaveUncategorized),
              value: _leave,
              onChanged: (v) => setState(() {
                _leave = v ?? false;
                if (_leave) _target = null;
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          key: const Key('reassignConfirm'),
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: (_leave || _target != null) ? () => Navigator.pop(context, _ReassignChoice(_leave ? null : _target)) : null,
          child: Text(s.delete),
        ),
      ],
    );
  }
}
