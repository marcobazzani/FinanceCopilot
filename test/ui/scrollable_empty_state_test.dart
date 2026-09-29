// The scrollable empty state lives with the shared EmptyState widget: a tab
// with nothing to show yet (the dashboard's History and Cash Flow, the Assets
// Overview) shows the one empty-state layout centred in a scrollable the
// pull-to-refresh gesture can drive.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/services/app_actions_controller.dart';
import 'package:finance_copilot/ui/widgets/empty_state.dart';

void main() {
  Future<void> pump(WidgetTester tester, {List<GlobalActionsRegistry> registry = const []}) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [for (final r in registry) globalActionsRegistryProvider.overrideWith((ref) => r)],
        child: MaterialApp(home: Scaffold(body: scrollableEmptyState(Icons.show_chart, 'Nothing yet'))),
      ),
    );
    await tester.pump();
  }

  testWidgets('the shared empty state, centred in a scrollable that always scrolls', (tester) async {
    await pump(tester);
    final empty = find.byType(EmptyState);
    expect(empty, findsOneWidget);
    expect(find.descendant(of: empty, matching: find.byIcon(Icons.show_chart)), findsOneWidget);
    expect(find.descendant(of: empty, matching: find.text('Nothing yet')), findsOneWidget);
    final scrollable = find.ancestor(of: empty, matching: find.byType(Scrollable)).first;
    expect(tester.widget<Scrollable>(scrollable).physics, isA<AlwaysScrollableScrollPhysics>());
    expect(tester.getCenter(find.text('Nothing yet')).dy, greaterThan(400), reason: 'it fills the view, not just the top of it');
  });

  testWidgets('on desktop there is no pull-to-refresh around it', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await pump(tester);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('on a phone a pull reaches the global refresh', (tester) async {
    var refreshes = 0;
    final registry = GlobalActionsRegistry(
      manualRefresh: () async => refreshes++,
      showImportExportDialog: (_) async {},
      showSettingsDialog: (_) async {},
      openImportFiles: (_) async {},
      openSupport: (_) async {},
      retryNetwork: () async {},
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await pump(tester, registry: [registry]);
      await tester.fling(find.text('Nothing yet'), const Offset(0, 1000), 1000);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(refreshes, 1);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
