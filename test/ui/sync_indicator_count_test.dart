// The red LED's tooltip says how many changes are not backed up, when known;
// the overflow entry on phone detail screens says the same.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/app_actions_controller.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/services/sync/backup_sync_status.dart';
import 'package:finance_copilot/ui/widgets/global_app_bar_actions.dart';

const s = AppStrings.en;

void main() {
  setUpAll(() async => initializeDateFormatting());

  Future<void> pump(WidgetTester tester, BackupSyncStatus status, {double width = 900, List<AppBarAction> local = const []}) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          globalActionsRegistryProvider.overrideWith(
            (ref) => GlobalActionsRegistry(
              manualRefresh: () async {},
              showImportExportDialog: (_) async {},
              showSettingsDialog: (_) async {},
              openImportFiles: (_) async {},
              openSupport: (_) async {},
              retryNetwork: () async {},
            ),
          ),
          backupSyncStatusProvider.overrideWith((ref) => status),
          appLocaleProvider.overrideWith((ref) => Stream.value('en')),
          currentDateProvider.overrideWithValue(DateTime(2026, 6, 30)),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              appBar: AppBar(actions: globalAppBarActions(context, ref, local: local)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('red with a known count: the tooltip counts the changes', (tester) async {
    await pump(tester, const BackupSyncStatus(indicator: BackupSyncIndicator.backupOlder, localChanges: 14));
    expect(find.byTooltip(s.syncBackupOlderCount(14)), findsOneWidget);
  });

  testWidgets('red without a count: the plain tooltip', (tester) async {
    await pump(tester, const BackupSyncStatus(indicator: BackupSyncIndicator.backupOlder, localChanges: 0));
    expect(find.byTooltip(s.syncBackupOlder), findsOneWidget);
  });

  testWidgets('phone detail screen: the overflow entry counts them too', (tester) async {
    await pump(
      tester,
      const BackupSyncStatus(indicator: BackupSyncIndicator.backupOlder, localChanges: 1),
      width: 400,
      local: [AppBarAction(icon: Icons.edit, tooltip: 'EditThing', onPressed: () {})],
    );
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text(s.syncBackupOlderCount(1)), findsOneWidget);
  });
}
