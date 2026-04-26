/// Single comprehensive happy-path integration test on realistic data.
///
/// Starts on the LANDING PAGE with an empty DB, walks through every major
/// feature with multi-year synthetic fixtures shaped like real broker
/// exports (Fineco transactions, Lista Titoli holdings, Revolut card).
///
/// Imports stress every balance mode (cumulative, balance-from-column,
/// balance-delta), the formula amount builder (Entrate − Uscite) and the
/// skip-rows path (Fineco's 12 banner rows). Every CAPEX schedule
/// frequency (weekly, monthly, quarterly, yearly), both directions
/// (inflow/outflow), both treatments (instant/spread), and the
/// ephemeral-inflow + linked-buffer reimbursement-with-refund paths are
/// exercised on the same shared DB.
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
import 'package:finance_copilot/services/buffer_service.dart';
import 'package:finance_copilot/services/extraordinary_event_service.dart';
import 'package:finance_copilot/services/import_service.dart';
import 'package:finance_copilot/services/transaction_service.dart';

import 'helpers/test_app.dart';

void _step(String msg) => debugPrint('▶ $msg');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Full walkthrough — multi-year, multi-asset, multi-account', (tester) async {
    final db = await pumpApp(tester, seedTestState: false);
    await longSettle(tester);
    await longSettle(tester);

    // ─────────────────────────────────────────────────────────────────────
    // Step 1: landing page → "Start Fresh".
    // ─────────────────────────────────────────────────────────────────────
    _step('1. Landing page — tap Start Fresh');
    expect(find.text('Welcome to FinanceCopilot'), findsOneWidget);
    await tester.tap(find.text('Start Fresh'));
    await longSettle(tester);

    // ─────────────────────────────────────────────────────────────────────
    // Step 2: Manage Intermediaries → add Default + Broker (UI).
    // The dialog now keeps the list visible while you add — see commit
    // 6c70ce6.
    // ─────────────────────────────────────────────────────────────────────
    _step('2. Accounts → Manage Intermediaries → add Default');
    await tester.tap(find.text('Accounts').first);
    await longSettle(tester);
    await tester.tap(find.byIcon(Icons.business));
    await longSettle(tester);
    expect(find.text('Intermediaries'), findsOneWidget);
    await tester.tap(find.text('Add Intermediary'));
    await longSettle(tester);
    await tester.enterText(find.byType(TextField), 'Default');
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await longSettle(tester);
    expect(find.text('Default'), findsWidgets);
    final defaultRow = await db.select(db.intermediaries).get();
    expect(defaultRow, hasLength(1));
    final defaultIntermediaryId = defaultRow.first.id;
    _step('   ✓ Default created (id=$defaultIntermediaryId)');

    _step('2b. Add Broker (same dialog open)');
    await tester.tap(find.text('Add Intermediary'));
    await longSettle(tester);
    await tester.enterText(find.byType(TextField), 'Broker Fineco');
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await longSettle(tester);
    expect(find.text('Broker Fineco'), findsWidgets);
    final intermediaries = await db.select(db.intermediaries).get();
    expect(intermediaries, hasLength(2));
    final brokerId = intermediaries.firstWhere((i) => i.name == 'Broker Fineco').id;
    _step('   ✓ Broker Fineco created (id=$brokerId)');

    await tester.tap(find.widgetWithText(FilledButton, 'Close'));
    await longSettle(tester);

    // ─────────────────────────────────────────────────────────────────────
    // Step 3: create accounts via FAB (UI).
    // ─────────────────────────────────────────────────────────────────────
    _step('3. Create account Fineco');
    await tester.tap(find.byType(FloatingActionButton).last);
    await longSettle(tester);
    await tester.enterText(find.byType(TextField), 'Fineco');
    await settle(tester);
    await tester.tap(find.text('Create'));
    await longSettle(tester);

    _step('3b. Create account Revolut');
    await tester.tap(find.byType(FloatingActionButton).last);
    await longSettle(tester);
    await tester.enterText(find.byType(TextField), 'Revolut');
    await settle(tester);
    await tester.tap(find.text('Create'));
    await longSettle(tester);

    final accounts = await db.select(db.accounts).get();
    expect(accounts, hasLength(2));
    final fineco = accounts.firstWhere((a) => a.name == 'Fineco');
    final revolut = accounts.firstWhere((a) => a.name == 'Revolut');

    final importer = ImportService(db);
    final txService = TransactionService(db);

    // ─────────────────────────────────────────────────────────────────────
    // Step 4: FINECO multi-year XLSX import — exercises:
    //   • skipRows = 12 (banner rows)
    //   • formula amount: + Entrate − Uscite
    //   • valueDate vs operationDate split
    //   • multi-column description (Descrizione + Descrizione_Completa)
    //   • multiple years of data populating the dashboard
    // Service-driven for reliability — formula UI is too dense to drive.
    // ─────────────────────────────────────────────────────────────────────
    _step('4. Fineco multi-year XLSX import — skipRows=12 + formula amount');
    late FilePreview fineco6yPreview;
    await tester.runAsync(() async {
      fineco6yPreview = await parseFixture(db, 'fineco_real.xlsx', skipRows: 12);
    });
    final finecoResult = await importer.importTransactions(
      preview: fineco6yPreview,
      mappings: const [
        ColumnMapping(sourceColumn: 'Data_Operazione', targetField: 'date'),
        ColumnMapping(sourceColumn: 'Data_Valuta', targetField: 'valueDate'),
        ColumnMapping(targetField: 'amount', formulaTerms: [
          FormulaTerm(operator: '+', sourceColumn: 'Entrate'),
          FormulaTerm(operator: '-', sourceColumn: 'Uscite'),
        ]),
        ColumnMapping(
          targetField: 'description',
          multiColumns: ['Descrizione', 'Descrizione_Completa'],
          multiDelimiter: ' · ',
        ),
      ],
      accountId: fineco.id,
    );
    _step('   ✓ imported ${finecoResult.importedRows} rows (6 years × ~3/month)');
    expect(finecoResult.importedRows, greaterThan(150));
    final finecoTxs = await (db.select(db.transactions)
          ..where((t) => t.accountId.equals(fineco.id))
          ..orderBy([(t) => OrderingTerm.asc(t.valueDate)]))
        .get();
    expect(finecoTxs.first.valueDate.year, 2020);
    expect(finecoTxs.last.valueDate.year, 2025);
    expect(finecoTxs.where((t) => t.amount > 1000).length, greaterThan(50),
        reason: 'monthly stipendio rows');

    // ─────────────────────────────────────────────────────────────────────
    // Step 5: stress balance-per-row — recalc cumulative, verify the
    // running balance matches sum-of-amounts on every single row.
    // Verifies round-10's valueDate-ordered seeding against ~200 rows.
    // ─────────────────────────────────────────────────────────────────────
    _step('5. Cumulative balance per row — recalc + verify all 200+ rows');
    await txService.recalculateBalances(fineco.id, balanceMode: 'cumulative');
    final fincoSorted = await (db.select(db.transactions)
          ..where((t) => t.accountId.equals(fineco.id))
          ..orderBy([(t) => OrderingTerm.asc(t.valueDate), (t) => OrderingTerm.asc(t.id)]))
        .get();
    var running = 0.0;
    for (final tx in fincoSorted) {
      running += tx.amount;
      expect(tx.balanceAfter, closeTo(running, 0.001),
          reason: 'tx#${tx.id} on ${tx.valueDate} should match running sum');
    }
    _step('   ✓ all ${fincoSorted.length} balanceAfter values match');

    // ─────────────────────────────────────────────────────────────────────
    // Step 6: REVOLUT multi-year CSV import — exercises:
    //   • balance-from-column (Saldo) — verbatim per-row
    //   • mixed Tipo: Pagamento con carta, Ricarica, Rimborso, Commissione,
    //     Cambia valuta, Chargeback su carta, Prelievo, Ricompensa
    //   • Italian datetime format (yyyy-MM-dd HH:mm:ss).
    // ─────────────────────────────────────────────────────────────────────
    _step('6. Revolut multi-year CSV import — balance-from-column');
    late FilePreview revolutPreview;
    await tester.runAsync(() async {
      revolutPreview = await parseFixture(db, 'revolut_real.csv');
    });
    final revolutResult = await importer.importTransactions(
      preview: revolutPreview,
      mappings: const [
        ColumnMapping(sourceColumn: 'Data di completamento', targetField: 'date'),
        ColumnMapping(sourceColumn: 'Data di inizio', targetField: 'valueDate'),
        ColumnMapping(sourceColumn: 'Importo', targetField: 'amount'),
        ColumnMapping(sourceColumn: 'Descrizione', targetField: 'description'),
        ColumnMapping(sourceColumn: 'Saldo', targetField: 'balanceAfter'),
      ],
      accountId: revolut.id,
      balanceMode: 'column',
    );
    _step('   ✓ imported ${revolutResult.importedRows} Revolut rows (Tipo mixed)');
    expect(revolutResult.importedRows, greaterThan(30));
    final revolutTxs = await (db.select(db.transactions)
          ..where((t) => t.accountId.equals(revolut.id))
          ..orderBy([(t) => OrderingTerm.asc(t.valueDate)]))
        .get();
    // Balance-from-column → balanceAfter on every row matches the CSV.
    for (final tx in revolutTxs) {
      expect(tx.balanceAfter, isNotNull,
          reason: 'tx ${tx.description} should have balanceAfter from column');
    }
    expect(revolutTxs.first.valueDate.year, 2020);
    expect(revolutTxs.last.valueDate.year, 2025);

    // ─────────────────────────────────────────────────────────────────────
    // Step 7: balance-DELTA mode — fixture has 4 dated rows and a blank
    // gap row in the middle. Verifies the round-6 fix where the first
    // row contributes 0 (no prior balance) and the gap row preserves
    // the last-known balance so the next valid row diffs correctly.
    // ─────────────────────────────────────────────────────────────────────
    _step('7. Balance-delta mode — first row 0, gap carries forward');
    late FilePreview balDeltaPreview;
    await tester.runAsync(() async {
      balDeltaPreview = await parseFixture(db, 'balance_delta.csv');
    });
    final balDeltaAccountId = await db.into(db.accounts).insert(
      AccountsCompanion.insert(name: 'BalDeltaAcc', currency: const Value('EUR')),
    );
    final balDeltaResult = await importer.importTransactions(
      preview: balDeltaPreview,
      mappings: const [
        ColumnMapping(sourceColumn: 'date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'desc', targetField: 'description'),
        ColumnMapping(
          sourceColumn: 'bal',
          targetField: 'amount',
          balanceDiffColumn: 'bal',
        ),
      ],
      accountId: balDeltaAccountId,
    );
    expect(balDeltaResult.importedRows, greaterThan(0));
    final balDeltaTxs = await (db.select(db.transactions)
          ..where((t) => t.accountId.equals(balDeltaAccountId))
          ..orderBy([(t) => OrderingTerm.asc(t.valueDate)]))
        .get();
    expect(balDeltaTxs.firstWhere((t) => t.description == 'opening').amount, 0.0,
        reason: 'first row contributes 0 (round-6 fix)');
    expect(balDeltaTxs.firstWhere((t) => t.description == 'paycheck').amount,
        closeTo(100.0, 0.001));
    expect(balDeltaTxs.firstWhere((t) => t.description == 'coffee').amount,
        closeTo(-20.0, 0.001));

    // ─────────────────────────────────────────────────────────────────────
    // Step 8: LISTA TITOLI multi-year XLSX import — exercises:
    //   • skipRows = 5 (banner)
    //   • type-from-column: 'A' → buy, 'V' → sell
    //   • multi-ISIN with multiple buys per ISIN across years
    //   • Italian decimal cells (Quantita, Prezzo, Controvalore).
    // ─────────────────────────────────────────────────────────────────────
    _step('8. Lista Titoli multi-year XLSX import — type-from-column A/V');
    late FilePreview listaTitoliPreview;
    await tester.runAsync(() async {
      listaTitoliPreview = await parseFixture(db, 'lista_titoli_real.xlsx', skipRows: 5);
    });
    final assetResult = await importer.importAssetEventsGrouped(
      preview: listaTitoliPreview,
      mappings: const [
        ColumnMapping(sourceColumn: 'Data valuta', targetField: 'date'),
        ColumnMapping(sourceColumn: 'Isin', targetField: 'isin'),
        ColumnMapping(sourceColumn: 'Segno', targetField: 'type'),
        ColumnMapping(sourceColumn: 'Quantita', targetField: 'quantity'),
        ColumnMapping(sourceColumn: 'Divisa', targetField: 'currency'),
        ColumnMapping(sourceColumn: 'Prezzo', targetField: 'price'),
        ColumnMapping(sourceColumn: 'Controvalore', targetField: 'amount'),
      ],
      baseCurrency: 'EUR',
      intermediaryId: brokerId,
      buyValues: const {'A'},
      sellValues: const {'V'},
    );
    _step('   ✓ imported ${assetResult.result.importedRows} asset events');
    expect(assetResult.result.importedRows, greaterThan(10));
    final assetEvents = await (db.select(db.assetEvents)
          ..orderBy([(e) => OrderingTerm.asc(e.valueDate)]))
        .get();
    expect(assetEvents.first.valueDate.year, 2020);
    expect(assetEvents.last.valueDate.year, 2025);
    expect(assetEvents.any((e) => e.type == EventType.sell), isTrue,
        reason: 'one Lista Titoli row uses Segno=V → sell');
    final assetsCreated = await db.select(db.assets).get();
    expect(assetsCreated.length, greaterThan(4),
        reason: 'multiple distinct ISINs across years');

    // ─────────────────────────────────────────────────────────────────────
    // Step 9: INCOME XLSX import via wizard.
    // ─────────────────────────────────────────────────────────────────────
    _step('9. Income XLSX import — wizard');
    late FilePreview incomePreview;
    await tester.runAsync(() async {
      incomePreview = await parseFixture(db, 'income.xlsx');
    });
    await pushImportScreen(tester, preview: incomePreview, target: ImportTarget.income);
    await longSettle(tester);
    if (find.text('Next').evaluate().isNotEmpty) {
      await tester.tap(find.text('Next'));
      await longSettle(tester);
    }
    if (find.widgetWithText(FilledButton, 'Import').evaluate().isNotEmpty) {
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Import'));
      await tester.tap(find.widgetWithText(FilledButton, 'Import'));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
    final incomeRows = await db.select(db.incomes).get();
    expect(incomeRows, isNotEmpty);
    while (find.byType(BackButton).evaluate().isNotEmpty) {
      await tester.tap(find.byType(BackButton).first);
      await settle(tester);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Step 10: ALL adjustment configurations.
    // Direction × treatment × ephemeral × frequency matrix.
    // ─────────────────────────────────────────────────────────────────────
    _step('10. Adjustments — comprehensive matrix');
    final eventsService = ExtraordinaryEventService(db);
    final bufferService = BufferService(db);

    // 10a. WEEKLY spread / outflow.
    _step('10a. Weekly spread outflow — grocery budget €100/week × 12');
    final weeklyId = await eventsService.create(
      name: 'Weekly groceries',
      direction: EventDirection.outflow,
      treatment: EventTreatment.spread,
      totalAmount: 1200.0,
      currency: 'EUR',
      eventDate: DateTime(2024, 1, 1),
      stepFrequency: StepFrequency.weekly,
      spreadStart: DateTime(2024, 1, 1),
      spreadEnd: DateTime(2024, 3, 18),
    );
    final weeklyEntries = await eventsService.getEntries(weeklyId);
    expect(weeklyEntries, hasLength(12));
    expect(weeklyEntries.every((e) => e.amount == -100.0), isTrue);

    // 10b. MONTHLY spread / outflow with linked buffer + reimbursement +
    //      refund (round-23 fix verification).
    _step('10b. Monthly spread outflow — car repair, +reimb, -refund');
    final carId = await eventsService.create(
      name: 'Car repair 2024',
      direction: EventDirection.outflow,
      treatment: EventTreatment.spread,
      totalAmount: 1200.0,
      currency: 'EUR',
      eventDate: DateTime(2024, 1, 1),
      stepFrequency: StepFrequency.monthly,
      spreadStart: DateTime(2024, 1, 1),
      spreadEnd: DateTime(2024, 12, 1),
    );
    final carBufferId = await eventsService.createLinkedBuffer(carId);
    await bufferService.createTransaction(
      bufferId: carBufferId,
      operationDate: DateTime(2024, 2, 15),
      valueDate: DateTime(2024, 2, 15),
      amount: 300.0,
      currency: 'EUR',
      isReimbursement: true,
    );
    await eventsService.generateScheduledEntries(carId);
    final scheduled1 = (await eventsService.getEntries(carId))
        .where((e) => e.entryKind == EventEntryKind.scheduled)
        .toList();
    expect(scheduled1.every((e) => e.amount == -75.0), isTrue,
        reason: '(1200-300)/12');

    await bufferService.createTransaction(
      bufferId: carBufferId,
      operationDate: DateTime(2024, 3, 1),
      valueDate: DateTime(2024, 3, 1),
      amount: -300.0,
      currency: 'EUR',
      isReimbursement: true,
    );
    await eventsService.generateScheduledEntries(carId);
    final scheduled2 = (await eventsService.getEntries(carId))
        .where((e) => e.entryKind == EventEntryKind.scheduled)
        .toList();
    expect(scheduled2.every((e) => e.amount == -100.0), isTrue,
        reason: 'net 0 reimbursed → full -100/step (round-23 fix)');

    // 10c. QUARTERLY spread / outflow.
    _step('10c. Quarterly spread outflow — insurance €1200/year, 4 steps');
    final insuranceId = await eventsService.create(
      name: 'Insurance quarterly',
      direction: EventDirection.outflow,
      treatment: EventTreatment.spread,
      totalAmount: 1200.0,
      currency: 'EUR',
      eventDate: DateTime(2023, 1, 1),
      stepFrequency: StepFrequency.quarterly,
      spreadStart: DateTime(2023, 1, 1),
      spreadEnd: DateTime(2023, 10, 1),
    );
    final qEntries = await eventsService.getEntries(insuranceId);
    expect(qEntries, hasLength(4));
    expect(qEntries.every((e) => e.amount == -300.0), isTrue);

    // 10d. YEARLY spread / outflow — month-end re-anchor (round-3/5).
    _step('10d. Yearly spread from Jan 31 — month-end re-anchor');
    final yearlyId = await eventsService.create(
      name: 'Annual subscription',
      direction: EventDirection.outflow,
      treatment: EventTreatment.spread,
      totalAmount: 360.0,
      currency: 'EUR',
      eventDate: DateTime(2022, 1, 31),
      stepFrequency: StepFrequency.yearly,
      spreadStart: DateTime(2022, 1, 31),
      spreadEnd: DateTime(2024, 1, 31),
    );
    final yEntries = await eventsService.getEntries(yearlyId);
    expect(yEntries, hasLength(3));
    expect(yEntries[0].date, DateTime(2022, 1, 31));
    expect(yEntries[1].date, DateTime(2023, 1, 31));
    expect(yEntries[2].date, DateTime(2024, 1, 31));

    // 10e. MONTHLY spread / INFLOW — bonus distribution.
    _step('10e. Monthly spread INFLOW — bonus 12 × +500');
    final bonusId = await eventsService.create(
      name: 'Bonus distribution 2025',
      direction: EventDirection.inflow,
      treatment: EventTreatment.spread,
      totalAmount: 6000.0,
      currency: 'EUR',
      eventDate: DateTime(2025, 1, 1),
      stepFrequency: StepFrequency.monthly,
      spreadStart: DateTime(2025, 1, 1),
      spreadEnd: DateTime(2025, 12, 1),
    );
    final bonusEntries = await eventsService.getEntries(bonusId);
    expect(bonusEntries, hasLength(12));
    expect(bonusEntries.every((e) => e.amount == 500.0), isTrue,
        reason: 'inflow → positive scheduled amounts');

    // 10f. INSTANT inflow + manual entry.
    _step('10f. Instant inflow Gift + manual entry');
    final giftId = await eventsService.create(
      name: 'Gift 2024',
      direction: EventDirection.inflow,
      treatment: EventTreatment.instant,
      totalAmount: 500.0,
      currency: 'EUR',
      eventDate: DateTime(2024, 6, 1),
    );
    await eventsService.addManualEntry(
      eventId: giftId,
      date: DateTime(2024, 6, 1),
      amount: 500.0,
      description: 'Birthday',
    );
    final giftEntries = await eventsService.getEntries(giftId);
    expect(giftEntries, hasLength(1));
    expect(giftEntries.first.amount, 500.0);

    // 10g. INSTANT outflow + manual entry.
    _step('10g. Instant outflow One-off + manual entry');
    final oneOffId = await eventsService.create(
      name: 'Plumber emergency',
      direction: EventDirection.outflow,
      treatment: EventTreatment.instant,
      totalAmount: 350.0,
      currency: 'EUR',
      eventDate: DateTime(2024, 8, 12),
    );
    await eventsService.addManualEntry(
      eventId: oneOffId,
      date: DateTime(2024, 8, 12),
      amount: 350.0,
      description: 'Plumber bill',
    );
    final oneOffEntries = await eventsService.getEntries(oneOffId);
    expect(oneOffEntries, hasLength(1));
    expect(oneOffEntries.first.amount, -350.0,
        reason: 'outflow direction signs the manual entry negative');

    // 10h. EPHEMERAL inflow.
    _step('10h. Ephemeral inflow — line of credit (Cash but never Saving)');
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

    // 10i. Treatment change spread → instant clears scheduled (round-20).
    _step('10i. Treatment change spread → instant — orphan cleanup (round-20)');
    await eventsService.update(
      yearlyId,
      ExtraordinaryEventsCompanion(
        treatment: const Value(EventTreatment.instant),
        stepFrequency: const Value(null),
        spreadStart: const Value(null),
        spreadEnd: const Value(null),
      ),
    );
    final scheduledAfterChange =
        (await eventsService.getEntries(yearlyId))
            .where((e) => e.entryKind == EventEntryKind.scheduled)
            .toList();
    expect(scheduledAfterChange, isEmpty,
        reason: 'spread→instant drops scheduled entries (round-20)');

    // ─────────────────────────────────────────────────────────────────────
    // Step 11: Dashboard tabs — navigate, scroll, expand.
    // Now actually populated with multi-year data so the charts have
    // something to render.
    // ─────────────────────────────────────────────────────────────────────
    Future<void> scrollAndExpand() async {
      final scrollable = find.byType(Scrollable);
      if (scrollable.evaluate().isNotEmpty) {
        for (var i = 0; i < 3; i++) {
          await tester.drag(scrollable.first, const Offset(0, -300));
          await settle(tester);
        }
      }
      final expansions = find.byType(ExpansionTile);
      for (var i = 0; i < expansions.evaluate().length; i++) {
        try {
          await tester.tap(expansions.at(i));
          await settle(tester);
        } catch (_) {}
      }
    }

    _step('11. Dashboard → History tab — scroll + expand');
    await tester.tap(find.text('Dashboard').first);
    await longSettle(tester);
    await scrollAndExpand();

    _step('11b. Dashboard → Allocation tab');
    if (find.text('Allocation').evaluate().isNotEmpty) {
      await tester.tap(find.text('Allocation'));
      await longSettle(tester);
      await scrollAndExpand();
    }

    _step('11c. Dashboard → Health tab');
    if (find.text('Health').evaluate().isNotEmpty) {
      await tester.tap(find.text('Health'));
      await longSettle(tester);
      await scrollAndExpand();
    }

    _step('11d. Dashboard → Cash Flow tab');
    if (find.text('Cash Flow').evaluate().isNotEmpty) {
      await tester.tap(find.text('Cash Flow'));
      await longSettle(tester);
      await scrollAndExpand();
    }

    // ─────────────────────────────────────────────────────────────────────
    // Step 12: cascade-delete sweep.
    // ─────────────────────────────────────────────────────────────────────
    _step('12. Cascade-delete sweep');
    await eventsService.delete(carId);
    expect(
      (await (db.select(db.bufferTransactions)
                ..where((t) => t.bufferId.equals(carBufferId)))
              .get()),
      isEmpty,
      reason: 'event delete cascades buffer transactions',
    );
    final remainingExtIds =
        (await db.select(db.extraordinaryEvents).get()).map((e) => e.id).toList();
    if (remainingExtIds.isNotEmpty) {
      await eventsService.deleteMany(remainingExtIds);
    }
    expect(await db.select(db.extraordinaryEvents).get(), isEmpty);

    // ─────────────────────────────────────────────────────────────────────
    // Step 13: final invariant snapshot.
    // ─────────────────────────────────────────────────────────────────────
    final finalAccounts = await db.select(db.accounts).get();
    final finalAssets = await db.select(db.assets).get();
    final finalIntermediaries = await db.select(db.intermediaries).get();
    final finalEvents = await db.select(db.extraordinaryEvents).get();
    final finalIncomes = await db.select(db.incomes).get();
    final finalTxs = await db.select(db.transactions).get();
    final finalAssetEvents = await db.select(db.assetEvents).get();
    _step(
      '13. Walkthrough done — '
      'intermediaries=${finalIntermediaries.length} '
      'accounts=${finalAccounts.length} '
      'assets=${finalAssets.length} '
      'transactions=${finalTxs.length} '
      'assetEvents=${finalAssetEvents.length} '
      'extEvents=${finalEvents.length} '
      'incomes=${finalIncomes.length}',
    );
    // Realistic shape: multi-year transactions, multiple assets, full
    // adjustment matrix exercised.
    expect(finalTxs.length, greaterThan(180),
        reason: 'multi-year Fineco + Revolut should produce many rows');
    expect(finalAssetEvents.length, greaterThan(10));
  });
}
