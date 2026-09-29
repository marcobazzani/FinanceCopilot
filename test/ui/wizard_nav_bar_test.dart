// The shared wizard navbar: one look for the bottom buttons of every wizard
// step — a filled primary action at the end, an optional outlined secondary
// action before it, an optional leading widget in the room left — and the
// import wizard's steps all go through it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/import/import_config_service.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/ui/screens/import/import_screen.dart';
import 'package:finance_copilot/ui/widgets/wizard_nav_bar.dart';

import 'import_wizard_harness.dart';

void main() {
  Future<void> pumpBar(WidgetTester tester, WizardNavBar bar) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [bar]),
        ),
      ),
    );
  }

  group('WizardNavBar', () {
    testWidgets('a primary action alone: a filled button at the end, off without a callback', (tester) async {
      await pumpBar(tester, const WizardNavBar(primaryLabel: 'Next', onPrimary: null));
      final next = find.widgetWithText(FilledButton, 'Next');
      expect(next, findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.descendant(of: next, matching: find.byType(Icon)), findsNothing);
      expect(tester.widget<FilledButton>(next).onPressed, isNull);
      expect(tester.getTopRight(next).dx, 800, reason: 'at the end of the bar');
    });

    testWidgets('a secondary action comes first, outlined; both call back; icons are shown', (tester) async {
      var primary = 0;
      var secondary = 0;
      await pumpBar(
        tester,
        WizardNavBar(
          primaryLabel: 'Import',
          primaryIcon: Icons.check,
          onPrimary: () => primary++,
          secondaryLabel: 'Let me edit',
          secondaryIcon: Icons.edit,
          onSecondary: () => secondary++,
        ),
      );
      final import = find.widgetWithText(FilledButton, 'Import');
      final edit = find.widgetWithText(OutlinedButton, 'Let me edit');
      expect(find.descendant(of: import, matching: find.byIcon(Icons.check)), findsOneWidget);
      expect(find.descendant(of: edit, matching: find.byIcon(Icons.edit)), findsOneWidget);
      expect(tester.getTopRight(edit).dx, lessThan(tester.getTopLeft(import).dx));
      expect(tester.getTopRight(import).dx, 800);
      await tester.tap(edit);
      await tester.tap(import);
      expect((primary, secondary), (1, 1));
    });

    testWidgets('a leading widget takes the room before the buttons', (tester) async {
      await pumpBar(tester, const WizardNavBar(primaryLabel: 'Import', onPrimary: null, leading: Text('Why it is off')));
      expect(tester.getTopLeft(find.text('Why it is off')).dx, 0);
      expect(tester.getTopRight(find.widgetWithText(FilledButton, 'Import')).dx, 800);
    });
  });

  group('the import wizard steps use it', () {
    const s = AppStrings.en;
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
      ],
      totalRows: 1,
      numberLocale: 'en_US',
    );

    Finder inNavBar(Finder button) => find.ancestor(of: button, matching: find.byType(WizardNavBar));

    Future<void> tap(WidgetTester tester, Finder f) async {
      await tester.ensureVisible(f);
      await h.settle(tester, frames: 4);
      await tester.tap(f);
      await h.settle(tester);
    }

    testWidgets('quick confirm, mapper and confirm step', (tester) async {
      await ImportConfigService(h.db).save(
        accountId: acct,
        skipRows: 0,
        mappings: {'date': 'Date', 'amount': 'Amount', 'description': 'Description', '__balanceMode': 'cumulative'},
        formula: const [],
        hashColumns: const [],
        numberLocale: 'en_US',
      );
      await h.pump(tester, ImportScreen(preselectedAccountId: acct, testPreview: statement));
      try {
        expect(inNavBar(find.widgetWithText(OutlinedButton, s.letMeEdit)), findsOneWidget, reason: 'quick confirm');
        expect(inNavBar(find.widgetWithText(FilledButton, s.importButton)), findsOneWidget, reason: 'quick confirm');

        await tap(tester, find.widgetWithText(OutlinedButton, s.letMeEdit));
        expect(inNavBar(find.widgetWithText(FilledButton, s.next)), findsOneWidget, reason: 'mapper');

        await tap(tester, find.widgetWithText(FilledButton, s.next));
        expect(inNavBar(find.widgetWithText(FilledButton, s.importButton)), findsOneWidget, reason: 'confirm step');
      } finally {
        await h.unmount(tester);
      }
    });
  });
}
