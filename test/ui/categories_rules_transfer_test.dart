// Settings → Categories & rules: exporting the rules to a JSON file and
// importing them on another database, through the screen's menu.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../helpers/fake_file_picker.dart';
import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/classification/category_service.dart';
import 'package:finance_copilot/services/classification/rule_service.dart';
import 'package:finance_copilot/services/classification/rule_transfer_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/classification/categories_rules_screen.dart';

void main() {
  const s = AppStrings.en;
  late AppDatabase db;
  late Directory dir;
  late FakeFilePicker picker;
  late FilePickerPlatform originalPicker;

  /// A rules file from another database: its Pets category and two rules.
  late String otherFile;

  // The screen's database and the one the rules file comes from.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('fc_rules_transfer_');
    picker = FakeFilePicker();
    originalPicker = FilePickerPlatform.instance;
    FilePickerPlatform.instance = picker;

    final other = AppDatabase.forTesting(NativeDatabase.memory());
    try {
      final pets = await CategoryService(other).create(name: 'Pets', type: CategoryType.expense);
      final rules = RuleService(other);
      await rules.create(matchType: RuleMatchType.merchantKey, pattern: 'CLINICA VET', categoryId: pets, direction: RuleDirection.outflow);
      await rules.create(
        matchType: RuleMatchType.contains,
        pattern: 'farmacia',
        categoryId: (await CategoryService(other).getByKey('health'))!.id,
      );
      otherFile = p.join(dir.path, 'rules.json');
      File(otherFile).writeAsStringSync((await RuleTransferService(other).exportJson()).json);
    } finally {
      await other.close();
    }
  });

  tearDown(() async {
    FilePickerPlatform.instance = originalPicker;
    await db.close();
    await dir.delete(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  /// Taps [finder] and lets what it starts run through real file I/O,
  /// alternating real time with frames until [until] holds (at most ~2 s).
  Future<void> tapWithIo(WidgetTester tester, Finder finder, {required bool Function() until}) async {
    await tester.runAsync(() async => tester.tap(finder));
    for (var i = 0; i < 40 && !until(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 60));
    }
    await settle(tester);
  }

  Future<void> pumpScreen(WidgetTester tester, {RuleTransferService Function(AppDatabase db)? transfer}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          if (transfer != null) ruleTransferServiceProvider.overrideWith((ref) => transfer(db)),
        ],
        child: const MaterialApp(home: CategoriesRulesScreen()),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip(s.rulesTransfer));
    await settle(tester);
  }

  bool shown(String text) => find.text(text).evaluate().isNotEmpty;

  Future<List<String>> patterns() async => [for (final r in await RuleService(db).getAll()) r.pattern];

  group('export', () {
    testWidgets('saves every rule and category as a JSON file named after the day', (tester) async {
      await RuleService(
        db,
      ).create(matchType: RuleMatchType.merchantKey, pattern: 'ESSELUNGA', categoryId: (await CategoryService(db).getByKey('groceries'))!.id);
      picker.saveTo = p.join(dir.path, 'out.json');
      await pumpScreen(tester);
      try {
        await openMenu(tester);
        await tapWithIo(tester, find.text(s.exportRules), until: () => shown(s.rulesExported(1, 24)));

        expect(picker.calls, ['save']);
        expect(picker.titles, [s.exportRulesPickerTitle]);
        final file = picker.saved.single;
        expect(file.fileName, matches(RegExp(r'^FinanceCopilot-rules-\d{4}-\d{2}-\d{2}\.json$')));
        expect(file.mimeType, 'application/json');
        final parsed = RuleTransferService.parse(file.bytes);
        expect(parsed.rules.single.pattern, 'ESSELUNGA');
        expect(parsed.categories, hasLength(24));
        expect(find.text(s.rulesExported(1, 24)), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a cancelled save says nothing', (tester) async {
      await pumpScreen(tester);
      try {
        await openMenu(tester);
        await tapWithIo(tester, find.text(s.exportRules), until: () => picker.calls.isNotEmpty);

        expect(picker.calls, ['save']);
        expect(find.byType(SnackBar), findsNothing);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('an export that fails is reported', (tester) async {
      await pumpScreen(tester, transfer: _FailingTransfer.new);
      try {
        await openMenu(tester);
        await tapWithIo(tester, find.text(s.exportRules), until: () => shown(s.rulesExportFailed));

        expect(find.text(s.rulesExportFailed), findsOneWidget);
        expect(picker.calls, isEmpty);
      } finally {
        await unmount(tester);
      }
    });
  });

  group('import', () {
    testWidgets('shows what the file holds and what it replaces, then replaces the rules and asks for a classifier run', (tester) async {
      await RuleService(
        db,
      ).create(matchType: RuleMatchType.merchantKey, pattern: 'OLD', categoryId: (await CategoryService(db).getByKey('shopping'))!.id);
      picker.picked = otherFile;
      await pumpScreen(tester);
      try {
        await openMenu(tester);
        await tapWithIo(tester, find.text(s.importRules), until: () => shown(s.importRulesConfirmTitle));

        expect(find.text(s.importRulesConfirmBody(2, 25, 1)), findsOneWidget);
        expect(find.byKey(const Key('rulesDirtyBanner')), findsNothing);
        await tapWithIo(tester, find.text(s.importRulesReplace), until: () => shown(s.rulesImported(2, 1)));

        expect(await patterns(), ['CLINICA VET', 'farmacia']);
        expect((await CategoryService(db).getAll()).where((c) => c.name == 'Pets'), hasLength(1));
        expect(find.text(s.rulesImported(2, 1)), findsOneWidget);
        expect(find.byKey(const Key('rulesDirtyBanner')), findsOneWidget, reason: 'imported rules are applied by the next classifier run');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('with no rules yet the confirmation only imports', (tester) async {
      picker.picked = otherFile;
      await pumpScreen(tester);
      try {
        await openMenu(tester);
        await tapWithIo(tester, find.text(s.importRules), until: () => shown(s.importRulesConfirmTitle));

        expect(find.text(s.importRulesConfirmBody(2, 25, 0)), findsOneWidget);
        expect(find.text(s.importRulesReplace), findsNothing);
        await tapWithIo(tester, find.text(s.importRulesConfirm), until: () => shown(s.rulesImported(2, 1)));
        expect(await patterns(), ['CLINICA VET', 'farmacia']);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('cancelling the confirmation changes nothing', (tester) async {
      await RuleService(
        db,
      ).create(matchType: RuleMatchType.merchantKey, pattern: 'OLD', categoryId: (await CategoryService(db).getByKey('shopping'))!.id);
      picker.picked = otherFile;
      await pumpScreen(tester);
      try {
        await openMenu(tester);
        await tapWithIo(tester, find.text(s.importRules), until: () => shown(s.importRulesConfirmTitle));
        await tester.tap(find.text(s.cancel));
        await settle(tester);

        expect(await patterns(), ['OLD']);
        expect(find.byType(SnackBar), findsNothing);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a file that is not a rules export is refused before anything is asked or changed', (tester) async {
      await RuleService(
        db,
      ).create(matchType: RuleMatchType.merchantKey, pattern: 'OLD', categoryId: (await CategoryService(db).getByKey('shopping'))!.id);
      final notRules = p.join(dir.path, 'notes.json');
      File(notRules).writeAsStringSync(jsonEncode({'hello': 'world'}));
      picker.picked = notRules;
      await pumpScreen(tester);
      try {
        await openMenu(tester);
        await tapWithIo(tester, find.text(s.importRules), until: () => shown(s.ruleFileProblem(RuleFileProblem.notRulesFile)));

        expect(find.text(s.ruleFileProblem(RuleFileProblem.notRulesFile)), findsOneWidget);
        expect(find.text(s.importRulesConfirmTitle), findsNothing);
        expect(await patterns(), ['OLD']);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a cancelled pick says nothing', (tester) async {
      await pumpScreen(tester);
      try {
        await openMenu(tester);
        await tapWithIo(tester, find.text(s.importRules), until: () => picker.calls.isNotEmpty);

        expect(picker.calls, ['pick']);
        expect(picker.titles, [s.importRulesPickerTitle]);
        expect(find.byType(SnackBar), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a picked file that cannot be read is reported', (tester) async {
      picker.picked = p.join(dir.path, 'gone.json');
      await pumpScreen(tester);
      try {
        await openMenu(tester);
        await tapWithIo(tester, find.text(s.importRules), until: () => shown(s.rulesImportFailed));

        expect(find.text(s.rulesImportFailed), findsOneWidget);
        expect(find.text(s.importRulesConfirmTitle), findsNothing);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('an import that fails is reported and leaves the rules unchanged', (tester) async {
      await RuleService(
        db,
      ).create(matchType: RuleMatchType.merchantKey, pattern: 'OLD', categoryId: (await CategoryService(db).getByKey('shopping'))!.id);
      picker.picked = otherFile;
      await pumpScreen(tester, transfer: _FailingTransfer.new);
      try {
        await openMenu(tester);
        await tapWithIo(tester, find.text(s.importRules), until: () => shown(s.importRulesConfirmTitle));
        await tapWithIo(tester, find.text(s.importRulesReplace), until: () => shown(s.rulesImportFailed));

        expect(find.text(s.rulesImportFailed), findsOneWidget);
        expect(await patterns(), ['OLD']);
        expect(find.byKey(const Key('rulesDirtyBanner')), findsNothing);
      } finally {
        await unmount(tester);
      }
    });
  });
}

/// A transfer whose export and import both fail, as on a full disk.
class _FailingTransfer extends RuleTransferService {
  _FailingTransfer(super.db);

  @override
  Future<({String json, int rules, int categories})> exportJson({DateTime? now}) => Future.error(const FileSystemException('disk full'));

  @override
  Future<RuleImportResult> importFile(RuleFile file) => Future.error(const FileSystemException('disk full'));
}
