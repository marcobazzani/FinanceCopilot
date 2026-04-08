import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:finance_copilot/database/database.dart';

import 'helpers/test_app.dart';

/// Regression test for #40: legacy DB at Documents path should auto-migrate.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Legacy DB at Documents path auto-migrates on startup', (tester) async {
    // 1. Create a legacy DB at the old Documents path with real data
    final docsDir = await getApplicationDocumentsDirectory();
    final legacyDir = Directory(p.join(docsDir.path, 'FinanceCopilot'));
    await legacyDir.create(recursive: true);
    final legacyPath = p.join(legacyDir.path, 'finance_copilot.db');

    // Create a real SQLite DB with an account at the legacy path
    final legacyDb = AppDatabase.forTesting(NativeDatabase(File(legacyPath)));
    await legacyDb.into(legacyDb.accounts).insert(AccountsCompanion.insert(
      name: 'Legacy Account',
      sortOrder: const Value(1),
    ));
    await legacyDb.close();

    // 2. Delete the new DB path so the app thinks it's a fresh install
    final newDbFile = await AppDatabase.dbFile();
    if (newDbFile.existsSync()) {
      await newDbFile.delete();
    }

    // 3. Launch the app — should auto-migrate and NOT show landing page
    await pumpApp(tester);

    // 4. Verify: the app shows the main navigation (not landing page)
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Accounts'), findsWidgets);

    // 5. Verify: the new DB file now exists
    expect(newDbFile.existsSync(), isTrue);

    // 6. Verify: legacy file still exists (copied, not moved)
    expect(File(legacyPath).existsSync(), isTrue);

    // Cleanup: remove legacy file
    await File(legacyPath).delete();
    if (legacyDir.existsSync()) {
      try { await legacyDir.delete(); } catch (_) {}
    }
  });
}
