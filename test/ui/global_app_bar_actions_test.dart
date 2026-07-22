import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/services/app_actions_controller.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/widgets/global_app_bar_actions.dart';

GlobalActionsRegistry _registry({Future<void> Function(BuildContext)? onSupport}) => GlobalActionsRegistry(
  manualRefresh: () async {},
  showImportExportDialog: (_) async {},
  showSettingsDialog: (_) async {},
  openImportFiles: (_) async {},
  openSupport: onSupport ?? (_) async {},
  retryNetwork: () async {},
);

Widget _harness({
  required double width,
  List<AppBarAction> local = const [],
  GlobalActionsRegistry? registry,
}) {
  return ProviderScope(
    overrides: [
      globalActionsRegistryProvider.overrideWith((ref) => registry ?? _registry()),
      // Avoid touching the DB-backed locale stream and the day-rollover Timer.
      appLocaleProvider.overrideWith((ref) => Stream.value('en')),
      currentDateProvider.overrideWithValue(DateTime(2026, 6, 30)),
    ],
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 800)),
        child: Consumer(
          builder: (context, ref, _) => Scaffold(
            appBar: AppBar(
              title: const Text('Title'),
              actions: globalAppBarActions(context, ref, local: local),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    // _WaybackAction builds a DateFormat; intl locale data must be loaded.
    await initializeDateFormatting();
  });

  group('globalAppBarActions layout', () {
    testWidgets('mobile (<600) keeps refresh/import-export/settings visible and '
        'folds local actions into the overflow menu', (tester) async {
      var edited = 0;
      var deleted = 0;
      await tester.pumpWidget(
        _harness(
          width: 400,
          local: [
            AppBarAction(icon: Icons.edit, tooltip: 'EditThing', onPressed: () => edited++),
            AppBarAction(
              icon: Icons.delete_outline,
              color: Colors.red,
              tooltip: 'DeleteThing',
              onPressed: () => deleted++,
            ),
          ],
        ),
      );
      await tester.pump();

      // The three always-visible globals plus support and the overflow button.
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byIcon(Icons.import_export), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.byIcon(Icons.support_agent), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);

      // Locals are NOT top-level icons on mobile (they live in the overflow).
      expect(find.byIcon(Icons.edit), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);

      // Open the overflow: locals appear as labelled entries, alongside the
      // remaining globals (e.g. the wayback machine).
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('EditThing'), findsOneWidget);
      expect(find.text('DeleteThing'), findsOneWidget);
      expect(find.text('Wayback Machine'), findsOneWidget);

      // Selecting a folded local runs its callback.
      await tester.tap(find.text('EditThing'));
      await tester.pumpAndSettle();
      expect(edited, 1);
      expect(deleted, 0);
    });

    testWidgets('desktop (>=600) renders all globals and locals as icon buttons '
        'with no overflow menu', (tester) async {
      await tester.pumpWidget(
        _harness(
          width: 900,
          local: [AppBarAction(icon: Icons.edit, tooltip: 'EditThing', onPressed: () {})],
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.more_vert), findsNothing);
      // Local action stays an icon button.
      expect(find.byIcon(Icons.edit), findsOneWidget);
      // Full global cluster is visible as icons.
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.byIcon(Icons.import_export), findsOneWidget);
      expect(find.byIcon(Icons.file_upload), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsOneWidget); // privacy
      expect(find.byIcon(Icons.history_toggle_off), findsOneWidget); // wayback
      expect(find.byIcon(Icons.support_agent), findsOneWidget); // support
    });

    testWidgets('the Support action is always visible (mobile + desktop) and '
        'invokes openSupport', (tester) async {
      var opened = 0;
      // Mobile: support stays a top-level icon alongside refresh/settings.
      await tester.pumpWidget(
        _harness(width: 400, registry: _registry(onSupport: (_) async => opened++)),
      );
      await tester.pump();
      expect(find.byIcon(Icons.support_agent), findsOneWidget);
      await tester.tap(find.byIcon(Icons.support_agent));
      await tester.pump();
      expect(opened, 1);

      // Desktop: still a top-level icon.
      await tester.pumpWidget(
        _harness(width: 900, registry: _registry(onSupport: (_) async => opened++)),
      );
      await tester.pump();
      expect(find.byIcon(Icons.support_agent), findsOneWidget);
    });

    testWidgets('no local actions on mobile still shows the overflow for the '
        'remaining globals', (tester) async {
      await tester.pumpWidget(_harness(width: 400));
      await tester.pump();

      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byIcon(Icons.import_export), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });
  });

  group('local submenu actions', () {
    testWidgets('mobile: a submenu action opens a modal listing its choices', (tester) async {
      var allTapped = 0;
      var p1Tapped = 0;
      await tester.pumpWidget(
        _harness(
          width: 400,
          local: [
            AppBarAction(
              icon: Icons.balance,
              tooltip: 'Rebalance',
              submenu: [
                AppBarSubAction(label: 'All', onSelected: () => allTapped++),
                AppBarSubAction(
                  label: 'Pillar 1',
                  dividerBefore: true,
                  onSelected: () => p1Tapped++,
                ),
              ],
            ),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      // Submenu action is a single labelled entry with a chevron affordance.
      expect(find.text('Rebalance'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await tester.tap(find.text('Rebalance'));
      await tester.pumpAndSettle();
      // The modal lists both choices.
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Pillar 1'), findsOneWidget);

      await tester.tap(find.text('Pillar 1'));
      await tester.pumpAndSettle();
      expect(p1Tapped, 1);
      expect(allTapped, 0);
    });

    testWidgets('desktop: a submenu action renders as a PopupMenuButton', (tester) async {
      var allTapped = 0;
      await tester.pumpWidget(
        _harness(
          width: 900,
          local: [
            AppBarAction(
              icon: Icons.balance,
              tooltip: 'Rebalance',
              submenu: [AppBarSubAction(label: 'All', onSelected: () => allTapped++)],
            ),
          ],
        ),
      );
      await tester.pump();

      // Rendered inline (no global overflow), tapping the icon opens the menu.
      expect(find.byIcon(Icons.more_vert), findsNothing);
      await tester.tap(find.byIcon(Icons.balance));
      await tester.pumpAndSettle();
      expect(find.text('All'), findsOneWidget);

      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(allTapped, 1);
    });

    testWidgets('a submenu-less action with null onPressed renders disabled', (tester) async {
      await tester.pumpWidget(
        _harness(
          width: 900,
          local: [const AppBarAction(icon: Icons.balance, tooltip: 'Rebalance')],
        ),
      );
      await tester.pump();

      final button = tester.widget<IconButton>(
        find.ancestor(of: find.byIcon(Icons.balance), matching: find.byType(IconButton)),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('wayback modal', () {
    testWidgets('tapping the wayback icon opens a modal; choosing a scope sets '
        'the wayback date', (tester) async {
      await tester.pumpWidget(_harness(width: 900));
      await tester.pump();

      final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
      expect(container.read(waybackDateProvider), isNull);

      await tester.tap(find.byIcon(Icons.history_toggle_off));
      await tester.pumpAndSettle();

      // Modal presents the scope choices (English strings).
      expect(find.text('Last end of month'), findsOneWidget);
      expect(find.text('Custom...'), findsOneWidget);

      await tester.tap(find.text('Last end of month'));
      await tester.pumpAndSettle();

      expect(container.read(waybackDateProvider), isNotNull);
    });
  });
}
