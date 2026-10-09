// The import mapper's titles and the preview's separator band read right for
// one row and for many, and the band says how many rows it hides once — it
// used to wrap the "⋯ N rows hidden ⋯" text in a second pair of dots.
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/ui/screens/import/import_screen.dart';

import 'import_wizard_harness.dart';

void main() {
  final h = ImportHarness();
  late int acct;

  setUpAll(ImportHarness.initLocales);
  setUp(() async {
    h.open();
    acct = await h.db.into(h.db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
  });
  tearDown(() => h.close());

  /// The parser's capped preview of a [total]-row file: its first 5 and last 5 rows.
  FilePreview capped(int total) => FilePreview(
    columns: const ['Date', 'Amount'],
    rows: [
      for (var i = 1; i <= 10; i++) {'Date': '$i/05/2022', 'Amount': '$i'},
    ],
    totalRows: total,
    numberLocale: 'en_US',
  );

  testWidgets('one hidden row: "⋯ 1 row hidden ⋯"', (tester) async {
    await h.pump(tester, ImportScreen(preselectedAccountId: acct, testPreview: capped(11)));
    try {
      expect(find.text('⋯ 1 row hidden ⋯'), findsOneWidget);
      expect(find.text('Preview (11 rows)'), findsOneWidget);
      expect(find.text('Map columns (2 columns, 11 rows)'), findsOneWidget);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('several hidden rows, in Italian', (tester) async {
    await h.pump(
      tester,
      ImportScreen(preselectedAccountId: acct, testPreview: capped(15)),
      language: 'it',
      locale: 'it_IT',
    );
    try {
      expect(find.text('⋯ 5 righe nascoste ⋯'), findsOneWidget);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('a one-row file', (tester) async {
    const single = FilePreview(
      columns: ['Date'],
      rows: [
        {'Date': '11/05/2022'},
      ],
      totalRows: 1,
      numberLocale: 'en_US',
    );
    await h.pump(tester, ImportScreen(preselectedAccountId: acct, testPreview: single));
    try {
      expect(find.text('Preview (1 row)'), findsOneWidget);
      expect(find.text('Map columns (1 column, 1 row)'), findsOneWidget);
    } finally {
      await h.unmount(tester);
    }
  });
}
