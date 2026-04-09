/// Single entry point for all integration tests.
/// One compile, one process, runs all tests sequentially.
///
/// Usage: flutter test integration_test/all_tests.dart -d macos
///
/// Each test file has exactly one testWidgets with its own pumpApp/DB.
/// They run sequentially in one process — no DB reinit crash because
/// each testWidgets gets a fresh WidgetTester with a new widget tree.
library;
import 'package:integration_test/integration_test.dart';

import 'allocation_test.dart' as allocation;
import 'app_test.dart' as app;
import 'accounts_test.dart' as accounts;
import 'asset_events_test.dart' as asset_events;
import 'assets_test.dart' as assets;
import 'capex_test.dart' as capex;
import 'crud_test.dart' as crud;
import 'dashboard_test.dart' as dashboard;
import 'delete_flows_test.dart' as delete_flows;
import 'full_flow_test.dart' as full_flow;
import 'import_asset_test.dart' as import_asset;
import 'import_csv_test.dart' as import_csv;
import 'import_dedup_test.dart' as import_dedup;
import 'import_income_test.dart' as import_income;
import 'import_transaction_test.dart' as import_transaction;
import 'legacy_migration_test.dart' as legacy_migration;
import 'import_test.dart' as import_screen;
import 'income_test.dart' as income;
import 'navigation_test.dart' as navigation;
import 'settings_test.dart' as settings;
import 'transactions_test.dart' as transactions;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  allocation.main();
  app.main();
  accounts.main();
  asset_events.main();
  assets.main();
  capex.main();
  crud.main();
  dashboard.main();
  delete_flows.main();
  full_flow.main();
  import_asset.main();
  import_csv.main();
  import_dedup.main();
  import_income.main();
  import_transaction.main();
  legacy_migration.main();
  import_screen.main();
  income.main();
  navigation.main();
  settings.main();
  transactions.main();
}
