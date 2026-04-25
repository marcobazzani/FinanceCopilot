import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/default_charts_exporter.dart';
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

DashboardChart _chart({
  required int id,
  required String widgetType,
  required String title,
  required String seriesJson,
  String? sourceChartIds,
  int sortOrder = 0,
}) =>
    DashboardChart(
      id: id,
      title: title,
      widgetType: widgetType,
      sortOrder: sortOrder,
      seriesJson: seriesJson,
      sourceChartIds: sourceChartIds,
      createdAt: DateTime(2024, 1, 1),
    );

void main() {
  final exporter = DefaultChartsExporter();
  const loader = DefaultChartsLoader();

  group('DefaultChartsExporter — clean category coverage', () {
    test('emits category names when chart matches full category set', () {
      final accounts = [_account(1), _account(2)];
      final json = exporter.export(
        charts: [
          _chart(
            id: 1,
            widgetType: 'cash',
            title: 'Cash',
            seriesJson: '[{"type":"account","id":1},{"type":"account","id":2}]',
          ),
        ],
        activeAccounts: accounts,
        activeAssets: const [],
        activeEvents: const [],
      );
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final charts = (decoded['charts'] as List).cast<Map<String, dynamic>>();
      expect(charts.first['role'], 'cash');
      expect(charts.first['categories'], contains('all_accounts'));
    });

    test('preserves sign on negative-signed entries', () {
      final json = exporter.export(
        charts: [
          _chart(
            id: 1,
            widgetType: 'cash',
            title: 'Cash',
            seriesJson: '[{"type":"ephemeral_inflow_value","id":5,"sign":-1}]',
          ),
        ],
        activeAccounts: const [],
        activeAssets: const [],
        activeEvents: [
          _event(id: 5, direction: EventDirection.inflow, isEphemeral: true),
        ],
      );
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final cats = (decoded['charts'] as List).first['categories'] as List;
      expect(cats.first, isA<Map>());
      expect((cats.first as Map)['category'], 'ephemeral_inflow_value');
      expect((cats.first as Map)['sign'], -1);
    });

    test('rejects partial category selection', () {
      final accounts = [_account(1), _account(2), _account(3)];
      expect(
        () => exporter.export(
          charts: [
            _chart(
              id: 1,
              widgetType: 'cash',
              title: 'Cash',
              // Only 2 of 3 accounts ticked — partial.
              seriesJson: '[{"type":"account","id":1},{"type":"account","id":2}]',
            ),
          ],
          activeAccounts: accounts,
          activeAssets: const [],
          activeEvents: const [],
        ),
        throwsA(isA<PartialCategoryExportException>()),
      );
    });

    test('combined chart with int-id sources emits "*" when covering all', () {
      final chartA = _chart(id: -1, widgetType: 'cash', title: 'Cash', seriesJson: '[]');
      final chartB = _chart(id: -2, widgetType: 'saving', title: 'Saving', seriesJson: '[]');
      final combined = _chart(
        id: -10,
        widgetType: 'chart',
        title: 'Totals',
        seriesJson: '[]',
        sourceChartIds: '[-1,-2]', // every bucket-2 chart present
      );
      final json = exporter.export(
        charts: [chartA, chartB, combined],
        activeAccounts: const [],
        activeAssets: const [],
        activeEvents: const [],
      );
      final list = (jsonDecode(json) as Map<String, dynamic>)['charts'] as List;
      final totals = list.firstWhere((m) => m['title'] == 'Totals') as Map<String, dynamic>;
      expect(totals['sourceChartIds'], '*');
    });

    test('combined chart with int-id sources emits title list when partial', () {
      final chartA = _chart(id: -1, widgetType: 'cash', title: 'Cash', seriesJson: '[]');
      final chartB = _chart(id: -2, widgetType: 'saving', title: 'Saving', seriesJson: '[]');
      final chartC = _chart(id: -3, widgetType: 'chart', title: 'Custom', seriesJson: '[]');
      final combined = _chart(
        id: -10,
        widgetType: 'chart',
        title: 'Totals',
        seriesJson: '[]',
        sourceChartIds: '[-1,-2]', // only Cash + Saving, not Custom
      );
      final json = exporter.export(
        charts: [chartA, chartB, chartC, combined],
        activeAccounts: const [],
        activeAssets: const [],
        activeEvents: const [],
      );
      final list = (jsonDecode(json) as Map<String, dynamic>)['charts'] as List;
      final totals = list.firstWhere((m) => m['title'] == 'Totals') as Map<String, dynamic>;
      // Title list, not int ids.
      expect(totals['sourceChartIds'], '["Cash","Saving"]');
    });

    test('price_changes and combined-overlay charts skip categories', () {
      final json = exporter.export(
        charts: [
          _chart(id: 1, widgetType: 'price_changes', title: 'PC', seriesJson: '[]'),
          _chart(
            id: 2,
            widgetType: 'chart',
            title: 'Totals',
            seriesJson: '[]',
            sourceChartIds: '*',
          ),
        ],
        activeAccounts: const [],
        activeAssets: const [],
        activeEvents: const [],
      );
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final list = (decoded['charts'] as List).cast<Map<String, dynamic>>();
      expect(list[0]['widgetType'], 'price_changes');
      expect(list[0].containsKey('categories'), isFalse);
      expect(list[1]['sourceChartIds'], '*');
      expect(list[1].containsKey('categories'), isFalse);
    });
  });

  group('Round-trip', () {
    test('loader → exporter → loader yields the same series', () {
      final accounts = [_account(1), _account(2)];
      final original = loader.parse(
        '{"version":1,"charts":[{"role":"cash","title":"Cash","categories":["all_accounts"]}]}',
        activeAccounts: accounts,
        activeAssets: const [],
        activeEvents: const [],
      );
      final json = exporter.export(
        charts: original,
        activeAccounts: accounts,
        activeAssets: const [],
        activeEvents: const [],
      );
      final round = loader.parse(
        json,
        activeAccounts: accounts,
        activeAssets: const [],
        activeEvents: const [],
      );
      expect(round.first.seriesJson, original.first.seriesJson);
      expect(round.first.widgetType, original.first.widgetType);
      expect(round.first.title, original.first.title);
    });
  });
}
