// End-to-end UI coverage for the income saved-config restore path after the
// type-heuristic removal. This closes the gap left when an earlier attempt
// asserted on mapper widgets (which a complete config skips via quick-confirm).
//
// Here we assert OUTCOMES (the DB rows + their IncomeType), driving the real
// chain: ImportScreen init → _loadSavedConfig(getIncome) → _applySavedConfig
// (restores __incomeValues/__refundValues tag sets) → _executeImport →
// importIncomes(tagged). Proves a saved income config classifies refunds vs
// income correctly through the actual UI — not a re-implemented stub.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/services/import/import_config_service.dart';
import 'package:finance_copilot/l10n/app_strings.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'restored income config (with tag keys) imports refund vs income correctly via UI',
    (tester) async {
      final db = await pumpApp(tester);

      // Pre-existing saved income config carrying the NEW tag keys, exactly as
      // the wizard persists them.
      await ImportConfigService(db).saveScoped(
        scope: ImportConfigScope.income,
        skipRows: 0,
        mappings: {
          'date': 'Date',
          'amount': 'Amount',
          'type': 'Tipo',
          '__incomeValues': '["Stipendio"]',
          '__refundValues': '["Rimborso"]',
        },
        formula: const [],
        hashColumns: const [],
      );

      // Full in-memory preview (rows == totalRows) so _loadCompletePreview
      // returns it as-is. numberLocale must match _effectiveNumberLocale()
      // (en_US default in tests) — otherwise the screen treats it as a locale
      // change and tries to re-parse a (nonexistent) file, skipping config
      // application. A real parsed preview always carries its numberLocale.
      final preview = FilePreview(
        columns: const ['Date', 'Amount', 'Tipo'],
        rows: const [
          {'Date': '2025-01-15', 'Amount': '3500', 'Tipo': 'Stipendio'},
          {'Date': '2025-01-20', 'Amount': '275', 'Tipo': 'Rimborso'},
        ],
        totalRows: 2,
        numberLocale: 'en_US',
      );

      await pushImportScreen(tester, preview: preview, target: ImportTarget.income, db: db);
      await longSettle(tester);

      const s = AppStrings.en;
      // A complete restored config auto-enters quick-confirm (Import button).
      // If it didn't, we'd be on the mapper with Next → advance, then Import.
      if (find.widgetWithText(FilledButton, s.importButton).evaluate().isEmpty &&
          find.widgetWithText(FilledButton, s.next).evaluate().isNotEmpty) {
        final next = find.widgetWithText(FilledButton, s.next);
        await tester.ensureVisible(next);
        await tester.tap(next);
        await longSettle(tester);
      }
      final importBtn = find.widgetWithText(FilledButton, s.importButton);
      expect(importBtn, findsWidgets, reason: 'restored income config should expose an Import action');
      await tester.ensureVisible(importBtn.first);
      await tester.tap(importBtn.first);
      await pumpFor(tester, const Duration(seconds: 10));

      // Outcome assertions — the real proof.
      final rows = await db.select(db.incomes).get();
      expect(rows, hasLength(2), reason: 'both rows imported via restored config');
      final byAmount = {for (final r in rows) r.amount: r.type};
      expect(byAmount[3500.0], IncomeType.income, reason: 'Stipendio → income (restored __incomeValues)');
      expect(byAmount[275.0], IncomeType.refund, reason: 'Rimborso → refund (restored __refundValues), NOT income');
    },
  );
}
