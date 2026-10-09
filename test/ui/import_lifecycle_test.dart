// The import wizard's async work against its own lifetime and against newer
// requests: an import keeps going (and finishes its bookkeeping) when the
// screen goes away, back is refused while it runs, only the latest of
// overlapping loads applies, nothing touches the state of a disposed screen,
// and work that failed is not retried on every rebuild.
import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/import/import_config_service.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/import/import_screen.dart';

import 'import_wizard_harness.dart';

/// Holds [getByAccount] for the accounts that have a closed gate.
class _GatedConfigService extends ImportConfigService {
  _GatedConfigService(super.db);
  final gates = <int, Gate>{};

  @override
  Future<ImportConfig?> getByAccount(int accountId) async {
    await gates[accountId]?.wait;
    return super.getByAccount(accountId);
  }
}

/// A page that opens [screen] on top of itself, so it can be left.
class _Launcher extends StatelessWidget {
  const _Launcher(this.screen);
  final Widget screen;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen)),
        child: const Text('open import'),
      ),
    ),
  );
}

void main() {
  final h = ImportHarness();
  late int acct;

  setUpAll(ImportHarness.initLocales);
  setUp(() async {
    h.open();
    acct = await h.db.into(h.db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
  });
  tearDown(() => h.close());

  const statement = FilePreview(
    columns: ['Date', 'Description', 'Amount'],
    rows: [
      {'Date': '11/05/2022', 'Description': 'Salary', 'Amount': '100'},
      {'Date': '12/05/2022', 'Description': 'Refund', 'Amount': '50'},
    ],
    totalRows: 2,
    numberLocale: 'en_US',
  );

  Future<void> saveConfig(int account, {bool withBalanceMode = true}) => ImportConfigService(h.db).save(
    accountId: account,
    skipRows: 0,
    mappings: {
      'date': 'Date',
      'amount': 'Amount',
      'description': 'Description',
      if (withBalanceMode) '__balanceMode': 'cumulative',
    },
    formula: const [],
    hashColumns: const [],
    numberLocale: 'en_US',
  );

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await h.settle(tester, frames: 4);
    await tester.tap(f);
    await h.settle(tester);
  }

  Future<void> openFromLauncher(WidgetTester tester, Widget screen) async {
    await h.pump(tester, _Launcher(screen));
    await tap(tester, find.text('open import'));
  }

  group('leaving mid-import', () {
    testWidgets('back is refused while the import runs; it then finishes on screen', (tester) async {
      await saveConfig(acct);
      final gate = Gate();
      h.importer.beforeImportTransactions = () => gate.wait;
      await openFromLauncher(tester, ImportScreen(preselectedAccountId: acct, testPreview: statement));
      try {
        await tap(tester, find.widgetWithText(FilledButton, 'Import'));
        expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Import')).onPressed, isNull, reason: 'no second import meanwhile');

        await tester.binding.handlePopRoute();
        await h.settle(tester);
        expect(find.byType(ImportScreen), findsOneWidget, reason: 'the import is still running');

        gate.open();
        await h.settle(tester);
        expect(find.text('Import Complete'), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('when the screen goes away mid-import, the config is still saved and the balances recalculated', (tester) async {
      // Booked before the file, but the money moved after it: only the
      // recalculation of the whole account puts the file's amounts before it.
      final manual = await h.db
          .into(h.db.transactions)
          .insert(
            TransactionsCompanion.insert(
              accountId: acct,
              operationDate: DateTime(2022, 5, 1),
              valueDate: DateTime(2022, 5, 20),
              amount: -7,
              balanceAfter: const Value(-7),
            ),
          );
      await saveConfig(acct, withBalanceMode: false);
      final gate = Gate();
      h.importer.beforeImportTransactions = () => gate.wait;
      await openFromLauncher(tester, ImportScreen(preselectedAccountId: acct, testPreview: statement));
      try {
        await tap(tester, find.widgetWithText(FilledButton, 'Import'));
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await h.settle(tester);
        expect(find.byType(ImportScreen), findsNothing);

        gate.open();
        await h.settle(tester);
        expect(tester.takeException(), isNull);

        final saved = jsonDecode((await ImportConfigService(h.db).getByAccount(acct))!.mappingsJson) as Map<String, dynamic>;
        expect(saved['__balanceMode'], 'cumulative', reason: 'the import config was saved');
        final rows = await (h.db.select(h.db.transactions)..orderBy([(t) => OrderingTerm.asc(t.valueDate)])).get();
        expect(rows.map((t) => t.balanceAfter), [100, 150, 143], reason: 'value-date running balance of the whole account');
        expect(rows.last.id, manual);
      } finally {
        await h.unmount(tester);
      }
    });
  });

  group('only the latest request applies', () {
    testWidgets('switching accounts quickly does not apply the previous account\'s saved config', (tester) async {
      final other = await h.db.into(h.db.accounts).insert(AccountsCompanion.insert(name: 'Other'));
      await saveConfig(acct);
      final configs = _GatedConfigService(h.db)
        ..gates[acct] = Gate()
        ..gates[other] = Gate();
      await h.pump(tester, const ImportScreen(testPreview: statement), overrides: [importConfigServiceProvider.overrideWithValue(configs)]);
      try {
        Future<void> pick(String name) async {
          await tap(tester, find.byType(DropdownButtonFormField<int>));
          await tap(tester, find.text(name).last);
        }

        await pick('Main');
        await pick('Other');
        configs.gates[other]!.open();
        await h.settle(tester);
        configs.gates[acct]!.open();
        await h.settle(tester);

        expect(find.text('Saved configuration detected for this account'), findsNothing);
        expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Next')).onPressed, isNull, reason: 'nothing mapped for "Other"');
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('an older, slower dry run does not replace a newer one', (tester) async {
      await saveConfig(acct);
      final gates = {1: Gate(), 2: Gate()};
      h.importer.beforePreview = (call) => gates[call]?.wait ?? Future<void>.value();
      h.importer.onPreviewTransactions = (call) async =>
          TransactionImportPreview(parsedRows: 100 + call, errorRows: 0, importSum: 0, rowsToReplace: 0);
      await h.pump(tester, ImportScreen(preselectedAccountId: acct, testPreview: statement));
      try {
        await tap(tester, find.widgetWithText(OutlinedButton, 'Let me edit'));
        await tap(tester, find.widgetWithText(FilledButton, 'Next')); // dry run 1
        await tap(tester, find.byKey(const Key('numberLocaleDropdown')));
        await tap(tester, find.text('Deutsch (de_DE)').last); // dry run 2

        gates[2]!.open();
        await h.settle(tester);
        gates[1]!.open();
        await h.settle(tester);

        expect(find.text('102'), findsOneWidget, reason: 'the dry run of the current settings');
        expect(find.text('101'), findsNothing);
        expect(find.text('Computing preview...'), findsNothing);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('clicking skip-rows twice keeps the rows of the latest click', (tester) async {
      final gates = {1: Gate(), 2: Gate()};
      h.importer.onParseFile = (path, skip) async {
        await gates[skip]?.wait;
        return FilePreview(
          columns: ['Date', 'Amount', 'Skipped $skip'],
          rows: [
            {'Date': '11/05/2022', 'Amount': '1', 'Skipped $skip': 'x'},
          ],
          totalRows: 1,
          filePath: path,
          skipRows: skip,
          numberLocale: 'en_US',
        );
      };
      await h.pump(tester, ImportScreen(preselectedAccountId: acct, initialFilePath: '/tmp/statement.csv'));
      try {
        expect(find.text('Skipped 0'), findsOneWidget);
        await tap(tester, find.text('Refine rows & columns'));
        await tap(tester, find.byIcon(Icons.arrow_drop_up));
        await tap(tester, find.byIcon(Icons.arrow_drop_up));

        gates[2]!.open();
        await h.settle(tester);
        gates[1]!.open();
        await h.settle(tester);

        expect(find.text('Skipped 2'), findsOneWidget);
        expect(find.text('Skipped 1'), findsNothing);
      } finally {
        await h.unmount(tester);
      }
    });
  });

  testWidgets('a file read that finishes after the screen is gone touches nothing', (tester) async {
    final gate = Gate();
    h.importer.onParseFile = (path, skip) async {
      await gate.wait;
      return FilePreview(columns: statement.columns, rows: statement.rows, totalRows: 2, filePath: path, numberLocale: 'en_US');
    };
    await h.pump(tester, ImportScreen(preselectedAccountId: acct, initialFilePath: '/tmp/statement.csv'));
    await h.unmount(tester);
    gate.open();
    await h.settle(tester);
    expect(tester.takeException(), isNull);
  });

  group('failed work is not retried on every rebuild', () {
    // Like the parser's capped preview of a 40-row file: its first 5 and last
    // 5 rows. The Type values of the whole file need the complete rows.
    final capped = FilePreview(
      columns: const ['Date', 'Amount', 'Kind'],
      rows: [
        for (var i = 1; i <= 10; i++) {'Date': '$i/05/2022', 'Amount': '100', 'Kind': 'SALARY'},
      ],
      totalRows: 40,
      numberLocale: 'en_US',
    );

    testWidgets('mapping the type column loads the values of every row', (tester) async {
      h.importer.onGetFullRows = (p) async => FilePreview(
        columns: capped.columns,
        rows: [
          ...capped.rows,
          {'Date': '13/05/2022', 'Amount': '10', 'Kind': 'BONUS'},
        ],
        totalRows: 11,
        numberLocale: 'en_US',
      );
      await h.pump(tester, ImportScreen(preselectedTarget: ImportTarget.income, testPreview: capped));
      try {
        await h.mapColumn(tester, 'Type', 'Kind');
        expect(find.text('BONUS'), findsOneWidget, reason: 'a value past the preview rows');
        expect(h.importer.getFullRowsCalls, 1);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('a failed load of the type values is not retried in a loop', (tester) async {
      h.importer.onGetFullRows = (p) async => throw StateError('file moved');
      await h.pump(tester, ImportScreen(preselectedTarget: ImportTarget.income, testPreview: capped));
      try {
        await h.mapColumn(tester, 'Type', 'Kind');
        await h.settle(tester, frames: 40);
        expect(h.importer.getFullRowsCalls, 1);
        expect(find.text('SALARY'), findsWidgets, reason: 'the preview values are still offered');
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('a failed quick-confirm dry run is not retried in a loop', (tester) async {
      await saveConfig(acct);
      h.importer.onPreviewTransactions = (call) async => throw StateError('database busy');
      await h.pump(tester, ImportScreen(preselectedAccountId: acct, testPreview: statement));
      try {
        await h.settle(tester, frames: 40);
        expect(find.text('Saved configuration detected for this account'), findsOneWidget);
        expect(h.importer.previewCalls, 1);
      } finally {
        await h.unmount(tester);
      }
    });
  });
}
