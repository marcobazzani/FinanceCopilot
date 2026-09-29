// Pillar dialog: a target the locale cannot read is flagged on the field and
// nothing is saved. It used to be read as "no target", so editing a pillar
// with a typo in its target silently wiped the target it had.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/pillars/pillar_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/pillars/pillar_create_dialog.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openDialog(WidgetTester tester, {Pillar? existing, String language = 'en'}) async {
    // Wide enough for the portfolio-model labels in the test font.
    tester.view.physicalSize = const Size(2400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          portableLanguageProvider.overrideWith((ref) => language),
          appLocaleProvider.overrideWith((ref) => Stream.value(language == 'it' ? 'it_IT' : 'en_US')),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => PillarCreateDialog(existing: existing),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  Finder field(int i) => find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).at(i);

  testWidgets('edit: an unreadable target is flagged and the stored target is kept', (tester) async {
    const s = AppStrings.en;
    final id = await PillarService(db).create(name: 'Retirement', targetValue: 5000);
    await openDialog(tester, existing: await PillarService(db).getById(id));
    try {
      await tester.enterText(field(1), '5,00.0');
      await tester.tap(find.widgetWithText(FilledButton, s.save));
      await settle(tester);

      expect(find.byType(AlertDialog), findsOneWidget, reason: 'nothing was saved, the dialog stays open');
      expect(find.text(s.invalidNumber), findsOneWidget);
      expect((await PillarService(db).getById(id))!.targetValue, 5000, reason: 'the target is not cleared');

      // Typing again clears the message; a readable target saves.
      await tester.enterText(field(1), '6000');
      await tester.pump();
      expect(find.text(s.invalidNumber), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, s.save));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect((await PillarService(db).getById(id))!.targetValue, 6000);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('edit: an emptied target still clears it', (tester) async {
    const s = AppStrings.en;
    final id = await PillarService(db).create(name: 'Retirement', targetValue: 5000);
    await openDialog(tester, existing: await PillarService(db).getById(id));
    try {
      await tester.enterText(field(1), '');
      await tester.tap(find.widgetWithText(FilledButton, s.save));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect((await PillarService(db).getById(id))!.targetValue, isNull);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('create (Italian): a target in the English spelling is not a number here; nothing is created', (tester) async {
    const s = AppStrings.it;
    await openDialog(tester, language: 'it');
    try {
      await tester.enterText(field(0), 'Pensione');
      await tester.enterText(field(1), '1,500.50');
      await tester.tap(find.widgetWithText(FilledButton, s.create));
      await settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(s.invalidNumber), findsOneWidget);
      expect(await PillarService(db).getAll(), isEmpty);

      await tester.enterText(field(1), '1.500,50');
      await tester.tap(find.widgetWithText(FilledButton, s.create));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect((await PillarService(db).getAll()).single.targetValue, 1500.5);
    } finally {
      await unmount(tester);
    }
  });
}
