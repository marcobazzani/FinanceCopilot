import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database.dart';
import '../../database/tables.dart';
import '../../l10n/app_strings.dart';
import '../../services/providers/providers.dart';
import 'category_edit_dialog.dart';

/// Single source of truth for how a [Category] is rendered anywhere in the
/// app: label (l10n for seeded keys, custom name otherwise), icon and color.

String categoryLabel(Category c, AppStrings s) => c.key != null ? s.categoryNameFor(c.key!) : c.name;

/// Label for a nullable category id; falls back to "Uncategorized".
String categoryLabelFor(int? id, Map<int, Category> byId, AppStrings s) {
  if (id == null) return s.uncategorized;
  final c = byId[id];
  return c == null ? s.uncategorized : categoryLabel(c, s);
}

const _iconByName = <String, IconData>{
  'work': Icons.work_outline,
  'percent': Icons.percent,
  'attach_money': Icons.attach_money,
  'replay': Icons.replay,
  'swap_horiz': Icons.swap_horiz,
  'trending_up': Icons.trending_up,
  'shopping_cart': Icons.shopping_cart_outlined,
  'restaurant': Icons.restaurant,
  'directions_bus': Icons.directions_bus,
  'directions_car': Icons.directions_car,
  'home': Icons.home_outlined,
  'bolt': Icons.bolt,
  'favorite': Icons.favorite_border,
  'shield': Icons.shield_outlined,
  'shopping_bag': Icons.shopping_bag_outlined,
  'movie': Icons.movie_outlined,
  'flight': Icons.flight,
  'school': Icons.school_outlined,
  'card_giftcard': Icons.card_giftcard,
  'account_balance': Icons.account_balance_outlined,
  'receipt_long': Icons.receipt_long,
  'payments': Icons.payments_outlined,
  'more_horiz': Icons.more_horiz,
  'label': Icons.label_outline,
  'pets': Icons.pets,
  'child_care': Icons.child_care,
  'sports': Icons.sports_soccer,
  'phone': Icons.phone_android,
  'coffee': Icons.coffee,
  'local_bar': Icons.local_bar,
  'fitness': Icons.fitness_center,
  'beach': Icons.beach_access,
  'build': Icons.build_outlined,
  'brush': Icons.brush,
  'music': Icons.music_note,
  'book': Icons.menu_book,
  'savings': Icons.savings_outlined,
};

/// Icon names a user can pick for a custom category.
List<String> get categoryIconNames => _iconByName.keys.toList();

IconData categoryIcon(Category c) => categoryIconByName(c.icon);

IconData categoryIconByName(String? name) => _iconByName[name] ?? Icons.label_outline;

Color? categoryColor(Category c) {
  final hex = c.color;
  if (hex == null || hex.isEmpty) return null;
  final v = int.tryParse(hex, radix: 16);
  if (v == null) return null;
  return Color(hex.length <= 6 ? (0xFF000000 | v) : v);
}

/// Color to paint a category with, always non-null: the stored one or a
/// stable hash-derived hue so custom categories without a color still get a
/// consistent identity in charts.
Color categoryPaint(Category c, ColorScheme scheme) {
  final stored = categoryColor(c);
  if (stored != null) return stored;
  final hue = (c.id * 47) % 360;
  return HSLColor.fromAHSL(1, hue.toDouble(), 0.55, 0.45).toColor();
}

/// Compact icon + label pill. Pass [category] = null for "Uncategorized".
class CategoryChip extends ConsumerWidget {
  final Category? category;
  final bool dense;
  final VoidCallback? onTap;

  const CategoryChip({required this.category, this.dense = true, this.onTap, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final scheme = Theme.of(context).colorScheme;
    final c = category;
    final color = c == null ? scheme.outline : categoryPaint(c, scheme);
    final label = c == null ? s.uncategorized : categoryLabel(c, s);
    final icon = c == null ? Icons.help_outline : categoryIcon(c);
    final child = Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 10, vertical: dense ? 2 : 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dense ? 12 : 16, color: color),
          SizedBox(width: dense ? 4 : 6),
          Text(
            label,
            style: TextStyle(fontSize: dense ? 11 : 13, color: color, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
    return onTap == null ? child : InkWell(borderRadius: BorderRadius.circular(999), onTap: onTap, child: child);
  }
}

/// Result of [showCategoryPicker]: `null` = dismissed; `CategoryPick(null)` =
/// "no category" chosen explicitly.
class CategoryPick {
  final int? categoryId;
  const CategoryPick(this.categoryId);
}

/// Modal category picker, grouped by [CategoryType], with search. Shared by
/// the edit screen, bulk selection and the wizard.
Future<CategoryPick?> showCategoryPicker(
  BuildContext context, {
  int? selected,
  bool allowNone = true,
  List<int> recentIds = const [],
}) {
  return showModalBottomSheet<CategoryPick>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CategoryPickerSheet(selected: selected, allowNone: allowNone, recentIds: recentIds),
  );
}

class _CategoryPickerSheet extends ConsumerStatefulWidget {
  final int? selected;
  final bool allowNone;
  final List<int> recentIds;
  const _CategoryPickerSheet({required this.selected, required this.allowNone, required this.recentIds});

  @override
  ConsumerState<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends ConsumerState<_CategoryPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final cats = ref.watch(categoriesProvider).value ?? const <Category>[];
    final byId = {for (final c in cats) c.id: c};
    final q = _query.trim().toLowerCase();
    final visible = q.isEmpty ? cats : cats.where((c) => categoryLabel(c, s).toLowerCase().contains(q)).toList();
    final recent = widget.recentIds.map((id) => byId[id]).whereType<Category>().toList();

    final sections = <Widget>[];
    if (q.isEmpty && recent.isNotEmpty) {
      sections.add(_header(context, s.wizardRecentCategories));
      sections.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final c in recent) CategoryChip(category: c, dense: false, onTap: () => _pick(c.id))],
          ),
        ),
      );
    }
    for (final type in CategoryType.values) {
      final ofType = visible.where((c) => c.type == type).toList();
      if (ofType.isEmpty) continue;
      sections.add(_header(context, s.categoryTypeName(type)));
      for (final c in ofType) {
        final color = categoryPaint(c, Theme.of(context).colorScheme);
        sections.add(
          ListTile(
            dense: true,
            leading: Icon(categoryIcon(c), color: color),
            title: Text(categoryLabel(c, s)),
            selected: c.id == widget.selected,
            trailing: c.id == widget.selected ? const Icon(Icons.check) : null,
            onTap: () => _pick(c.id),
          ),
        );
      }
    }
    sections.add(const Divider());
    // Fast path: create a category right here and select it. When a search
    // found nothing, the query becomes the proposed name.
    sections.add(
      ListTile(
        key: const Key('categoryPickerNew'),
        dense: true,
        leading: const Icon(Icons.add),
        title: Text(q.isNotEmpty && visible.isEmpty ? s.createCategoryNamed(_query.trim()) : s.newCategoryEllipsis),
        onTap: () async {
          final id = await showCategoryEditDialog(context, initialName: q.isEmpty ? null : _query.trim());
          if (id != null && mounted) _pick(id);
        },
      ),
    );
    if (widget.allowNone && q.isEmpty) {
      sections.add(
        ListTile(
          dense: true,
          leading: const Icon(Icons.block),
          title: Text(s.noCategory),
          selected: widget.selected == null,
          onTap: () => _pick(null),
        ),
      );
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (ctx, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              key: const Key('categoryPickerSearch'),
              autofocus: false,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: s.search,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView(controller: controller, children: sections),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1.1,
      ),
    ),
  );

  void _pick(int? id) => Navigator.of(context).pop(CategoryPick(id));
}

/// Read-only form-field-looking row that opens [showCategoryPicker] on tap.
/// Used by the transaction edit screen.
class CategoryField extends ConsumerWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  final String? helperText;

  const CategoryField({required this.value, required this.onChanged, this.helperText, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final byId = ref.watch(categoriesByIdProvider);
    final c = value == null ? null : byId[value];
    return InkWell(
      onTap: () async {
        final pick = await showCategoryPicker(context, selected: value);
        if (pick != null) onChanged(pick.categoryId);
      },
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: s.category,
          helperText: helperText,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: CategoryChip(category: c, dense: false),
        ),
      ),
    );
  }
}
