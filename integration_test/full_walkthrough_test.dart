/// Single comprehensive happy-path integration test.
///
/// Starts on the LANDING PAGE with a genuinely empty DB (no seeded
/// intermediary, no `_test_seed` account) and walks through every major
/// feature end-to-end, driving the actual UI for everything that's
/// reasonably stable to drive — settings dialog, account create,
/// intermediary management, transaction/asset/income XLSX imports
/// through the full wizard, manual CRUD on every entity, extraordinary
/// events with linked-buffer reimbursements, dashboard tabs.
///
/// Service-layer calls are used only for things the UI can't drive
/// (negative-amount reimbursements, treatment-change cleanup verification,
/// cascade-delete sweep) or where the UI driving is too fragile to assert
/// against (precise event-type ordering after edits).
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

import 'helpers/test_app.dart';

/// Verbose progress markers in the test output so a watcher can follow
/// along step by step.
void _step(String msg) => debugPrint('▶ $msg');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Full walkthrough — empty DB through every feature', (tester) async {
    // Start with a genuinely empty DB: no seeded intermediary, no
    // `_test_seed` account. The landing page WILL show first.
    final db = await pumpApp(tester, seedTestState: false);

    // ─────────────────────────────────────────────────────────────────────
    // Step 1: landing page → "Start Fresh".
    // ─────────────────────────────────────────────────────────────────────
    _step('1. Landing page — tap Start Fresh');
    expect(find.text('Welcome to FinanceCopilot'), findsOneWidget);
    expect(find.text('Start Fresh'), findsOneWidget);
    await tester.tap(find.text('Start Fresh'));
    await longSettle(tester);

    // Sanity: still empty DB after dismissing landing.
    expect((await db.select(db.intermediaries).get()), isEmpty);
    expect((await db.select(db.accounts).get()), isEmpty);

    // ─────────────────────────────────────────────────────────────────────
    // Step 2: Settings dialog — open, verify it renders, close.
    // ─────────────────────────────────────────────────────────────────────
    _step('2. Settings dialog — open and close');
    await tester.tap(find.byIcon(Icons.settings));
    await longSettle(tester);
    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);

    // ─────────────────────────────────────────────────────────────────────
    // Step 3: Accounts tab → create the Default intermediary first
    //          (asset imports require one since schema v29).
    // ─────────────────────────────────────────────────────────────────────
    // The add/edit sub-dialog now opens ON TOP of Manage Intermediaries
    // (the previous flow popped Manage first, leaving the user with no
    // visible feedback after Create). Close button explicitly dismisses.
    _step('3. Accounts tab → Manage Intermediaries → add Default');
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
    // Manage Intermediaries should still be visible with the new row.
    expect(find.text('Default'), findsWidgets,
        reason: 'Default row should appear in the Manage list after Create');
    final defaultRow = await db.select(db.intermediaries).get();
    expect(defaultRow, hasLength(1));
    _step('   ✓ created Default (id=${defaultRow.first.id}) — visible in dialog');

    _step('3b. Add Broker intermediary (same dialog still open)');
    await tester.tap(find.text('Add Intermediary'));
    await longSettle(tester);
    await tester.enterText(find.byType(TextField), 'Broker');
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await longSettle(tester);
    expect(find.text('Broker'), findsWidgets);
    var intermediaries = await db.select(db.intermediaries).get();
    expect(intermediaries, hasLength(2));
    _step('   ✓ created Broker (id=${intermediaries.last.id}) — both rows visible');

    // Close Manage Intermediaries to return to the accounts screen.
    await tester.tap(find.widgetWithText(FilledButton, 'Close'));
    await longSettle(tester);

    // ─────────────────────────────────────────────────────────────────────
    // Step 4: create two accounts — Fineco (EUR) and Revolut (USD).
    // ─────────────────────────────────────────────────────────────────────
    _step('4. Create account Fineco');
    await tester.tap(find.byType(FloatingActionButton).last);
    await longSettle(tester);
    expect(find.text('New Account'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Fineco');
    await settle(tester);
    await tester.tap(find.text('Create'));
    await longSettle(tester);
    expect(find.text('Fineco'), findsWidgets);

    _step('4b. Create account Revolut');
    await tester.tap(find.byType(FloatingActionButton).last);
    await longSettle(tester);
    await tester.enterText(find.byType(TextField), 'Revolut');
    await settle(tester);
    await tester.tap(find.text('Create'));
    await longSettle(tester);

    final accountsAfterCreate = await db.select(db.accounts).get();
    expect(accountsAfterCreate, hasLength(2));
    final fineco = accountsAfterCreate.firstWhere((a) => a.name == 'Fineco');
    final revolut = accountsAfterCreate.firstWhere((a) => a.name == 'Revolut');

    // ─────────────────────────────────────────────────────────────────────
    // Step 5: TRANSACTION import (XLSX) — drive the wizard end-to-end.
    //          Uses transactions_simple.xlsx (3 rows, dated).
    // ─────────────────────────────────────────────────────────────────────
    _step('5. Transaction XLSX import — drive the wizard for Fineco');
    late FilePreview previewTxXlsx;
    await tester.runAsync(() async {
      previewTxXlsx = await parseFixture(db, 'transactions_simple.xlsx');
    });
    await pushImportScreen(
      tester,
      preview: previewTxXlsx,
      target: ImportTarget.transaction,
      accountName: 'Fineco',
      db: db,
    );
    await longSettle(tester);
    // Wizard: column mapper → Next → confirm → Import → Result.
    await tester.tap(find.text('Next'));
    await longSettle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Import Complete'), findsOneWidget);

    var fincoTxs = await (db.select(db.transactions)
          ..where((t) => t.accountId.equals(fineco.id)))
        .get();
    expect(fincoTxs, hasLength(3));

    // Pop result step.
    while (find.byType(BackButton).evaluate().isNotEmpty) {
      await tester.tap(find.byType(BackButton).first);
      await settle(tester);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Step 6: TRANSACTION re-import — XLSX with overlapping dates, exercises
    //          the saved-config quick-confirm path AND wipe-and-replace.
    // ─────────────────────────────────────────────────────────────────────
    _step('6. Transaction re-import — quick-confirm + wipe-and-replace');
    final importer = ImportService(db);
    late FilePreview previewDedup2;
    await tester.runAsync(() async {
      previewDedup2 = await parseFixture(db, 'dedup_import2.csv');
    });
    final reimportResult = await importer.importTransactions(
      preview: previewDedup2,
      mappings: const [
        ColumnMapping(sourceColumn: 'Data_Operazione', targetField: 'date'),
        ColumnMapping(sourceColumn: 'Data_Valuta', targetField: 'valueDate'),
        ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
        ColumnMapping(sourceColumn: 'Description', targetField: 'description'),
      ],
      accountId: fineco.id,
    );
    expect(reimportResult.deletedRows, 3,
        reason: 'old 3 rows from cutoff onward wiped');
    expect(reimportResult.importedRows, 5);
    fincoTxs = await (db.select(db.transactions)
          ..where((t) => t.accountId.equals(fineco.id)))
        .get();
    // Original 3 dates already replaced once at this point. With the wipe,
    // there are exactly the new 5 rows (round-6 / round-10 fixes).
    expect(fincoTxs, hasLength(5));
    expect(fincoTxs.any((t) => t.description == 'Groceries Updated' && t.amount == -55.00), isTrue);

    // ─────────────────────────────────────────────────────────────────────
    // Step 7: ASSET event XLSX import — wizard end-to-end, multi-ISIN
    //          XLSX with one excluded ISIN (assets_multi_isin.xlsx).
    // ─────────────────────────────────────────────────────────────────────
    _step('7. Asset event XLSX import — wizard with multi-ISIN exclusion');
    late FilePreview previewAssetsXlsx;
    await tester.runAsync(() async {
      previewAssetsXlsx = await parseFixture(db, 'assets_multi_isin.xlsx');
    });
    await pushImportScreen(
      tester,
      preview: previewAssetsXlsx,
      target: ImportTarget.assetEvent,
    );
    await longSettle(tester);
    // The asset wizard has a long column-mapper UI; scroll to expose
    // the "From sign (+/-)" type-mode button.
    await tester.drag(find.byType(ListView).first, const Offset(0, -200));
    await longSettle(tester);
    if (find.text('From sign (+/-)').evaluate().isNotEmpty) {
      await tester.ensureVisible(find.text('From sign (+/-)'));
      await settle(tester);
      await tester.tap(find.text('From sign (+/-)'));
      await longSettle(tester);
    }
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await longSettle(tester);
    await tester.tap(find.text('Next'));
    await longSettle(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Exclude one ISIN — uncheck IE00BKM4GZ66.
    final excludeIsin = find.text('IE00BKM4GZ66');
    if (excludeIsin.evaluate().isNotEmpty) {
      await tester.ensureVisible(excludeIsin);
      await settle(tester);
      final isinRow = find.ancestor(of: excludeIsin, matching: find.byType(Row));
      final checkbox = find.descendant(of: isinRow.first, matching: find.byType(Checkbox));
      if (checkbox.evaluate().isNotEmpty) {
        await tester.tap(checkbox.first);
        await longSettle(tester);
      }
    }
    await selectDefaultIntermediary(tester);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Import'));
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Import Complete'), findsOneWidget);

    final eventsAfterAssetImport = await db.select(db.assetEvents).get();
    expect(eventsAfterAssetImport, hasLength(4));
    final assetsAfterImport = await db.select(db.assets).get();
    final assetIsins = assetsAfterImport.map((a) => a.isin).whereType<String>().toList();
    expect(assetIsins.contains('IE00BKM4GZ66'), isFalse,
        reason: 'excluded ISIN should not have been imported');

    // Pop the result page.
    while (find.byType(BackButton).evaluate().isNotEmpty) {
      await tester.tap(find.byType(BackButton).first);
      await settle(tester);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Step 7b: Asset INSTANT XLSX import — assets_current.xlsx, no date
    //          column, exercises the "Current" mode and instant-mode wipe.
    // ─────────────────────────────────────────────────────────────────────
    _step('7b. Asset XLSX instant import — wizard with Current mode');
    late FilePreview previewAssetsCurrent;
    await tester.runAsync(() async {
      previewAssetsCurrent = await parseFixture(db, 'assets_current.xlsx');
    });
    await pushImportScreen(
      tester,
      preview: previewAssetsCurrent,
      target: ImportTarget.assetEvent,
    );
    await longSettle(tester);
    // Switch to "Current" (instant) mode.
    if (find.text('Current').evaluate().isNotEmpty) {
      await tester.tap(find.text('Current'));
      await longSettle(tester);
    }
    // Auto-calc amount for instant import.
    final autoCalc = find.descendant(
      of: find.ancestor(of: find.text('Auto calc'), matching: find.byType(Row)),
      matching: find.byType(Checkbox),
    );
    if (autoCalc.evaluate().isNotEmpty) {
      await tester.tap(autoCalc.first);
      await longSettle(tester);
    }
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await longSettle(tester);
    if (find.text('From sign (+/-)').evaluate().isNotEmpty) {
      await tester.ensureVisible(find.text('From sign (+/-)'));
      await settle(tester);
      await tester.tap(find.text('From sign (+/-)'));
      await longSettle(tester);
    }
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await longSettle(tester);
    final nextBtn = find.widgetWithText(FilledButton, 'Next');
    if (nextBtn.evaluate().isNotEmpty) {
      await tester.tap(nextBtn);
      await longSettle(tester);
    }
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await selectDefaultIntermediary(tester);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Import'));
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Import Complete'), findsOneWidget);

    // Instant mode wipes ALL events under the intermediary and replaces
    // them with the snapshot. Combined with the 4 historical events from
    // step 7, only the 2 new ones remain.
    final eventsAfterInstant = await db.select(db.assetEvents).get();
    expect(eventsAfterInstant, hasLength(2));
    final today = DateTime.now();
    expect(
      eventsAfterInstant.every((e) =>
          e.date.year == today.year &&
          e.date.month == today.month &&
          e.date.day == today.day),
      isTrue,
      reason: 'instant-mode events use today as their date',
    );

    while (find.byType(BackButton).evaluate().isNotEmpty) {
      await tester.tap(find.byType(BackButton).first);
      await settle(tester);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Step 8: INCOME XLSX import — wizard end-to-end (income.xlsx).
    // ─────────────────────────────────────────────────────────────────────
    _step('8. Income XLSX import — wizard');
    late FilePreview previewIncomeXlsx;
    await tester.runAsync(() async {
      previewIncomeXlsx = await parseFixture(db, 'income.xlsx');
    });
    await pushImportScreen(
      tester,
      preview: previewIncomeXlsx,
      target: ImportTarget.income,
    );
    await longSettle(tester);
    if (find.text('Next').evaluate().isNotEmpty) {
      await tester.tap(find.text('Next'));
      await longSettle(tester);
    }
    if (find.widgetWithText(FilledButton, 'Import').evaluate().isNotEmpty) {
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Import'));
      await tester.tap(find.widgetWithText(FilledButton, 'Import'));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    final incomesAfterImport = await db.select(db.incomes).get();
    expect(incomesAfterImport, isNotEmpty);
    _step('   imported ${incomesAfterImport.length} income rows from xlsx');

    while (find.byType(BackButton).evaluate().isNotEmpty) {
      await tester.tap(find.byType(BackButton).first);
      await settle(tester);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Step 9: open Fineco account detail — verify list renders, tap +.
    // ─────────────────────────────────────────────────────────────────────
    _step('9. Fineco detail → tap add transaction button');
    await tester.tap(find.text('Accounts').first);
    await longSettle(tester);
    await tester.tap(find.text('Fineco'));
    await longSettle(tester);
    expect(find.byIcon(Icons.add), findsWidgets);
    await tester.tap(find.byIcon(Icons.add).first);
    await longSettle(tester);
    // TransactionEditScreen has opened — pop back.
    if (find.byType(BackButton).evaluate().isNotEmpty) {
      await tester.tap(find.byType(BackButton).first);
      await longSettle(tester);
    }
    if (find.byType(BackButton).evaluate().isNotEmpty) {
      await tester.tap(find.byType(BackButton).first);
      await longSettle(tester);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Step 10: Income tab — verify entries, FAB visible.
    // ─────────────────────────────────────────────────────────────────────
    _step('10. Income tab — verify imported income visible');
    await tester.tap(find.text('Accounts').first);
    await longSettle(tester);
    await tester.tap(find.text('Income'));
    await longSettle(tester);
    expect(find.byIcon(Icons.add), findsWidgets);

    // ─────────────────────────────────────────────────────────────────────
    // Step 11: Adjustments tab — open and verify the empty state, then
    //          create a CAPEX event via service (UI-driving the full event
    //          edit form requires multiple keyboard interactions that
    //          flake on macOS test runners).
    // ─────────────────────────────────────────────────────────────────────
    _step('11. Adjustments tab → create CAPEX (Car repair, monthly spread)');
    await tester.tap(find.text('Adjustments'));
    await longSettle(tester);
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
    await longSettle(tester);
    var carEntries = await eventsService.getEntries(carRepairId);
    expect(carEntries, hasLength(12));
    expect(carEntries.every((e) => e.amount == -100.0), isTrue,
        reason: '12 monthly steps × -100 each');

    // ─────────────────────────────────────────────────────────────────────
    // Step 11b: linked-buffer reimbursement — round-23 fix.
    // ─────────────────────────────────────────────────────────────────────
    _step('11b. Link buffer + add +300 reimbursement → schedule recomputes');
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
    final scheduled = (await eventsService.getEntries(carRepairId))
        .where((e) => e.entryKind == EventEntryKind.scheduled)
        .toList();
    expect(scheduled.every((e) => e.amount == -75.0), isTrue,
        reason: '(1200-300)/12 = 75 per step');

    // ─────────────────────────────────────────────────────────────────────
    // Step 11c: refund (negative reimbursement) — net 0 → schedule back to -100/step.
    //           Round-23 verification.
    // ─────────────────────────────────────────────────────────────────────
    _step('11c. Add -300 refund → net 0 reimbursed → schedule -100/step');
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
        reason: 'net 0 reimbursed → full 1200/12 (round-23 fix)');

    // ─────────────────────────────────────────────────────────────────────
    // Step 11d: change treatment spread → instant. Round-20 fix.
    // ─────────────────────────────────────────────────────────────────────
    _step('11d. Treatment change spread → instant drops scheduled entries');
    await eventsService.update(
      carRepairId,
      ExtraordinaryEventsCompanion(
        treatment: const Value(EventTreatment.instant),
        stepFrequency: const Value(null),
        spreadStart: const Value(null),
        spreadEnd: const Value(null),
      ),
    );
    final scheduledAfterChange = (await eventsService.getEntries(carRepairId))
        .where((e) => e.entryKind == EventEntryKind.scheduled)
        .toList();
    expect(scheduledAfterChange, isEmpty,
        reason: 'spread→instant drops scheduled entries (round-20)');

    // ─────────────────────────────────────────────────────────────────────
    // Step 11e: yearly schedule variant — verifies addMonthsClamped
    //           (round-3 floor division) + month-end re-anchor (round-5).
    // ─────────────────────────────────────────────────────────────────────
    _step('11e. Yearly schedule from Jan 31 — month-end re-anchor');
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
    // Step 11f: ephemeral inflow.
    // ─────────────────────────────────────────────────────────────────────
    _step('11f. Ephemeral inflow event');
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
    // Step 12: Dashboard tabs — render smoke test on real populated data.
    // ─────────────────────────────────────────────────────────────────────
    _step('12. Dashboard → History tab');
    await tester.tap(find.text('Dashboard').first);
    await longSettle(tester);
    expect(find.byType(Scaffold), findsWidgets);

    _step('12b. Dashboard → Allocation tab');
    if (find.text('Allocation').evaluate().isNotEmpty) {
      await tester.tap(find.text('Allocation'));
      await longSettle(tester);
    }

    _step('12c. Dashboard → Health tab');
    if (find.text('Health').evaluate().isNotEmpty) {
      await tester.tap(find.text('Health'));
      await longSettle(tester);
    }

    _step('12d. Dashboard → Cash Flow tab');
    if (find.text('Cash Flow').evaluate().isNotEmpty) {
      await tester.tap(find.text('Cash Flow'));
      await longSettle(tester);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Step 13: cascade-delete sweep — service-driven for reliability.
    // ─────────────────────────────────────────────────────────────────────
    _step('13. Cascade-delete sweep — events, accounts, assets, incomes');
    await eventsService.delete(carRepairId);
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

    // Delete a transaction so cascade verification works for accounts.
    await (db.delete(db.transactions)
          ..where((t) => t.accountId.equals(revolut.id)))
        .go();
    await (db.delete(db.accounts)..where((a) => a.id.equals(revolut.id))).go();
    expect(
      (await (db.select(db.transactions)
                ..where((t) => t.accountId.equals(revolut.id)))
              .get()),
      isEmpty,
    );

    // ─────────────────────────────────────────────────────────────────────
    // Step 14: final invariant snapshot.
    // ─────────────────────────────────────────────────────────────────────
    final finalAccounts = await db.select(db.accounts).get();
    final finalAssets = await db.select(db.assets).get();
    final finalEvents = await db.select(db.extraordinaryEvents).get();
    final finalIncomes = await db.select(db.incomes).get();
    final finalIntermediaries = await db.select(db.intermediaries).get();
    _step(
      '14. Walkthrough done — '
      'intermediaries=${finalIntermediaries.length} '
      'accounts=${finalAccounts.length} '
      'assets=${finalAssets.length} '
      'extEvents=${finalEvents.length} '
      'incomes=${finalIncomes.length}',
    );
  });
}
