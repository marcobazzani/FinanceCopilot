import 'package:drift/native.dart';
import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/domain/asset_event_service.dart';
import 'package:finance_copilot/services/portfolio/portfolio_rebalance_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/pillars/rebalance_preview_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('rebalance preview omits target buys summary card', (tester) async {
    final draft = PortfolioRebalanceDraft(
      mode: PortfolioRebalanceMode.sellAndBuy,
      scope: const PortfolioRebalanceScope.currentPillar('pillar-1'),
      baseCurrency: 'EUR',
      rows: const [],
      unresolved: const [],
      availableCashBase: 1000,
      targetBuyBase: 980,
      executedBuyBase: 950,
      buyShortfallBase: 30,
      leftoverCashBase: 50,
      currentPortfolioValueBase: 5000,
      projectedPortfolioValueBase: 5950,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLocaleProvider.overrideWith((ref) => Stream.value('en')),
          portfolioRebalanceServiceProvider.overrideWithValue(_FakePortfolioRebalanceService(db, draft)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: RebalancePreviewDialog(pillarId: 'pillar-1'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Cash after sells'), findsOneWidget);
    expect(find.text('Executed buys'), findsOneWidget);
    expect(find.text('Estimated tax'), findsOneWidget);
    expect(find.text('Cash remaining'), findsOneWidget);
    expect(find.text('Target buys'), findsNothing);
  });
}

class _FakePortfolioRebalanceService extends PortfolioRebalanceService {
  final PortfolioRebalanceDraft draft;

  _FakePortfolioRebalanceService(super.db, this.draft);

  @override
  Stream<PortfolioRebalanceDraft> buildDraftStream({
    required PortfolioRebalanceScope scope,
    required PortfolioRebalanceMode mode,
    double contributionAmount = 0,
    DateTime? asOf,
  }) {
    return Stream.value(draft);
  }

  @override
  Future<List<int>> applyDraft(
    PortfolioRebalanceDraft draft,
    AssetEventService eventService, {
    DateTime? date,
  }) async {
    return const [];
  }
}
