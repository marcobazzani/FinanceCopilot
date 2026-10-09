// The app shell's Settings dialog reads the default tax rate in the locale its
// field is spelled in, strictly. It used a lenient parser that guessed the
// separator: "12.5" was accepted in it_IT (where the dot groups thousands),
// "26,5" in en_US (where the comma does), and "1.000" — a thousand in it_IT
// — was read as 1 and saved as a 1% rate. Text the locale cannot read is now
// flagged on the field and nothing is saved.
import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
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

class _SignedOutSync extends GoogleDriveSyncService {
  @override
  bool get isSignedIn => false;

  @override
  String? get userEmail => null;

  @override
  bool get needsReauth => false;

  @override
  Future<bool> trySilentSignIn() async => false;

  @override
  Future<DriveFileInfo?> getRemoteInfo() async => null;
}

class _OfflinePrices extends MarketPriceService {
  _OfflinePrices(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

void main() {
  late Directory dir;
  late AppDatabase db;

  setUpAll(() async => initializeDateFormatting());

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fc_shell_tax_rate_strict_');
    AppSettings.resetForTesting();
    AppSettings.testConfigDir = dir;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_pathProvider, (call) async => dir.path);
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
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

  Future<void> pumpShell(WidgetTester tester, {required String locale}) async {
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
          appLocaleProvider.overrideWith((ref) => Stream.value(locale)),
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

  Future<String?> config(String key) async => (await (db.select(db.appConfigs)..where((c) => c.key.equals(key))).getSingleOrNull())?.value;

  group('AppShell', skip: _dbFileName.isEmpty ? 'needs --dart-define=DB_FILE_NAME=<name>' : null, () {
    const s = AppStrings.en;

    Future<void> openSettings(WidgetTester tester) async {
      final registry = ProviderScope.containerOf(tester.element(find.byType(AppShell))).read(globalActionsRegistryProvider)!;
      unawaited(registry.showSettingsDialog(tester.element(find.text(s.landingTitle))));
      await settle(tester);
      expect(find.widgetWithText(AlertDialog, s.settingsTitle), findsOneWidget);
    }

    Finder taxField() => find.widgetWithText(TextFormField, s.settingsDefaultTaxRate);
    bool dialogClosed() => find.byType(AlertDialog).evaluate().isEmpty;

    for (final (locale, typed, error) in [
      ('it_IT', '12.5', s.invalidNumber),
      ('en_US', '26,5', s.invalidNumber),
      // A thousand in it_IT: out of range, not a 1% rate.
      ('it_IT', '1.000', s.settingsTaxRateInvalid),
    ]) {
      testWidgets('$locale: "$typed" is flagged and the stored rate is kept', (tester) async {
        await pumpShell(tester, locale: locale);
        try {
          await openSettings(tester);
          await tester.enterText(taxField(), typed);
          await tester.pump();
          await tapWithIo(tester, find.widgetWithText(FilledButton, s.save), until: dialogClosed);

          expect(find.widgetWithText(AlertDialog, s.settingsTitle), findsOneWidget, reason: 'the dialog stays open on invalid input');
          expect(find.descendant(of: taxField(), matching: find.text(error)), findsOneWidget);
          expect(await config('TAX_RATE'), '0.26', reason: 'the lenient parser saved it');
        } finally {
          await unmount(tester);
        }
      });
    }

    for (final (locale, typed) in [('it_IT', '26,5'), ('en_US', '26.5')]) {
      testWidgets('$locale: "$typed" is read in the locale and saved', (tester) async {
        await pumpShell(tester, locale: locale);
        try {
          await openSettings(tester);
          await tester.enterText(taxField(), typed);
          await tester.pump();
          await tapWithIo(tester, find.widgetWithText(FilledButton, s.save), until: dialogClosed);

          expect(find.byType(AlertDialog), findsNothing);
          expect(await config('TAX_RATE'), '0.265');
        } finally {
          await unmount(tester);
        }
      });
    }
  });
}
