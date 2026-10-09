// Intermediary dialogs (shared by the Accounts and Assets screens).
//
// Pinned bugs:
//  * The delete confirmation promised that the intermediary's assets would be
//    moved to "Unassigned", but IntermediaryService.delete refuses to delete an
//    intermediary that still has assets — and that refusal (a StateError) was
//    not caught, so the user got no feedback at all.
//  * Enter in the name field and the Create/Save button both submitted, with
//    no in-flight guard: a quick second submit created a duplicate.
import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/domain/intermediary_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/utils/dialogs.dart';

/// Holds every create until the test opens [gate], so a second submit can land
/// while the first is still in flight.
class _GatedIntermediaryService extends IntermediaryService {
  _GatedIntermediaryService(super.db);

  final gate = Completer<void>();
  final created = <String>[];

  @override
  Future<int> create({required String name}) async {
    created.add(name);
    await gate.future;
    return super.create(name: name);
  }
}

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
  Future<void> pumpHost(
    WidgetTester tester,
    Future<void> Function(BuildContext context, WidgetRef ref) open, {
    List overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db), ...overrides],
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

  Future<List<Intermediary>> intermediaries() => db.select(db.intermediaries).get();

  Finder dialogField() => find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));

  group('confirmAndDeleteIntermediary', () {
    testWidgets('title, buttons and outcome: Cancel keeps it, Delete removes it and unassigns its accounts', (tester) async {
      final broker = await seedIntermediary('Broker');
      final account = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main', intermediaryId: Value(broker.id)));
      await pumpHost(tester, (context, ref) => confirmAndDeleteIntermediary(context, ref, broker));
      try {
        expect(find.widgetWithText(AlertDialog, s.deleteIntermediary), findsOneWidget);
        expect(find.widgetWithText(TextButton, s.cancel), findsOneWidget);
        final delete = find.widgetWithText(FilledButton, s.delete);
        expect(delete, findsOneWidget);
        expect(tester.widget<FilledButton>(delete).style, isNull, reason: 'the confirm button keeps the default colour');

        await tester.tap(find.widgetWithText(TextButton, s.cancel));
        await settle(tester);
        expect(find.byType(AlertDialog), findsNothing);
        expect(await intermediaries(), hasLength(1));

        await tester.tap(find.text('open'));
        await settle(tester);
        await tester.tap(find.widgetWithText(FilledButton, s.delete));
        await settle(tester);
        expect(find.byType(AlertDialog), findsNothing);
        expect(await intermediaries(), isEmpty);
        final unlinked = await (db.select(db.accounts)..where((a) => a.id.equals(account))).getSingle();
        expect(unlinked.intermediaryId, isNull);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('the confirmation says what really happens: accounts are unassigned, assets block the delete', (tester) async {
      final broker = await seedIntermediary('Broker');
      await pumpHost(tester, (context, ref) => confirmAndDeleteIntermediary(context, ref, broker));
      try {
        expect(find.text(s.deleteIntermediaryConfirmUnlinks('Broker')), findsOneWidget);
        expect(find.textContaining('assets will be moved'), findsNothing);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('an intermediary that still holds assets is kept and the user is told why', (tester) async {
      final broker = await seedIntermediary('Broker');
      for (final name in ['Fund A', 'Fund B']) {
        await db
            .into(db.assets)
            .insert(
              AssetsCompanion.insert(
                name: name,
                assetType: AssetType.stockEtf,
                valuationMethod: ValuationMethod.marketPrice,
                intermediaryId: broker.id,
              ),
            );
      }
      await pumpHost(tester, (context, ref) => showManageIntermediariesDialog(context, ref));
      try {
        // A row is deleted by swiping it (it used to have a trash button).
        await tester.drag(find.text('Broker'), const Offset(-600, 0));
        await settle(tester);
        await tester.tap(find.widgetWithText(FilledButton, s.delete));
        await settle(tester);

        expect(find.text(s.intermediaryHasAssets('Broker', 2)), findsOneWidget);
        expect(await intermediaries(), hasLength(1));
        expect(find.widgetWithText(AlertDialog, s.intermediaries), findsOneWidget, reason: 'the management dialog stays open');
      } finally {
        await unmount(tester);
      }
    });
  });

  group('showIntermediaryEditDialog', () {
    testWidgets('Enter in the name field creates it and closes the dialog', (tester) async {
      await pumpHost(tester, (context, ref) => showIntermediaryEditDialog(context, ref));
      try {
        expect(find.widgetWithText(AlertDialog, s.addIntermediary), findsOneWidget);
        await tester.enterText(dialogField(), '  Broker  ');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await settle(tester);

        expect(find.byType(AlertDialog), findsNothing);
        expect((await intermediaries()).map((i) => i.name), ['Broker']);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('Create with the field still focused creates it and closes the dialog', (tester) async {
      await pumpHost(tester, (context, ref) => showIntermediaryEditDialog(context, ref));
      try {
        await tester.enterText(dialogField(), 'Broker');
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, s.create));
        await settle(tester);

        expect(find.byType(AlertDialog), findsNothing);
        expect((await intermediaries()).map((i) => i.name), ['Broker']);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('Cancel with the field still focused creates nothing', (tester) async {
      await pumpHost(tester, (context, ref) => showIntermediaryEditDialog(context, ref));
      try {
        await tester.enterText(dialogField(), 'Broker');
        await tester.tap(find.widgetWithText(TextButton, s.cancel));
        await settle(tester);

        expect(find.byType(AlertDialog), findsNothing);
        expect(await intermediaries(), isEmpty);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('an empty name cannot be submitted', (tester) async {
      await pumpHost(tester, (context, ref) => showIntermediaryEditDialog(context, ref));
      try {
        await tester.enterText(dialogField(), '   ');
        await tester.pump();
        expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, s.create)).onPressed, isNull);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await settle(tester);

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(await intermediaries(), isEmpty);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('edit: the field starts with the current name and Save renames it', (tester) async {
      final broker = await seedIntermediary('Broker');
      await pumpHost(tester, (context, ref) => showIntermediaryEditDialog(context, ref, intermediary: broker));
      try {
        expect(find.widgetWithText(AlertDialog, s.editIntermediary), findsOneWidget);
        expect(tester.widget<TextField>(dialogField()).controller!.text, 'Broker');
        await tester.enterText(dialogField(), 'Broker 2');
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, s.save));
        await settle(tester);

        expect(find.byType(AlertDialog), findsNothing);
        expect((await intermediaries()).map((i) => i.name), ['Broker 2']);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('Enter then Create while the first save is still running creates one intermediary', (tester) async {
      final service = _GatedIntermediaryService(db);
      await pumpHost(
        tester,
        (context, ref) => showIntermediaryEditDialog(context, ref),
        overrides: [intermediaryServiceProvider.overrideWithValue(service)],
      );
      try {
        await tester.enterText(dialogField(), 'Broker');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, s.create));
        await tester.pump();
        service.gate.complete();
        await settle(tester);

        expect(service.created, ['Broker']);
        expect(find.byType(AlertDialog), findsNothing);
        expect(await intermediaries(), hasLength(1));
      } finally {
        await unmount(tester);
      }
    });
  });
}
