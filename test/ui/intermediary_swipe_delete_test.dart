// Intermediaries are deleted the canonical way: a swipe on their row in the
// management dialog, or the trashcan of their edit dialog — no row trash
// button. Both ask the intermediary's own confirmation (its accounts are
// unassigned) and explain a refusal (it still holds assets) where it can be
// read, inside the dialog.
import 'package:drift/drift.dart' hide isNotNull, isNull;
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
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpHost(WidgetTester tester, Future<void> Function(BuildContext context, WidgetRef ref) open) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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

  Future<Intermediary> seedIntermediary(String name) async {
    final id = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: name));
    return (db.select(db.intermediaries)..where((i) => i.id.equals(id))).getSingle();
  }

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

  Future<List<String>> names() async => (await db.select(db.intermediaries).get()).map((i) => i.name).toList();

  Finder manageDialog() => find.widgetWithText(AlertDialog, s.intermediaries);

  Future<void> swipe(WidgetTester tester, String name) async {
    await tester.drag(find.descendant(of: manageDialog(), matching: find.text(name)), const Offset(-600, 0));
    await settle(tester);
  }

  void expectConfirm(WidgetTester tester, String name) {
    final confirm = find.widgetWithText(AlertDialog, s.deleteIntermediary);
    expect(confirm, findsOneWidget, reason: 'it asks first');
    expect(find.descendant(of: confirm, matching: find.text(s.deleteIntermediaryConfirmUnlinks(name))), findsOneWidget);
  }

  group('management dialog', () {
    testWidgets('a row has no trash button: it swipes; Cancel keeps it, Delete removes it and unassigns its accounts', (tester) async {
      final broker = await seedIntermediary('Broker');
      await seedIntermediary('Other');
      final account = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main', intermediaryId: Value(broker.id)));
      await pumpHost(tester, (context, ref) => showManageIntermediariesDialog(context, ref));
      try {
        expect(find.descendant(of: manageDialog(), matching: find.byIcon(Icons.delete)), findsNothing);
        expect(find.descendant(of: manageDialog(), matching: find.byIcon(Icons.delete_outline)), findsNothing);

        await swipe(tester, 'Broker');
        expectConfirm(tester, 'Broker');
        await tester.tap(find.widgetWithText(TextButton, s.cancel));
        await settle(tester);
        expect(await names(), ['Broker', 'Other']);
        expect(
          find.descendant(of: manageDialog(), matching: find.text('Broker')),
          findsOneWidget,
          reason: 'the row comes back',
        );

        await swipe(tester, 'Broker');
        await tester.tap(find.widgetWithText(FilledButton, s.delete));
        await settle(tester);
        expect(await names(), ['Other']);
        expect((await (db.select(db.accounts)..where((a) => a.id.equals(account))).getSingle()).intermediaryId, isNull);
        expect(manageDialog(), findsOneWidget, reason: 'the management dialog stays open');
        expect(tester.takeException(), isNull);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a refused swipe keeps the row and says why inside the dialog; a later delete clears it', (tester) async {
      final broker = await seedIntermediary('Broker');
      await seedAsset(broker.id);
      await seedIntermediary('Empty');
      await pumpHost(tester, (context, ref) => showManageIntermediariesDialog(context, ref));
      try {
        await swipe(tester, 'Broker');
        await tester.tap(find.widgetWithText(FilledButton, s.delete));
        await settle(tester);
        final refusal = find.text(s.intermediaryHasAssets('Broker', 1));
        expect(find.descendant(of: manageDialog(), matching: refusal), findsOneWidget);
        expect(refusal.hitTestable(), findsOneWidget);
        expect(
          find.descendant(of: manageDialog(), matching: find.text('Broker')),
          findsOneWidget,
          reason: 'the row slides back',
        );
        expect(await names(), ['Broker', 'Empty']);

        await swipe(tester, 'Empty');
        await tester.tap(find.widgetWithText(FilledButton, s.delete));
        await settle(tester);
        expect(refusal, findsNothing);
        expect(await names(), ['Broker']);
        expect(tester.takeException(), isNull);
      } finally {
        await unmount(tester);
      }
    });
  });

  group('edit dialog', () {
    Finder trashcan() => find.descendant(of: find.widgetWithText(AlertDialog, s.editIntermediary), matching: find.byTooltip(s.delete));

    testWidgets('its title row has the trashcan: Cancel keeps the intermediary, Delete removes it and closes the form', (tester) async {
      final broker = await seedIntermediary('Broker');
      int? result = -1;
      await pumpHost(tester, (context, ref) async => result = await showIntermediaryEditDialog(context, ref, intermediary: broker));
      try {
        expect(trashcan(), findsOneWidget);
        await tester.tap(trashcan());
        await settle(tester);
        expectConfirm(tester, 'Broker');
        await tester.tap(
          find.descendant(of: find.widgetWithText(AlertDialog, s.deleteIntermediary), matching: find.widgetWithText(TextButton, s.cancel)),
        );
        await settle(tester);
        expect(await names(), ['Broker']);
        expect(find.widgetWithText(AlertDialog, s.editIntermediary), findsOneWidget, reason: 'the form stays open');

        await tester.tap(trashcan());
        await settle(tester);
        await tester.tap(find.widgetWithText(FilledButton, s.delete));
        await settle(tester);
        expect(await names(), isEmpty);
        expect(find.byType(AlertDialog), findsNothing);
        expect(result, isNull, reason: 'nothing was saved');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a refused delete keeps the form open and says why in it', (tester) async {
      final broker = await seedIntermediary('Broker');
      await seedAsset(broker.id);
      await pumpHost(tester, (context, ref) => showIntermediaryEditDialog(context, ref, intermediary: broker));
      try {
        await tester.tap(trashcan());
        await settle(tester);
        await tester.tap(find.widgetWithText(FilledButton, s.delete));
        await settle(tester);
        final refusal = find.text(s.intermediaryHasAssets('Broker', 1));
        expect(find.descendant(of: find.widgetWithText(AlertDialog, s.editIntermediary), matching: refusal), findsOneWidget);
        expect(refusal.hitTestable(), findsOneWidget);
        expect(await names(), ['Broker']);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('adding has no trashcan', (tester) async {
      await pumpHost(tester, (context, ref) => showIntermediaryEditDialog(context, ref));
      try {
        expect(find.widgetWithText(AlertDialog, s.addIntermediary), findsOneWidget);
        expect(find.byTooltip(s.delete), findsNothing);
      } finally {
        await unmount(tester);
      }
    });
  });
}
