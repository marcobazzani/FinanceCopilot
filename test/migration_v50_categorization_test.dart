import 'dart:io';

import 'package:drift/native.dart';
import 'package:finance_copilot/database/category_seeds.dart';
import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Migration 50: transaction categorization columns + default categories.
void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fc_migration_v50_');
    path = p.join(dir.path, 'migration.db');
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  /// Create a current-schema DB, then strip the v50 additions and stamp it
  /// as v49 so the upgrade path runs on reopen.
  Future<void> createV49Db({int existingCustomCategories = 0}) async {
    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    await db.select(db.accounts).get();
    await db.close();

    final raw = sqlite.sqlite3.open(path);
    try {
      raw.execute('DELETE FROM categories');
      raw.execute('DROP INDEX IF EXISTS idx_transactions_merchant_key');
      raw.execute('DROP INDEX IF EXISTS idx_transactions_category');
      for (final c in ['key', 'is_archived', 'sort_order']) {
        raw.execute('ALTER TABLE categories DROP COLUMN $c');
      }
      for (final c in ['merchant_key', 'counterparty', 'entry_kind']) {
        raw.execute('ALTER TABLE transactions DROP COLUMN $c');
      }
      for (final c in ['match_type', 'account_id', 'direction', 'amount_min', 'amount_max']) {
        raw.execute('ALTER TABLE auto_categorization_rules DROP COLUMN $c');
      }
      for (var i = 0; i < existingCustomCategories; i++) {
        raw.execute("INSERT INTO categories (name, type, is_essential) VALUES ('Custom $i', 'expense', 0)");
      }
      raw.execute('PRAGMA user_version = 49');
    } finally {
      raw.dispose();
    }
  }

  Future<Set<String>> columns(AppDatabase db, String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  test('v49 → v50 adds the categorization columns and seeds default categories', () async {
    await createV49Db();

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    final version = (await db.customSelect('PRAGMA user_version').get()).first.read<int>('user_version');
    expect(version, 50);

    expect(await columns(db, 'categories'), containsAll(['key', 'is_archived', 'sort_order']));
    expect(await columns(db, 'transactions'), containsAll(['merchant_key', 'counterparty', 'entry_kind']));
    expect(
      await columns(db, 'auto_categorization_rules'),
      containsAll(['match_type', 'account_id', 'direction', 'amount_min', 'amount_max']),
    );

    final cats = await db.select(db.categories).get();
    expect(cats, hasLength(defaultCategorySeeds.length));
    expect(cats.map((c) => c.key).toSet(), defaultCategorySeeds.map((s) => s.key).toSet());
    expect(cats.every((c) => !c.isArchived), isTrue);
    // sortOrder follows seed order.
    final byKey = {for (final c in cats) c.key!: c};
    for (var i = 0; i < defaultCategorySeeds.length; i++) {
      expect(byKey[defaultCategorySeeds[i].key]!.sortOrder, i);
      expect(byKey[defaultCategorySeeds[i].key]!.type, defaultCategorySeeds[i].type);
    }

    final indexes = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' AND name IN "
          "('idx_transactions_merchant_key','idx_transactions_category')",
        )
        .get();
    expect(indexes, hasLength(2));
    await db.close();
  });

  test('seeding preserves pre-existing user categories and is idempotent', () async {
    await createV49Db(existingCustomCategories: 2);

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    final cats = await db.select(db.categories).get();
    expect(cats, hasLength(defaultCategorySeeds.length + 2));
    expect(cats.where((c) => c.key == null).map((c) => c.name), containsAll(['Custom 0', 'Custom 1']));

    // Re-running the seed inserts nothing.
    expect(await db.seedDefaultCategories(), 0);
    expect(await db.select(db.categories).get(), hasLength(defaultCategorySeeds.length + 2));

    // Re-inserts only a missing default (restore-defaults semantics).
    await (db.delete(db.categories)..where((c) => c.key.equals('groceries'))).go();
    expect(await db.seedDefaultCategories(), 1);
    await db.close();
  });

  test('seed-set top-up adds only new defaults and respects deliberate deletions', () async {
    await createV49Db();
    // Simulate a DB that already ran v50 with the v1 seed set: remove the
    // v2 addition and one v1 default the user deleted on purpose, stamp v1.
    final db1 = AppDatabase.forTesting(NativeDatabase(File(path)));
    await (db1.delete(db1.categories)..where((c) => c.key.equals('childcare'))).go();
    await (db1.delete(db1.categories)..where((c) => c.key.equals('cash'))).go();
    await db1.into(db1.appConfigs).insertOnConflictUpdate(AppConfigsCompanion.insert(key: kCategorySeedVersionKey, value: '1'));
    await db1.close();

    final db2 = AppDatabase.forTesting(NativeDatabase(File(path)));
    await db2.select(db2.accounts).get(); // triggers beforeOpen
    final keys = (await db2.select(db2.categories).get()).map((c) => c.key).toSet();
    expect(keys, contains('childcare'), reason: 'new v2 default is added');
    expect(keys, isNot(contains('cash')), reason: 'a default deleted by the user is not resurrected');
    final v = await (db2.select(db2.appConfigs)..where((c) => c.key.equals(kCategorySeedVersionKey))).getSingle();
    expect(v.value, kCategorySeedVersion.toString());
    await db2.close();

    // Restore defaults is the explicit path that brings a deleted default back.
    final db3 = AppDatabase.forTesting(NativeDatabase(File(path)));
    expect(await db3.seedDefaultCategories(), 1);
    await db3.close();
  });

  test('fresh database is seeded with default categories and default rule columns', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final cats = await db.select(db.categories).get();
    expect(cats, hasLength(defaultCategorySeeds.length));
    expect(cats.map((c) => c.key), contains('childcare'));
    expect(await db.select(db.autoCategorizationRules).get(), isEmpty, reason: 'no rules are ever seeded');
    final v = await (db.select(db.appConfigs)..where((c) => c.key.equals(kCategorySeedVersionKey))).getSingle();
    expect(v.value, kCategorySeedVersion.toString());

    final groceries = cats.singleWhere((c) => c.key == 'groceries');
    final ruleId = await db
        .into(db.autoCategorizationRules)
        .insert(AutoCategorizationRulesCompanion.insert(pattern: 'ESSELUNGA', categoryId: groceries.id));
    final rule = await (db.select(db.autoCategorizationRules)..where((r) => r.id.equals(ruleId))).getSingle();
    expect(rule.matchType, RuleMatchType.merchantKey);
    expect(rule.direction, RuleDirection.any);
    expect(rule.isActive, isTrue);
    expect(rule.accountId, isNull);
    await db.close();
  });
}
