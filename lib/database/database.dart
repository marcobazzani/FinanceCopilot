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
  Portfolios,
  PortfolioAssets,
  PortfolioModels,
  DailySnapshots,
  DepreciationSchedules,
  DepreciationEntries,
  Buffers,
  BufferTransactions,
  MarketPrices,
  ExchangeRates,
  RegisteredEvents,
  HealthReimbursements,
  PerformanceSummaries,
  CalendarDays,
  AppConfigs,
  ImportConfigs,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For testing: inject a custom executor.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          _log.info('Creating database schema (v$schemaVersion)');
          await m.createAll();
          await _createIndexes();
          await _seedAppConfig();
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
    };

    for (final entry in defaults.entries) {
      await into(appConfigs).insert(AppConfigsCompanion.insert(
        key: entry.key,
        value: entry.value.$1,
        description: Value(entry.value.$2),
      ));
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbFolder = Directory(p.join(dir.path, 'AssetManager'));
    if (!await dbFolder.exists()) {
      _log.info('Creating database directory: ${dbFolder.path}');
      await dbFolder.create(recursive: true);
    }
    final file = File(p.join(dbFolder.path, 'asset_manager.db'));
    _log.info('Opening database: ${file.path}');
    return NativeDatabase.createInBackground(file);
  });
}
