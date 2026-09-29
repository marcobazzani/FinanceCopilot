// Import wizard texts: why rows were skipped, a failed import, an unreadable
// file and the wizard's help/formula/preview texts are worded in the user's
// language (here Italian) instead of internal English; the mappings summary is
// the same in the quick confirm and the confirm step.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

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

  // Row 2's amount is not a number.
  const statement = FilePreview(
    columns: ['Date', 'Description', 'Amount', 'Memo', 'State'],
    rows: [
      {'Date': '11/05/2022', 'Description': 'Stipendio', 'Amount': '2.500,00', 'Memo': 'a', 'State': 'COMPLETED'},
      {'Date': '12/05/2022', 'Description': 'Affitto', 'Amount': 'abc', 'Memo': 'b', 'State': 'COMPLETED'},
    ],
    totalRows: 2,
    numberLocale: 'it_IT',
  );

  Future<void> saveConfig(
    Map<String, String?> mappings, {
    String? locale = 'it_IT',
    List<Map<String, String>> formula = const [],
  }) => ImportConfigService(h.db).save(
    accountId: acct,
    skipRows: 0,
    mappings: {'date': 'Date', 'description': 'Description', '__balanceMode': 'cumulative', ...mappings},
    formula: formula,
    hashColumns: const [],
    numberLocale: locale,
  );

  ImportScreen screen({FilePreview preview = statement}) => ImportScreen(preselectedAccountId: acct, testPreview: preview);

  Future<void> tapFinder(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await h.settle(tester, frames: 4);
    await tester.tap(target);
    await h.settle(tester);
  }

  Future<void> tapButton(WidgetTester tester, Type type, String label) => tapFinder(tester, find.widgetWithText(type, label));

  /// A segment of a SegmentedButton.
  Future<void> tapSegment(WidgetTester tester, String label) => tapFinder(tester, find.text(label).first);

  group('why rows were not imported', () {
    testWidgets('the dry run and the result list the skipped row in Italian', (tester) async {
      await saveConfig({'amount': 'Amount'});
      await h.pump(tester, screen(), language: 'it', locale: 'it_IT');
      try {
        const reason = 'Riga 2: "abc" non è un numero nel formato it_IT';
        expect(find.text(reason), findsOneWidget, reason: 'the quick-confirm dry run');
        await tapButton(tester, FilledButton, 'Importa');
        expect(find.text('Importazione completata'), findsOneWidget);
        expect(find.text(reason), findsOneWidget, reason: 'the result step');
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('a failed import says so in Italian', (tester) async {
      await saveConfig({'amount': 'Amount'});
      h.importer.onImportTransactions = () async => throw StateError('disk full');
      await h.pump(tester, screen(), language: 'it', locale: 'it_IT');
      try {
        await tapButton(tester, FilledButton, 'Importa');
        expect(find.text('Importazione non riuscita: Bad state: disk full'), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('an unreadable file says so in Italian', (tester) async {
      h.importer.onParseFile = (path, _) async => throw FileSystemException('Cannot open file', path);
      await h.pump(
        tester,
        ImportScreen(preselectedAccountId: acct, initialFilePath: '/nowhere/estratto.csv'),
        language: 'it',
        locale: 'it_IT',
      );
      try {
        expect(find.textContaining('Errore nella lettura del file: '), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });
  });

  group('wizard help, formula and preview texts', () {
    testWidgets('the balance modes explain themselves in Italian', (tester) async {
      await h.pump(tester, screen(), language: 'it', locale: 'it_IT');
      try {
        expect(find.text('Saldo = somma progressiva degli importi dal più vecchio al più nuovo'), findsOneWidget);
        await tapSegment(tester, 'Somma filtrata');
        await h.mapColumn(tester, 'Colonna filtro', 'State');
        expect(
          find.text('Solo le transazioni con valori inclusi entrano nella somma progressiva. Quelle escluse mantengono l\'ultimo saldo noto.'),
          findsOneWidget,
        );
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('the balance-difference amount spells its formula in Italian', (tester) async {
      await h.pump(tester, screen(), language: 'it', locale: 'it_IT');
      try {
        await tapButton(tester, OutlinedButton, 'Saldo Δ');
        expect(find.textContaining('Anteprima: importo = saldo[i] − saldo[i−1] → '), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('the combined-column preview is labelled in Italian', (tester) async {
      await h.pump(tester, screen(), language: 'it', locale: 'it_IT');
      try {
        await h.mapColumn(tester, 'Descrizione *', 'Description');
        await tester.tap(find.byTooltip('Combina più colonne'));
        await h.settle(tester);
        expect(find.textContaining('Anteprima: '), findsOneWidget);
        expect(find.textContaining('Preview:'), findsNothing);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('the computed fee shows its formula and an empty preview in Italian', (tester) async {
      await h.pump(
        tester,
        const ImportScreen(preselectedTarget: ImportTarget.assetEvent, testPreview: statement),
        language: 'it',
        locale: 'it_IT',
      );
      try {
        await tapSegment(tester, 'Calcolato');
        expect(find.text('commissione = |importo| − quantità × prezzo / tasso di cambio'), findsOneWidget);
        expect(find.text('Anteprima: N/D'), findsOneWidget, reason: 'nothing mapped yet: no fee to show');
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('the "today" hint of an unmapped date is in the locale\'s date format', (tester) async {
      await h.pump(
        tester,
        const ImportScreen(preselectedTarget: ImportTarget.assetEvent, testPreview: statement),
        language: 'it',
        locale: 'it_IT',
      );
      try {
        await tapSegment(tester, 'Attuale');
        final row = find.ancestor(of: find.text('Data operazione'), matching: find.byType(Row)).first;
        final dropdown = tester.widget<DropdownButton<String>>(find.descendant(of: row, matching: find.byType(DropdownButton<String>)).first);
        expect((dropdown.hint! as Text).data, 'Non mappato (→ ${DateFormat.yMd('it_IT').format(DateTime.now())})');
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('the Auto number format names the app locale (pin)', (tester) async {
      await h.pump(tester, screen(), language: 'it', locale: 'it_IT');
      try {
        await h.mapColumn(tester, 'Data operazione *', 'Date');
        await h.mapColumn(tester, 'importo *', 'Amount');
        await h.mapColumn(tester, 'Descrizione *', 'Description');
        await tapButton(tester, FilledButton, 'Avanti');
        expect(find.text('Auto (it_IT)'), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });
  });

  group('mappings summary', () {
    // Quick confirm first, then the confirm step reached via "Let me edit" → Next.
    Future<void> bothSummaries(WidgetTester tester, void Function(String where) check) async {
      await h.pump(tester, screen(), language: 'en', locale: 'it_IT');
      try {
        check('quick confirm');
        await tapButton(tester, OutlinedButton, 'Let me edit');
        await tapButton(tester, FilledButton, 'Next');
        check('confirm step');
      } finally {
        await h.unmount(tester);
      }
    }

    testWidgets('plain mappings are listed alike in both (pin)', (tester) async {
      await saveConfig({'amount': 'Amount'});
      await bothSummaries(tester, (where) {
        expect(find.textContaining('date ← Date'), findsOneWidget, reason: where);
        expect(find.textContaining('amount ← Amount'), findsOneWidget, reason: where);
        expect(find.textContaining('description ← Description'), findsOneWidget, reason: where);
      });
    });

    testWidgets('a formula amount is listed alike in both (pin)', (tester) async {
      await saveConfig(
        {},
        formula: const [
          {'operator': '+', 'sourceColumn': 'Amount'},
          {'operator': '-', 'sourceColumn': 'Memo'},
        ],
      );
      await bothSummaries(tester, (where) => expect(find.textContaining('amount ← Amount - Memo'), findsOneWidget, reason: where));
    });

    testWidgets('a balance-difference amount is listed alike in both (pin)', (tester) async {
      await saveConfig({'__balanceDiffColumn': 'Amount'});
      await bothSummaries(tester, (where) => expect(find.textContaining('amount ← Δ Amount'), findsOneWidget, reason: where));
    });

    testWidgets('the default value date names the field in both; combined columns are listed in both', (tester) async {
      await saveConfig({'amount': 'Amount', '__multi_description': '["Description","Memo"]'});
      await bothSummaries(tester, (where) {
        expect(find.textContaining('valueDate ← Operation Date'), findsOneWidget, reason: where);
        expect(find.textContaining('description ← Description + Memo'), findsOneWidget, reason: where);
      });
    });

    testWidgets('the default value date is named in Italian', (tester) async {
      await saveConfig({'amount': 'Amount'});
      await h.pump(tester, screen(), language: 'it', locale: 'it_IT');
      try {
        expect(find.textContaining('valueDate ← Data operazione'), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });
  });

  testWidgets('filtered mode: an unknown opening balance is said, not replaced by 0', (tester) async {
    await h.db
        .into(h.db.transactions)
        .insert(
          TransactionsCompanion.insert(accountId: acct, operationDate: DateTime(2022, 5, 1), valueDate: DateTime(2022, 5, 1), amount: 100),
        );
    await saveConfig({
      'amount': 'Memo',
      '__balanceMode': 'filtered',
      '__balanceFilterColumn': 'State',
      '__balanceFilterInclude': '["COMPLETED"]',
    });
    const numeric = FilePreview(
      columns: ['Date', 'Description', 'Memo', 'State'],
      rows: [
        {'Date': '11/05/2022', 'Description': 'Stipendio', 'Memo': '10', 'State': 'COMPLETED'},
      ],
      totalRows: 1,
      numberLocale: 'it_IT',
    );
    await h.pump(
      tester,
      screen(preview: numeric),
      language: 'it',
      locale: 'it_IT',
    );
    try {
      expect(find.text('Saldo previsto'), findsOneWidget);
      expect(find.text('Sconosciuto: il movimento precedente all\'importazione non ha un saldo salvato'), findsOneWidget);
    } finally {
      await h.unmount(tester);
    }
  });
}
