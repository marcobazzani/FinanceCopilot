// Rebalance preview: the Apply confirmation (title, message, buttons; Cancel
// books nothing and keeps the preview open, confirming books the draft once
// and closes it) and the buy-only contribution read strictly in the display
// locale (an empty field plans with no new cash). Pinned before the dialog
// moved onto showConfirmDialog and the field onto readOptionalNumber.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/domain/asset_event_service.dart';
import 'package:finance_copilot/services/portfolio/portfolio_rebalance_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/pillars/rebalance_preview_dialog.dart';

PortfolioRebalanceDraft _draft(PortfolioRebalanceMode mode, double contribution) => PortfolioRebalanceDraft(
  mode: mode,
  scope: const PortfolioRebalanceScope.currentPillar('pillar-1'),
  baseCurrency: 'EUR',
  rows: [
    PortfolioRebalanceDraftRow(
      pillarId: 'pillar-1',
      pillarName: 'Growth',
      assetId: 1,
      assetName: 'World ETF',
      isin: null,
      type: EventType.buy,
      amount: 100,
      baseAmount: 100,
      estimatedQuantity: 1,
      price: 100,
      currency: 'EUR',
      fxRate: 1,
      estimatedTax: 0,
      currentBaseValue: 1000,
      projectedBaseValue: 1100,
      notes: '',
    ),
  ],
  unresolved: const [],
  availableCashBase: 100 + contribution,
  targetBuyBase: 100,
  executedBuyBase: 100,
  buyShortfallBase: 0,
  leftoverCashBase: 0,
  currentPortfolioValueBase: 1000,
  projectedPortfolioValueBase: 1100,
);

class _FakeRebalanceService extends PortfolioRebalanceService {
  _FakeRebalanceService(super.db);

  final contributions = <double>[];
  int applied = 0;

  @override
  Stream<PortfolioRebalanceDraft> buildDraftStream({
    required PortfolioRebalanceScope scope,
    required PortfolioRebalanceMode mode,
    double contributionAmount = 0,
    DateTime? asOf,
  }) {
    if (mode == PortfolioRebalanceMode.buyOnly) contributions.add(contributionAmount);
    return Stream.value(_draft(mode, contributionAmount));
  }

  @override
  Future<List<int>> applyDraft(PortfolioRebalanceDraft draft, AssetEventService eventService, {DateTime? date}) async {
    applied++;
    return const [];
  }
}

void main() {
  const s = AppStrings.en;
  late AppDatabase db;
  late _FakeRebalanceService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = _FakeRebalanceService(db);
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  /// Opens the preview as the app does: a dialog over a screen. Completes
  /// with what the preview returned once closed.
  Future<List<bool?>> open(WidgetTester tester, {String locale = 'en_US'}) async {
    final results = <bool?>[];
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value(locale)),
          portfolioRebalanceServiceProvider.overrideWithValue(service),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async => results.add(
                  await showDialog<bool>(
                    context: context,
                    builder: (_) => const RebalancePreviewDialog(pillarId: 'pillar-1'),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open'));
    await settle(tester);
    return results;
  }

  Finder confirmDialog() => find.ancestor(of: find.text(s.rebalanceApplyConfirmTitle), matching: find.byType(AlertDialog));

  testWidgets('Apply asks first: Cancel books nothing and keeps the preview; confirming books once and closes it', (tester) async {
    final results = await open(tester);
    await tester.tap(find.widgetWithText(FilledButton, s.rebalanceApplyDraft));
    await settle(tester);

    expect(confirmDialog(), findsOneWidget);
    final alert = tester.widget<AlertDialog>(confirmDialog());
    expect((alert.title! as Text).data, s.rebalanceApplyConfirmTitle);
    expect((alert.content! as Text).data, s.rebalanceApplyConfirmBody);
    expect(find.descendant(of: confirmDialog(), matching: find.widgetWithText(TextButton, s.cancel)), findsOneWidget);
    final confirm = find.descendant(of: confirmDialog(), matching: find.widgetWithText(FilledButton, s.rebalanceApplyDraft));
    expect(tester.widget<FilledButton>(confirm).style, isNull, reason: 'the default colour');

    await tester.tap(find.descendant(of: confirmDialog(), matching: find.widgetWithText(TextButton, s.cancel)));
    await settle(tester);
    expect(confirmDialog(), findsNothing);
    expect(service.applied, 0);
    expect(find.byType(RebalancePreviewDialog), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, s.rebalanceApplyDraft)).onPressed,
      isNotNull,
      reason: 'Apply works again',
    );

    await tester.tap(find.widgetWithText(FilledButton, s.rebalanceApplyDraft));
    await settle(tester);
    await tester.tap(find.descendant(of: confirmDialog(), matching: find.widgetWithText(FilledButton, s.rebalanceApplyDraft)));
    await settle(tester);
    expect(service.applied, 1);
    expect(find.byType(RebalancePreviewDialog), findsNothing);
    expect(results, [true]);
  });

  group('buy-only contribution', () {
    Finder field() => find.widgetWithText(TextField, s.rebalanceContribution);

    Future<void> buyOnly(WidgetTester tester) async {
      await tester.tap(find.text(s.rebalanceBuyOnly));
      await settle(tester);
    }

    testWidgets('English: "1,250.5" is 1250.5, "1,5" is flagged and plans nothing, empty plans with 0', (tester) async {
      await open(tester);
      await buyOnly(tester);
      expect(service.contributions, [0], reason: 'an empty field plans with no new cash');

      await tester.enterText(field(), '1,250.5');
      await settle(tester);
      expect(service.contributions.last, 1250.5);
      expect(find.text(s.invalidNumber), findsNothing);

      final requested = service.contributions.length;
      await tester.enterText(field(), '1,5');
      await settle(tester);
      expect(find.text(s.invalidNumber), findsOneWidget);
      expect(service.contributions.length, requested, reason: 'nothing is planned from an unreadable contribution');

      await tester.enterText(field(), '');
      await settle(tester);
      expect(find.text(s.invalidNumber), findsNothing);
      expect(service.contributions.last, 0);
    });
  });
}
