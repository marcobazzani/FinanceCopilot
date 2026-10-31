// What a manual edit records: the area and kind of change each write makes,
// and the log that compares two states of the same data.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/edit_log.dart';
import 'package:finance_copilot/database/manual_edit_tracker.dart';

void main() {
  test('every table is assigned an area, or marked provider data, so a new one needs a decision', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final tables = db.allTables.map((t) => t.actualTableName).toSet();
    expect(tables.difference(editAreaOfTable.keys.toSet()), isEmpty, reason: 'add the new table to editAreaOfTable');
    expect(editAreaOfTable.keys.toSet().difference(tables), isEmpty, reason: 'drop the tables that no longer exist');
  });

  test('provider data is no area; an unknown table still counts, as other data', () {
    expect(editAreaOf('market_prices'), isNull);
    expect(editAreaOf('exchange_rates'), isNull);
    expect(editAreaOf('buffer_transactions'), EditArea.adjustments, reason: 'reimbursements belong to their adjustment');
    expect(editAreaOf('a_table_added_later'), EditArea.other);
  });

  group('classifyWrite', () {
    test('an insert adds', () {
      expect(classifyWrite('INSERT INTO "accounts" ("name") VALUES (?)'), (EditArea.accounts, EditKind.added));
      expect(classifyWrite('INSERT OR IGNORE INTO categories VALUES (1)'), (EditArea.categories, EditKind.added));
    });

    test('an insert that may overwrite, an update and a replace change', () {
      expect(
        classifyWrite('INSERT INTO "app_configs" ("key", "value") VALUES (?, ?) ON CONFLICT("key") DO UPDATE SET "value" = ?'),
        (EditArea.settings, EditKind.changed),
      );
      expect(classifyWrite('INSERT OR REPLACE INTO "pillar_assets" VALUES (?)'), (EditArea.pillars, EditKind.changed));
      expect(classifyWrite('REPLACE INTO import_configs VALUES (1)'), (EditArea.importSettings, EditKind.changed));
      expect(classifyWrite('UPDATE "transactions" SET "category_id" = ? WHERE "id" = ?'), (EditArea.transactions, EditKind.changed));
    });

    test('a delete deletes', () {
      expect(classifyWrite('DELETE FROM "asset_events" WHERE "id" = ?'), (EditArea.assetEvents, EditKind.deleted));
    });

    test('provider data, reads and anything else are no edits', () {
      expect(classifyWrite('INSERT INTO "market_prices" VALUES (?)'), isNull);
      expect(classifyWrite('SELECT * FROM accounts'), isNull);
      expect(classifyWrite('PRAGMA foreign_keys = ON'), isNull);
    });
  });

  group('EditLog', () {
    const log = EditLog(
      changes: 7,
      tokens: {(EditArea.accounts, EditKind.added): 'a1', (EditArea.rules, EditKind.changed): 'b2'},
    );

    test('survives its stored form', () {
      expect(EditLog.decode(log.encode()), log);
    });

    test('a missing or unreadable log is empty; unknown areas are left out', () {
      expect(EditLog.decode(null), EditLog.empty);
      expect(EditLog.decode('not json'), EditLog.empty);
      expect(EditLog.decode('[1, 2]'), EditLog.empty);
      expect(
        EditLog.decode('{"n": 2, "accounts.added": "x", "future.added": "y", "accounts.renamed": "z"}'),
        const EditLog(changes: 2, tokens: {(EditArea.accounts, EditKind.added): 'x'}),
      );
    });

    test('tells the kinds of change made since an earlier log', () {
      const later = EditLog(
        changes: 9,
        tokens: {(EditArea.accounts, EditKind.added): 'a1', (EditArea.rules, EditKind.changed): 'c3', (EditArea.assets, EditKind.deleted): 'd4'},
      );
      expect(later.editedSince(log), {(EditArea.rules, EditKind.changed), (EditArea.assets, EditKind.deleted)});
      expect(log.editedSince(log), isEmpty);
    });
  });
}
