import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/default_charts_loader.dart';

Account _account(int id) => Account(
      id: id,
      name: 'Account $id',
      type: AccountType.bank,
      currency: 'EUR',
      institution: '',
      isActive: true,
      includeInNetWorth: true,
      sortOrder: 0,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

Asset _asset({
  required int id,
  required InstrumentType type,
}) =>
    Asset(
      id: id,
      intermediaryId: 1,
      name: 'Asset $id',
      assetType: AssetType.stockEtf,
      instrumentType: type,
      assetClass: AssetClass.equity,
      assetGroup: '',
      valuationMethod: ValuationMethod.marketPrice,
      currency: 'EUR',
      isActive: true,
      includeInNetWorth: true,
      sortOrder: 0,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

ExtraordinaryEvent _event({
  required int id,
  required EventDirection direction,
  bool isEphemeral = false,
}) =>
    ExtraordinaryEvent(
      id: id,
      name: 'Event $id',
      direction: direction,
      treatment: EventTreatment.instant,
      totalAmount: 100,
      currency: 'EUR',
      eventDate: DateTime(2024, 6, 1),
      isActive: true,
      isEphemeral: isEphemeral,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

void main() {
  const loader = DefaultChartsLoader();

  group('DefaultChartsLoader.parse — category expansion', () {
    test('all_accounts expands to one entry per active account', () {
      final result = loader.parse(
        '{"version":1,"charts":[{"role":"cash","title":"Cash","categories":["all_accounts"]}]}',
        activeAccounts: [_account(1), _account(2)],
        activeAssets: const [],
        activeEvents: const [],
      );
      expect(result, hasLength(1));
      expect(result.first.widgetType, 'cash');
      expect(result.first.title, 'Cash');
      expect(result.first.seriesJson,
          '[{"type":"account","id":1},{"type":"account","id":2}]');
    });

    test('all_market_liquid excludes illiquid types', () {
      final result = loader.parse(
        '{"version":1,"charts":[{"role":"liquid_investments","title":"L","categories":["all_market_liquid"]}]}',
        activeAccounts: const [],
        activeAssets: [
          _asset(id: 10, type: InstrumentType.etf),
          _asset(id: 11, type: InstrumentType.pension),
          _asset(id: 12, type: InstrumentType.stock),
        ],
        activeEvents: const [],
      );
      expect(result.first.seriesJson,
          '[{"type":"asset_market","id":10},{"type":"asset_market","id":12}]');
    });

    test('ephemeral_inflow_value with sign:-1 emits sign field', () {
      final result = loader.parse(
        '{"version":1,"charts":[{"role":"cash","title":"Cash","categories":[{"category":"ephemeral_inflow_value","sign":-1}]}]}',
        activeAccounts: const [],
        activeAssets: const [],
        activeEvents: [
          _event(id: 5, direction: EventDirection.inflow, isEphemeral: true),
        ],
      );
      expect(result.first.seriesJson,
          '[{"type":"ephemeral_inflow_value","id":5,"sign":-1}]');
    });

    test('non_ephemeral_inflow excludes ephemeral events', () {
      final result = loader.parse(
        '{"version":1,"charts":[{"role":"saving","title":"Saving","categories":["non_ephemeral_inflow_value"]}]}',
        activeAccounts: const [],
        activeAssets: const [],
        activeEvents: [
          _event(id: 5, direction: EventDirection.inflow, isEphemeral: true),
          _event(id: 6, direction: EventDirection.inflow, isEphemeral: false),
        ],
      );
      expect(result.first.seriesJson,
          '[{"type":"income_adj_value","id":6}]');
    });

    test('widgetType=price_changes preserved with empty categories', () {
      final result = loader.parse(
        '{"version":1,"charts":[{"widgetType":"price_changes","title":"PC"}]}',
        activeAccounts: const [],
        activeAssets: const [],
        activeEvents: const [],
      );
      expect(result.first.widgetType, 'price_changes');
      expect(result.first.seriesJson, '[]');
    });

    test('combined chart with title-list sourceChartIds preserves it raw', () {
      // Loader stores the JSON as-is in DashboardChart.sourceChartIds; the
      // resolver decodes at render time.
      final result = loader.parse(
        '{"version":1,"charts":[{"widgetType":"chart","title":"Totals","sourceChartIds":["Cash","Saving"]}]}',
        activeAccounts: const [],
        activeAssets: const [],
        activeEvents: const [],
      );
      // The raw value should be the JSON-encoded list of titles.
      expect(result.first.sourceChartIds, '["Cash","Saving"]');
    });

    test('combined chart with sourceChartIds:* preserves marker', () {
      final result = loader.parse(
        '{"version":1,"charts":[{"widgetType":"chart","title":"Totals","sourceChartIds":"*"}]}',
        activeAccounts: const [],
        activeAssets: const [],
        activeEvents: const [],
      );
      expect(result.first.sourceChartIds, '*');
    });

    test('sortOrder reflects JSON order', () {
      final result = loader.parse(
        '{"version":1,"charts":['
        '{"widgetType":"price_changes","title":"PC"},'
        '{"role":"cash","title":"Cash","categories":["all_accounts"]},'
        '{"role":"saving","title":"Saving","categories":["all_accounts"]}'
        ']}',
        activeAccounts: [_account(1)],
        activeAssets: const [],
        activeEvents: const [],
      );
      expect(result.map((c) => c.sortOrder).toList(), [0, 1, 2]);
    });
  });
}
