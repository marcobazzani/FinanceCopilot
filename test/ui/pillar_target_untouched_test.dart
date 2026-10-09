// Pillar dialog: a target the user leaves alone saves unchanged. It was
// pre-filled with two decimals at most, so saving a name-only edit rewrote a
// stored 1234.5678 as 1234.57.
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

/// Opens the dialog once the locale is loaded, as in the app (the shell
/// watches it): the dialog reads it in initState.
class _Launcher extends ConsumerWidget {
  const _Launcher(this.existing);
  final Pillar existing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(appLocaleProvider).hasValue;
    return Scaffold(
      body: ready
          ? TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => PillarCreateDialog(existing: existing),
              ),
              child: const Text('open'),
            )
          : const SizedBox.shrink(),
    );
  }
}

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

  Future<void> openDialog(WidgetTester tester, Pillar existing, String language) async {
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
        child: MaterialApp(home: _Launcher(existing)),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  Finder field(int i) => find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).at(i);

  for (final (language, spelled) in [('it', '1234,5678'), ('en', '1234.5678')]) {
    testWidgets('edit ($language): a target left alone is pre-filled with every digit and saves unchanged', (tester) async {
      final s = AppStrings.of(language);
      final id = await PillarService(db).create(name: 'Retirement', targetValue: 1234.5678);
      await openDialog(tester, (await PillarService(db).getById(id))!, language);
      try {
        expect(tester.widget<TextField>(field(1)).controller!.text, spelled, reason: 'it used to be pre-filled rounded to two decimals');
        await tester.enterText(field(0), 'Retirement (EU)');
        await tester.tap(find.widgetWithText(FilledButton, s.save));
        await settle(tester);

        expect(find.byType(AlertDialog), findsNothing);
        final saved = (await PillarService(db).getById(id))!;
        expect(saved.name, 'Retirement (EU)');
        expect(saved.targetValue, 1234.5678, reason: 'a name-only edit rewrote the target as 1234.57');
      } finally {
        await unmount(tester);
      }
    });
  }

  testWidgets('edit: a round target keeps its short spelling', (tester) async {
    final id = await PillarService(db).create(name: 'Retirement', targetValue: 5000);
    await openDialog(tester, (await PillarService(db).getById(id))!, 'it');
    try {
      expect(tester.widget<TextField>(field(1)).controller!.text, '5000');
    } finally {
      await unmount(tester);
    }
  });
}
