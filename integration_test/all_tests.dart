/// Single entry point for all integration tests.
/// One compile, one process, runs all tests sequentially.
///
/// Usage: flutter test integration_test/all_tests.dart -d macos
///
/// Suite shape (post per-feature-test deletion): ONE happy-path
/// walkthrough (`full_walkthrough_test.dart`) that exercises every major
/// feature on a single shared DB, plus the legacy-migration regression
/// check. The live network test (`live_data_fetch_test.dart`) lives in its
/// own file and is run separately because it makes real HTTP calls.
library;

import 'package:integration_test/integration_test.dart';

import 'asset_unlock_edit_test.dart' as asset_unlock_edit;
import 'appbar_mobile_overflow_test.dart' as appbar_mobile_overflow;
import 'full_walkthrough_test.dart' as full_walkthrough;
import 'import_sheet_cancel_test.dart' as import_sheet_cancel;
import 'income_saved_config_restore_test.dart' as income_saved_config_restore;
import 'ledger_filter_test.dart' as ledger_filter;
import 'legacy_migration_test.dart' as legacy_migration;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  full_walkthrough.main();
  legacy_migration.main();
  asset_unlock_edit.main();
  import_sheet_cancel.main();
  income_saved_config_restore.main();
  ledger_filter.main();
  appbar_mobile_overflow.main();
}
