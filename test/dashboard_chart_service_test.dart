import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/dashboard_chart_service.dart';

void main() {
  late AppDatabase db;
  late DashboardChartService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = DashboardChartService(db);
  });

  tearDown(() async => await db.close());

  // Note: AppDatabase.onCreate seeds three default widgets ("Price Changes"
  // card at sortOrder 0, "Net Worth" at 1, "Invested vs Market Value" at 2).
  // Tests account for these seeded rows.

  group('Chart CRUD', () {
    test('create chart and retrieve', () async {
      final id = await service.create(
        title: 'My Chart',
        seriesJson: '[{"type":"account","id":1}]',
      );

      final charts = await service.getAll();
      final chart = charts.firstWhere((c) => c.id == id);
      expect(chart.title, 'My Chart');
      expect(chart.seriesJson, '[{"type":"account","id":1}]');
    });

    test('create multiple charts, verify sortOrder auto-increment', () async {
      // Database seeds 5 widgets with sortOrder 0..4 (price_changes + cash +
      // saving + portfolio + liquid_investments). Next created charts auto-
      // increment from there.
      final id1 = await service.create(title: 'A', seriesJson: '[]');
      final id2 = await service.create(title: 'B', seriesJson: '[]');
      final id3 = await service.create(title: 'C', seriesJson: '[]');

      final charts = await service.getAll();
      final a = charts.firstWhere((c) => c.id == id1);
      final b = charts.firstWhere((c) => c.id == id2);
      final c = charts.firstWhere((c) => c.id == id3);

      expect(a.sortOrder, 5);
      expect(b.sortOrder, 6);
      expect(c.sortOrder, 7);
    });

    test('update title', () async {
      final id = await service.create(title: 'Old Title', seriesJson: '[]');

      await service.update(id, title: 'New Title');

      final charts = await service.getAll();
      final chart = charts.firstWhere((c) => c.id == id);
      expect(chart.title, 'New Title');
    });

    test('update seriesJson', () async {
      final id = await service.create(
        title: 'Chart',
        seriesJson: '[{"type":"account","id":1}]',
      );

      await service.update(
        id,
        seriesJson: '[{"type":"asset_invested","id":2}]',
      );

      final charts = await service.getAll();
      final chart = charts.firstWhere((c) => c.id == id);
      expect(chart.seriesJson, '[{"type":"asset_invested","id":2}]');
    });

    test('delete chart', () async {
      final id = await service.create(title: 'Doomed', seriesJson: '[]');

      final beforeCount = (await service.getAll()).length;
      await service.delete(id);
      final afterCount = (await service.getAll()).length;

      expect(afterCount, beforeCount - 1);
    });

    test('seriesJson stored and retrieved correctly', () async {
      const json = '[{"type":"account","id":1},{"type":"asset_market","id":5}]';
      final id = await service.create(title: 'Complex', seriesJson: json);

      final charts = await service.getAll();
      final chart = charts.firstWhere((c) => c.id == id);
      expect(chart.seriesJson, json);
    });
  });

  group('watchAll', () {
    test('watchAll ordered by sortOrder', () async {
      // Seed widgets have sortOrder 0, 1, 2. Add more.
      await service.create(title: 'Third', seriesJson: '[]');
      await service.create(title: 'Fourth', seriesJson: '[]');

      final charts = await service.watchAll().first;
      for (var i = 1; i < charts.length; i++) {
        expect(charts[i].sortOrder, greaterThanOrEqualTo(charts[i - 1].sortOrder));
      }
    });

    test('watchAll reflects updates', () async {
      final id = await service.create(title: 'Watch Me', seriesJson: '[]');

      await service.update(id, title: 'Updated Watch');

      final charts = await service.watchAll().first;
      final chart = charts.firstWhere((c) => c.id == id);
      expect(chart.title, 'Updated Watch');
    });
  });
}
