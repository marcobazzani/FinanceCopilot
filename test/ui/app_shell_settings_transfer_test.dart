// The app shell's Settings dialog and database transfers, driven through the
// global-actions registry the shell publishes (the callbacks every AppBar
// uses) from the landing page.
//
// Pinned bugs:
//  * The Settings form started from 'EUR', the default number format and the
//    default tax rate when the stored settings had not loaded yet, and Save
//    wrote those defaults over the stored ones.
//  * An untouched system-default number format was saved as the concrete
//    locale it resolved to on this device.
//  * The database file pickers were titled in English whatever the UI language.
//  * A Drive restore started from the landing page that failed was only
//    logged: the landing page closed on an empty database and nobody was told.
import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
// The picker's platform interface is the plugin's own test seam: the method
// channel it uses under test does not transmit dialog titles.
// ignore: implementation_imports
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/main.dart';
import 'package:finance_copilot/services/app_actions_controller.dart';
import 'package:finance_copilot/services/app_settings.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/services/sync/google_drive_sync_service.dart';

/// The shell keys the local DB file and the Drive backup by this name; CI
/// always passes `--dart-define=DB_FILE_NAME=…`.
const _dbFileName = String.fromEnvironment('DB_FILE_NAME');
const _pathProvider = MethodChannel('plugins.flutter.io/path_provider');

class _FakeSync extends GoogleDriveSyncService {
  bool signedIn = false;
  Object? restoreError;
  int restores = 0;

  @override
  bool get isSignedIn => signedIn;

  @override
  String? get userEmail => signedIn ? 'me@example.com' : null;

  @override
  bool get needsReauth => false;

  @override
  Future<bool> trySilentSignIn() async => false;

  @override
  Future<bool> signIn() async => signedIn = true;

  @override
  Future<void> signOut() async => signedIn = false;

  @override
  Future<DriveFileInfo?> getRemoteInfo() async => null;

  @override
  Future<DriveFileInfo?> restoreFromDrive() async {
    restores++;
    if (restoreError case final e?) throw e;
    return null;
  }
}

class _OfflinePrices extends MarketPriceService {
  _OfflinePrices(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

/// Records the title of every file picker opened; the user always cancels.
class _RecordingPicker extends FilePickerPlatform {
  final titles = <String?>[];

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) async {
    titles.add(dialogTitle);
    return null;
  }

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    titles.add(dialogTitle);
    return null;
  }
}

void main() {
  late Directory dir;
  late AppDatabase db;
  late _FakeSync sync;
  late _RecordingPicker picker;
  late FilePickerPlatform originalPicker;

  setUpAll(() async => initializeDateFormatting());

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fc_shell_settings_');
    AppSettings.resetForTesting();
    AppSettings.testConfigDir = dir;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_pathProvider, (call) async => dir.path);
    originalPicker = FilePickerPlatform.instance;
    picker = _RecordingPicker();
    FilePickerPlatform.instance = picker;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    sync = _FakeSync();
  });

  tearDown(() async {
    await db.close();
    FilePickerPlatform.instance = originalPicker;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_pathProvider, null);
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

  /// Pumps the shell. Without a database file on disk it settles on the
  /// landing page.
  Future<void> pumpShell(WidgetTester tester, {String language = 'en', List extraOverrides = const []}) async {
    tester.view.physicalSize = const Size(599, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          googleDriveSyncProvider.overrideWith((ref) => sync),
          marketPriceServiceProvider.overrideWith((ref) => _OfflinePrices(db)),
          portableLanguageProvider.overrideWith((ref) => language),
          ...extraOverrides,
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

  GlobalActionsRegistry registry(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(AppShell))).read(globalActionsRegistryProvider)!;

  /// A context inside the landing page's Scaffold, standing in for the AppBar
  /// action that opens a global dialog.
  BuildContext hostContext(WidgetTester tester, AppStrings s) => tester.element(find.text(s.landingTitle));

  void expectVisibleSnack(String message) {
    expect(find.widgetWithText(SnackBar, message), findsOneWidget);
    expect(find.widgetWithText(SnackBar, message).hitTestable(), findsOneWidget, reason: 'not under a modal barrier');
  }

  Future<String?> config(String key) async => (await (db.select(db.appConfigs)..where((c) => c.key.equals(key))).getSingleOrNull())?.value;

  Future<void> store(String key, String value) =>
      db.into(db.appConfigs).insertOnConflictUpdate(AppConfigsCompanion.insert(key: key, value: value));

  group('AppShell', skip: _dbFileName.isEmpty ? 'needs --dart-define=DB_FILE_NAME=<name>' : null, () {
    group('Settings dialog', () {
      const s = AppStrings.en;

      Future<void> openSettings(WidgetTester tester) async {
        unawaited(registry(tester).showSettingsDialog(hostContext(tester, s)));
        await settle(tester);
        expect(find.widgetWithText(AlertDialog, s.settingsTitle), findsOneWidget);
      }

      Finder saveButton() => find.widgetWithText(FilledButton, s.save);

      /// The number-format dropdown's options: (locale code, label).
      List<(String?, String?)> numberFormatItems(WidgetTester tester) {
        final dropdown = find.descendant(of: find.byType(DropdownButtonFormField<String>).at(1), matching: find.byType(DropdownButton<String>));
        return [for (final item in tester.widget<DropdownButton<String>>(dropdown).items!) (item.value, (item.child as Text).data)];
      }

      testWidgets('the number formats offered: the system default, then the same formats as the import wizard', (tester) async {
        await pumpShell(tester, extraOverrides: [appLocaleProvider.overrideWith((ref) => Stream.value('en_US'))]);
        try {
          await openSettings(tester);
          final items = numberFormatItems(tester);
          expect(items.map((i) => i.$1), ['', 'it_IT', 'en_US', 'en_GB', 'de_DE', 'fr_FR', 'es_ES']);
          expect(items.first.$2, s.systemDefault);
          // One table for both pickers: each format is named as in the import
          // wizard (pinned in import_number_format_picker_test.dart).
          expect(items.skip(1).toList(), [for (final (code, label) in s.numberLocaleOptions) (code, label)]);
          expect(AppStrings.it.numberLocaleOptions, s.numberLocaleOptions, reason: 'each format named in its own language');
        } finally {
          await unmount(tester);
        }
      });

      testWidgets('Save is off until the stored settings have loaded, and then saves them as they are', (tester) async {
        await store('BASE_CURRENCY', 'GBP');
        await store('TAX_RATE', '0.3');
        await store('LOCALE', 'it_IT');
        final currency = StreamController<String>();
        final locale = StreamController<String>();
        final taxRate = StreamController<double>();
        addTearDown(currency.close);
        addTearDown(locale.close);
        addTearDown(taxRate.close);
        await pumpShell(
          tester,
          extraOverrides: [
            baseCurrencyProvider.overrideWith((ref) => currency.stream),
            appLocaleProvider.overrideWith((ref) => locale.stream),
            defaultTaxRateProvider.overrideWith((ref) => taxRate.stream),
          ],
        );
        try {
          await openSettings(tester);
          expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull, reason: 'nothing to save before the stored values are known');
          await tester.tap(saveButton());
          await settle(tester);
          expect(await config('BASE_CURRENCY'), 'GBP');
          expect(await config('TAX_RATE'), '0.3');
          expect(await config('LOCALE'), 'it_IT');

          currency.add('GBP');
          locale.add('it_IT');
          taxRate.add(0.3);
          await settle(tester);
          expect(find.text('GBP'), findsOneWidget);
          expect(tester.widget<TextFormField>(find.widgetWithText(TextFormField, s.settingsDefaultTaxRate)).controller!.text, '30');
          await tapWithIo(tester, saveButton(), until: () => find.byType(AlertDialog).evaluate().isEmpty);

          expect(find.byType(AlertDialog), findsNothing);
          expect(await config('BASE_CURRENCY'), 'GBP');
          expect(await config('TAX_RATE'), '0.3');
          expect(await config('LOCALE'), 'it_IT');
        } finally {
          await unmount(tester);
        }
      });

      testWidgets('an untouched system-default number format stays the system default', (tester) async {
        // Stored: '' (system default), which this device resolves to en_US.
        await store('LOCALE', '');
        await pumpShell(tester, extraOverrides: [appLocaleProvider.overrideWith((ref) => Stream.value('en_US'))]);
        try {
          await openSettings(tester);
          await tapWithIo(tester, saveButton(), until: () => find.byType(AlertDialog).evaluate().isEmpty);

          expect(find.byType(AlertDialog), findsNothing);
          expect(await config('LOCALE'), '', reason: 'the device locale is not pinned as a choice the user never made');
        } finally {
          await unmount(tester);
        }
      });

      testWidgets('a number format the user picks is saved', (tester) async {
        await store('LOCALE', '');
        await pumpShell(tester, extraOverrides: [appLocaleProvider.overrideWith((ref) => Stream.value('en_US'))]);
        try {
          await openSettings(tester);
          await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
          await settle(tester);
          await tester.tap(find.text(numberFormatItems(tester).firstWhere((i) => i.$1 == 'de_DE').$2!).last);
          await settle(tester);
          await tapWithIo(tester, saveButton(), until: () => find.byType(AlertDialog).evaluate().isEmpty);

          expect(await config('LOCALE'), 'de_DE');
        } finally {
          await unmount(tester);
        }
      });
    });

    group('database transfers', () {
      testWidgets('the export picker is titled in the UI language', (tester) async {
        const s = AppStrings.it;
        await pumpShell(tester, language: 'it');
        try {
          unawaited(registry(tester).showImportExportDialog(hostContext(tester, s)));
          await settle(tester);
          await tapWithIo(tester, find.text(s.settingsExportDb), until: () => picker.titles.isNotEmpty);

          expect(picker.titles, [s.dbExportPickerTitle]);
          expect(s.dbExportPickerTitle, isNot(AppStrings.en.dbExportPickerTitle));
        } finally {
          await unmount(tester);
        }
      });

      testWidgets('the import picker is titled in the UI language', (tester) async {
        const s = AppStrings.it;
        await pumpShell(tester, language: 'it');
        try {
          await tester.tap(find.text(s.landingImportDb));
          await settle(tester);

          expect(picker.titles, [s.dbImportPickerTitle]);
          expect(s.dbImportPickerTitle, isNot(AppStrings.en.dbImportPickerTitle));
        } finally {
          await unmount(tester);
        }
      });

      testWidgets('landing page: a failed Drive restore is reported and the landing page stays', (tester) async {
        const s = AppStrings.it;
        sync.restoreError = Exception('HTTP 500 token=secret');
        await pumpShell(tester, language: 'it');
        try {
          await tester.tap(find.text(s.landingSyncDrive));
          await settle(tester);

          expect(sync.restores, 1);
          expectVisibleSnack(s.importExportRestoreFailed);
          expect(find.textContaining('secret'), findsNothing);
          expect(find.text(s.landingTitle), findsOneWidget, reason: 'nothing was restored: the user can retry or start another way');
        } finally {
          await unmount(tester);
        }
      });

      testWidgets('landing page: a Drive backup from another app version is refused with the reason', (tester) async {
        const s = AppStrings.en;
        sync.restoreError = const SchemaVersionMismatchException(localVersion: 50, remoteVersion: 7);
        await pumpShell(tester);
        try {
          await tester.tap(find.text(s.landingSyncDrive));
          await settle(tester);

          expectVisibleSnack(s.dbSchemaMismatch(7, 50));
          expect(find.text(s.landingTitle), findsOneWidget);
        } finally {
          await unmount(tester);
        }
      });
    });
  });
}
