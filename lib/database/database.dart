import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/logger.dart';
import 'tables.dart';

part 'database.g.dart';

final _log = getLogger('Database');

@DriftDatabase(tables: [
  Accounts,
  Categories,
  Transactions,
  AutoCategorizationRules,
  Assets,
  AssetEvents,
  AssetSnapshots,
  DepreciationSchedules,
  DepreciationEntries,
  Buffers,
  BufferTransactions,
  MarketPrices,
  ExchangeRates,
  RegisteredEvents,
  HealthReimbursements,
  AppConfigs,
  ImportConfigs,
  DashboardCharts,
  IncomeAdjustments,
  IncomeAdjustmentExpenses,
  Incomes,
  AssetCompositions,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Open a database at a specific file path.
  AppDatabase.withPath(String path) : super(_openAtPath(path));

  /// For testing: inject a custom executor.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 20;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          _log.info('Creating database schema (v$schemaVersion)');
          await m.createAll();
          await _createIndexes();
          await _seedAppConfig();
          await _seedDefaultCharts();
          _log.info('Database schema created and seeded');
        },
        onUpgrade: (Migrator m, int from, int to) async {
          _log.info('Upgrading database from v$from to v$to');
          if (from < 2) {
            await m.createTable(importConfigs);
          }
          if (from < 3) {
            await customStatement('ALTER TABLE accounts ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0');
            await customStatement('UPDATE accounts SET sort_order = id');
          }
          if (from < 4) {
            await _createIndexes();
          }
          if (from < 5) {
            await customStatement('ALTER TABLE assets ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0');
            await customStatement('UPDATE assets SET sort_order = id');
          }
          if (from < 6) {
            await customStatement("ALTER TABLE depreciation_schedules ADD COLUMN step_frequency TEXT NOT NULL DEFAULT 'monthly'");
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_depreciation_entries_schedule_date '
              'ON depreciation_entries(schedule_id, date ASC)',
            );
          }
          if (from < 7) {
            await customStatement('ALTER TABLE depreciation_schedules ADD COLUMN expense_date INTEGER NULL');
          }
          if (from < 8) {
            await customStatement('ALTER TABLE assets ADD COLUMN yahoo_ticker TEXT NULL');
          }
          if (from < 9) {
            await customStatement(
              "INSERT OR IGNORE INTO app_configs (key, value, description) "
              "VALUES ('ALPHA_VANTAGE_API_KEY', '', 'Alpha Vantage API key (free: alphavantage.co/support/#api-key)')"
            );
            await customStatement(
              "INSERT OR IGNORE INTO app_configs (key, value, description) "
              "VALUES ('MARKET_PRICE_PROVIDER', 'alphavantage', 'Market price data provider: alphavantage or yahoo')"
            );
          }
          if (from < 10) {
            await customStatement(
              "INSERT OR IGNORE INTO app_configs (key, value, description) "
              "VALUES ('GOOGLE_SHEETS_ID', '', 'Google Sheets spreadsheet ID for market price data')"
            );
          }
          if (from < 11) {
            await customStatement(
              "INSERT OR IGNORE INTO app_configs (key, value, description) "
              "VALUES ('PRICE_PROVIDER', 'investing', 'Price data provider: investing or googlesheets')"
            );
          }
          if (from < 12) {
            // Drop unused tables
            await customStatement('DROP TABLE IF EXISTS portfolio_models');
            await customStatement('DROP TABLE IF EXISTS portfolio_assets');
            await customStatement('DROP TABLE IF EXISTS portfolios');
            await customStatement('DROP TABLE IF EXISTS daily_snapshots');
            await customStatement('DROP TABLE IF EXISTS performance_summaries');
            await customStatement('DROP TABLE IF EXISTS calendar_days');
          }
          if (from < 13) {
            await m.createTable(dashboardCharts);
            await _seedDefaultCharts();
          }
          if (from < 14) {
            await m.createTable(incomeAdjustments);
            await m.createTable(incomeAdjustmentExpenses);
          }
          if (from < 15) {
            await m.createTable(incomes);
          }
          if (from < 16) {
            await customStatement(
              "INSERT OR IGNORE INTO app_configs (key, value, description) "
              "VALUES ('LOCALE', '', 'Display locale (empty = system default)')"
            );
          }
          if (from < 17) {
            await customStatement('ALTER TABLE dashboard_charts ADD COLUMN source_chart_ids TEXT');
          }
          if (from < 18) {
            await customStatement("ALTER TABLE dashboard_charts ADD COLUMN widget_type TEXT NOT NULL DEFAULT 'chart'");
            await customStatement('UPDATE dashboard_charts SET sort_order = sort_order + 1');
            await customStatement(
              "INSERT INTO dashboard_charts (title, widget_type, sort_order, series_json) "
              "VALUES ('Price Changes', 'price_changes', 0, '[]')"
            );
          }
          if (from < 19) {
            await m.createTable(assetCompositions);
          }
          if (from < 20) {
            // Add type column, migrate description→type, drop description
            await customStatement(
              "ALTER TABLE incomes ADD COLUMN type TEXT NOT NULL DEFAULT 'income'",
            );
            await customStatement(
              "UPDATE incomes SET type = 'refund' WHERE LOWER(description) LIKE '%rimborso%'",
            );
            await customStatement(
              'ALTER TABLE incomes DROP COLUMN description',
            );
          }
        },
      );

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transactions_account_date_id '
      'ON transactions(account_id, operation_date DESC, id DESC)',
    );
  }

  /// Seed default AppConfig values from MoneyHistory Graph row 3455.
  Future<void> _seedAppConfig() async {
    final defaults = {
      'RT_SMA_WINDOW': ('365', 'Moving average window for total savings (days)'),
      'EXPENSE_SMA_WINDOW': ('365', 'Moving average window for expenses (days)'),
      'RAL_WINDOW': ('365', 'Window for annualised salary computation (days)'),
      'VOL_WINDOW': ('7', 'Window for volatility computation (days)'),
      'NET_PL_SMA_WINDOW': ('1530', 'Moving average window for net P/L (days)'),
      'TAX_RATE': ('0.26', 'Default Italian capital gains tax rate'),
      'SWR': ('0.0275', 'Safe withdrawal rate'),
      'BASE_CURRENCY': ('EUR', 'Base currency for all calculations'),
      'DEFAULT_DEPRECIATION_METHOD': ('LINEAR', 'Default depreciation method'),
      'LOCALE': ('', 'Display locale (empty = system default)'),
    };

    for (final entry in defaults.entries) {
      await into(appConfigs).insert(AppConfigsCompanion.insert(
        key: entry.key,
        value: entry.value.$1,
        description: Value(entry.value.$2),
      ));
    }
  }

  /// Seed default dashboard widgets: price changes card + two charts.
  Future<void> _seedDefaultCharts() async {
    // Widget 0: Price Changes card
    await into(dashboardCharts).insert(DashboardChartsCompanion.insert(
      title: 'Price Changes',
      widgetType: const Value('price_changes'),
      sortOrder: const Value(0),
      seriesJson: '[]',
    ));

    // Gather all active accounts, assets, and adjustment schedules
    final accounts = await (select(this.accounts)..where((a) => a.isActive.equals(true))).get();
    final assets = await (select(this.assets)..where((a) => a.isActive.equals(true))).get();
    final schedules = await (select(depreciationSchedules)..where((s) => s.isActive.equals(true))).get();

    // Chart 1: Net Worth — all accounts + all assets (invested) + all adjustments
    final nwSeries = <Map<String, dynamic>>[
      for (final a in accounts) {'type': 'account', 'id': a.id},
      for (final a in assets) {'type': 'asset_invested', 'id': a.id},
      for (final s in schedules) {'type': 'adjustment', 'id': s.id},
    ];
    await into(dashboardCharts).insert(DashboardChartsCompanion.insert(
      title: 'Net Worth',
      sortOrder: const Value(1),
      seriesJson: _encodeJson(nwSeries),
    ));

    // Chart 2: Invested vs Market — all assets (invested + market)
    final invSeries = <Map<String, dynamic>>[
      for (final a in assets) ...[
        {'type': 'asset_invested', 'id': a.id},
        {'type': 'asset_market', 'id': a.id},
      ],
    ];
    await into(dashboardCharts).insert(DashboardChartsCompanion.insert(
      title: 'Invested vs Market Value',
      sortOrder: const Value(2),
      seriesJson: _encodeJson(invSeries),
    ));
  }

  static String _encodeJson(List<Map<String, dynamic>> list) {
    // Manual JSON encoding to avoid importing dart:convert in this file
    final items = list.map((m) {
      final type = m['type'] as String;
      final id = m['id'] as int;
      return '{"type":"$type","id":$id}';
    }).join(',');
    return '[$items]';
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbFolder = Directory(p.join(dir.path, 'FinanceCopilot'));
    if (!await dbFolder.exists()) {
      _log.info('Creating database directory: ${dbFolder.path}');
      await dbFolder.create(recursive: true);
    }
    final file = File(p.join(dbFolder.path, 'finance_copilot.db'));
    // ignore: avoid_print
    print('DB:  ${file.path}');
    _log.info('Opening database: ${file.path}');
    return NativeDatabase(file);
  });
}

LazyDatabase _openAtPath(String path) {
  return LazyDatabase(() async {
    final file = File(path);
    final parent = file.parent;
    if (!await parent.exists()) {
      _log.info('Creating database directory: ${parent.path}');
      await parent.create(recursive: true);
    }
    // ignore: avoid_print
    print('DB:  $path');
    _log.info('Opening database at path: $path');
    return NativeDatabase(file);
  });
}
