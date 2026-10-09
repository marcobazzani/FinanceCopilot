import 'package:drift/drift.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/utils/logger.dart';

final _log = getLogger('CategoryService');

/// Usage of a category across the ledger and the rule set.
class CategoryUsage {
  final int transactions;
  final int rules;
  const CategoryUsage({required this.transactions, required this.rules});
  bool get isEmpty => transactions == 0 && rules == 0;
}

/// CRUD for transaction categories. Display names for seeded rows are
/// resolved from [Category.key] by the UI (l10n); this service only stores.
class CategoryService {
  final AppDatabase _db;
  CategoryService(this._db);

  SimpleSelectStatement<$CategoriesTable, Category> _select({bool includeArchived = false}) {
    final q = _db.select(_db.categories);
    if (!includeArchived) q.where((c) => c.isArchived.equals(false));
    q.orderBy([(c) => OrderingTerm.asc(c.sortOrder), (c) => OrderingTerm.asc(c.name)]);
    return q;
  }

  Stream<List<Category>> watchAll({bool includeArchived = false}) => _select(includeArchived: includeArchived).watch();

  Future<List<Category>> getAll({bool includeArchived = false}) => _select(includeArchived: includeArchived).get();

  Future<Category?> getById(int id) => (_db.select(_db.categories)..where((c) => c.id.equals(id))).getSingleOrNull();

  /// The seeded category with [key], or null if the user deleted it.
  Future<Category?> getByKey(String key) => (_db.select(_db.categories)..where((c) => c.key.equals(key))).getSingleOrNull();

  Future<int> create({
    required String name,
    required CategoryType type,
    String? icon,
    String? color,
    bool isEssential = false,
  }) async {
    final maxRow = await _db.customSelect('SELECT COALESCE(MAX(sort_order), -1) AS m FROM categories', readsFrom: {_db.categories}).getSingle();
    final next = maxRow.read<int>('m') + 1;
    _log.info('create: name=$name type=${type.name}');
    return _db
        .into(_db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: name.trim(),
            type: type,
            icon: Value(icon),
            color: Value(color),
            isEssential: Value(isEssential),
            sortOrder: Value(next),
          ),
        );
  }

  /// Rename. A seeded category loses its l10n [Category.key] so the custom
  /// name wins from now on.
  Future<bool> rename(int id, String name) async {
    final n = await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(name: Value(name.trim()), key: const Value(null)),
    );
    return n > 0;
  }

  Future<bool> update(int id, CategoriesCompanion companion) async {
    final n = await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(companion);
    return n > 0;
  }

  Future<bool> setArchived(int id, bool archived) => update(id, CategoriesCompanion(isArchived: Value(archived)));

  /// Persist a new display order: [ids] in the desired order.
  Future<void> reorder(List<int> ids) async {
    await _db.transaction(() async {
      for (var i = 0; i < ids.length; i++) {
        await (_db.update(_db.categories)..where((c) => c.id.equals(ids[i]))).write(CategoriesCompanion(sortOrder: Value(i)));
      }
    });
  }

  Future<CategoryUsage> usage(int id) async {
    final tx =
        await (_db.selectOnly(_db.transactions)
              ..addColumns([_db.transactions.id.count()])
              ..where(_db.transactions.categoryId.equals(id)))
            .getSingle();
    final rules =
        await (_db.selectOnly(_db.autoCategorizationRules)
              ..addColumns([_db.autoCategorizationRules.id.count()])
              ..where(_db.autoCategorizationRules.categoryId.equals(id)))
            .getSingle();
    return CategoryUsage(
      transactions: tx.read(_db.transactions.id.count()) ?? 0,
      rules: rules.read(_db.autoCategorizationRules.id.count()) ?? 0,
    );
  }

  /// Delete a category. Transactions move to [reassignTo] (or become
  /// uncategorized when null); rules move to [reassignTo] or are deleted when
  /// null, because a rule must point at a category.
  Future<void> delete(int id, {int? reassignTo}) async {
    if (reassignTo == id) throw ArgumentError('reassignTo must differ from the deleted category');
    await _db.transaction(() async {
      await (_db.update(_db.transactions)..where((t) => t.categoryId.equals(id))).write(
        TransactionsCompanion(categoryId: Value(reassignTo)),
      );
      if (reassignTo != null) {
        await (_db.update(_db.autoCategorizationRules)..where((r) => r.categoryId.equals(id))).write(
          AutoCategorizationRulesCompanion(categoryId: Value(reassignTo)),
        );
      } else {
        await (_db.delete(_db.autoCategorizationRules)..where((r) => r.categoryId.equals(id))).go();
      }
      await (_db.update(_db.categories)..where((c) => c.parentId.equals(id))).write(
        const CategoriesCompanion(parentId: Value(null)),
      );
      await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
    });
    _log.info('delete: id=$id reassignTo=$reassignTo');
  }

  /// Re-insert any missing default category. Returns how many were added.
  Future<int> restoreDefaults() => _db.seedDefaultCategories();
}
