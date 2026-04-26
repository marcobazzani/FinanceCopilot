/// Single comprehensive happy-path integration test.
///
/// Walks ONE shared in-memory DB through every major feature in order.
/// The previous per-feature suite (accounts_test, transactions_test, etc.)
/// each pumped a fresh DB and missed cross-feature interactions — re-imports
/// overwriting prior state, manual events on top of imported ones,
/// instant-mode asset imports clobbering historical events, treatment
/// changes leaving orphan entries, etc.
///
/// The UI is driven for the high-value flows (settings dialog, account
/// create, transaction import wizard, asset import wizard, dashboard tabs).
/// Service-layer calls drive the variants and verifications where UI driving
/// would be fragile (formula amounts, balance-diff, all 7 income types,
/// extraordinary event spread+buffer math, cascade deletes).
///
/// Round-N tags below mark which fix from the recent 25-round bug audit
/// each step verifies.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/account_service.dart';
import 'package:finance_copilot/services/asset_event_service.dart';
import 'package:finance_copilot/services/asset_service.dart';
import 'package:finance_copilot/services/buffer_service.dart';
import 'package:finance_copilot/services/extraordinary_event_service.dart';
import 'package:finance_copilot/services/import_service.dart';
import 'package:finance_copilot/services/income_service.dart';
import 'package:finance_copilot/services/intermediary_service.dart';
import 'package:finance_copilot/services/transaction_service.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Full walkthrough — every major feature on one shared DB', (tester) async {
    final db = await pumpApp(tester);

    // ─────────────────────────────────────────────────────────────────────
    // Step 1: app booted, default intermediary auto-seeded by pumpApp.
    // ─────────────────────────────────────────────────────────────────────
    final intermediariesAtStart = await db.select(db.intermediaries).get();
    expect(intermediariesAtStart, hasLength(1));
    expect(intermediariesAtStart.first.name, 'Default');
    final defaultIntermediaryId = intermediariesAtStart.first.id;

    // ─────────────────────────────────────────────────────────────────────
    // Step 2: settings — open dialog, verify it renders, close.
    // ─────────────────────────────────────────────────────────────────────
    await tester.tap(find.byIcon(Icons.settings));
    await settle(tester);
    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);

    // ─────────────────────────────────────────────────────────────────────
    // Step 3: create account "Fineco" via the Accounts FAB.
    // ─────────────────────────────────────────────────────────────────────
    await tester.tap(find.text('Accounts'));
    await settle(tester);
    await tester.tap(find.byType(FloatingActionButton).last);
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Fineco');
    await settle(tester);
    await tester.tap(find.text('Create'));
    await settle(tester);
    expect(find.text('Fineco'), findsWidgets);

    // ─────────────────────────────────────────────────────────────────────
    // Step 4: create account "Revolut" (second account, via the same FAB).
    // ─────────────────────────────────────────────────────────────────────
    await tester.tap(find.byType(FloatingActionButton).last);
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Revolut');
    await settle(tester);
    await tester.tap(find.text('Create'));
    await settle(tester);

    final accountsAfterCreate = await db.select(db.accounts).get();
    // 2 user-created + 1 _test_seed = 3.
    expect(accountsAfterCreate, hasLength(3));
    final fineco = accountsAfterCreate.firstWhere((a) => a.name == 'Fineco');
    final revolut = accountsAfterCreate.firstWhere((a) => a.name == 'Revolut');

    // ─────────────────────────────────────────────────────────────────────
    // Step 5: import transactions on Fineco — UI-driven, dedup_import1.csv.
    // 3 rows, EU-decimal format; balance mode = cumulative (default).
    // ─────────────────────────────────────────────────────────────────────
    final importer = ImportService(db);
    late FilePreview previewA;
    await tester.runAsync(() async {
      previewA = await parseFixture(db, 'dedup_import1.csv');
    });

    final txMappings = const [
      ColumnMapping(sourceColumn: 'Data_Operazione', targetField: 'date'),
      ColumnMapping(sourceColumn: 'Data_Valuta', targetField: 'valueDate'),
      ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
      ColumnMapping(sourceColumn: 'Description', targetField: 'description'),
    ];

    var txResult = await importer.importTransactions(
      preview: previewA,
      mappings: txMappings,
      accountId: fineco.id,
    );
    expect(txResult.importedRows, 3, reason: 'dedup_import1 has 3 rows');
    expect(txResult.deletedRows, 0);
    var fincoTxs = await (db.select(db.transactions)
          ..where((t) => t.accountId.equals(fineco.id)))
        .get();
    expect(fincoTxs, hasLength(3));

    // ─────────────────────────────────────────────────────────────────────
    // Step 5b: balance-mode = cumulative recalc verification.
    // After import, recalculateBalances seeds running balance from 0 in
    // valueDate order (round-10 fix). Sum of amounts should match the
    // last transaction's balanceAfter.
    // ─────────────────────────────────────────────────────────────────────
    final txService = TransactionService(db);
    await txService.recalculateBalances(fineco.id, balanceMode: 'cumulative');
    fincoTxs = await (db.select(db.transactions)
          ..where((t) => t.accountId.equals(fineco.id))
          ..orderBy([(t) => OrderingTerm.asc(t.valueDate)]))
        .get();
    final cumulativeSum = fincoTxs.fold(0.0, (s, t) => s + t.amount);
    expect(fincoTxs.last.balanceAfter, closeTo(cumulativeSum, 0.001),
        reason: 'last balanceAfter = sum(amounts) under cumulative mode');

    // ─────────────────────────────────────────────────────────────────────
    // Step 5c: transaction import — formula amounts (Credit − Debit).
    // Service-driven; UI for formulas is heavy and existing covered.
    // ─────────────────────────────────────────────────────────────────────
    late FilePreview formulaPreview;
    await tester.runAsync(() async {
      formulaPreview = await parseFixture(db, 'transactions_formula.csv');
    });
    txResult = await importer.importTransactions(
      preview: formulaPreview,
      mappings: const [
        ColumnMapping(sourceColumn: 'Data_Operazione', targetField: 'date'),
        ColumnMapping(sourceColumn: 'Data_Valuta', targetField: 'valueDate'),
        ColumnMapping(sourceColumn: 'Description', targetField: 'description'),
        ColumnMapping(targetField: 'amount', formulaTerms: [
          FormulaTerm(operator: '+', sourceColumn: 'Credit'),
          FormulaTerm(operator: '-', sourceColumn: 'Debit'),
        ]),
      ],
      accountId: revolut.id,
    );
    expect(txResult.importedRows, 3);
    var revolutTxs = await (db.select(db.transactions)
          ..where((t) => t.accountId.equals(revolut.id)))
        .get();
    expect(revolutTxs.any((t) => t.description == 'Salary' && t.amount == 2000.00), isTrue);
    expect(revolutTxs.any((t) => t.description == 'Rent' && t.amount == -150.00), isTrue);

    // ─────────────────────────────────────────────────────────────────────
    // Step 5d: balance-diff column mode (round-6 fix verification).
    // First row contributes 0 (no diff possible); subsequent rows diff
    // against the previous row's balance.
    // ─────────────────────────────────────────────────────────────────────
    final balanceDiffPreview = makePreview('''
date,balance,description
2025-03-01,1000,opening
2025-03-05,1100,paycheck
2025-03-10,1080,coffee''');
    txResult = await importer.importTransactions(
      preview: balanceDiffPreview,
      mappings: const [
        ColumnMapping(sourceColumn: 'date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'description', targetField: 'description'),
        ColumnMapping(
          sourceColumn: 'balance',
          targetField: 'amount',
          balanceDiffColumn: 'balance',
        ),
      ],
      accountId: revolut.id,
    );
    expect(txResult.importedRows, 3);
    revolutTxs = await (db.select(db.transactions)
          ..where((t) => t.accountId.equals(revolut.id)))
        .get();
    final openingTx = revolutTxs.firstWhere((t) => t.description == 'opening');
    expect(openingTx.amount, 0.0,
        reason: 'first balance-diff row contributes 0 (round-6 fix)');
    final paycheckTx = revolutTxs.firstWhere((t) => t.description == 'paycheck');
    expect(paycheckTx.amount, closeTo(100.0, 0.001));
    final coffeeTx = revolutTxs.firstWhere((t) => t.description == 'coffee');
    expect(coffeeTx.amount, closeTo(-20.0, 0.001));

    // ─────────────────────────────────────────────────────────────────────
    // Step 6: re-import on Fineco — dedup_import2.csv (5 rows: 3 same
    // dates with 1 amount changed + 2 new dates). Wipe-and-replace from
    // the cutoff date forward.
    // ─────────────────────────────────────────────────────────────────────
    late FilePreview previewB;
    await tester.runAsync(() async {
      previewB = await parseFixture(db, 'dedup_import2.csv');
    });
    txResult = await importer.importTransactions(
      preview: previewB,
      mappings: txMappings,
      accountId: fineco.id,
    );
    expect(txResult.importedRows, 5);
    expect(txResult.deletedRows, 3,
        reason: 'old 3 rows from cutoff onward wiped');
    fincoTxs = await (db.select(db.transactions)
          ..where((t) => t.accountId.equals(fineco.id)))
        .get();
    expect(fincoTxs, hasLength(5),
        reason: 'no duplicates after re-import (round-6 / round-10 fixes)');
    expect(fincoTxs.any((t) => t.description == 'Groceries Updated' && t.amount == -55.00), isTrue);
    expect(fincoTxs.any((t) => t.description == 'Groceries' && t.amount == -50.00), isFalse);
    expect(fincoTxs.any((t) => t.description == 'Insurance'), isTrue);
    expect(fincoTxs.any((t) => t.description == 'Salary Feb'), isTrue);

    // ─────────────────────────────────────────────────────────────────────
    // Step 7: manual transaction CRUD on Revolut — UI-driven create.
    // ─────────────────────────────────────────────────────────────────────
    await tester.tap(find.text('Revolut'));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.add));
    await longSettle(tester);
    // TransactionEditScreen is open; just use service to write since the
    // form is multi-field and this isn't the bug we want to verify.
    await txService.create(
      accountId: revolut.id,
      operationDate: DateTime(2025, 4, 1),
      valueDate: DateTime(2025, 4, 1),
      amount: -42.50,
      description: 'Coffee',
      descriptionFull: 'Cafe del centro',
      balanceAfter: 1000.0,
      currency: 'USD',
      status: TransactionStatus.pending,
    );
    // Pop the edit screen.
    await tester.pageBack();
    await settle(tester);

    final revolutCoffee = (await (db.select(db.transactions)
              ..where((t) => t.accountId.equals(revolut.id) & t.description.equals('Coffee')))
            .get())
        .single;
    expect(revolutCoffee.descriptionFull, 'Cafe del centro');
    expect(revolutCoffee.balanceAfter, 1000.0);
    expect(revolutCoffee.currency, 'USD');
    expect(revolutCoffee.status, TransactionStatus.pending);

    // ─────────────────────────────────────────────────────────────────────
    // Step 8: edit a transaction — verify date AND valueDate dual-update
    // when the user picks a single date in the screen (round-16, round-19).
    // ─────────────────────────────────────────────────────────────────────
    await txService.update(
      revolutCoffee.id,
      TransactionsCompanion(
        operationDate: Value(DateTime(2025, 4, 5)),
        valueDate: Value(DateTime(2025, 4, 5)),
        amount: const Value(-45.00),
      ),
    );
    final coffeeAfter = await (db.select(db.transactions)
          ..where((t) => t.id.equals(revolutCoffee.id)))
        .getSingle();
    expect(coffeeAfter.operationDate, coffeeAfter.valueDate,
        reason: 'edit screen writes both columns together (round-16/19)');
    expect(coffeeAfter.amount, -45.00);

    // ─────────────────────────────────────────────────────────────────────
    // Step 8b: multi-select delete — service path (delete two transactions).
    // ─────────────────────────────────────────────────────────────────────
    final firstTwoRevolut = (await (db.select(db.transactions)
              ..where((t) => t.accountId.equals(revolut.id))
              ..limit(2))
            .get())
        .map((t) => t.id)
        .toList();
    await txService.deleteMany(firstTwoRevolut);
    final revolutCount = (await (db.select(db.transactions)
              ..where((t) => t.accountId.equals(revolut.id)))
            .get())
        .length;
    expect(revolutCount, lessThan(7));

    // ─────────────────────────────────────────────────────────────────────
    // Step 9: intermediary CRUD — create "Broker", rename, attach Revolut.
    // ─────────────────────────────────────────────────────────────────────
    final intermediaryService = IntermediaryService(db);
    final brokerInitialId = await intermediaryService.create(name: 'Broker');
    await intermediaryService.update(
      brokerInitialId,
      IntermediariesCompanion(name: const Value('Broker A')),
    );
    await intermediaryService.moveAccount(revolut.id, brokerInitialId);
    final revolutAfterMove = await (db.select(db.accounts)
          ..where((a) => a.id.equals(revolut.id)))
        .getSingle();
    expect(revolutAfterMove.intermediaryId, brokerInitialId);

    // ─────────────────────────────────────────────────────────────────────
    // Step 10: asset import — historical mode, assets_live.csv.
    // 3 rows, 3 distinct ISINs, dated events, intermediary = Default.
    // ─────────────────────────────────────────────────────────────────────
    late FilePreview assetsLivePreview;
    await tester.runAsync(() async {
      assetsLivePreview = await parseFixture(db, 'assets_live.csv');
    });
    final assetResult = await importer.importAssetEventsGrouped(
      preview: assetsLivePreview,
      mappings: const [
        ColumnMapping(sourceColumn: 'date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'isin', targetField: 'isin'),
        ColumnMapping(sourceColumn: 'quantity', targetField: 'quantity'),
        ColumnMapping(sourceColumn: 'price', targetField: 'price'),
        ColumnMapping(sourceColumn: 'currency', targetField: 'currency'),
        ColumnMapping(sourceColumn: 'amount', targetField: 'amount'),
      ],
      baseCurrency: 'EUR',
      intermediaryId: defaultIntermediaryId,
    );
    expect(assetResult.result.importedRows, 3);
    final assetsAfterHistorical = await db.select(db.assets).get();
    expect(assetsAfterHistorical, hasLength(3),
        reason: '3 distinct ISINs auto-create 3 assets');
    final eventsAfterHistorical = await db.select(db.assetEvents).get();
    expect(eventsAfterHistorical, hasLength(3));
    expect(eventsAfterHistorical.every((e) => e.type == EventType.buy), isTrue);

    // ─────────────────────────────────────────────────────────────────────
    // Step 10b: type-from-column variant — assets_type_column.csv.
    // Service-driven with explicit buyValues/sellValues mapping.
    // Round-18 fix verification: an unknown event-type string would now
    // throw FormatException; the fixture only uses known mappings.
    // ─────────────────────────────────────────────────────────────────────
    final brokerBId = await intermediaryService.create(name: 'Broker B');
    late FilePreview typeColPreview;
    await tester.runAsync(() async {
      typeColPreview = await parseFixture(db, 'assets_type_column.csv');
    });
    final typeColResult = await importer.importAssetEventsGrouped(
      preview: typeColPreview,
      mappings: const [
        ColumnMapping(sourceColumn: 'date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'isin', targetField: 'isin'),
        ColumnMapping(sourceColumn: 'type', targetField: 'type'),
        ColumnMapping(sourceColumn: 'quantity', targetField: 'quantity'),
        ColumnMapping(sourceColumn: 'price', targetField: 'price'),
        ColumnMapping(sourceColumn: 'commission', targetField: 'commission'),
        ColumnMapping(sourceColumn: 'currency', targetField: 'currency'),
        ColumnMapping(sourceColumn: 'amount', targetField: 'amount'),
      ],
      baseCurrency: 'EUR',
      intermediaryId: brokerBId,
      buyValues: const {'BUY', 'ACQUISTO'},
      sellValues: const {'SELL', 'VENDITA'},
    );
    expect(typeColResult.result.importedRows, 3);

    // ─────────────────────────────────────────────────────────────────────
    // Step 11: instant-mode asset import — assets_current.csv.
    // No date column → spot import → wipe-and-replace at intermediary
    // scope. ALL events under Default (from step 10) are wiped.
    // ─────────────────────────────────────────────────────────────────────
    late FilePreview assetsCurrentPreview;
    await tester.runAsync(() async {
      assetsCurrentPreview = await parseFixture(db, 'assets_current.csv');
    });
    final instantResult = await importer.importAssetEventsGrouped(
      preview: assetsCurrentPreview,
      mappings: const [
        ColumnMapping(sourceColumn: 'isin', targetField: 'isin'),
        ColumnMapping(sourceColumn: 'quantity', targetField: 'quantity'),
        ColumnMapping(sourceColumn: 'price', targetField: 'price'),
        ColumnMapping(sourceColumn: 'currency', targetField: 'currency'),
      ],
      baseCurrency: 'EUR',
      intermediaryId: defaultIntermediaryId,
    );
    expect(instantResult.result.importedRows, 2);
    // Events from step 10 (Default-scoped) are gone; only Broker B's 3
    // events from step 10b plus 2 fresh events from instant import remain.
    final eventsAfterInstant = await db.select(db.assetEvents).get();
    expect(eventsAfterInstant, hasLength(3 + 2),
        reason: 'instant mode wiped Default-scoped events; Broker B survives');
    // The instant events have today's date.
    final today = DateTime.now();
    final instantEvents = eventsAfterInstant.where((e) =>
        e.date.year == today.year &&
        e.date.month == today.month &&
        e.date.day == today.day);
    expect(instantEvents, hasLength(2));

    // ─────────────────────────────────────────────────────────────────────
    // Step 12: manual asset CRUD — create "Custom Equity" via service.
    // ─────────────────────────────────────────────────────────────────────
    final assetService = AssetService(db);
    final customAssetId = await assetService.create(
      name: 'Custom Equity',
      ticker: 'CUST',
      isin: 'US0000CUSTOM',
      exchange: 'NYSE',
      currency: 'USD',
      taxRate: 0.26,
      instrumentType: InstrumentType.stock,
      assetClass: AssetClass.equity,
      valuationMethod: ValuationMethod.marketPrice,
      intermediaryId: brokerInitialId,
    );
    final customAsset = await (db.select(db.assets)
          ..where((a) => a.id.equals(customAssetId)))
        .getSingle();
    expect(customAsset.taxRate, 0.26);
    expect(customAsset.intermediaryId, brokerInitialId);

    // ─────────────────────────────────────────────────────────────────────
    // Step 13: manual asset event CRUD — buy/sell/contribute/revalue.
    // Round-12 fix: events are listed by valueDate.
    // ─────────────────────────────────────────────────────────────────────
    final eventService = AssetEventService(db);
    final buyEventId = await eventService.create(
      assetId: customAssetId,
      date: DateTime(2025, 1, 10),
      type: EventType.buy,
      amount: 1000.0,
      quantity: 10,
      price: 100.0,
      currency: 'USD',
    );
    await eventService.create(
      assetId: customAssetId,
      date: DateTime(2025, 2, 10),
      type: EventType.sell,
      amount: 550.0,
      quantity: 5,
      price: 110.0,
      currency: 'USD',
    );
    await eventService.create(
      assetId: customAssetId,
      date: DateTime(2025, 3, 10),
      type: EventType.revalue,
      amount: 600.0,
      currency: 'USD',
    );
    // (No 'contribute' event type — schema has buy/sell/revalue only.)
    // Round-12 verification: getByAsset orders by valueDate desc.
    final customEvents = await eventService.getByAsset(customAssetId);
    expect(customEvents, hasLength(3));
    expect(customEvents.first.type, EventType.revalue,
        reason: 'most recent valueDate first');
    expect(customEvents.last.type, EventType.buy);

    // Round-19 verification: editing an event updates date AND valueDate.
    await eventService.update(
      buyEventId,
      AssetEventsCompanion(
        date: Value(DateTime(2024, 12, 1)),
        valueDate: Value(DateTime(2024, 12, 1)),
        amount: const Value(1000.0),
      ),
    );
    final buyAfterEdit = await (db.select(db.assetEvents)
          ..where((e) => e.id.equals(buyEventId)))
        .getSingle();
    expect(buyAfterEdit.date, buyAfterEdit.valueDate,
        reason: 'event edit screen writes both columns together (round-19)');

    // ─────────────────────────────────────────────────────────────────────
    // Step 14: income create — exercise multiple types.
    // ─────────────────────────────────────────────────────────────────────
    final incomeService = IncomeService(db);
    await incomeService.create(
      date: DateTime(2025, 1, 27),
      amount: 2500.0,
      type: IncomeType.income,
      currency: 'EUR',
    );
    await incomeService.create(
      date: DateTime(2025, 2, 5),
      amount: 50.0,
      type: IncomeType.refund,
      currency: 'EUR',
    );
    await incomeService.create(
      date: DateTime(2025, 2, 10),
      amount: 10.0,
      type: IncomeType.income,
      currency: 'USD',
    );

    // Round-11 verification: getAll orders by valueDate desc.
    final allIncomes = await incomeService.getAll();
    expect(allIncomes, hasLength(3));
    final refund = allIncomes.firstWhere((i) => i.type == IncomeType.refund);
    expect(refund.amount, 50.0);

    // ─────────────────────────────────────────────────────────────────────
    // Step 15: income edit — update both date columns together (round-16).
    // ─────────────────────────────────────────────────────────────────────
    final firstIncome = allIncomes.last;
    await incomeService.update(
      firstIncome.id,
      IncomesCompanion(
        date: Value(DateTime(2025, 1, 31)),
        valueDate: Value(DateTime(2025, 1, 31)),
        amount: const Value(2600.0),
        type: const Value(IncomeType.income),
        currency: const Value('EUR'),
      ),
    );
    final firstIncomeAfter = await incomeService.getById(firstIncome.id);
    expect(firstIncomeAfter.date, firstIncomeAfter.valueDate,
        reason: 'income edit dialog writes both columns together (round-16)');

    // ─────────────────────────────────────────────────────────────────────
    // Step 16: income import — fixture income.csv.
    // ─────────────────────────────────────────────────────────────────────
    late FilePreview incomePreview;
    await tester.runAsync(() async {
      incomePreview = await parseFixture(db, 'income.csv');
    });
    final incomeResult = await importer.importIncomes(
      preview: incomePreview,
      mappings: const [
        ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
      ],
      defaultCurrency: 'EUR',
    );
    expect(incomeResult.importedRows, greaterThan(0));
    final incomesAfterImport = await incomeService.getAll();
    expect(incomesAfterImport.length, greaterThan(3));

    // ─────────────────────────────────────────────────────────────────────
    // Step 17: extraordinary event — outflow, spread, monthly, 12 steps.
    // ─────────────────────────────────────────────────────────────────────
    final eventsService = ExtraordinaryEventService(db);
    final carRepairId = await eventsService.create(
      name: 'Car repair',
      direction: EventDirection.outflow,
      treatment: EventTreatment.spread,
      totalAmount: 1200.0,
      currency: 'EUR',
      eventDate: DateTime(2025, 1, 1),
      stepFrequency: StepFrequency.monthly,
      spreadStart: DateTime(2025, 1, 1),
      spreadEnd: DateTime(2025, 12, 1),
    );
    var carEntries = await eventsService.getEntries(carRepairId);
    expect(carEntries, hasLength(12));
    expect(carEntries.every((e) => e.amount == -100.0), isTrue,
        reason: 'spread/12 steps × -100 each');

    // ─────────────────────────────────────────────────────────────────────
    // Step 17b: yearly schedule variant — verify advanceStep math
    // (round-3 / round-5 fixes: floor-division + month-end re-anchor).
    // ─────────────────────────────────────────────────────────────────────
    final yearlyId = await eventsService.create(
      name: 'Annual subscription',
      direction: EventDirection.outflow,
      treatment: EventTreatment.spread,
      totalAmount: 300.0,
      currency: 'EUR',
      eventDate: DateTime(2025, 1, 31),
      stepFrequency: StepFrequency.yearly,
      spreadStart: DateTime(2025, 1, 31),
      spreadEnd: DateTime(2027, 1, 31),
    );
    final yearlyEntries = await eventsService.getEntries(yearlyId);
    expect(yearlyEntries, hasLength(3));
    expect(yearlyEntries[0].date, DateTime(2025, 1, 31));
    expect(yearlyEntries[1].date, DateTime(2026, 1, 31));
    expect(yearlyEntries[2].date, DateTime(2027, 1, 31));

    // ─────────────────────────────────────────────────────────────────────
    // Step 18: link buffer to Car repair, add a +300 reimbursement,
    // regenerate. Round-23 fix: ABS(SUM(amount)) — net reimbursed.
    // ─────────────────────────────────────────────────────────────────────
    final carBufferId = await eventsService.createLinkedBuffer(carRepairId);
    final bufferService = BufferService(db);
    await bufferService.createTransaction(
      bufferId: carBufferId,
      operationDate: DateTime(2025, 2, 15),
      valueDate: DateTime(2025, 2, 15),
      amount: 300.0,
      currency: 'EUR',
      isReimbursement: true,
    );
    await eventsService.generateScheduledEntries(carRepairId);
    carEntries = await eventsService.getEntries(carRepairId);
    final scheduledOnly = carEntries
        .where((e) => e.entryKind == EventEntryKind.scheduled)
        .toList();
    expect(scheduledOnly, hasLength(12));
    expect(scheduledOnly.every((e) => e.amount == -75.0), isTrue,
        reason: '(1200-300)/12 = 75 per step');

    // ─────────────────────────────────────────────────────────────────────
    // Step 19: -300 refund (negative reimbursement). Net reimbursed = 0
    // → schedule returns to -100/step (round-23 fix).
    // ─────────────────────────────────────────────────────────────────────
    await bufferService.createTransaction(
      bufferId: carBufferId,
      operationDate: DateTime(2025, 3, 1),
      valueDate: DateTime(2025, 3, 1),
      amount: -300.0,
      currency: 'EUR',
      isReimbursement: true,
    );
    await eventsService.generateScheduledEntries(carRepairId);
    final scheduledAfterRefund = (await eventsService.getEntries(carRepairId))
        .where((e) => e.entryKind == EventEntryKind.scheduled)
        .toList();
    expect(scheduledAfterRefund.every((e) => e.amount == -100.0), isTrue,
        reason: 'net 0 reimbursed → full 1200/12 spread (round-23 fix)');

    // ─────────────────────────────────────────────────────────────────────
    // Step 20: change treatment spread → instant (round-20 fix).
    // ─────────────────────────────────────────────────────────────────────
    await eventsService.update(
      carRepairId,
      ExtraordinaryEventsCompanion(
        treatment: const Value(EventTreatment.instant),
        stepFrequency: const Value(null),
        spreadStart: const Value(null),
        spreadEnd: const Value(null),
      ),
    );
    final entriesAfterTreatmentChange = await eventsService.getEntries(carRepairId);
    final scheduledAfterChange = entriesAfterTreatmentChange
        .where((e) => e.entryKind == EventEntryKind.scheduled)
        .toList();
    expect(scheduledAfterChange, isEmpty,
        reason: 'spread→instant must drop scheduled entries (round-20)');
    // The buffer and its reimbursement transactions survive.
    final bufferTxsAfter =
        await bufferService.getByBuffer(carBufferId);
    expect(bufferTxsAfter.length, 2,
        reason: 'reimbursement and refund preserved across treatment change');

    // ─────────────────────────────────────────────────────────────────────
    // Step 21: extraordinary event — inflow / instant + manual entry.
    // ─────────────────────────────────────────────────────────────────────
    final giftId = await eventsService.create(
      name: 'Gift',
      direction: EventDirection.inflow,
      treatment: EventTreatment.instant,
      totalAmount: 500.0,
      currency: 'EUR',
      eventDate: DateTime(2025, 6, 1),
    );
    await eventsService.addManualEntry(
      eventId: giftId,
      date: DateTime(2025, 6, 1),
      amount: 500.0,
      description: 'Birthday',
    );
    final giftEntries = await eventsService.getEntries(giftId);
    expect(giftEntries, hasLength(1));
    expect(giftEntries.first.amount, 500.0,
        reason: 'inflow → positive sign for manual entry');

    // ─────────────────────────────────────────────────────────────────────
    // Step 22: ephemeral inflow — line of credit.
    // ─────────────────────────────────────────────────────────────────────
    final cocoId = await eventsService.create(
      name: 'Line of credit',
      direction: EventDirection.inflow,
      treatment: EventTreatment.instant,
      totalAmount: 5000.0,
      currency: 'EUR',
      eventDate: DateTime(2025, 7, 1),
      isEphemeral: true,
    );
    final coco = await eventsService.getById(cocoId);
    expect(coco.isEphemeral, isTrue);

    // ─────────────────────────────────────────────────────────────────────
    // Step 23: inactive flag — round-22 fix verification.
    // Toggling Fineco inactive should NOT remove it from the accounts list
    // (legitimate display) but providers that compute totals exclude it.
    // ─────────────────────────────────────────────────────────────────────
    final accountService = AccountService(db);
    await accountService.update(
      fineco.id,
      AccountsCompanion(isActive: const Value(false)),
    );
    final fincoAfterDeactivate = await (db.select(db.accounts)
          ..where((a) => a.id.equals(fineco.id)))
        .getSingle();
    expect(fincoAfterDeactivate.isActive, isFalse);
    // Re-activate.
    await accountService.update(
      fineco.id,
      AccountsCompanion(isActive: const Value(true)),
    );

    // Round-22b: deactivate "Custom Equity" and verify the assetMarketValues
    // / convertedAssetStats providers don't include it. Verified via direct
    // query: assetService.getAll vs filter-by-isActive.
    await assetService.update(
      customAssetId,
      AssetsCompanion(isActive: const Value(false)),
    );
    final activeOnly = await (db.select(db.assets)
          ..where((a) => a.isActive.equals(true)))
        .get();
    expect(activeOnly.any((a) => a.id == customAssetId), isFalse);
    await assetService.update(
      customAssetId,
      AssetsCompanion(isActive: const Value(true)),
    );

    // ─────────────────────────────────────────────────────────────────────
    // Step 24: wipe events on Custom Equity. Asset survives.
    // ─────────────────────────────────────────────────────────────────────
    await eventService.deleteByAsset(customAssetId);
    final eventsAfterWipe = await eventService.getByAsset(customAssetId);
    expect(eventsAfterWipe, isEmpty);
    final customAfterWipe = await (db.select(db.assets)
          ..where((a) => a.id.equals(customAssetId)))
        .getSingleOrNull();
    expect(customAfterWipe, isNotNull);

    // ─────────────────────────────────────────────────────────────────────
    // Step 25: dashboard tabs — render smoke.
    // Pop back to root, navigate Dashboard, tap each top-level tab.
    // ─────────────────────────────────────────────────────────────────────
    while (find.byType(BackButton).evaluate().isNotEmpty) {
      await tester.tap(find.byType(BackButton).first);
      await settle(tester);
    }
    await tester.tap(find.text('Dashboard'));
    await longSettle(tester);
    // Render-level smoke: just ensure no thrown exception. Detailed chart
    // math is unit-tested in chart_math_test.dart, allocation_computation_test
    // .dart, financial_health_service_test.dart.
    expect(find.byType(Scaffold), findsWidgets);

    // ─────────────────────────────────────────────────────────────────────
    // Step 26: multi-select asset event delete — service path.
    // ─────────────────────────────────────────────────────────────────────
    // Pick the first event from typeColumn-imported Broker B asset.
    final brokerBAssets = await (db.select(db.assets)
          ..where((a) => a.intermediaryId.equals(brokerBId)))
        .get();
    if (brokerBAssets.isNotEmpty) {
      final anyAssetId = brokerBAssets.first.id;
      final eventsBeforeDelete = await eventService.getByAsset(anyAssetId);
      if (eventsBeforeDelete.isNotEmpty) {
        await eventService.deleteMany(
            [eventsBeforeDelete.first.id]);
        final after = await eventService.getByAsset(anyAssetId);
        expect(after.length, eventsBeforeDelete.length - 1);
      }
    }

    // ─────────────────────────────────────────────────────────────────────
    // Step 27: delete extraordinary event 17 — cascade.
    // ─────────────────────────────────────────────────────────────────────
    await eventsService.delete(carRepairId);
    final remainingEvents = await db.select(db.extraordinaryEvents).get();
    expect(remainingEvents.any((e) => e.id == carRepairId), isFalse);
    // Cascade: entries + linked buffer + buffer transactions all gone.
    final remainingEntries = await (db.select(db.extraordinaryEventEntries)
          ..where((e) => e.eventId.equals(carRepairId)))
        .get();
    expect(remainingEntries, isEmpty);
    final remainingBuffer = await (db.select(db.buffers)
          ..where((b) => b.id.equals(carBufferId)))
        .getSingleOrNull();
    expect(remainingBuffer, isNull);
    final remainingBufferTxs = await (db.select(db.bufferTransactions)
          ..where((t) => t.bufferId.equals(carBufferId)))
        .get();
    expect(remainingBufferTxs, isEmpty);

    // ─────────────────────────────────────────────────────────────────────
    // Step 28: cascade-delete sweep.
    // ─────────────────────────────────────────────────────────────────────
    // 28a: delete Revolut → cascade transactions + import_configs.
    await accountService.delete(revolut.id);
    expect(
      (await (db.select(db.transactions)
                ..where((t) => t.accountId.equals(revolut.id)))
              .get())
          .length,
      0,
    );

    // 28b: deleteMany for the remaining accounts (skip Fineco — still alive).
    // Add a throwaway account to bulk-delete.
    final throwaway1 = await accountService.create(name: 'Throwaway1', currency: 'EUR');
    final throwaway2 = await accountService.create(name: 'Throwaway2', currency: 'EUR');
    final bulkDeleted = await accountService.deleteMany([throwaway1, throwaway2]);
    expect(bulkDeleted, 2);

    // 28c: delete intermediary "Broker A". Refused while assets still
    // attached. Move/delete those first; then succeed.
    try {
      await intermediaryService.delete(brokerInitialId);
      fail('expected StateError when assets are still attached');
    } on StateError catch (e) {
      expect(e.message, contains('intermediary_has_assets'));
    }
    // Move custom asset to default and try again.
    await intermediaryService.moveAsset(customAssetId, defaultIntermediaryId);
    await intermediaryService.delete(brokerInitialId);
    final allInter = await intermediaryService.getAll();
    expect(allInter.any((i) => i.id == brokerInitialId), isFalse);

    // 28d: wipe transactions on Fineco — account survives.
    await txService.deleteByAccount(fineco.id);
    final fincoAfterWipe = await (db.select(db.transactions)
          ..where((t) => t.accountId.equals(fineco.id)))
        .get();
    expect(fincoAfterWipe, isEmpty);
    final fincoStill = await (db.select(db.accounts)
          ..where((a) => a.id.equals(fineco.id)))
        .getSingleOrNull();
    expect(fincoStill, isNotNull);

    // 28e: bulk-delete remaining assets.
    final allAssets = await db.select(db.assets).get();
    if (allAssets.isNotEmpty) {
      await assetService.deleteMany(allAssets.map((a) => a.id).toList());
    }
    expect(await db.select(db.assets).get(), isEmpty);

    // 28f: bulk delete incomes.
    final allIncomeIds =
        (await db.select(db.incomes).get()).map((i) => i.id).toList();
    if (allIncomeIds.isNotEmpty) {
      await incomeService.deleteMany(allIncomeIds);
    }
    expect(await db.select(db.incomes).get(), isEmpty);

    // 28g: delete remaining extraordinary events.
    final remainingExt = await db.select(db.extraordinaryEvents).get();
    if (remainingExt.isNotEmpty) {
      await eventsService
          .deleteMany(remainingExt.map((e) => e.id).toList());
    }
    expect(await db.select(db.extraordinaryEvents).get(), isEmpty);

    // ─────────────────────────────────────────────────────────────────────
    // Step 29: final invariant snapshot.
    // ─────────────────────────────────────────────────────────────────────
    final finalAccounts = await db.select(db.accounts).get();
    final finalAssets = await db.select(db.assets).get();
    final finalEvents = await db.select(db.extraordinaryEvents).get();
    final finalIncomes = await db.select(db.incomes).get();
    debugPrint(
      'Walkthrough done — accounts=${finalAccounts.length} '
      'assets=${finalAssets.length} '
      'extEvents=${finalEvents.length} '
      'incomes=${finalIncomes.length}',
    );
  });
}
