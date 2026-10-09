// The import wizard's "Refine rows & columns" panel:
//
//  * An unreadable skip-rows value (not a whole number, or negative) is
//    flagged on the field and not applied — it used to become 0 silently and
//    re-read the file without the rows the user meant to skip.
//  * The panel follows the reference collapsible style: its ExpansionTile has
//    no card of its own around it, and its header still opens it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/ui/screens/import/import_screen.dart';

import 'import_wizard_harness.dart';

void main() {
  const s = AppStrings.en;
  final h = ImportHarness();
  late int acct;
  late List<int> parsedWith;

  setUpAll(ImportHarness.initLocales);
  setUp(() async {
    h.open();
    acct = await h.db.into(h.db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    parsedWith = [];
    h.importer.onParseFile = (path, skip) async {
      parsedWith.add(skip);
      return FilePreview(
        columns: ['Date', 'Amount', 'Skipped $skip'],
        rows: [
          {'Date': '11/05/2022', 'Amount': '1', 'Skipped $skip': 'x'},
        ],
        totalRows: 1,
        filePath: path,
        skipRows: skip,
        numberLocale: 'en_US',
      );
    };
  });
  tearDown(() => h.close());

  Future<void> openPanel(WidgetTester tester) async {
    await h.pump(tester, ImportScreen(preselectedAccountId: acct, initialFilePath: '/tmp/statement.csv'));
    await tester.ensureVisible(find.text(s.refineRowsColumns));
    await tester.tap(find.text(s.refineRowsColumns));
    await h.settle(tester);
  }

  Finder skipRowsField() => find.ancestor(of: find.byIcon(Icons.arrow_drop_up), matching: find.byType(TextFormField));

  /// Types [text] and waits past the field's re-read delay.
  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(skipRowsField(), text);
    await tester.pump(const Duration(milliseconds: 1200));
    await h.settle(tester);
  }

  testWidgets('pin: a whole number re-reads the file skipping that many rows', (tester) async {
    await openPanel(tester);
    try {
      expect(find.text('Skipped 0'), findsOneWidget);
      await type(tester, '2');
      expect(find.text('Skipped 2'), findsOneWidget);
      expect(parsedWith.last, 2);
      expect(find.text(s.invalidNumber), findsNothing);
    } finally {
      await h.unmount(tester);
    }
  });

  for (final unreadable in ['abc', '-1', '1.5', '']) {
    testWidgets('"$unreadable" is flagged and not applied', (tester) async {
      await openPanel(tester);
      try {
        await type(tester, '2');
        final reads = parsedWith.length;

        await type(tester, unreadable);
        expect(find.text(s.invalidNumber), findsOneWidget, reason: 'said on the field');
        expect(parsedWith.length, reads, reason: 'the file is not re-read with a guessed value');
        expect(find.text('Skipped 2'), findsOneWidget, reason: 'the rows of the last readable value stay');

        await type(tester, '3');
        expect(find.text(s.invalidNumber), findsNothing);
        expect(find.text('Skipped 3'), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });
  }

  testWidgets('the arrows step from the last readable value and clear the error', (tester) async {
    await openPanel(tester);
    try {
      await type(tester, '2');
      await type(tester, 'abc');
      await tester.tap(find.byIcon(Icons.arrow_drop_up));
      await h.settle(tester);
      expect(find.text(s.invalidNumber), findsNothing);
      expect(find.text('Skipped 3'), findsOneWidget);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('the panel has no card of its own; its header opens it', (tester) async {
    await h.pump(tester, ImportScreen(preselectedAccountId: acct, initialFilePath: '/tmp/statement.csv'));
    try {
      final tile = find.ancestor(of: find.text(s.refineRowsColumns), matching: find.byType(ExpansionTile)).first;
      expect(find.ancestor(of: tile, matching: find.byType(Card)), findsNothing);
      expect(find.text(s.skipRows), findsNothing, reason: 'collapsed at first');
      await tester.ensureVisible(find.text(s.refineRowsColumns));
      await tester.tap(find.text(s.refineRowsColumns));
      await h.settle(tester);
      expect(find.text(s.skipRows), findsOneWidget);
    } finally {
      await h.unmount(tester);
    }
  });
}
