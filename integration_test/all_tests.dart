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

import 'full_walkthrough_test.dart' as full_walkthrough;
import 'legacy_migration_test.dart' as legacy_migration;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  full_walkthrough.main();
  legacy_migration.main();
}
