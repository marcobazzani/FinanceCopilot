// Dashboard screen:
//  * render order of the History tab: the Price Changes widget, then the
//    combined overlay, then every other chart by its sort order (pinned before
//    the two copies of the bucket rule were folded into one);
//  * History and Cash Flow with no data at all: the shared empty state, in a
//    scrollable the pull-to-refresh gesture can drive;
//  * the debug chart editor (run with DEBUG_CHARTS=1): the delete and reset
//    confirmations and the reorder (pinned before they moved onto
//    showConfirmDialog and the dead reorder code went).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/build_flags.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/models/dashboard_chart.dart';
import 'package:finance_copilot/services/app_actions_controller.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart';
import 'package:finance_copilot/ui/widgets/empty_state.dart';

import 'dashboard_harness.dart';

void main() {
  const s = AppStrings.en;
  final h = DashboardHarness();

  setUpAll(() async => initializeDateFormatting());
  setUp(h.open);
  tearDown(h.close);

  testWidgets('History renders Price Changes, then the combined overlay, then the other charts by sort order', (tester) async {
    await h.seed();
    final created = DateTime(2026, 1, 1);
    DashboardChart chart(int id, String title, int sortOrder, {String widgetType = 'chart', String? sources}) => DashboardChart(
      id: id,
      title: title,
      widgetType: widgetType,
      sortOrder: sortOrder,
      seriesJson: '[]',
      sourceChartIds: sources,
      createdAt: created,
    );
    await h.pump(
      tester,
      overrides: [
        dashboardChartsProvider.overrideWithValue([
          chart(-1, 'Zeta', 0),
          chart(-2, 'Overlay', 1, sources: '["Zeta","Alpha"]'),
          chart(-3, 'Price Changes', 2, widgetType: 'price_changes'),
          chart(-4, 'Alpha', 3),
        ]),
      ],
    );
    try {
      await h.openTab(tester, 'History');
      double top(Finder f) {
        expect(f, findsOneWidget);
        return tester.getTopLeft(f).dy;
      }

      final priceChanges = top(find.ancestor(of: find.text(s.dashPriceChanges), matching: find.byType(Card)).first);
      final overlay = top(find.widgetWithText(ChartCard, 'Overlay'));
      final zeta = top(find.widgetWithText(ExpansionTile, 'Zeta'));
      final alpha = top(find.widgetWithText(ExpansionTile, 'Alpha'));
      expect(priceChanges, lessThan(overlay));
      expect(overlay, lessThan(zeta));
      expect(zeta, lessThan(alpha), reason: 'the rest keep their sort order');
    } finally {
      await h.unmount(tester);
    }
  });

  group('no data yet', () {
    for (final (tab, message) in [('History', s.dashNoData), ('Cash Flow', s.noDataYet)]) {
      testWidgets('$tab: the shared empty state, and a pull refreshes', (tester) async {
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
          await h.pump(tester, overrides: [globalActionsRegistryProvider.overrideWith((ref) => registry)]);
          await h.openTab(tester, tab);
          final empty = find.byType(EmptyState);
          expect(empty, findsOneWidget);
          expect(find.descendant(of: empty, matching: find.text(message)), findsOneWidget);
          final scrollable = find.ancestor(of: empty, matching: find.byType(Scrollable)).first;
          expect(tester.widget<Scrollable>(scrollable).physics, isA<AlwaysScrollableScrollPhysics>());

          // Far enough to arm the indicator on this tall view.
          await tester.fling(find.text(message), const Offset(0, 1000), 1000);
          await h.settle(tester);
          expect(refreshes, 1, reason: 'the pull-to-refresh gesture reaches the global refresh');
        } finally {
          await h.unmount(tester);
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  });

  group('debug chart editor', () {
    List<String> titles() => [for (final c in h.container.read(dashboardChartsProvider)) c.title];

    void expectConfirm(WidgetTester tester, {required String title, required String content, required String confirm, Color? color}) {
      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      final alert = tester.widget<AlertDialog>(dialog);
      expect((alert.title! as Text).data, title);
      expect((alert.content! as Text).data, content);
      expect(find.descendant(of: dialog, matching: find.widgetWithText(TextButton, s.cancel)), findsOneWidget);
      final button = tester.widget<FilledButton>(find.descendant(of: dialog, matching: find.widgetWithText(FilledButton, confirm)));
      expect(button.style?.backgroundColor?.resolve({}), color);
    }

    Finder tile(String title) => find.widgetWithText(ExpansionTile, title);

    testWidgets('delete asks first: Cancel keeps the chart, the red Delete removes it', skip: !debugChartsEnabled, (tester) async {
      await h.seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'History');
        Future<void> tapDelete() async {
          await tester.tap(find.descendant(of: tile('Invested'), matching: find.byTooltip(s.delete)));
          await h.settle(tester);
        }

        await tapDelete();
        expectConfirm(tester, title: s.chartDeleteTitle, content: s.chartDeleteConfirm('Invested'), confirm: s.delete, color: Colors.red);
        await h.tapDialogButton(tester, s.cancel);
        expect(find.byType(AlertDialog), findsNothing);
        expect(titles(), contains('Invested'));

        await tapDelete();
        await h.tapDialogButton(tester, s.delete);
        expect(find.byType(AlertDialog), findsNothing);
        expect(titles(), isNot(contains('Invested')));
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('reset asks first: Cancel keeps the edits, Reset to Defaults restores the charts', skip: !debugChartsEnabled, (tester) async {
      await h.seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'History');
        final original = titles();
        final notifier = h.container.read(editableChartsProvider.notifier);
        notifier.delete(h.container.read(dashboardChartsProvider).firstWhere((c) => c.title == 'Invested').id);
        await h.settle(tester);

        Future<void> tapReset() async {
          await tester.tap(find.byTooltip(s.chartResetDefaults));
          await h.settle(tester);
        }

        await tapReset();
        expectConfirm(tester, title: s.chartResetConfirmTitle, content: s.chartResetConfirmBody, confirm: s.chartResetDefaults);
        await h.tapDialogButton(tester, s.cancel);
        expect(titles(), isNot(contains('Invested')));

        await tapReset();
        await h.tapDialogButton(tester, s.chartResetDefaults);
        expect(titles(), original);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('move down swaps a chart with the next one', skip: !debugChartsEnabled, (tester) async {
      await h.seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'History');
        final before = titles();
        final i = before.indexOf('Total Assets');
        await tester.tap(find.descendant(of: tile('Total Assets'), matching: find.byTooltip(s.moveDown)));
        await h.settle(tester);
        final after = titles();
        expect(after[i], before[i + 1]);
        expect(after[i + 1], 'Total Assets');
        expect(after.toSet(), before.toSet());
      } finally {
        await h.unmount(tester);
      }
    });
  });
}
