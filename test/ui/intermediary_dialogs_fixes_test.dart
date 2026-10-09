// Intermediary dialogs (shared by the Accounts and Assets screens):
//  * refusing to delete an intermediary that still holds assets: the reason
//    used to be a snack bar raised under the open management dialog's modal
//    barrier, where it could not be seen; it now shows inside the dialog.
//  * the add form completes with the id of the intermediary it created, so a
//    caller can select it without diffing the list before and after.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/utils/dialogs.dart';

void main() {
  const s = AppStrings.en;
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  /// A screen whose only button runs [open] with a context under the app's
  /// Scaffold (the way the Accounts / Assets screens call these helpers).
  Future<void> pumpHost(WidgetTester tester, Future<void> Function(BuildContext context, WidgetRef ref) open) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Center(
                child: TextButton(onPressed: () => open(context, ref), child: const Text('open')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<int> seedIntermediary(String name) => db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: name));

  Future<void> seedAsset(int intermediaryId) => db
      .into(db.assets)
      .insert(
        AssetsCompanion.insert(
          name: 'Fund',
          assetType: AssetType.stockEtf,
          valuationMethod: ValuationMethod.marketPrice,
          intermediaryId: intermediaryId,
        ),
      );

  testWidgets('the refusal to delete an intermediary with assets is shown where it can be read', (tester) async {
    await seedAsset(await seedIntermediary('Broker'));
    await pumpHost(tester, (context, ref) => showManageIntermediariesDialog(context, ref));
    try {
      // A row is deleted by swiping it (it used to have a trash button).
      await tester.drag(find.text('Broker'), const Offset(-600, 0));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, s.delete));
      await settle(tester);

      final refusal = find.text(s.intermediaryHasAssets('Broker', 1));
      expect(refusal, findsOneWidget);
      expect(refusal.hitTestable(), findsOneWidget, reason: 'not under the management dialog\'s barrier');
      expect(find.descendant(of: find.widgetWithText(AlertDialog, s.intermediaries), matching: refusal), findsOneWidget);
      expect(await db.select(db.intermediaries).get(), hasLength(1));
    } finally {
      await unmount(tester);
    }
  });

  group('the add/edit form completes with', () {
    Future<int?> run(WidgetTester tester, {Intermediary? intermediary, String? typed, bool cancel = false}) async {
      int? result = -1;
      await pumpHost(tester, (context, ref) async => result = await showIntermediaryEditDialog(context, ref, intermediary: intermediary));
      if (typed != null) await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), typed);
      await tester.pump();
      await tester.tap(
        cancel ? find.widgetWithText(TextButton, s.cancel) : find.widgetWithText(FilledButton, intermediary == null ? s.create : s.save),
      );
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      return result;
    }

    testWidgets('the id of the intermediary it created', (tester) async {
      await seedIntermediary('Existing');
      try {
        final id = await run(tester, typed: 'Broker');
        final created = (await db.select(db.intermediaries).get()).singleWhere((i) => i.name == 'Broker');
        expect(id, created.id);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('the id of the intermediary it renamed', (tester) async {
      final id = await seedIntermediary('Broker');
      final broker = await (db.select(db.intermediaries)..where((i) => i.id.equals(id))).getSingle();
      try {
        expect(await run(tester, intermediary: broker, typed: 'Broker 2'), id);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('null when cancelled', (tester) async {
      try {
        expect(await run(tester, typed: 'Broker', cancel: true), isNull);
        expect(await db.select(db.intermediaries).get(), isEmpty);
      } finally {
        await unmount(tester);
      }
    });
  });

  testWidgets('a later delete that succeeds clears the refusal', (tester) async {
    await seedAsset(await seedIntermediary('Broker'));
    await seedIntermediary('Empty');
    await pumpHost(tester, (context, ref) => showManageIntermediariesDialog(context, ref));
    try {
      await tester.drag(find.text('Broker'), const Offset(-600, 0));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, s.delete));
      await settle(tester);
      expect(find.text(s.intermediaryHasAssets('Broker', 1)), findsOneWidget);

      await tester.drag(find.text('Empty'), const Offset(-600, 0));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, s.delete));
      await settle(tester);

      expect(find.text(s.intermediaryHasAssets('Broker', 1)), findsNothing);
      expect((await db.select(db.intermediaries).get()).map((i) => i.name), ['Broker']);
    } finally {
      await unmount(tester);
    }
  });
}
