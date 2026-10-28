// The sync indicator on the import/export icon: a green dot when the Drive
// backup is newer, red when it is older, none otherwise; the tooltip says
// what a click does, and the click goes where the shell sends it. On phone
// detail screens the icon folds into the overflow, which then carries the dot.

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
  late List<String> calls;

  setUpAll(() async => initializeDateFormatting());
  setUp(() => calls = []);

  GlobalActionsRegistry registry({bool wiresIndicator = true}) => GlobalActionsRegistry(
    manualRefresh: () async => calls.add('refresh'),
    showImportExportDialog: (_) async => calls.add('dialog'),
    openSyncIndicator: wiresIndicator ? (_) async => calls.add('indicator') : null,
    showSettingsDialog: (_) async {},
    openImportFiles: (_) async {},
    openSupport: (_) async {},
    retryNetwork: () async {},
  );

  Future<void> pump(
    WidgetTester tester, {
    BackupSyncIndicator indicator = BackupSyncIndicator.off,
    double width = 900,
    List<AppBarAction> local = const [],
    GlobalActionsRegistry? reg,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          globalActionsRegistryProvider.overrideWith((ref) => reg ?? registry()),
          backupSyncStatusProvider.overrideWith((ref) => BackupSyncStatus(indicator: indicator)),
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

  Badge ledOn(WidgetTester tester, IconData icon) =>
      tester.widget<Badge>(find.ancestor(of: find.byIcon(icon), matching: find.byType(Badge)).first);

  group('on the import/export icon', () {
    testWidgets('off: no dot, the Import/Export tooltip, a click to the shell', (tester) async {
      await pump(tester);
      expect(ledOn(tester, Icons.import_export).isLabelVisible, isFalse);
      expect(find.byTooltip(s.tooltipImportExportDb), findsOneWidget);

      await tester.tap(find.byIcon(Icons.import_export));
      expect(calls, ['indicator']);
    });

    testWidgets('a newer backup: a green dot, and the tooltip offers the restore', (tester) async {
      await pump(tester, indicator: BackupSyncIndicator.backupNewer);
      final led = ledOn(tester, Icons.import_export);
      expect((led.isLabelVisible, led.backgroundColor), (true, Colors.green));
      expect(find.byTooltip(s.syncBackupNewer), findsOneWidget);

      await tester.tap(find.byIcon(Icons.import_export));
      expect(calls, ['indicator']);
    });

    testWidgets('an older backup: a red dot, and the tooltip offers the backup', (tester) async {
      await pump(tester, indicator: BackupSyncIndicator.backupOlder);
      final led = ledOn(tester, Icons.import_export);
      expect((led.isLabelVisible, led.backgroundColor), (true, Colors.red));
      expect(find.byTooltip(s.syncBackupOlder), findsOneWidget);
    });

    testWidgets('a shell without the indicator action opens the Import/Export dialog', (tester) async {
      await pump(tester, indicator: BackupSyncIndicator.backupOlder, reg: registry(wiresIndicator: false));
      await tester.tap(find.byIcon(Icons.import_export));
      expect(calls, ['dialog']);
    });
  });

  group('phone layout', () {
    testWidgets('main tab: the icon itself carries the dot, the overflow none', (tester) async {
      await pump(tester, indicator: BackupSyncIndicator.backupNewer, width: 400);
      expect(ledOn(tester, Icons.import_export).isLabelVisible, isTrue);
      expect(ledOn(tester, Icons.more_vert).isLabelVisible, isFalse);
    });

    testWidgets('detail screen: the overflow and its import/export entry carry the dot', (tester) async {
      await pump(
        tester,
        indicator: BackupSyncIndicator.backupOlder,
        width: 400,
        local: [AppBarAction(icon: Icons.edit, tooltip: 'EditThing', onPressed: () {})],
      );
      expect(ledOn(tester, Icons.more_vert).isLabelVisible, isTrue);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(ledOn(tester, Icons.import_export).isLabelVisible, isTrue);
      expect(find.text(s.syncBackupOlder), findsOneWidget, reason: 'the entry says what it does');
      expect(find.text(s.tooltipRefresh), findsOneWidget);

      await tester.tap(find.text(s.syncBackupOlder));
      await tester.pumpAndSettle();
      expect(calls, ['indicator']);
    });

    testWidgets('detail screen, nothing to sync: no dot, the usual entry', (tester) async {
      await pump(
        tester,
        width: 400,
        local: [AppBarAction(icon: Icons.edit, tooltip: 'EditThing', onPressed: () {})],
      );
      expect(ledOn(tester, Icons.more_vert).isLabelVisible, isFalse);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text(s.tooltipImportExportDb), findsOneWidget);
    });
  });

  testWidgets('Refresh is called just that', (tester) async {
    await pump(tester);
    expect(find.byTooltip('Refresh'), findsOneWidget);
    expect(AppStrings.it.tooltipRefresh, 'Aggiorna');
  });
}
