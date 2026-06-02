import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import '../utils/logger.dart';
import 'db_file_name.dart';
import 'tables.dart';

part 'database.g.dart';

final _log = getLogger('Database');

/// Thrown when [AppDatabase.mergeFromAttachedDb] is asked to merge a backup
/// whose drift schema version does not match this app's. A column-intersection
/// copy across schema versions would silently drop or mis-fill columns, so the
/// merge is refused outright.
class SchemaVersionMismatchException implements Exception {
  const SchemaVersionMismatchException({
    required this.localVersion,
    required this.remoteVersion,
  });

  /// This app's drift schema version.
  final int localVersion;

  /// The backup file's drift schema version.
  final int remoteVersion;

  @override
  String toString() =>
      'SchemaVersionMismatchException(local: $localVersion, '
      'remote: $remoteVersion)';
}

@DriftDatabase(
  tables: [
    Intermediaries,
    Accounts,
    Categories,
    Transactions,
    AutoCategorizationRules,
    Assets,
    AssetEvents,
    AssetSnapshots,
    Buffers,
    BufferTransactions,
    MarketPrices,
    ExchangeRates,
    HealthReimbursements,
    AppConfigs,
    ImportConfigs,
    Incomes,
    AssetCompositions,
    ExtraordinaryEvents,
    ExtraordinaryEventEntries,
    PortfolioModels,
    PortfolioModelItems,
    Pillars,
    PillarAssets,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Open a database at a specific file path.
  AppDatabase.withPath(String path) : super(_openAtPath(path));

  /// For testing: inject a custom executor.
  AppDatabase.forTesting(super.e);

  /// Returns the DB file reference without opening or creating it.
  static Future<File> dbFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, dbFileName));
  }

  @override
  int get schemaVersion => 43;

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
      if (from < 8) {
        await customStatement('ALTER TABLE assets ADD COLUMN yahoo_ticker TEXT NULL');
      }
      if (from < 9) {
        await customStatement(
          "INSERT OR IGNORE INTO app_configs (key, value, description) "
          "VALUES ('ALPHA_VANTAGE_API_KEY', '', 'Alpha Vantage API key (free: alphavantage.co/support/#api-key)')",
        );
        await customStatement(
          "INSERT OR IGNORE INTO app_configs (key, value, description) "
          "VALUES ('MARKET_PRICE_PROVIDER', 'alphavantage', 'Market price data provider: alphavantage or yahoo')",
        );
      }
      if (from < 10) {
        await customStatement(
          "INSERT OR IGNORE INTO app_configs (key, value, description) "
          "VALUES ('GOOGLE_SHEETS_ID', '', 'Google Sheets spreadsheet ID for market price data')",
        );
      }
      if (from < 11) {
        await customStatement(
          "INSERT OR IGNORE INTO app_configs (key, value, description) "
          "VALUES ('PRICE_PROVIDER', 'investing', 'Price data provider: investing or googlesheets')",
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
        // dashboardCharts table was created here historically; v32
        // drops it again (chart config now lives in JSON asset).
      }
      if (from < 14) {
        // Legacy tables (income_adjustments, income_adjustment_expenses)
        // were introduced here and dropped in v28. Users upgrading from
        // pre-v14 straight to >=v28 never had data in them — we skip
        // creating them since the schema no longer defines the classes.
      }
      if (from < 15) {
        await m.createTable(incomes);
      }
      if (from < 16) {
        await customStatement(
          "INSERT OR IGNORE INTO app_configs (key, value, description) "
          "VALUES ('LOCALE', '', 'Display locale (empty = system default)')",
        );
      }
      if (from < 17) {
        await customStatement('ALTER TABLE dashboard_charts ADD COLUMN source_chart_ids TEXT');
      }
      if (from < 18) {
        if (!await _hasColumn('dashboard_charts', 'widget_type')) {
          await customStatement("ALTER TABLE dashboard_charts ADD COLUMN widget_type TEXT NOT NULL DEFAULT 'chart'");
          await customStatement('UPDATE dashboard_charts SET sort_order = sort_order + 1');
          await customStatement(
            "INSERT INTO dashboard_charts (title, widget_type, sort_order, series_json) "
            "VALUES ('Price Changes', 'price_changes', 0, '[]')",
          );
        }
      }
      if (from < 19) {
        if (!await _tableExists('asset_compositions')) {
          await m.createTable(assetCompositions);
        }
      }
      if (from < 20) {
        if (!await _hasColumn('incomes', 'type')) {
          await customStatement(
            "ALTER TABLE incomes ADD COLUMN type TEXT NOT NULL DEFAULT 'income'",
          );
          await customStatement(
            "UPDATE incomes SET type = 'refund' WHERE LOWER(description) LIKE '%rimborso%'",
          );
        }
        if (await _hasColumn('incomes', 'description')) {
          await customStatement(
            'ALTER TABLE incomes DROP COLUMN description',
          );
        }
      }
      if (from < 21) {
        if (!await _hasColumn('assets', 'instrument_type')) {
          await customStatement(
            "ALTER TABLE assets ADD COLUMN instrument_type TEXT NOT NULL DEFAULT 'etf'",
          );
          await customStatement(
            "ALTER TABLE assets ADD COLUMN asset_class TEXT NOT NULL DEFAULT 'equity'",
          );
          const migration = {
            'stock': ('stock', 'equity'),
            'stockEtf': ('etf', 'equity'),
            'bondEtf': ('etf', 'fixedIncome'),
            'commEtf': ('etf', 'commodities'),
            'goldEtc': ('etc', 'commodities'),
            'monEtf': ('etf', 'moneyMarket'),
            'crypto': ('crypto', 'crypto'),
            'cash': ('cash', 'cash'),
            'pension': ('pension', 'multiAsset'),
            'deposit': ('deposit', 'cash'),
            'realEstate': ('realEstate', 'realEstate'),
            'alternative': ('alternative', 'alternative'),
            'liability': ('liability', 'fixedIncome'),
          };
          for (final entry in migration.entries) {
            await customStatement(
              "UPDATE assets SET instrument_type = '${entry.value.$1}', "
              "asset_class = '${entry.value.$2}' "
              "WHERE asset_type = '${entry.key}'",
            );
          }
        }
      }
      if (from < 22) {
        if (!await _tableExists('intermediaries')) {
          await customStatement(
            'CREATE TABLE intermediaries ('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'name TEXT NOT NULL, '
            'sort_order INTEGER NOT NULL DEFAULT 0, '
            "created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "
            "updated_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER))"
            ')',
          );
        }
        if (!await _hasColumn('accounts', 'intermediary_id')) {
          await customStatement(
            'ALTER TABLE accounts ADD COLUMN intermediary_id INTEGER REFERENCES intermediaries(id)',
          );
        }
        if (!await _hasColumn('assets', 'intermediary_id')) {
          await customStatement(
            'ALTER TABLE assets ADD COLUMN intermediary_id INTEGER REFERENCES intermediaries(id)',
          );
        }
        // Create intermediaries from existing account institutions
        await customStatement(
          "INSERT OR IGNORE INTO intermediaries (name) "
          "SELECT DISTINCT institution FROM accounts "
          "WHERE institution != '' AND institution IS NOT NULL",
        );
        // Link accounts to their intermediary
        await customStatement(
          'UPDATE accounts SET intermediary_id = ('
          '  SELECT id FROM intermediaries WHERE intermediaries.name = accounts.institution'
          ") WHERE institution != '' AND institution IS NOT NULL AND intermediary_id IS NULL",
        );
        _log.info('Migration 22: intermediaries table created, accounts linked');
      }
      if (from < 23) {
        // Drop unused event types — only buy/sell/revalue are supported
        final deleted = await customUpdate(
          "DELETE FROM asset_events WHERE type NOT IN ('buy', 'sell', 'revalue')",
          updates: {assetEvents},
        );
        _log.info('Migration 23: removed $deleted legacy event type records');
      }
      if (from < 24) {
        // Add value_date to asset_events and incomes (default = date)
        if (!await _hasColumn('asset_events', 'value_date')) {
          await customStatement(
            'ALTER TABLE asset_events ADD COLUMN value_date INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement('UPDATE asset_events SET value_date = date');
        }
        if (!await _hasColumn('incomes', 'value_date')) {
          await customStatement(
            'ALTER TABLE incomes ADD COLUMN value_date INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement('UPDATE incomes SET value_date = date');
        }
        _log.info('Migration 24: added value_date to asset_events and incomes');
      }
      if (from < 25) {
        await _createIndexes();
        await customStatement(
          "INSERT OR REPLACE INTO app_configs (key, value) "
          "VALUES ('PENDING_BALANCE_RECALC', '1')",
        );
        _log.info('Migration 25: added indexes, flagged balance recalculation');
      }
      if (from < 26) {
        // Drop ghost columns left over from removed bank-import feature.
        // These columns no longer exist in the schema (tables.dart) but
        // persist in databases created before they were removed.
        if (await _hasColumn('accounts', 'bank_account_id')) {
          await customStatement('ALTER TABLE accounts DROP COLUMN bank_account_id');
        }
        if (await _hasColumn('accounts', 'bank_session_id')) {
          await customStatement('ALTER TABLE accounts DROP COLUMN bank_session_id');
        }
        _log.info('Migration 26: dropped ghost columns from accounts');
      }
      if (from < 27) {
        // Unify DepreciationSchedules + IncomeAdjustments into ExtraordinaryEvents.
        // Phase 1 migration: create new tables + backfill. Old tables kept
        // read-only until v28 cleanup.
        await m.createTable(extraordinaryEvents);
        await m.createTable(extraordinaryEventEntries);

        // Backfill CAPEX schedules → outflow/spread events (preserve IDs).
        await customStatement('''
              INSERT INTO extraordinary_events
                (id, name, direction, treatment, total_amount, currency, event_date,
                 transaction_id, step_frequency, spread_start, spread_end, buffer_id,
                 is_active, created_at, updated_at)
              SELECT
                id, asset_name, 'outflow', 'spread', total_amount, currency,
                COALESCE(expense_date, start_date),
                transaction_id, step_frequency, start_date, end_date, buffer_id,
                is_active, created_at, updated_at
              FROM depreciation_schedules
            ''');

        // Backfill CAPEX entries → scheduled entries (negate amount).
        await customStatement('''
              INSERT INTO extraordinary_event_entries
                (event_id, date, amount, entry_kind, cumulative, remaining)
              SELECT schedule_id, date, -amount, 'scheduled', cumulative, remaining
              FROM depreciation_entries
            ''');

        // Backfill IncomeAdjustments → inflow/instant events (fresh IDs).
        final oldIas = await customSelect(
          'SELECT id, name, total_amount, currency, income_date, is_active, created_at '
          'FROM income_adjustments',
        ).get();
        final idMap = <int, int>{};
        for (final row in oldIas) {
          final oldId = row.read<int>('id');
          final insertResult = await customInsert(
            'INSERT INTO extraordinary_events '
            '(name, direction, treatment, total_amount, currency, event_date, '
            ' is_active, created_at, updated_at) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
            variables: [
              Variable.withString(row.read<String>('name')),
              Variable.withString('inflow'),
              Variable.withString('instant'),
              Variable.withReal(row.read<double>('total_amount')),
              Variable.withString(row.read<String>('currency')),
              Variable.withDateTime(row.read<DateTime>('income_date')),
              Variable.withBool(row.read<bool>('is_active')),
              Variable.withDateTime(row.read<DateTime>('created_at')),
              Variable.withDateTime(row.read<DateTime>('created_at')),
            ],
          );
          idMap[oldId] = insertResult;
        }

        // Backfill IncomeAdjustmentExpenses → manual entries (positive amount).
        for (final entry in idMap.entries) {
          await customStatement(
            'INSERT INTO extraordinary_event_entries '
            '(event_id, date, amount, entry_kind, description, created_at) '
            'SELECT ?, date, amount, ?, description, created_at '
            'FROM income_adjustment_expenses WHERE adjustment_id = ?',
            [
              entry.value,
              'manual',
              entry.key,
            ],
          );
        }

        // NB: zero-amount inflow events (e.g. credit-line buckets)
        // are left as inflow/instant. Reclassifying them to outflow would
        // shift their chart contribution from the incomeAdj series
        // (excluded from the Cash line) into the adjustment series
        // (included in Cash), producing a spurious Cash-line jump.

        _log.info('Migration 27: created ExtraordinaryEvents, backfilled ${idMap.length + 1} events');
      }
      if (from < 28) {
        // Cleanup: drop the legacy tables whose data was backfilled in v27,
        // rename buffers.linked_depreciation_id -> linked_event_id (the
        // stored IDs match since v27 preserved CAPEX schedule IDs), and
        // drop the long-unused transactions.depreciation_id column.
        await customStatement('PRAGMA foreign_keys = OFF');
        try {
          // Drop child tables before parents (FK order).
          await customStatement('DROP TABLE IF EXISTS depreciation_entries');
          await customStatement('DROP TABLE IF EXISTS depreciation_schedules');
          await customStatement('DROP TABLE IF EXISTS income_adjustment_expenses');
          await customStatement('DROP TABLE IF EXISTS income_adjustments');

          // Rename Buffers FK column. SQLite ≥3.25 supports RENAME COLUMN.
          if (await _hasColumn('buffers', 'linked_depreciation_id')) {
            await customStatement('ALTER TABLE buffers RENAME COLUMN linked_depreciation_id TO linked_event_id');
          }

          // Drop the unused Transactions.depreciation_id column.
          if (await _hasColumn('transactions', 'depreciation_id')) {
            await customStatement('ALTER TABLE transactions DROP COLUMN depreciation_id');
          }
        } finally {
          await customStatement('PRAGMA foreign_keys = ON');
        }
        _log.info(
          'Migration 28: dropped legacy CAPEX/IncomeAdj tables, '
          'renamed buffers FK, dropped transactions.depreciation_id',
        );
      }
      if (from < 29) {
        // Every asset must now have an intermediary. Any asset currently
        // without one is moved to a "Default" intermediary created on the
        // fly (or reused if it already exists).
        final orphanCount = (await customSelect(
          'SELECT COUNT(*) AS c FROM assets WHERE intermediary_id IS NULL',
        ).getSingle()).read<int>('c');

        if (orphanCount > 0) {
          // Find or create the Default intermediary.
          final existing = await customSelect(
            "SELECT id FROM intermediaries WHERE name = 'Default' LIMIT 1",
          ).getSingleOrNull();
          int defaultId;
          if (existing != null) {
            defaultId = existing.read<int>('id');
          } else {
            await customStatement(
              "INSERT INTO intermediaries (name) VALUES ('Default')",
            );
            defaultId = (await customSelect(
              "SELECT id FROM intermediaries WHERE name = 'Default' LIMIT 1",
            ).getSingle()).read<int>('id');
          }
          await customStatement(
            'UPDATE assets SET intermediary_id = ? WHERE intermediary_id IS NULL',
            [defaultId],
          );
          _log.info('Migration 29: moved $orphanCount orphan assets to Default intermediary (id=$defaultId)');
        } else {
          _log.info('Migration 29: no orphan assets to backfill');
        }
      }
      if (from < 30) {
        // Per-source number-format locale for imports. NULL means
        // "Auto — use the app's configured locale at import time".
        if (!await _hasColumn('import_configs', 'number_locale')) {
          await customStatement(
            'ALTER TABLE import_configs ADD COLUMN number_locale TEXT',
          );
        }
        if (!await _hasColumn('intermediaries', 'default_import_locale')) {
          await customStatement(
            'ALTER TABLE intermediaries ADD COLUMN default_import_locale TEXT',
          );
        }
        _log.info('Migration 30: added number_locale columns');
      }
      if (from < 31) {
        // Ephemeral inflow adjustments — line-of-credit money. Routed
        // to Cash (negated) but never to Saving.
        if (!await _hasColumn('extraordinary_events', 'is_ephemeral')) {
          await customStatement(
            'ALTER TABLE extraordinary_events '
            'ADD COLUMN is_ephemeral INTEGER NOT NULL DEFAULT 0',
          );
        }
        _log.info('Migration 31: added extraordinary_events.is_ephemeral');
      }
      if (from < 32) {
        // Chart configuration moved to assets/default_charts.json. The
        // dashboard_charts table is no longer used; drop it (and its
        // generated row data) entirely.
        await customStatement('DROP TABLE IF EXISTS dashboard_charts');
        _log.info('Migration 32: dropped dashboard_charts table');
      }
      if (from < 33) {
        // Backfill: every existing revalue event becomes a market_prices
        // row, so manual assets render in every dashboard, allocation,
        // health KPI, and chart consumer the same way priced assets do.
        // close_price = revalue.amount / qty_at_value_date so a later
        // buy/sell can't retroactively shift the implied per-unit price.
        // Must stay in sync with resyncRevaluePricesForAsset in
        // asset_event_service.dart.
        await customStatement(
          "INSERT OR REPLACE INTO market_prices (asset_id, date, close_price, currency) "
          "SELECT e.asset_id, e.value_date, e.amount / qty.q, "
          "       COALESCE((SELECT a.currency FROM assets a WHERE a.id = e.asset_id), 'EUR') "
          "FROM asset_events e "
          "JOIN ("
          "  SELECT rev.id, "
          "         (SELECT SUM(CASE WHEN sub.type = 'buy' THEN COALESCE(sub.quantity, 0) "
          "                          WHEN sub.type = 'sell' THEN -COALESCE(sub.quantity, 0) "
          "                          ELSE 0 END) "
          "          FROM asset_events sub "
          "          WHERE sub.asset_id = rev.asset_id "
          "          AND sub.value_date <= rev.value_date) AS q "
          "  FROM asset_events rev "
          "  WHERE rev.type = 'revalue'"
          ") qty ON qty.id = e.id "
          "WHERE e.type = 'revalue' AND qty.q > 0",
        );
        _log.info('Migration 33: backfilled market_prices from revalue events');
      }
      if (from < 34) {
        // Add `asset_id` column to incomes so pension-contribution
        // rows can be linked back to their source pension fund. The
        // column is nullable; existing rows leave it NULL.
        if (!await _hasColumn('incomes', 'asset_id')) {
          await customStatement(
            'ALTER TABLE incomes ADD COLUMN asset_id INTEGER REFERENCES assets(id)',
          );
          _log.info('Migration 34: added asset_id column to incomes');
        }
      }
      if (from < 35) {
        // valuationMethod was wrongly defaulted to eventDriven for every
        // newly-created asset. Promote any asset with a ticker or ISIN
        // (i.e., a public price source exists) to marketPrice. Assets
        // with neither — genuinely manual revaluation funds — stay as is.
        await customStatement(
          "UPDATE assets SET valuation_method='marketPrice' "
          "WHERE valuation_method='eventDriven' "
          "AND ((ticker IS NOT NULL AND ticker <> '') "
          "  OR (isin IS NOT NULL AND isin <> ''))",
        );
        _log.info('Migration 35: promoted eventDriven assets with public source to marketPrice');
      }
      if (from < 36) {
        if (!await _tableExists('pillars')) {
          await m.createTable(pillars);
        }
        if (!await _tableExists('pillar_assets')) {
          await m.createTable(pillarAssets);
        }
        await _createIndexes();
        _log.info('Migration 36: created pillars + pillar_assets');
      }
      if (from < 37) {
        if (await _hasColumn('pillars', 'reference_portfolio')) {
          await customStatement(
            'ALTER TABLE pillars DROP COLUMN reference_portfolio',
          );
          _log.info('Migration 37: dropped pillars.reference_portfolio');
        }
      }
      if (from < 38) {
        if (await _hasColumn('pillars', 'emoji')) {
          await customStatement(
            'ALTER TABLE pillars DROP COLUMN emoji',
          );
          _log.info('Migration 38: dropped pillars.emoji');
        }
      }
      if (from < 39) {
        // Drop the never-read assets.yahoo_ticker column (carry-over from
        // a long-removed provider integration) and the unused
        // registered_events table + RegisteredEventType enum.
        // (Cache-key + asset.exchange normalisation deferred to v40 —
        // v39's own UPDATE was clobbered by an earlier rename pass.)
        if (await _hasColumn('assets', 'yahoo_ticker')) {
          await customStatement('ALTER TABLE assets DROP COLUMN yahoo_ticker');
        }
        await customStatement('DROP TABLE IF EXISTS registered_events');
        _log.info('Migration 39: dropped yahoo_ticker, registered_events');
      }
      if (from < 40) {
        // (a) Rename legacy app_configs cache keys INVESTING_*→PROVIDER_*
        //     using INSERT-OR-IGNORE then DELETE so we survive the
        //     partial state v39 left behind (where some PROVIDER_* rows
        //     already exist alongside their INVESTING_* counterparts).
        //     The PROVIDER_* row wins; INVESTING_* gets cleaned up.
        // (b) Heal stored description text that still mentions the
        //     external provider by name (cosmetic, but eliminates a
        //     grep hit on a fresh-from-old-DB install).
        // (c) Normalise assets.exchange to canonical English provider
        //     names (e.g. 'MIL'→'Milan', 'NYQ'→'NYSE'). Same heal
        //     applied to PROVIDER_*_<exchange> cache-key suffixes so
        //     the asset row and the cache key continue to agree.
        await customStatement(
          "INSERT OR IGNORE INTO app_configs (key, value, description) "
          "SELECT 'PROVIDER_CID_' || SUBSTR(key, LENGTH('INVESTING_CID_') + 1), value, "
          "       REPLACE(description, 'Investing.com', 'provider') "
          "FROM app_configs WHERE key LIKE 'INVESTING_CID_%'",
        );
        await customStatement(
          "INSERT OR IGNORE INTO app_configs (key, value, description) "
          "SELECT 'PROVIDER_URL_' || SUBSTR(key, LENGTH('INVESTING_URL_') + 1), value, "
          "       REPLACE(description, 'Investing.com', 'provider') "
          "FROM app_configs WHERE key LIKE 'INVESTING_URL_%'",
        );
        await customStatement(
          "INSERT OR IGNORE INTO app_configs (key, value, description) "
          "SELECT 'PROVIDER_FX_CID_' || SUBSTR(key, LENGTH('INVESTING_FX_CID_') + 1), value, "
          "       REPLACE(description, 'Investing.com', 'provider') "
          "FROM app_configs WHERE key LIKE 'INVESTING_FX_CID_%'",
        );
        await customStatement("DELETE FROM app_configs WHERE key LIKE 'INVESTING_%'");

        // (b) cosmetic heal of any remaining provider mentions in description
        await customStatement(
          "UPDATE app_configs SET description = REPLACE(description, 'Investing.com', 'provider') "
          "WHERE description LIKE '%Investing.com%'",
        );

        // (c) normalise asset.exchange + cache-key suffixes via the
        //     legacy-alias map (codes + Italian variants → canonical
        //     English name).
        const aliases = {
          'MIL': 'Milan',
          'NYQ': 'NYSE',
          'NMS': 'NASDAQ',
          'NYS': 'NYSE',
          'ASE': 'AMEX',
          'XETRA': 'Xetra',
          'FRA': 'Frankfurt',
          'LON': 'London',
          'AMS': 'Amsterdam',
          'PAR': 'Paris',
          'BRU': 'Brussels',
          'LIS': 'Lisbon',
          'SIX': 'Switzerland',
          'TSE': 'Toronto',
          'HKG': 'Hong Kong',
          'TYO': 'Tokyo',
          'Milano': 'Milan',
          'Londra': 'London',
          'Francoforte': 'Frankfurt',
          'Parigi': 'Paris',
          'Bruxelles': 'Brussels',
          'Lisbona': 'Lisbon',
          'Svizzera': 'Switzerland',
        };
        for (final entry in aliases.entries) {
          final from_ = entry.key;
          final to = entry.value;
          await customStatement(
            'UPDATE assets SET exchange = ? WHERE exchange = ?',
            [to, from_],
          );
          // Cache-key suffix rename. Using INSERT OR IGNORE + DELETE
          // again so a row with the canonical suffix wins if both forms
          // happen to coexist.
          for (final prefix in const ['PROVIDER_CID_', 'PROVIDER_URL_']) {
            await customStatement(
              "INSERT OR IGNORE INTO app_configs (key, value, description) "
              "SELECT REPLACE(key, ?, ?), value, description "
              "FROM app_configs WHERE key LIKE ? AND key LIKE ?",
              ['_$from_', '_$to', '$prefix%', '%_$from_'],
            );
            await customStatement(
              "DELETE FROM app_configs WHERE key LIKE ? AND key LIKE ?",
              ['$prefix%', '%_$from_'],
            );
          }
        }
        _log.info(
          'Migration 40: cache keys renamed INVESTING_*→PROVIDER_*; '
          'asset.exchange + cache-key suffixes normalised to canonical names',
        );
      }
      if (from < 41) {
        if (!await _tableExists('portfolio_models')) {
          await m.createTable(portfolioModels);
        }
        if (!await _tableExists('portfolio_model_items')) {
          await m.createTable(portfolioModelItems);
        }
        if (!await _hasColumn('pillars', 'portfolio_model_id')) {
          await customStatement(
            'ALTER TABLE pillars ADD COLUMN portfolio_model_id TEXT '
            'REFERENCES portfolio_models(id) ON DELETE SET NULL',
          );
        }
        await _createIndexes();
        _log.info('Migration 41: created portfolio models and linked pillars');
      }
      if (from < 42) {
        if (!await _hasColumn('assets', 'include_in_savings') && await _hasColumn('assets', 'include_in_net_worth')) {
          await customStatement(
            'ALTER TABLE assets RENAME COLUMN include_in_net_worth TO include_in_savings',
          );
        }
        _log.info('Migration 42: renamed assets.include_in_net_worth to include_in_savings');
      }
      if (from < 43) {
        if (!await _hasColumn('portfolio_model_items', 'preferred_ticker')) {
          await customStatement(
            'ALTER TABLE portfolio_model_items ADD COLUMN preferred_ticker TEXT',
          );
        }
        if (!await _hasColumn('portfolio_model_items', 'preferred_exchange')) {
          await customStatement(
            'ALTER TABLE portfolio_model_items ADD COLUMN preferred_exchange TEXT',
          );
        }
        _log.info('Migration 43: added preferred listing metadata to portfolio model items');
      }
    },
  );

  Future<bool> _hasColumn(String table, String column) async {
    final rows = await customSelect('PRAGMA table_info($table)').get();
    return rows.any((r) => r.read<String>('name') == column);
  }

  Future<bool> _tableExists(String table) async {
    final row = await customSelect(
      "SELECT COUNT(*) AS cnt FROM sqlite_master WHERE type='table' AND name=?",
      variables: [Variable.withString(table)],
    ).getSingle();
    return row.read<int>('cnt') > 0;
  }

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transactions_account_date_id '
      'ON transactions(account_id, operation_date DESC, id DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_event_entries_event_date '
      'ON extraordinary_event_entries(event_id, date ASC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_asset_events_asset_date '
      'ON asset_events(asset_id, date ASC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_asset_compositions_asset_id '
      'ON asset_compositions(asset_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_market_prices_asset_date '
      'ON market_prices(asset_id, date DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_buffer_transactions_buffer_id '
      'ON buffer_transactions(buffer_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pillar_assets_asset '
      'ON pillar_assets(asset_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_portfolio_model_items_model '
      'ON portfolio_model_items(model_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pillars_portfolio_model '
      'ON pillars(portfolio_model_id)',
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
      await into(appConfigs).insert(
        AppConfigsCompanion.insert(
          key: entry.key,
          value: entry.value.$1,
          description: Value(entry.value.$2),
        ),
      );
    }
  }

  /// Merge the contents of an external SQLite backup file at [tmpPath] into
  /// this database via `ATTACH DATABASE`.
  ///
  /// For every user table in the backup: DELETE FROM main + INSERT FROM
  /// SELECT (column intersection). The whole copy runs in one transaction —
  /// it either fully succeeds or rolls back leaving local data untouched.
  /// This avoids the Windows file-lock problem (no close, no file swap).
  ///
  /// Throws [SchemaVersionMismatchException] when the backup's drift schema
  /// version differs from this app's — a column-intersection copy across
  /// schema versions would silently drop or mis-fill columns.
  Future<void> mergeFromAttachedDb(String tmpPath) async {
    // Escape single quotes in the path for SQL string literal safety.
    final sqlPath = tmpPath.replaceAll("'", "''");
    await customStatement("ATTACH DATABASE '$sqlPath' AS src");
    try {
      // Schema-version gate: a backup from a different app version has a
      // different table shape; copying it by column intersection would
      // silently drop or mis-fill columns. Refuse instead of corrupting.
      final remoteVersion = (await customSelect('PRAGMA src.user_version').getSingle()).read<int>('user_version');
      if (remoteVersion != schemaVersion) {
        throw SchemaVersionMismatchException(
          localVersion: schemaVersion,
          remoteVersion: remoteVersion,
        );
      }

      // Discover user tables in the source DB. Exclude SQLite's schema table
      // and Android's auto-generated metadata table, but we DO want
      // `sqlite_sequence` so AUTOINCREMENT counters stay in sync — otherwise
      // the next insert locally could reuse an ID already present in the
      // data we just copied.
      final rows = await customSelect(
        "SELECT name FROM src.sqlite_master "
        "WHERE type='table' "
        "AND name NOT LIKE 'sqlite_stat%' "
        "AND name NOT IN ('sqlite_master', 'sqlite_temp_master', 'android_metadata')",
      ).get();
      final tables = rows.map((r) => r.read<String>('name')).toList();
      _log.info('mergeFromAttachedDb: copying ${tables.length} tables from $tmpPath');

      await transaction(() async {
        // FK constraints would fire during intermediate states while we wipe
        // and repopulate tables. Disable them for the duration of the copy —
        // we trust the remote DB is internally consistent.
        await customStatement('PRAGMA defer_foreign_keys = ON');
        for (final table in tables) {
          try {
            // Use column intersection so schema differences (extra columns in
            // either the source or target) don't cause INSERT failures.
            final srcCols = (await customSelect('PRAGMA src.table_info("$table")').get()).map((r) => r.read<String>('name')).toSet();
            final dstCols = (await customSelect('PRAGMA main.table_info("$table")').get()).map((r) => r.read<String>('name')).toSet();
            final common = srcCols.intersection(dstCols);
            if (common.isEmpty) {
              _log.warning('mergeFromAttachedDb: no common columns for $table, skipping');
              continue;
            }
            final cols = common.map((c) => '"$c"').join(', ');
            await customStatement('DELETE FROM main."$table"');
            await customStatement(
              'INSERT INTO main."$table" ($cols) SELECT $cols FROM src."$table"',
            );
          } catch (e) {
            _log.warning('mergeFromAttachedDb: failed to copy table $table: $e');
            rethrow;
          }
        }
      });
      notifyUpdates({
        for (final table in tables)
          if (table != 'sqlite_sequence') TableUpdate(table),
      });
      _log.info('mergeFromAttachedDb: merge committed');
    } finally {
      try {
        await customStatement('DETACH DATABASE src');
      } catch (e) {
        _log.warning('mergeFromAttachedDb: DETACH failed (harmless): $e');
      }
    }
  }
}

/// Ensure sqlite3 native library is configured (needed on Android).
Future<void> _ensureSqliteConfigured() async {
  if (Platform.isAndroid) {
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
  }
  final cacheDir = await getTemporaryDirectory();
  sqlite3.tempDirectory = cacheDir.path;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    await _ensureSqliteConfigured();
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      _log.info('Creating database directory: ${dir.path}');
      await dir.create(recursive: true);
    }
    final file = File(p.join(dir.path, dbFileName));
    // ignore: avoid_print
    print('DB:  ${file.path}');
    _log.info('Opening database: ${file.path}');
    return NativeDatabase(file);
  });
}

LazyDatabase _openAtPath(String path) {
  return LazyDatabase(() async {
    await _ensureSqliteConfigured();
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
