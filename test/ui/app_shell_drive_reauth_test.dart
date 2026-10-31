// A Drive sign-in Google will no longer renew is said as such, with the
// button that signs in again, instead of a bare "Backup failed".

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
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/services/sync/google_drive_sync_service.dart';

const _dbFileName = String.fromEnvironment('DB_FILE_NAME');
const _pathProvider = MethodChannel('plugins.flutter.io/path_provider');
const s = AppStrings.en;

class _ExpiredSync extends GoogleDriveSyncService {
  int signIns = 0;

  @override
  bool get isSignedIn => true;

  @override
  String? get userEmail => 'me@example.com';

  @override
  Future<bool> trySilentSignIn() async => false;

  @override
  Future<bool> signIn() async {
    signIns++;
    return true;
  }

  @override
  Future<DriveFileInfo?> getRemoteInfo() async => throw const DriveSignInExpired();
}

void main() {
  late Directory dir;
  late AppDatabase db;

  setUpAll(() async => initializeDateFormatting());

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fc_shell_drive_reauth_');
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

  group('AppShell', skip: _dbFileName.isEmpty ? 'needs --dart-define=DB_FILE_NAME=<name>' : null, () {
    testWidgets('a backup whose Drive sign-in expired asks to sign in again, and the button does', (tester) async {
      final sync = _ExpiredSync();
      tester.view.physicalSize = const Size(599, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            googleDriveSyncProvider.overrideWith((ref) => sync),
            portableLanguageProvider.overrideWith((ref) => 'en'),
            appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          ],
          child: const MaterialApp(home: AppShell(enableStartupSync: false)),
        ),
      );
      await settle(tester);
      try {
        final registry = ProviderScope.containerOf(tester.element(find.byType(AppShell))).read(globalActionsRegistryProvider)!;
        unawaited(registry.showImportExportDialog(tester.element(find.text(s.landingTitle))));
        await settle(tester);
        await tester.tap(find.text(s.importExportBackupDrive));
        await settle(tester);

        expect(find.widgetWithText(SnackBar, s.syncReauthNeeded), findsOneWidget);
        expect(find.text(s.importExportBackupFailed), findsNothing);

        await tester.tap(find.widgetWithText(SnackBarAction, s.settingsSyncSignIn));
        await settle(tester);
        expect(sync.signIns, 1);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
      }
    });
  });
}
