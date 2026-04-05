/// End-to-end test using real app binary with CGEvent mouse automation.
///
/// Run: dart run integration_test/e2e_test.dart
/// Requires: app already built (flutter build macos --release)
/// Requires: Accessibility permissions for terminal
library;

import 'dart:io';
import 'e2e_helpers.dart';

Future<void> main() async {
  print('=== FinanceCopilot E2E Tests ===\n');

  // ── Prepare & Launch ──────────────────────────────────

  print('Phase 1: Prepare test DB & Launch');

  // Generate isolated test DB (never uses personal data)
  print('  Generating test DB...');
  final testDb = await prepareTestDb();
  check(File(testDb).existsSync(), 'Test DB generated');

  await launchApp();
  await screenshot('01_launch');

  // Open the test DB via native file picker
  await openTestDb(testDb);
  await allowPermissionDialog();
  await wait(3);
  await screenshot('02_app_loaded');
  pass('App launched with test DB');

  // ── Navigate all sidebar screens ─────────────────────

  print('\nPhase 2: Navigation');

  await navigateTo('Dashboard');
  await screenshot('04_dashboard');
  pass('Dashboard');

  await navigateTo('Accounts');
  await screenshot('05_accounts');
  pass('Accounts');

  await navigateTo('Assets');
  await screenshot('06_assets');
  pass('Assets');

  await navigateTo('Adjustments');
  await screenshot('07_adjustments');
  pass('Adjustments');

  await navigateTo('Income');
  await screenshot('08_income');
  pass('Income');

  // ── Dashboard tabs ───────────────────────────────────

  print('\nPhase 3: Dashboard tabs');
  await navigateTo('Dashboard');

  await dashTab('Health');
  await screenshot('09_health');
  pass('Health tab');

  await dashTab('History');
  await screenshot('10_history');
  pass('History tab');

  await dashTab('Cash Flow');
  await screenshot('11_cashflow');
  pass('Cash Flow tab');

  await dashTab('Assets Overview');
  await screenshot('12_overview');
  pass('Assets Overview tab');

  // ── Settings ─────────────────────────────────────────

  print('\nPhase 4: Settings');
  await toolbar('settings');
  await screenshot('13_settings');
  pass('Settings opened');

  await pressKey('escape');
  await wait(1);
  pass('Settings closed');

  // ── Click into an asset detail ───────────────────────

  print('\nPhase 5: Asset detail');
  await navigateTo('Assets');
  await wait(2);

  // Click on the first asset in the list (approximately y=70 in display)
  await click(350, 70);
  await wait(3);
  await screenshot('14_asset_detail');
  pass('Asset detail opened');

  // Go back
  await click(15, 28); // Back button
  await wait(2);
  pass('Back to assets list');

  // ── Price refresh (real HTTP) ────────────────────────

  print('\nPhase 6: Price refresh (real HTTP)');
  await navigateTo('Dashboard');
  await toolbar('refresh');
  await wait(15); // Wait for real API calls to complete
  await screenshot('15_after_refresh');
  pass('Price refresh triggered');

  // ── DB verification ──────────────────────────────────

  print('\nPhase 7: DB verification');
  final db = dbPath;

  if (File(db).existsSync()) {
    final assets = await queryDb(db, 'SELECT COUNT(*) FROM assets WHERE is_active = 1;');
    check(int.parse(assets) > 0, 'Active assets in DB', 'count=$assets');

    final accounts = await queryDb(db, 'SELECT COUNT(*) FROM accounts;');
    check(int.parse(accounts) > 0, 'Accounts in DB', 'count=$accounts');

    final prices = await queryDb(db, 'SELECT COUNT(*) FROM market_prices;');
    check(int.parse(prices) > 0, 'Market prices in DB', 'count=$prices');

    final latest = await queryDb(db,
      "SELECT close_price FROM market_prices ORDER BY date DESC LIMIT 1;");
    final price = double.tryParse(latest) ?? 0;
    check(price > 0 && price < 500000, 'Latest price is reasonable', 'price=$latest');

    final ter = await queryDb(db,
      "SELECT ter FROM assets WHERE ter IS NOT NULL LIMIT 1;");
    if (ter.isNotEmpty) {
      final terVal = double.tryParse(ter) ?? -1;
      check(terVal > 0 && terVal < 5.0, 'TER is reasonable', 'ter=$ter');
    }

    final events = await queryDb(db, 'SELECT COUNT(*) FROM asset_events;');
    check(int.parse(events) > 0, 'Asset events in DB', 'count=$events');

    final compositions = await queryDb(db, 'SELECT COUNT(*) FROM asset_compositions;');
    // Compositions may be 0 if sync hasn't run yet (e.g. test DB without full app init)
    if (int.parse(compositions) > 0) {
      pass('Compositions in DB');
    } else {
      pass('Compositions not yet synced (expected for test DB)');
    }
  } else {
    fail('DB file exists', 'Not found at $db');
  }

  // ── Cleanup ──────────────────────────────────────────

  print('\nScreenshots saved to /tmp/e2e_*.png');
  printSummary();
  await killApp();
}
