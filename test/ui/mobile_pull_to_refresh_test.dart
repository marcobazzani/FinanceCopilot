import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/services/refresh_service.dart';
import 'package:finance_copilot/ui/widgets/mobile_pull_to_refresh.dart';

Widget _harness({required Future<void> Function() onRefresh}) {
  return ProviderScope(
    overrides: [
      manualRefreshProvider.overrideWithValue(onRefresh),
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
        'manualRefreshProvider', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        var refreshes = 0;
        await tester.pumpWidget(_harness(onRefresh: () async {
          refreshes++;
        }));
        await tester.pump();

        expect(find.byType(RefreshIndicator), findsOneWidget);

        await tester.fling(find.text('top'), const Offset(0, 400), 1000);
        await tester.pumpAndSettle();

        expect(refreshes, 1);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('on macOS (desktop), the widget returns its child unchanged '
        '-- no RefreshIndicator', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        var refreshes = 0;
        await tester.pumpWidget(_harness(onRefresh: () async {
          refreshes++;
        }));
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
