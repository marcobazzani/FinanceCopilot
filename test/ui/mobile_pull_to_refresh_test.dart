import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/services/app_actions_controller.dart';
import 'package:finance_copilot/ui/widgets/mobile_pull_to_refresh.dart';

GlobalActionsRegistry _registry({
  Future<void> Function()? onRefresh,
}) => GlobalActionsRegistry(
  manualRefresh: onRefresh ?? () async {},
  showImportExportDialog: (_) async {},
  showSettingsDialog: (_) async {},
  openImportFiles: (_) async {},
  retryNetwork: () async {},
);

Widget _harness({GlobalActionsRegistry? registry}) {
  return ProviderScope(
    overrides: [
      globalActionsRegistryProvider.overrideWith((ref) => registry),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: MobilePullToRefresh(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 200, child: Center(child: Text('top'))),
              SizedBox(height: 200, child: Center(child: Text('mid'))),
              SizedBox(height: 200, child: Center(child: Text('bot'))),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('MobilePullToRefresh', () {
    testWidgets('on Android, drag-down at the top of a scrollable invokes '
        'GlobalActionsRegistry.manualRefresh', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        var refreshes = 0;
        await tester.pumpWidget(
          _harness(
            registry: _registry(
              onRefresh: () async {
                refreshes++;
              },
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(RefreshIndicator), findsOneWidget);

        await tester.fling(find.text('top'), const Offset(0, 400), 1000);
        await tester.pumpAndSettle();

        expect(refreshes, 1);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('on Android with no registry yet (AppShell not mounted), '
        'the pull is a safe no-op', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await tester.pumpWidget(_harness(registry: null));
        await tester.pump();

        expect(find.byType(RefreshIndicator), findsOneWidget);

        await tester.fling(find.text('top'), const Offset(0, 400), 1000);
        await tester.pumpAndSettle();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('on macOS (desktop), the widget returns its child unchanged '
        '-- no RefreshIndicator', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        var refreshes = 0;
        await tester.pumpWidget(
          _harness(
            registry: _registry(
              onRefresh: () async {
                refreshes++;
              },
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(RefreshIndicator), findsNothing);

        await tester.fling(find.text('top'), const Offset(0, 400), 1000);
        await tester.pumpAndSettle();
        expect(refreshes, 0);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
