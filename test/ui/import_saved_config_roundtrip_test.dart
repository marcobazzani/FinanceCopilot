// Pin: the import wizard reads back every setting it saves. A saved config is
// restored, the import runs from the quick confirm, and the config the wizard
// saves afterwards is the one it loaded — key for key, in the stored format.
// Guards the reading of the hidden `__*` keys against any change of behaviour.
import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/import/import_config_service.dart';
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

  Future<Map<String, dynamic>> savedMappings(Future<ImportConfig?> config) async =>
      jsonDecode((await config)!.mappingsJson) as Map<String, dynamic>;

  Future<void> importFromQuickConfirm(WidgetTester tester, ImportScreen screen) async {
    await h.pump(tester, screen);
    final import = find.widgetWithText(FilledButton, 'Import');
    expect(import, findsOneWidget, reason: 'the saved config covers everything: quick confirm');
    await tester.ensureVisible(import);
    await tester.tap(import);
    await h.settle(tester, frames: 30);
    expect(find.text('Import Complete'), findsOneWidget);
  }

  Future<List<Transaction>> rows() =>
      (h.db.select(h.db.transactions)..orderBy([(t) => OrderingTerm.asc(t.valueDate), (t) => OrderingTerm.asc(t.id)])).get();

  testWidgets('filtered balance, combined columns, delimiter, row filters', (tester) async {
    final mappings = <String, String?>{
      'date': 'Date',
      'amount': 'Amount',
      'description': null,
      '__multi_description': jsonEncode(['Description', 'Note']),
      '__delim_description': ' / ',
      '__balanceMode': 'filtered',
      '__balanceFilterColumn': 'State',
      '__balanceFilterInclude': jsonEncode(['DONE', 'PENDING']),
      '__rowFilters': jsonEncode([
        {'column': 'Description', 'op': 'notContains', 'value': 'ZZZ'},
      ]),
      '__filterCombine': 'any',
    };
    await ImportConfigService(h.db).save(
      accountId: acct,
      skipRows: 0,
      mappings: mappings,
      formula: const [],
      hashColumns: const [],
      numberLocale: 'en_US',
    );
    const statement = FilePreview(
      columns: ['Date', 'Description', 'Note', 'Amount', 'State'],
      rows: [
        {'Date': '01/03/2024', 'Description': 'Salary', 'Note': 'March', 'Amount': '100', 'State': 'DONE'},
        {'Date': '02/03/2024', 'Description': 'Card', 'Note': 'Shop', 'Amount': '-30', 'State': 'FAILED'},
        {'Date': '03/03/2024', 'Description': 'Refund', 'Note': 'Shop', 'Amount': '10', 'State': 'PENDING'},
        {'Date': '04/03/2024', 'Description': 'ZZZ test', 'Note': '', 'Amount': '999', 'State': 'DONE'},
      ],
      totalRows: 4,
      numberLocale: 'en_US',
    );
    try {
      await importFromQuickConfirm(tester, ImportScreen(preselectedAccountId: acct, testPreview: statement));
      final imported = await rows();
      expect(imported.map((t) => t.description), ['Salary / March', 'Card / Shop', 'Refund / Shop'], reason: 'row filter and combined columns');
      expect(imported.map((t) => t.balanceAfter), [100, 100, 110], reason: 'filtered balance: FAILED is not included');
      expect(imported.map((t) => t.status), [TransactionStatus.settled, TransactionStatus.cancelled, TransactionStatus.settled]);
      expect(await savedMappings(ImportConfigService(h.db).getByAccount(acct)), mappings);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('column balance with an amount formula and a value date', (tester) async {
    final mappings = <String, String?>{
      'date': 'Date',
      'description': 'Description',
      'valueDate': 'Value',
      'balanceAfter': 'Balance',
      '__balanceMode': 'column',
    };
    const formula = [
      {'operator': '+', 'sourceColumn': 'In'},
      {'operator': '-', 'sourceColumn': 'Out'},
    ];
    await ImportConfigService(h.db).save(
      accountId: acct,
      skipRows: 0,
      mappings: mappings,
      formula: formula,
      hashColumns: const [],
      numberLocale: 'en_US',
    );
    const statement = FilePreview(
      columns: ['Date', 'Value', 'Description', 'In', 'Out', 'Balance'],
      rows: [
        {'Date': '01/03/2024', 'Value': '01/03/2024', 'Description': 'Salary', 'In': '100', 'Out': '', 'Balance': '1100'},
        {'Date': '02/03/2024', 'Value': '02/03/2024', 'Description': 'Card', 'In': '', 'Out': '30', 'Balance': '1070'},
      ],
      totalRows: 2,
      numberLocale: 'en_US',
    );
    try {
      await importFromQuickConfirm(tester, ImportScreen(preselectedAccountId: acct, testPreview: statement));
      final imported = await rows();
      expect(imported.map((t) => t.amount), [100, -30]);
      expect(imported.map((t) => t.balanceAfter), [1100, 1070], reason: 'anchored on the bank closing');
      final config = (await ImportConfigService(h.db).getByAccount(acct))!;
      expect(jsonDecode(config.mappingsJson), mappings);
      expect(jsonDecode(config.formulaJson), formula);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('balance-difference amount, cumulative balance', (tester) async {
    final mappings = <String, String?>{
      'date': 'Date',
      'description': 'Description',
      '__balanceDiffColumn': 'Balance',
      '__balanceMode': 'cumulative',
    };
    await ImportConfigService(h.db).save(
      accountId: acct,
      skipRows: 0,
      mappings: mappings,
      formula: const [],
      hashColumns: const [],
      numberLocale: 'en_US',
    );
    const statement = FilePreview(
      columns: ['Date', 'Description', 'Balance'],
      rows: [
        {'Date': '01/03/2024', 'Description': 'Opening', 'Balance': '1000'},
        {'Date': '02/03/2024', 'Description': 'Salary', 'Balance': '1100'},
        {'Date': '03/03/2024', 'Description': 'Card', 'Balance': '1070'},
      ],
      totalRows: 3,
      numberLocale: 'en_US',
    );
    try {
      await importFromQuickConfirm(tester, ImportScreen(preselectedAccountId: acct, testPreview: statement));
      final imported = await rows();
      expect(imported.map((t) => t.amount), [0, 100, -30], reason: 'the first row has no balance before it');
      expect(imported.map((t) => t.balanceAfter), [0, 100, 70]);
      expect(await savedMappings(ImportConfigService(h.db).getByAccount(acct)), mappings);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('single-asset events: mode, type tags, revalue amount column, sign and price flags', (tester) async {
    final broker = await h.db.into(h.db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    final fund = await h.db
        .into(h.db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'Pension fund',
            assetType: AssetType.alternative,
            valuationMethod: ValuationMethod.eventDriven,
            intermediaryId: broker,
          ),
        );
    final mappings = <String, String?>{
      'date': 'Date',
      'amount': 'In',
      'type': 'Kind',
      '__balanceMode': 'cumulative',
      '__assetImportMode': 'historic',
      '__typeMode': 'column',
      '__negativeIsBuy': 'true',
      '__buyValues': jsonEncode(['CONTRIB']),
      '__sellValues': jsonEncode(['WITHDRAW']),
      '__revalueValues': jsonEncode(['TOTAL']),
      '__feeValues': jsonEncode(['FEE']),
      '__revalueAmountColumn': 'Balance',
      '__feeMode': 'column',
      '__autoCalcPrice': 'true',
    };
    await ImportConfigService(h.db).saveScoped(
      scope: ImportConfigScope.assetSingle,
      assetId: fund,
      skipRows: 0,
      mappings: mappings,
      formula: const [],
      hashColumns: const [],
      numberLocale: 'en_US',
    );
    const statement = FilePreview(
      columns: ['Date', 'Kind', 'In', 'Balance'],
      rows: [
        {'Date': '31/01/2024', 'Kind': 'CONTRIB', 'In': '100', 'Balance': ''},
        {'Date': '31/01/2024', 'Kind': 'TOTAL', 'In': '', 'Balance': '104'},
      ],
      totalRows: 2,
      numberLocale: 'en_US',
    );
    await h.pump(tester, const ImportScreen(preselectedTarget: ImportTarget.assetEvent, testPreview: statement));
    try {
      await tester.tap(find.text('Import into single asset'));
      await h.settle(tester);
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await h.settle(tester);
      await tester.tap(find.text('Pension fund').last);
      await h.settle(tester);
      final import = find.widgetWithText(FilledButton, 'Import');
      expect(import, findsOneWidget, reason: 'the saved config covers everything: quick confirm');
      await tester.ensureVisible(import);
      await tester.tap(import);
      await h.settle(tester, frames: 30);
      expect(find.text('Import Complete'), findsOneWidget);

      final events = await (h.db.select(h.db.assetEvents)..orderBy([(e) => OrderingTerm.asc(e.id)])).get();
      expect(events.map((e) => (e.type, e.amount)), [(EventType.buy, 100.0), (EventType.revalue, 104.0)]);
      expect(await savedMappings(ImportConfigService(h.db).getByAsset(fund)), mappings);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('income type tags', (tester) async {
    final mappings = <String, String?>{
      'date': 'Date',
      'amount': 'Amount',
      'type': 'Kind',
      '__balanceMode': 'cumulative',
      '__incomeValues': jsonEncode(['Salary']),
      '__refundValues': jsonEncode(['Refund']),
      '__pensionContributionValues': jsonEncode(['Pension']),
    };
    await ImportConfigService(h.db).saveScoped(
      scope: ImportConfigScope.income,
      skipRows: 0,
      mappings: mappings,
      formula: const [],
      hashColumns: const [],
    );
    const statement = FilePreview(
      columns: ['Date', 'Amount', 'Kind'],
      rows: [
        {'Date': '01/03/2024', 'Amount': '3000', 'Kind': 'Salary'},
        {'Date': '02/03/2024', 'Amount': '40', 'Kind': 'Refund'},
        {'Date': '03/03/2024', 'Amount': '200', 'Kind': 'Pension'},
      ],
      totalRows: 3,
      numberLocale: 'en_US',
    );
    try {
      await importFromQuickConfirm(tester, const ImportScreen(preselectedTarget: ImportTarget.income, testPreview: statement));
      final incomes = await (h.db.select(h.db.incomes)..orderBy([(i) => OrderingTerm.asc(i.date)])).get();
      expect(incomes.map((i) => i.type), [IncomeType.income, IncomeType.refund, IncomeType.pensionContribution]);
      expect(await savedMappings(ImportConfigService(h.db).getIncome()), mappings);
    } finally {
      await h.unmount(tester);
    }
  });
}
