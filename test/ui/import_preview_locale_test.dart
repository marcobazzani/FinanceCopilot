// The wizard's inline previews read numbers exactly like the import: in the
// chosen number format (here it_IT, where "1.000" is one thousand), not with a
// guess that reads "1.000" as 1. They spell the result in the app's locale
// ("1.000,00" in it_IT, not "1000.00") and separate the values with a dot, so
// a decimal comma cannot be read as a list comma.
import 'package:flutter/material.dart';
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
    acct = await h.db.into(h.db.accounts).insert(AccountsCompanion.insert(name: 'Conto'));
  });
  tearDown(() => h.close());

  const statement = FilePreview(
    columns: ['Balance', 'Fee', 'Date', 'Description'],
    rows: [
      {'Balance': '1.000', 'Fee': '2', 'Date': '11/05/2022', 'Description': 'a'},
      {'Balance': '1.500', 'Fee': '3', 'Date': '12/05/2022', 'Description': 'b'},
      {'Balance': '2.250', 'Fee': '4', 'Date': '13/05/2022', 'Description': 'c'},
    ],
    totalRows: 3,
    numberLocale: 'it_IT',
  );

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await h.settle(tester, frames: 4);
    await tester.tap(f);
    await h.settle(tester);
  }

  Future<void> pumpTransactions(WidgetTester tester) => h.pump(
    tester,
    ImportScreen(preselectedAccountId: acct, testPreview: statement),
    locale: 'it_IT',
  );

  testWidgets('balance difference: 1.000 → 1.500 → 2.250 is +500 then +750', (tester) async {
    await pumpTransactions(tester);
    try {
      await tap(tester, find.widgetWithText(OutlinedButton, 'Balance Δ'));
      expect(find.textContaining('→ 1.000,00 (first)  ·  500,00  ·  750,00'), findsOneWidget);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('formula: the terms are read in the file format', (tester) async {
    await pumpTransactions(tester);
    try {
      await tap(tester, find.widgetWithText(OutlinedButton, 'Formula'));
      expect(find.text('Preview: 1.000,00  ·  1.500,00  ·  2.250,00'), findsOneWidget);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('combined numeric columns add up in the file format', (tester) async {
    await pumpTransactions(tester);
    try {
      await h.mapColumn(tester, 'Description *', 'Balance');
      await tester.tap(find.byTooltip('Combine multiple columns'));
      await h.settle(tester);
      expect(find.text('Preview: 1.002,00'), findsOneWidget, reason: 'Balance 1.000 + Fee 2');
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('computed fee: |1.010| − 10 × 100 / 1 is 10', (tester) async {
    const trades = FilePreview(
      columns: ['Gross', 'Units', 'Unit price', 'FX', 'Day', 'Code'],
      rows: [
        {'Gross': '1.010', 'Units': '10', 'Unit price': '100', 'FX': '1', 'Day': '11/05/2022', 'Code': 'IE00B4L5Y983'},
      ],
      totalRows: 1,
      numberLocale: 'it_IT',
    );
    await h.pump(
      tester,
      const ImportScreen(preselectedTarget: ImportTarget.assetEvent, testPreview: trades),
      locale: 'it_IT',
    );
    try {
      await h.mapColumn(tester, 'Amount', 'Gross');
      await h.mapColumn(tester, 'Quantity', 'Units');
      await h.mapColumn(tester, 'Price', 'Unit price');
      await h.mapColumn(tester, 'Exchange Rate', 'FX');
      await tap(tester, find.text('Computed').first);
      expect(find.text('Preview: 10,00'), findsOneWidget);
    } finally {
      await h.unmount(tester);
    }
  });
}
