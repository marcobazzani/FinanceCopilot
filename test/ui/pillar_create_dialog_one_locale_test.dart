// Pillar dialog: the target is pre-filled and read back in one locale — the
// stored one it was pre-filled in — even when the display locale changes while
// the dialog is open: a pre-filled "1234,5678" (it_IT) is not re-read as an
// en_US number, where it does not read at all.
import 'dart:async';

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
  const s = AppStrings.en;
  late AppDatabase db;
  late StreamController<String> locale;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    locale = StreamController<String>();
  });
  tearDown(() async {
    // Not awaited: a stream nobody listened to completes its close only once listened to.
    unawaited(locale.close());
    await db.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openDialog(WidgetTester tester, Pillar existing) async {
    tester.view.physicalSize = const Size(2400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => locale.stream),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
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

  Finder targetField() => find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).at(1);

  testWidgets('a locale change while the dialog is open: the pre-filled target still saves unchanged', (tester) async {
    final id = await PillarService(db).create(name: 'Retirement', targetValue: 1234.5678);
    locale.add('it_IT');
    await openDialog(tester, (await PillarService(db).getById(id))!);
    try {
      expect(tester.widget<TextField>(targetField()).controller!.text, '1234,5678');

      locale.add('en_US');
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, s.save));
      await settle(tester);

      expect(find.byType(AlertDialog), findsNothing, reason: 'saved, not flagged as an unreadable number');
      expect((await PillarService(db).getById(id))!.targetValue, 1234.5678);
    } finally {
      await unmount(tester);
    }
  });
}
