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
      // Avoid the DB-backed locale stream and the day-rollover Timer.
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

  group('phone layout (< 600)', () {
    testWidgets('main tab screen (no local actions): refresh/import-export/'
        'settings/support are visible; the rest are in the overflow', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_harness(width: 400));
      await tester.pump();

      // Primary globals visible as icons.
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byIcon(Icons.import_export), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.byIcon(Icons.support_agent), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);

      // Non-primary globals are NOT top-level icons (they live in the overflow).
      expect(find.byIcon(Icons.visibility), findsNothing); // privacy
      expect(find.byIcon(Icons.history_toggle_off), findsNothing); // wayback
      expect(find.byIcon(Icons.file_upload), findsNothing); // import file

      // They appear once the overflow is opened.
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Wayback Machine'), findsOneWidget);
    });

    testWidgets('detail screen (has local actions): locals stay visible, ALL '
        'globals fold into the overflow', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _harness(
          width: 400,
          local: [
            AppBarAction(icon: Icons.edit, tooltip: 'EditThing', onPressed: () {}),
            AppBarAction(
              icon: Icons.delete_outline,
              color: Colors.red,
              tooltip: 'DeleteThing',
              onPressed: () {},
            ),
          ],
        ),
      );
      await tester.pump();

      // Local actions remain visible icons.
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);

      // Globals are folded away — not top-level icons on a detail screen —
      // but the overflow button is present so they remain reachable.
      expect(find.byIcon(Icons.refresh), findsNothing);
      expect(find.byIcon(Icons.settings), findsNothing);
      expect(find.byIcon(Icons.support_agent), findsNothing);
      expect(find.byIcon(Icons.import_export), findsNothing);
      expect(find.byIcon(Icons.visibility), findsNothing);
    });
  });

  group('desktop layout (>= 600)', () {
    testWidgets('all globals and local actions render as icon buttons, no overflow', (tester) async {
      await tester.pumpWidget(
        _harness(
          width: 900,
          local: [AppBarAction(icon: Icons.edit, tooltip: 'EditThing', onPressed: () {})],
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(find.byIcon(Icons.edit), findsOneWidget); // local
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byIcon(Icons.import_export), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.byIcon(Icons.support_agent), findsOneWidget);
      expect(find.byIcon(Icons.file_upload), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsOneWidget); // privacy
      expect(find.byIcon(Icons.history_toggle_off), findsOneWidget); // wayback
    });
  });

  group('support action', () {
    testWidgets('visible on a phone main screen and invokes openSupport', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      var opened = 0;
      await tester.pumpWidget(
        _harness(width: 400, registry: _registry(onSupport: (_) async => opened++)),
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.support_agent));
      await tester.pump();
      expect(opened, 1);
    });
  });

  group('local submenu action', () {
    testWidgets('renders as a PopupMenuButton and dispatches the chosen entry', (tester) async {
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
      expect(find.text('Last end of month'), findsOneWidget);
      expect(find.text('Custom...'), findsOneWidget);

      await tester.tap(find.text('Last end of month'));
      await tester.pumpAndSettle();
      expect(container.read(waybackDateProvider), isNotNull);
    });
  });
}
