import 'package:drift/drift.dart';

import '../database/database.dart';

class DashboardChartService {
  final AppDatabase _db;

  DashboardChartService(this._db);

  Stream<List<DashboardChart>> watchAll() {
    return (_db.select(_db.dashboardCharts)
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .watch();
  }

  Future<List<DashboardChart>> getAll() {
    return (_db.select(_db.dashboardCharts)
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .get();
  }

  Future<int> create({required String title, required String seriesJson, String? sourceChartIds}) async {
    final maxOrder = await _db.customSelect(
      'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next_order FROM dashboard_charts',
    ).getSingle();
    final nextOrder = maxOrder.read<int>('next_order');

    return _db.into(_db.dashboardCharts).insert(
      DashboardChartsCompanion.insert(
        title: title,
        sortOrder: Value(nextOrder),
        seriesJson: seriesJson,
        sourceChartIds: Value(sourceChartIds),
      ),
    );
  }

  Future<void> update(int id, {String? title, String? seriesJson, int? sortOrder, String? sourceChartIds}) {
    return (_db.update(_db.dashboardCharts)..where((c) => c.id.equals(id))).write(
      DashboardChartsCompanion(
        title: title != null ? Value(title) : const Value.absent(),
        seriesJson: seriesJson != null ? Value(seriesJson) : const Value.absent(),
        sortOrder: sortOrder != null ? Value(sortOrder) : const Value.absent(),
        sourceChartIds: sourceChartIds != null ? Value(sourceChartIds) : const Value.absent(),
      ),
    );
  }

  Future<void> delete(int id) {
    return (_db.delete(_db.dashboardCharts)..where((c) => c.id.equals(id))).go();
  }
}
