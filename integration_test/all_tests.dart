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

import 'app_test.dart' as app;
import 'accounts_test.dart' as accounts;
import 'asset_events_test.dart' as asset_events;
import 'assets_test.dart' as assets;
import 'capex_test.dart' as capex;
import 'crud_test.dart' as crud;
import 'dashboard_test.dart' as dashboard;
import 'full_flow_test.dart' as full_flow;
import 'import_csv_test.dart' as import_csv;
import 'import_test.dart' as import_screen;
import 'income_test.dart' as income;
import 'navigation_test.dart' as navigation;
import 'settings_test.dart' as settings;
import 'transactions_test.dart' as transactions;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  app.main();
  accounts.main();
  asset_events.main();
  assets.main();
  capex.main();
  crud.main();
  dashboard.main();
  full_flow.main();
  import_csv.main();
  import_screen.main();
  income.main();
  navigation.main();
  settings.main();
  transactions.main();
}
