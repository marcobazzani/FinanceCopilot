import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:finance_copilot/services/import_service.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Import CSV: transaction with amount from column', (tester) async {
    final db = await pumpApp(tester, seed: (db) async {
      await seedAccount(db, name: 'Main Account');
    });

    late FilePreview preview;
    await tester.runAsync(() async {
      preview = await parseFixture(db, 'transactions_simple.csv');
    });

    await pushImportScreen(tester, preview: preview);
    expect(find.text('Data_Operazione'), findsWidgets);
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
        const ColumnMapping(sourceColumn: 'Data_Operazione', targetField: 'date'),
        const ColumnMapping(sourceColumn: 'Data_Valuta', targetField: 'valueDate'),
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
}
