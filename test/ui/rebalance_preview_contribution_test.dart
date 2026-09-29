// Rebalance preview, buy-only mode: a contribution the active locale cannot
// read is flagged on the field and no draft is computed from it. Strict
// parsing returns null for such text, and the dialog used to turn that into
// a 0 contribution — showing (and letting the user apply) a plan for money
// they did not type.
import 'package:drift/native.dart';
import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/asset_event_service.dart';
import 'package:finance_copilot/services/portfolio/portfolio_rebalance_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/pillars/rebalance_preview_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
      amount: contribution,
      baseAmount: contribution,
      estimatedQuantity: 1,
      price: 100,
      currency: 'EUR',
      fxRate: 1,
      estimatedTax: 0,
      currentBaseValue: 1000,
      projectedBaseValue: 1000 + contribution,
      notes: '',
    ),
  ],
  unresolved: const [],
  availableCashBase: contribution,
  targetBuyBase: contribution,
  executedBuyBase: contribution,
  buyShortfallBase: 0,
  leftoverCashBase: 0,
  currentPortfolioValueBase: 1000,
  projectedPortfolioValueBase: 1000 + contribution,
);

/// Records every contribution a draft is requested for.
class _RecordingRebalanceService extends PortfolioRebalanceService {
  _RecordingRebalanceService(super.db);

  final contributions = <double>[];

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
  Future<List<int>> applyDraft(PortfolioRebalanceDraft draft, AssetEventService eventService, {DateTime? date}) async => const [];
}

void main() {
  late AppDatabase db;
  late _RecordingRebalanceService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = _RecordingRebalanceService(db);
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpDialog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLocaleProvider.overrideWith((ref) => Stream.value('it_IT')),
          portfolioRebalanceServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(
          home: Scaffold(body: RebalancePreviewDialog(pillarId: 'pillar-1')),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Buy only'));
    await settle(tester);
  }

  Finder applyButton() => find.widgetWithText(FilledButton, 'Apply draft');

  testWidgets('a contribution the locale reads is used for the draft', (tester) async {
    await pumpDialog(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Contribution'), '1.250,5');
    await settle(tester);

    expect(service.contributions.last, 1250.5);
    expect(find.text('Invalid number'), findsNothing);
    expect(tester.widget<FilledButton>(applyButton()).onPressed, isNotNull);
  });

  testWidgets('an unreadable contribution is flagged and no draft is computed from it', (tester) async {
    await pumpDialog(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Contribution'), '500');
    await settle(tester);
    expect(service.contributions.last, 500);
    final requested = service.contributions.length;

    // "1.5" is not a number in it_IT (the dot groups thousands).
    await tester.enterText(find.widgetWithText(TextField, 'Contribution'), '1.5');
    await settle(tester);

    expect(find.text('Invalid number'), findsOneWidget);
    expect(service.contributions.length, requested, reason: 'no draft for a contribution the user did not type (it used to be 0)');
    expect(applyButton(), findsNothing, reason: 'nothing to apply while the contribution is invalid');

    // Correcting the text brings the draft back.
    await tester.enterText(find.widgetWithText(TextField, 'Contribution'), '1,5');
    await settle(tester);
    expect(find.text('Invalid number'), findsNothing);
    expect(service.contributions.last, 1.5);
    expect(applyButton(), findsOneWidget);
  });

  testWidgets('an empty contribution still plans with no new cash', (tester) async {
    await pumpDialog(tester);
    expect(service.contributions, [0]);
    expect(find.text('Invalid number'), findsNothing);
  });
}
