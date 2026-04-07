import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:finance_copilot/services/import_service.dart';

import 'helpers/test_app.dart';

/// Tap Buy/Sell ChoiceChips for asset type-from-column mapping.
/// Assumes 2 unique values (e.g. "Buy" and "Sell"), each row has a Buy and Sell chip.
/// First row gets mapped to Buy, second row to Sell.
Future<void> tapBuySellChips(WidgetTester tester) async {
  final buyChips = find.widgetWithText(ChoiceChip, 'Buy');
  final sellChips = find.widgetWithText(ChoiceChip, 'Sell');
  if (buyChips.evaluate().isNotEmpty) {
    await tester.ensureVisible(buyChips.first);
    await settle(tester);
    await tester.tap(buyChips.first);
    await settle(tester);
  }
  if (sellChips.evaluate().length >= 2) {
    await tester.ensureVisible(sellChips.last);
    await settle(tester);
    await tester.tap(sellChips.last);
    await settle(tester);
  }
}

/// Full UI-driven import flow tests covering all import types, modes, and file formats.
///
/// Every test loads real fixture files from integration_test/fixtures/ (bundled as assets),
/// parses them via the real ImportService.parseFile(), and drives the full import UI.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ── Transaction: amount from column (CSV fixture) ───────

  testWidgets('Import CSV: transaction with amount from column', (tester) async {
    final db = await pumpApp(tester, seed: (db) async {
      await seedAccount(db, name: 'Main Account');
    });

    late FilePreview preview;
    await tester.runAsync(() async {
      preview = await parseFixture(db, 'transactions_simple.csv');
    });

    await pushImportScreen(tester, preview: preview);
    expect(find.text('Date'), findsWidgets);
    expect(find.text('Amount'), findsWidgets);

    await tester.tap(find.text('Next'));
    await settle(tester);
    await tester.tap(find.text('Main Account'));
    await settle(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Import Complete'), findsOneWidget);
    final txs = await db.select(db.transactions).get();
    expect(txs.length, 3);
    expect(txs.any((t) => t.description == 'Supermarket' && t.amount == -42.50), isTrue);
    expect(txs.any((t) => t.description == 'Salary' && t.amount == 1500.00), isTrue);
    expect(txs.any((t) => t.description == 'Electricity' && t.amount == -120.00), isTrue);
  });

  // ── Transaction: amount from column (XLSX fixture with typed cells) ──

  testWidgets('Import XLSX: transaction with typed date/number cells', (tester) async {
    final db = await pumpApp(tester, seed: (db) async {
      await seedAccount(db, name: 'Bank XLSX');
    });

    late FilePreview preview;
    await tester.runAsync(() async {
      preview = await parseFixture(db, 'transactions_simple.xlsx');
    });

    await pushImportScreen(tester, preview: preview);
    await tester.tap(find.text('Next'));
    await settle(tester);
    await tester.tap(find.text('Bank XLSX'));
    await settle(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Import Complete'), findsOneWidget);
    final txs = await db.select(db.transactions).get();
    expect(txs.length, 3);
    expect(txs.any((t) => t.amount == -42.50), isTrue);
    expect(txs.any((t) => t.amount == 1500.00), isTrue);
  });

  // ── Transaction: European CSV fixture (semicolon + comma decimal) ──

  testWidgets('Import CSV: European format (semicolon, comma decimal)', (tester) async {
    final db = await pumpApp(tester, seed: (db) async {
      await seedAccount(db, name: 'EU Bank');
    });

    late FilePreview preview;
    await tester.runAsync(() async {
      preview = await parseFixture(db, 'transactions_simple_eu.csv');
    });

    await pushImportScreen(tester, preview: preview);
    await tester.tap(find.text('Next'));
    await settle(tester);
    await tester.tap(find.text('EU Bank'));
    await settle(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Import Complete'), findsOneWidget);
    final txs = await db.select(db.transactions).get();
    expect(txs.length, 3);
    expect(txs.any((t) => t.amount == -42.50), isTrue);
    expect(txs.any((t) => t.amount == 1500.00), isTrue);
  });

  // ── Transaction: amount from formula (CSV fixture + service) ────

  testWidgets('Import: transaction with amount from formula', (tester) async {
    final db = await pumpApp(tester, seed: (db) async {
      await seedAccount(db, name: 'Bank');
    });

    late FilePreview preview;
    await tester.runAsync(() async {
      preview = await parseFixture(db, 'transactions_formula.csv');
    });

    final importer = ImportService(db);
    final accounts = await db.select(db.accounts).get();
    final accountId = accounts.firstWhere((a) => a.name == 'Bank').id;

    final result = await importer.importTransactions(
      preview: preview,
      mappings: [
        const ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
        const ColumnMapping(sourceColumn: 'Description', targetField: 'description'),
        ColumnMapping(targetField: 'amount', formulaTerms: [
          const FormulaTerm(operator: '+', sourceColumn: 'Credit'),
          const FormulaTerm(operator: '-', sourceColumn: 'Debit'),
        ]),
      ],
      accountId: accountId,
    );

    expect(result.importedRows, 3);
    final txs = await db.select(db.transactions).get();
    expect(txs.any((t) => t.description == 'Salary' && t.amount == 2000.00), isTrue);
    expect(txs.any((t) => t.description == 'Rent' && t.amount == -150.00), isTrue);
    expect(txs.any((t) => t.description == 'Groceries' && t.amount == -30.00), isTrue);
  });

  // ── Transaction: skip rows (XLSX fixture) ───────────────

  testWidgets('Import XLSX: transaction with skip rows', (tester) async {
    final db = await pumpApp(tester, seed: (db) async {
      await seedAccount(db, name: 'Checking');
    });

    late FilePreview preview;
    await tester.runAsync(() async {
      preview = await parseFixture(db, 'transactions_skip_rows.xlsx', skipRows: 2);
    });

    await pushImportScreen(tester, preview: preview);
    await tester.tap(find.text('Next'));
    await settle(tester);
    await tester.tap(find.text('Checking'));
    await settle(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Import Complete'), findsOneWidget);
    final txs = await db.select(db.transactions).get();
    expect(txs.length, 2);
    expect(txs.any((t) => t.description == 'Insurance'), isTrue);
    expect(txs.any((t) => t.description == 'Salary March'), isTrue);
  });

  // ── Asset: historic + type from column + fee from column (CSV fixture) ──

  testWidgets('Import CSV: asset historic, type from column, fee from column', (tester) async {
    final db = await pumpApp(tester);

    late FilePreview preview;
    await tester.runAsync(() async {
      preview = await parseFixture(db, 'assets_type_column.csv');
    });

    await pushImportScreen(tester, preview: preview, target: ImportTarget.assetEvent);

    await tester.drag(find.byType(ListView).first, const Offset(0, -200));
    await settle(tester);
    await tapBuySellChips(tester);

    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await settle(tester);
    await tester.tap(find.text('Next'));
    await settle(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Import Complete'), findsOneWidget);
    final events = await db.select(db.assetEvents).get();
    expect(events.length, 3);
    expect(events.where((e) => e.commission == 5.00).length, 2);
    expect(events.where((e) => e.commission == 3.00).length, 1);
  });

  // ── Asset: European CSV fixture (semicolon, comma decimal) ──

  testWidgets('Import CSV: asset European format (semicolon, comma decimal)', (tester) async {
    final db = await pumpApp(tester);

    late FilePreview preview;
    await tester.runAsync(() async {
      preview = await parseFixture(db, 'assets_type_column_eu.csv');
    });

    await pushImportScreen(tester, preview: preview, target: ImportTarget.assetEvent);

    await tester.drag(find.byType(ListView).first, const Offset(0, -200));
    await settle(tester);
    await tapBuySellChips(tester);

    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await settle(tester);
    await tester.tap(find.text('Next'));
    await settle(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Import Complete'), findsOneWidget);
    final events = await db.select(db.assetEvents).get();
    expect(events.length, 3);
    expect(events.where((e) => e.commission == 5.00).length, 2);
    expect(events.where((e) => e.price == 95.50).length, 1);
  });

  // ── Asset: historic + type from sign + fee computed (XLSX fixture) ──

  testWidgets('Import XLSX: asset historic, type from sign, fee computed', (tester) async {
    final db = await pumpApp(tester);

    late FilePreview preview;
    await tester.runAsync(() async {
      preview = await parseFixture(db, 'assets_sign_computed.xlsx');
    });

    await pushImportScreen(tester, preview: preview, target: ImportTarget.assetEvent);

    await tester.drag(find.byType(ListView).first, const Offset(0, -200));
    await settle(tester);
    await tester.tap(find.text('From sign (+/-)'));
    await settle(tester);
    await tester.tap(find.text('Computed'));
    await settle(tester);

    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await settle(tester);
    await tester.tap(find.text('Next'));
    await settle(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Import Complete'), findsOneWidget);
    final events = await db.select(db.assetEvents).get();
    expect(events.length, 2);
    final buy = events.firstWhere((e) => e.quantity == 20);
    expect(buy.type.name, 'buy');
    expect(buy.commission, closeTo(10.0, 0.01));
    final sell = events.firstWhere((e) => e.type.name == 'sell');
    expect(sell.commission, closeTo(5.0, 0.01));
  });

  // ── Asset: current mode + auto-calc amount (CSV fixture) ─

  testWidgets('Import CSV: asset current mode with auto-calc amount', (tester) async {
    final db = await pumpApp(tester);

    late FilePreview preview;
    await tester.runAsync(() async {
      preview = await parseFixture(db, 'assets_current.csv');
    });

    await pushImportScreen(tester, preview: preview, target: ImportTarget.assetEvent);

    await tester.tap(find.text('Current'));
    await settle(tester);

    final autoCalcCheckbox = find.descendant(
      of: find.ancestor(of: find.text('Auto calc'), matching: find.byType(Row)),
      matching: find.byType(Checkbox),
    );
    await tester.tap(autoCalcCheckbox.first);
    await settle(tester);

    final listView = find.byType(ListView).first;
    await tester.drag(listView, const Offset(0, -300));
    await settle(tester);
    await tester.tap(find.text('From sign (+/-)'));
    await settle(tester);
    await tester.drag(listView, const Offset(0, -500));
    await settle(tester);

    final nextBtn = find.widgetWithText(FilledButton, 'Next');
    expect(nextBtn, findsOneWidget);
    await tester.tap(nextBtn);
    await settle(tester);
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      await tester.drag(scrollable.last, const Offset(0, -300));
      await settle(tester);
    }

    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Import Complete'), findsOneWidget);
    final events = await db.select(db.assetEvents).get();
    expect(events.length, 2);
    final em = events.firstWhere((e) => e.quantity == 15);
    expect(em.amount, closeTo(487.50, 0.01));
    final gold = events.firstWhere((e) => e.quantity == 8);
    expect(gold.amount, closeTo(2800.00, 0.01));
    final today = DateTime.now();
    expect(em.date.year, today.year);
    expect(em.date.month, today.month);
    expect(em.date.day, today.day);
  });

  // ── Asset: multi-ISIN with excluded ISIN (XLSX fixture) ──

  testWidgets('Import XLSX: asset multi-ISIN with one excluded', (tester) async {
    final db = await pumpApp(tester);

    late FilePreview preview;
    await tester.runAsync(() async {
      preview = await parseFixture(db, 'assets_multi_isin.xlsx');
    });

    await pushImportScreen(tester, preview: preview, target: ImportTarget.assetEvent);

    await tester.drag(find.byType(ListView).first, const Offset(0, -200));
    await settle(tester);
    await tester.tap(find.text('From sign (+/-)'));
    await settle(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await settle(tester);
    await tester.tap(find.text('Next'));
    await settle(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Uncheck IE00BKM4GZ66
    final excludeIsin = find.text('IE00BKM4GZ66');
    expect(excludeIsin, findsOneWidget);
    final isinRow = find.ancestor(of: excludeIsin, matching: find.byType(Row));
    final checkbox = find.descendant(of: isinRow.first, matching: find.byType(Checkbox));
    if (checkbox.evaluate().isNotEmpty) {
      await tester.tap(checkbox.first);
      await settle(tester);
    }

    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Import Complete'), findsOneWidget);
    final events = await db.select(db.assetEvents).get();
    expect(events.length, 4);
    final assets = await db.select(db.assets).get();
    final assetIsins = assets.map((a) => a.isin).whereType<String>().toList();
    expect(assetIsins.contains('IE00B4L5Y983'), isTrue);
    expect(assetIsins.contains('LU0908500753'), isTrue);
    expect(assetIsins.contains('IE00BKM4GZ66'), isFalse);
  });

  // ── Income (CSV fixture) ───────────────────────────────

  testWidgets('Import CSV: income', (tester) async {
    final db = await pumpApp(tester);

    late FilePreview preview;
    await tester.runAsync(() async {
      preview = await parseFixture(db, 'income.csv');
    });

    await pushImportScreen(tester, preview: preview, target: ImportTarget.income);
    await tester.tap(find.text('Next'));
    await settle(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Import Complete'), findsOneWidget);
    final incomes = await db.select(db.incomes).get();
    expect(incomes.length, 3);
    expect(incomes.where((i) => i.amount == 3500.00).length, 2);
    expect(incomes.where((i) => i.amount == 3600.00).length, 1);
  });

  // ── Income (XLSX fixture) ──────────────────────────────

  testWidgets('Import XLSX: income with typed cells', (tester) async {
    final db = await pumpApp(tester);

    late FilePreview preview;
    await tester.runAsync(() async {
      preview = await parseFixture(db, 'income.xlsx');
    });

    await pushImportScreen(tester, preview: preview, target: ImportTarget.income);
    await tester.tap(find.text('Next'));
    await settle(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Import Complete'), findsOneWidget);
    final incomes = await db.select(db.incomes).get();
    expect(incomes.length, 3);
  });

  // ── Consecutive imports: wipe-and-replace dedup ─────────

  testWidgets('Import: 3 consecutive transaction imports with dedup', (tester) async {
    final db = await pumpApp(tester, seed: (db) async {
      await seedAccount(db, name: 'Dedup Account');
    });

    final importer = ImportService(db);
    final accounts = await db.select(db.accounts).get();
    final accountId = accounts.firstWhere((a) => a.name == 'Dedup Account').id;

    final mappings = [
      const ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
      const ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
      const ColumnMapping(sourceColumn: 'Description', targetField: 'description'),
    ];

    // Import 1: January transactions
    late FilePreview p1;
    await tester.runAsync(() async {
      p1 = await parseFixture(db, 'dedup_import1.csv');
    });
    var result = await importer.importTransactions(
      preview: p1, mappings: mappings, accountId: accountId,
    );
    expect(result.importedRows, 3);
    var txs = await db.select(db.transactions).get();
    expect(txs.length, 3);

    // Import 2: January + February (overlaps with import 1)
    // Wipes Jan onward, re-inserts 5 rows — total 5, not 8
    late FilePreview p2;
    await tester.runAsync(() async {
      p2 = await parseFixture(db, 'dedup_import2.csv');
    });
    result = await importer.importTransactions(
      preview: p2, mappings: mappings, accountId: accountId,
    );
    expect(result.importedRows, 5);
    txs = await db.select(db.transactions).get();
    expect(txs.length, 5);
    expect(txs.any((t) => t.description == 'Groceries Updated' && t.amount == -55.00), isTrue);
    expect(txs.any((t) => t.description == 'Groceries' && t.amount == -50.00), isFalse);

    // Import 3: Only February (narrower range)
    // Wipes from Feb 10 onward, keeps Jan rows from import 2
    late FilePreview p3;
    await tester.runAsync(() async {
      p3 = await parseFixture(db, 'dedup_import3.csv');
    });
    result = await importer.importTransactions(
      preview: p3, mappings: mappings, accountId: accountId,
    );
    expect(result.importedRows, 3);
    txs = await db.select(db.transactions).get();
    // Jan: 3 rows preserved, Feb: 3 rows from import 3
    expect(txs.length, 6);
    expect(txs.any((t) => t.description == 'Groceries Updated'), isTrue);
    expect(txs.any((t) => t.description == 'Salary Jan'), isTrue);
    expect(txs.any((t) => t.description == 'Utilities'), isTrue);
    expect(txs.any((t) => t.description == 'Insurance'), isTrue);
    expect(txs.any((t) => t.description == 'Salary Feb'), isTrue);
    expect(txs.any((t) => t.description == 'Phone Bill'), isTrue);
    // No duplicates
    expect(txs.where((t) => t.description == 'Insurance').length, 1);
    expect(txs.where((t) => t.description == 'Salary Feb').length, 1);
  });
}
