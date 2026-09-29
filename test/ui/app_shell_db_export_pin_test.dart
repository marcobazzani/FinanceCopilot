// Pins the database exports the app shell starts before they share one
// helper: the one from Import / Export and the "Export first" offered before
// an import replaces data. (The export forced before a wipe is pinned in
// app_shell_test.dart.) An export that succeeds, is cancelled or fails ends
// each flow the way it always has.
import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/main.dart';
import 'package:finance_copilot/services/app_actions_controller.dart';
import 'package:finance_copilot/services/app_settings.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/services/sync/google_drive_sync_service.dart';

/// The shell keys the local DB file by this name; CI always passes
/// `--dart-define=DB_FILE_NAME=…`.
const _dbFileName = String.fromEnvironment('DB_FILE_NAME');
const _pathProvider = MethodChannel('plugins.flutter.io/path_provider');
const _filePicker = MethodChannel('miguelruivo.flutter.plugins.filepicker');

class _SignedOutSync extends GoogleDriveSyncService {
  @override
  bool get isSignedIn => false;

  @override
  Future<bool> trySilentSignIn() async => false;
}

class _OfflinePrices extends MarketPriceService {
  _OfflinePrices(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};

  @override
  Future<void> syncPrices({bool forceToday = false}) async {}
}

void main() {
  const s = AppStrings.en;
  late Directory dir;
  late AppDatabase db;
  var tempDirFails = false;
  String? saveResult;
  late List<String> pickerCalls;

  setUpAll(() async => initializeDateFormatting());

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fc_shell_export_');
    AppSettings.resetForTesting();
    AppSettings.testConfigDir = dir;
    tempDirFails = false;
    saveResult = null;
    pickerCalls = [];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_pathProvider, (call) async {
      if (call.method == 'getTemporaryDirectory' && tempDirFails) throw PlatformException(code: 'no_temp_dir');
      return dir.path;
    });
    messenger.setMockMethodCallHandler(_filePicker, (call) async {
      pickerCalls.add(call.method);
      return call.method == 'save' ? saveResult : null; // an import pick is always cancelled
    });
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_pathProvider, null);
    messenger.setMockMethodCallHandler(_filePicker, null);
    AppSettings.resetForTesting();
    await dir.delete(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  /// Taps [finder] and lets the flow it starts run through real file I/O,
  /// alternating real time with frames until [until] holds (at most ~2 s).
  Future<void> tapWithIo(WidgetTester tester, Finder finder, {required bool Function() until}) async {
    await tester.runAsync(() async => tester.tap(finder));
    for (var i = 0; i < 40 && !until(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 60));
    }
    await settle(tester);
  }

  /// Pumps the shell on its landing page (no database file on disk).
  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(599, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          googleDriveSyncProvider.overrideWith((ref) => _SignedOutSync()),
          marketPriceServiceProvider.overrideWith((ref) => _OfflinePrices(db)),
          portableLanguageProvider.overrideWith((ref) => 'en'),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
        ],
        child: const MaterialApp(home: AppShell(enableStartupSync: false)),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openImportExport(WidgetTester tester) async {
    final registry = ProviderScope.containerOf(tester.element(find.byType(AppShell))).read(globalActionsRegistryProvider)!;
    unawaited(registry.showImportExportDialog(tester.element(find.text(s.landingTitle))));
    await settle(tester);
  }

  bool shown(String text) => find.text(text).evaluate().isNotEmpty;
  List<String> snacks() => [
    for (final e in find.descendant(of: find.byType(SnackBar), matching: find.byType(Text)).evaluate()) (e.widget as Text).data ?? '',
  ];

  group('AppShell database export', skip: _dbFileName.isEmpty ? 'needs --dart-define=DB_FILE_NAME=<name>' : null, () {
    group('from Import / Export', () {
      testWidgets('an export that succeeds is confirmed', (tester) async {
        saveResult = p.join(dir.path, 'exported.db');
        await pumpShell(tester);
        try {
          await openImportExport(tester);
          await tapWithIo(tester, find.text(s.settingsExportDb), until: () => shown(s.settingsExportSuccess));

          expect(pickerCalls, ['save']);
          expect(snacks(), [s.settingsExportSuccess]);
        } finally {
          await unmount(tester);
        }
      });

      testWidgets('a cancelled export says nothing', (tester) async {
        await pumpShell(tester);
        try {
          await openImportExport(tester);
          await tapWithIo(tester, find.text(s.settingsExportDb), until: () => pickerCalls.isNotEmpty);

          expect(pickerCalls, ['save']);
          expect(snacks(), isEmpty);
          expect(find.byType(AlertDialog), findsNothing);
        } finally {
          await unmount(tester);
        }
      });

      testWidgets('a failing export is reported', (tester) async {
        tempDirFails = true;
        await pumpShell(tester);
        try {
          await openImportExport(tester);
          await tester.tap(find.text(s.settingsExportDb));
          await settle(tester);

          expect(pickerCalls, isEmpty);
          expect(snacks(), [s.dbExportFailed]);
        } finally {
          await unmount(tester);
        }
      });
    });

    group('"Export first" before an import replaces data', () {
      Future<void> chooseExportFirst(WidgetTester tester) async {
        await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main')); // data an import would replace
        await pumpShell(tester);
        await openImportExport(tester);
        await tester.runAsync(() async => tester.tap(find.text(s.settingsImportDb)));
        for (var i = 0; i < 40 && !shown(s.settingsImportWarningTitle); i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
          await tester.pump(const Duration(milliseconds: 60));
        }
        await settle(tester);
        expect(find.text(s.settingsImportWarningTitle), findsOneWidget);
      }

      testWidgets('an export that succeeds goes on to the import picker, with no export message', (tester) async {
        saveResult = p.join(dir.path, 'exported.db');
        try {
          await chooseExportFirst(tester);
          await tapWithIo(tester, find.text(s.settingsExportFirst), until: () => pickerCalls.length >= 2);

          expect(pickerCalls.first, 'save');
          expect(pickerCalls, hasLength(2), reason: 'then the database to import is picked (and cancelled here)');
          expect(pickerCalls.last, isNot('save'));
          expect(snacks(), isEmpty);
        } finally {
          await unmount(tester);
        }
      });

      testWidgets('a cancelled export stops the import', (tester) async {
        try {
          await chooseExportFirst(tester);
          await tapWithIo(tester, find.text(s.settingsExportFirst), until: () => pickerCalls.isNotEmpty);
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
          await settle(tester);

          expect(pickerCalls, ['save'], reason: 'no database is picked to import');
          expect(snacks(), isEmpty);
        } finally {
          await unmount(tester);
        }
      });

      testWidgets('a failing export is reported and stops the import', (tester) async {
        tempDirFails = true;
        try {
          await chooseExportFirst(tester);
          await tapWithIo(tester, find.text(s.settingsExportFirst), until: () => shown(s.dbExportFailed));

          expect(pickerCalls, isEmpty);
          expect(snacks(), [s.dbExportFailed]);
        } finally {
          await unmount(tester);
        }
      });
    });
  });
}
