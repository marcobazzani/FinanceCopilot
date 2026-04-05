/// Generates a minimal test DB using sqlite3 CLI.
/// No Flutter dependencies — runs with plain `dart`.
///
/// Usage: dart run integration_test/generate_test_db.dart /tmp/test.db
library;
import 'dart:io';

Future<void> main(List<String> args) async {
  final path = args.isNotEmpty ? args[0] : '/tmp/FinanceCopilot_e2e_test.db';

  // Delete old
  final f = File(path);
  if (f.existsSync()) f.deleteSync();

  // Create schema and seed data via sqlite3
  final sql = '''
-- Minimal schema matching Drift's generated tables
CREATE TABLE IF NOT EXISTS accounts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'checking',
  currency TEXT NOT NULL DEFAULT 'EUR',
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1,
  notes TEXT
);

CREATE TABLE IF NOT EXISTS assets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  asset_type TEXT NOT NULL DEFAULT 'stockEtf',
  instrument_type TEXT DEFAULT 'etf',
  asset_class TEXT DEFAULT 'equity',
  valuation_method TEXT NOT NULL DEFAULT 'marketPrice',
  ticker TEXT,
  isin TEXT,
  currency TEXT DEFAULT 'EUR',
  exchange TEXT DEFAULT 'MIL',
  ter REAL,
  is_active INTEGER NOT NULL DEFAULT 1,
  sort_order INTEGER NOT NULL DEFAULT 0,
  intermediary_id INTEGER,
  notes TEXT
);

CREATE TABLE IF NOT EXISTS asset_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id INTEGER NOT NULL,
  date INTEGER NOT NULL,
  type TEXT NOT NULL DEFAULT 'buy',
  amount REAL NOT NULL DEFAULT 0,
  quantity REAL,
  price REAL,
  currency TEXT DEFAULT 'EUR',
  exchange_rate REAL,
  commission REAL,
  notes TEXT
);

CREATE TABLE IF NOT EXISTS market_prices (
  asset_id INTEGER NOT NULL,
  date INTEGER NOT NULL,
  close_price REAL NOT NULL,
  currency TEXT NOT NULL DEFAULT 'EUR',
  PRIMARY KEY (asset_id, date)
);

CREATE TABLE IF NOT EXISTS transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id INTEGER NOT NULL,
  operation_date INTEGER NOT NULL,
  value_date INTEGER,
  amount REAL NOT NULL,
  description TEXT DEFAULT '',
  currency TEXT DEFAULT 'EUR',
  category_id INTEGER,
  balance_after REAL,
  status TEXT,
  raw_metadata TEXT
);

CREATE TABLE IF NOT EXISTS app_configs (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  description TEXT
);

CREATE TABLE IF NOT EXISTS asset_compositions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id INTEGER NOT NULL,
  field TEXT NOT NULL DEFAULT '',
  label TEXT NOT NULL DEFAULT '',
  weight REAL NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS exchange_rates (
  pair TEXT NOT NULL,
  date INTEGER NOT NULL,
  rate REAL NOT NULL,
  PRIMARY KEY (pair, date)
);

CREATE TABLE IF NOT EXISTS incomes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date INTEGER NOT NULL,
  amount REAL NOT NULL,
  currency TEXT DEFAULT 'EUR',
  type TEXT DEFAULT 'income',
  source TEXT,
  notes TEXT
);

-- Seed config
INSERT INTO app_configs VALUES ('BASE_CURRENCY', 'EUR', 'Base currency');
INSERT INTO app_configs VALUES ('LOCALE', 'en_US', 'Display locale');
INSERT INTO app_configs VALUES ('TAX_RATE', '0.26', 'Capital gains tax rate');

-- Seed accounts
INSERT INTO accounts (name, type, currency) VALUES ('Fineco', 'checking', 'EUR');
INSERT INTO accounts (name, type, currency) VALUES ('Revolut', 'checking', 'EUR');

-- Seed assets
INSERT INTO assets (name, ticker, isin, exchange, currency, ter)
  VALUES ('iShares MSCI World', 'SWDA', 'IE00B4L5Y983', 'MIL', 'EUR', 0.20);
INSERT INTO assets (name, ticker, isin, exchange, currency, ter)
  VALUES ('Amundi Stoxx Europe 600', 'MEUD', 'LU0908500753', 'MIL', 'EUR', 0.07);
INSERT INTO assets (name, ticker, isin, exchange, currency)
  VALUES ('Amazon', 'AMZN', 'US0231351067', 'NYQ', 'USD');

-- Seed buy events (epoch seconds)
INSERT INTO asset_events (asset_id, date, type, amount, quantity, price, currency)
  VALUES (1, 1705276800, 'buy', 955.0, 10, 95.5, 'EUR');
INSERT INTO asset_events (asset_id, date, type, amount, quantity, price, currency)
  VALUES (1, 1717200000, 'buy', 510.0, 5, 102.0, 'EUR');
INSERT INTO asset_events (asset_id, date, type, amount, quantity, price, currency)
  VALUES (2, 1705276800, 'buy', 4210.0, 20, 210.5, 'EUR');
INSERT INTO asset_events (asset_id, date, type, amount, quantity, price, currency)
  VALUES (3, 1705276800, 'buy', 1800.0, 10, 180.0, 'USD');

-- Seed prices
INSERT INTO market_prices VALUES (1, 1717200000, 102.0, 'EUR');
INSERT INTO market_prices VALUES (1, 1735689600, 110.0, 'EUR');
INSERT INTO market_prices VALUES (2, 1717200000, 260.0, 'EUR');
INSERT INTO market_prices VALUES (2, 1735689600, 289.0, 'EUR');
INSERT INTO market_prices VALUES (3, 1717200000, 185.0, 'USD');
INSERT INTO market_prices VALUES (3, 1735689600, 210.0, 'USD');

-- Seed transactions
INSERT INTO transactions (account_id, operation_date, amount, description, currency)
  VALUES (1, 1705276800, -42.50, 'Supermarket', 'EUR');
INSERT INTO transactions (account_id, operation_date, amount, description, currency)
  VALUES (1, 1705363200, 1500.00, 'Salary', 'EUR');
INSERT INTO transactions (account_id, operation_date, amount, description, currency)
  VALUES (1, 1705449600, -120.00, 'Electricity', 'EUR');

-- Seed income
INSERT INTO incomes (date, amount, currency, source) VALUES (1705276800, 3000.0, 'EUR', 'Salary');
INSERT INTO incomes (date, amount, currency, source) VALUES (1707955200, 3000.0, 'EUR', 'Salary');
''';

  // Use Process.start to pipe SQL via stdin

  // Write SQL via stdin
  final proc = await Process.start('sqlite3', [path]);
  proc.stdin.write(sql);
  await proc.stdin.close();
  final exitCode = await proc.exitCode;

  if (exitCode != 0) {
    final stderr = await proc.stderr.transform(const SystemEncoding().decoder).join();
    print('ERROR: $stderr');
    exit(1);
  }

  print('Test DB created at $path (${File(path).lengthSync()} bytes)');
  print('  Accounts: 2, Assets: 3, Events: 4, Prices: 6, Transactions: 3');
}
