// After an import the wizard recalculates the account's balances from the
// stored statement text. That text is in the account's number format: read
// as en_US, an it_IT "1.100,00" is no balance at all, so a column-mode
// account lost its anchor on the bank's closing and restarted from 0.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
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
    acct = await h.db.into(h.db.accounts).insert(AccountsCompanion.insert(name: 'Conto'));
  });
  tearDown(() => h.close());

  testWidgets('column mode, it_IT: the balances stay anchored on the bank balance column', (tester) async {
    await ImportConfigService(h.db).save(
      accountId: acct,
      skipRows: 0,
      mappings: {'date': 'Data', 'amount': 'Importo', 'description': 'Causale', 'balanceAfter': 'Saldo', '__balanceMode': 'column'},
      formula: const [],
      hashColumns: const [],
      numberLocale: 'it_IT',
    );
    const statement = FilePreview(
      columns: ['Data', 'Causale', 'Importo', 'Saldo'],
      rows: [
        {'Data': '11/05/2022', 'Causale': 'Stipendio', 'Importo': '100,00', 'Saldo': '1.100,00'},
        {'Data': '12/05/2022', 'Causale': 'Rimborso', 'Importo': '50,00', 'Saldo': '1.150,00'},
      ],
      totalRows: 2,
      numberLocale: 'it_IT',
    );
    await h.pump(
      tester,
      ImportScreen(preselectedAccountId: acct, testPreview: statement),
      locale: 'it_IT',
    );
    try {
      await tester.tap(find.widgetWithText(FilledButton, 'Import'));
      await h.settle(tester);
      expect(find.text('Import Complete'), findsOneWidget);
      final rows = await (h.db.select(h.db.transactions)..orderBy([(t) => OrderingTerm.asc(t.valueDate)])).get();
      expect(rows.map((t) => t.balanceAfter), [1100, 1150]);
    } finally {
      await h.unmount(tester);
    }
  });
}
