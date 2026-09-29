// Rebalance preview.
//
// Privacy: the cash, buys, taxes, trade amounts and quantities are all
// position size and are masked; the labels and the before → after portfolio
// weights are shape and stay readable. Each assertion pair lives in the same
// test, so blurring the whole dialog would fail as surely as leaking it.
//
// Robustness: Apply cannot run twice while a draft is being applied, and a
// failing draft stream shows the error instead of spinning forever.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/asset_event_service.dart';
import 'package:finance_copilot/services/portfolio/portfolio_rebalance_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/pillars/rebalance_preview_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

PortfolioRebalanceDraftRow _row({
  required String name,
  required EventType type,
  required double baseAmount,
  required double quantity,
  required double tax,
  required double current,
  required double projected,
}) => PortfolioRebalanceDraftRow(
  pillarId: 'pillar-1',
  pillarName: 'Growth',
  assetId: 1,
  assetName: name,
  isin: null,
  type: type,
  amount: baseAmount,
  baseAmount: baseAmount,
  estimatedQuantity: quantity,
  price: 100,
  currency: 'EUR',
  fxRate: 1,
  estimatedTax: tax,
  currentBaseValue: current,
  projectedBaseValue: projected,
  notes: '',
);

final _draft = PortfolioRebalanceDraft(
  mode: PortfolioRebalanceMode.sellAndBuy,
  scope: const PortfolioRebalanceScope.currentPillar('pillar-1'),
  baseCurrency: 'EUR',
  rows: [
    _row(name: 'World ETF', type: EventType.buy, baseAmount: 1234.5, quantity: 12, tax: 45.6, current: 2000, projected: 3234.5),
    _row(name: 'Bond ETF', type: EventType.sell, baseAmount: 300, quantity: 3, tax: 10, current: 3000, projected: 2700),
  ],
  unresolved: const [],
  availableCashBase: 1000,
  targetBuyBase: 980,
  executedBuyBase: 950,
  buyShortfallBase: 30,
  leftoverCashBase: 50,
  currentPortfolioValueBase: 5000,
  projectedPortfolioValueBase: 6234.5,
);

class _FakeRebalanceService extends PortfolioRebalanceService {
  final Stream<PortfolioRebalanceDraft> Function() stream;
  final Completer<void> applying = Completer<void>();
  int applyCalls = 0;

  _FakeRebalanceService(super.db, this.stream);

  @override
  Stream<PortfolioRebalanceDraft> buildDraftStream({
    required PortfolioRebalanceScope scope,
    required PortfolioRebalanceMode mode,
    double contributionAmount = 0,
    DateTime? asOf,
  }) => stream();

  @override
  Future<List<int>> applyDraft(PortfolioRebalanceDraft draft, AssetEventService eventService, {DateTime? date}) async {
    applyCalls++;
    await applying.future;
    return const [];
  }
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  /// Opens the preview as the app does (a dialog over a screen) and returns
  /// the scope's container.
  Future<ProviderContainer> open(WidgetTester tester, _FakeRebalanceService service) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('en')),
          portfolioRebalanceServiceProvider.overrideWithValue(service),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => const RebalancePreviewDialog(pillarId: 'pillar-1'),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(tester.element(find.text('open')));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return container;
  }

  testWidgets('privacy masks cash, buys, taxes, trade amounts and quantities; labels and weights stay readable', (tester) async {
    final container = await open(tester, _FakeRebalanceService(db, () => Stream.value(_draft)));
    container.read(privacyModeProvider.notifier).state = true;
    await tester.pump();

    for (final value in ['1,000.00 EUR', '950.00 EUR', '55.60 EUR', '50.00 EUR']) {
      final metric = find.text(value);
      expect(metric, findsOneWidget, reason: 'summary metric $value');
      expect(masked(metric), isTrue, reason: 'summary metric $value is position size');
    }
    for (final label in ['Cash after sells', 'Executed buys', 'Estimated tax', 'Cash remaining']) {
      expect(masked(find.text(label)), isFalse, reason: 'the label "$label" stays readable');
    }

    // World ETF row: 1,234.50 EUR · Quantity: 12 · 40.00% → 51.88% · Estimated tax: 45.60 EUR
    for (final figure in ['1,234.50 EUR', '12', '45.60 EUR']) {
      final f = find.text(figure);
      expect(f, findsOneWidget, reason: 'row figure $figure is rendered on its own');
      expect(masked(f), isTrue, reason: 'row figure $figure is position size');
    }
    final weights = find.textContaining('40.00% → 51.88%');
    expect(weights, findsOneWidget);
    expect(masked(weights), isFalse, reason: 'portfolio weights are shape, not magnitude');
  });

  testWidgets('Apply cannot start a second time while the first apply is still running', (tester) async {
    final service = _FakeRebalanceService(db, () => Stream.value(_draft));
    await open(tester, service);

    Finder confirmButton() => find.descendant(
      of: find.ancestor(of: find.text('Apply draft?'), matching: find.byType(AlertDialog)),
      matching: find.widgetWithText(FilledButton, 'Apply draft'),
    );
    Future<void> applyOnce() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Apply draft').first);
      await tester.pump(const Duration(milliseconds: 300));
      if (confirmButton().evaluate().isEmpty) return;
      await tester.tap(confirmButton());
      await tester.pump(const Duration(milliseconds: 300));
    }

    await applyOnce();
    expect(service.applyCalls, 1);
    // The first apply is still in flight: a second tap must not start another.
    await applyOnce();
    expect(service.applyCalls, 1, reason: 'a second apply while the first runs would book the trades twice');

    service.applying.complete();
    await tester.pumpAndSettle();
    expect(find.byType(RebalancePreviewDialog), findsNothing, reason: 'the preview closes once the apply finished');
  });

  testWidgets('a failing draft stream shows the error instead of an endless spinner', (tester) async {
    await open(tester, _FakeRebalanceService(db, () => Stream<PortfolioRebalanceDraft>.error(StateError('no price for World ETF'))));
    await tester.pump();

    expect(find.textContaining('no price for World ETF'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
