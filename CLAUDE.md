# Build & Deploy

- When needed, always build first, then kill the running app, then start the new build. Never kill before the build completes.
  ```
  source .env && dart fix --apply && flutter build macos --release --dart-define=BUILD_TS=$(date +%Y%m%d_%H%M%S) --dart-define=GOOGLE_CLIENT_ID=$GOOGLE_CLIENT_ID --dart-define=GOOGLE_CLIENT_SECRET=$GOOGLE_CLIENT_SECRET && pkill -f "FinanceCopilot" 2>/dev/null; open build/macos/Build/Products/Release/FinanceCopilot.app
  ```
- Android APK build:
  ```
  source .env && flutter build apk --release --dart-define=BUILD_TS=$(date +%Y%m%d_%H%M%S) --dart-define=GOOGLE_CLIENT_ID=$GOOGLE_CLIENT_ID --dart-define=GOOGLE_CLIENT_SECRET=$GOOGLE_CLIENT_SECRET --dart-define=GOOGLE_WEB_CLIENT_ID=$GOOGLE_WEB_CLIENT_ID --dart-define=GOOGLE_ANDROID_CLIENT_ID=$GOOGLE_ANDROID_CLIENT_ID
  ```
- OAuth credentials are in `.env` (gitignored). Never commit secrets to git.

## Android Emulator

- Available emulators: `Medium_Phone_API_35`, `Pixel_8_Pro_API_35`
- Steps (in order):
  1. Launch emulator: `flutter emulators --launch <emulator_id>`
  2. Wait for it to appear: `flutter devices` (look for `emulator-XXXX`)
  3. Build APK: `source .env && flutter build apk --release --dart-define=BUILD_TS=$(date +%Y%m%d_%H%M%S) --dart-define=GOOGLE_CLIENT_ID=$GOOGLE_CLIENT_ID --dart-define=GOOGLE_CLIENT_SECRET=$GOOGLE_CLIENT_SECRET --dart-define=GOOGLE_WEB_CLIENT_ID=$GOOGLE_WEB_CLIENT_ID --dart-define=GOOGLE_ANDROID_CLIENT_ID=$GOOGLE_ANDROID_CLIENT_ID`
  4. Install: `flutter install -d emulator-XXXX`
  5. Launch app: `adb -s emulator-XXXX shell monkey -p net.bazzani.financecopilot -c android.intent.category.LAUNCHER 1`
- Package name is `net.bazzani.financecopilot` (NOT `com.example.finance_copilot`).
- To run a second emulator alongside an existing one, just launch it — don't kill the first. They get sequential ports (5554, 5556, ...).
- If `am start` or `monkey` fails with "Activity does not exist" on a freshly launched emulator, the emulator image is likely corrupted (e.g. EdXposed or other framework mods). Fix: kill it (`adb -s emulator-XXXX emu kill`), relaunch with `flutter emulators --launch`, and reinstall.

## Windows VM (Parallels)

- A Parallels "Windows 11" VM runs on this Mac. Use `prlctl exec "Windows 11"` to run commands.
- Flutter path: `C:\Users\marco\dev\flutter\bin\flutter.bat`
- Project path: `C:\Users\marco\dev\FinanceCopilot`
- Build: `prlctl exec "Windows 11" cmd /c "cd /d C:\Users\marco\dev\FinanceCopilot && C:\Users\marco\dev\flutter\bin\flutter.bat build windows --release 2>&1"`
- Kill before rebuild: `prlctl exec "Windows 11" cmd /c "taskkill /F /IM FinanceCopilot.exe 2>&1"`
- **Launch GUI app** — `prlctl exec` runs in a non-interactive service session (Session 0), so use a scheduled task to launch in the user's interactive session:
  ```
  prlctl exec "Windows 11" cmd /c "schtasks /Create /TN LaunchFC /TR \"C:\Users\marco\dev\FinanceCopilot\build\windows\x64\runner\Release\FinanceCopilot.exe\" /SC ONCE /ST 00:00 /F /RU marco 2>&1 && schtasks /Run /TN LaunchFC 2>&1 && schtasks /Delete /TN LaunchFC /F 2>&1"
  ```

# Git Workflow

- Do NOT commit automatically after every change. Build first, let the user test, and only commit when the user asks or when starting a completely different task.
- Use concise, meaningful commit messages.
- NEVER add `Co-Authored-By:` lines to commits. Not under any circumstances, not for any reason. No exceptions.
- **Use `develop` branch for testing/exchanging code** (e.g. syncing with Windows VM). Never push to `main` unless the user explicitly confirms. Push to `develop` freely for testing.
- Only bump `appVersion` in `lib/version.dart` when releasing on `main`, not on develop/feature branches.
- **NEVER commit or push until ALL test suites have passed. No exceptions.**
- **NEVER run git add/commit/push while tests are still running.** Wait for all test results first.
- Before every commit, run ALL of these and verify green:
  1. `dart fix --apply && dart analyze lib/ test/ integration_test/` -- zero warnings/infos allowed
  2. `flutter test` -- all unit tests must pass
  3. `flutter test integration_test/all_tests.dart -d macos` -- all integration tests must pass
  4. `flutter test integration_test/live_data_fetch_test.dart -d macos` -- live data fetch test must pass
  5. NEVER commit with known failing tests. NEVER skip any test suite.

## Releasing a new version

0. **Pre-release check**: a working nightly build with `main` merged into `develop` must exist and pass CI before starting the release. Verify with `gh run list --branch develop --limit 1`.
1. Merge `develop` into `main`: `git checkout main && git merge develop --no-edit`
2. Bump version in `lib/version.dart` (only on main)
3. Commit: `git commit -am "Release vX.Y.Z"`
4. Tag and push: `git tag vX.Y.Z && git push origin main && git push origin vX.Y.Z`
5. Summarize changes: run `git log --oneline vPREVIOUS..vX.Y.Z` and write a user-facing summary (features + bug fixes, no implementation details)
6. Create GitHub Release: use `gh release create vX.Y.Z --title "vX.Y.Z -- short description" --notes "..."` with the summary
7. Wait for CI/CD to complete: `gh run list --branch main --limit 1` -- CI builds macOS DMG + Windows ZIP, attaches to release, updates Homebrew tap
8. Sync develop: `git checkout develop && git merge main --no-edit && git push origin develop`


# Code Quality

- Never duplicate code. Extract shared logic into utilities or service methods.
- Single source of truth: queries, parsing, business logic must be defined once and reused.
- **Financial accuracy**: NEVER silently fallback to wrong values when data is missing. No `?? 1.0` for FX rates, no returning original amounts when conversion fails. Missing data must be surfaced (log warning, show indicator, skip the calculation) — never hidden behind a default that produces silently incorrect financial figures.
- **Tests are mandatory**: Every new feature, bug fix, or service method MUST include tests. Coverage must increase, never decrease. If an existing test needs to change, the change must be proven necessary (the old behavior was wrong), not blindly modified to make it pass.
- **Before any refactor or optimization**: Write a specific test that pins the current behavior of the code you're about to change. Run it and confirm it passes. Only then refactor. After refactoring, the same test must still pass with identical results. This is non-negotiable — no behavioral change without a test proving equivalence.

# Localization

- Always translate every string the user sees in the UI (use `AppStrings` / l10n).
- Always localize dates (both input parsing and output formatting) based on the application's locale configuration.



# Navigation

- Do NOT run `find` or exploratory commands to locate files — check the code directly.

# Long-Running Commands

- Never sleep longer than 10 seconds in any command. Run long tasks in background and check for progress periodically.

# Python

- NEVER use `--break-system-packages` with pip. Use `python3 -m venv` for virtual environments instead.

# Database & Sandbox

The app runs sandboxed on macOS. All internal data lives inside the container.

- **Protect user data**: Before running integration tests or any operation that launches the app (which may modify the DB), back up the container. Restore it before committing.
  - Backup: `cp -a ~/Library/Containers/net.bazzani.financecopilot ~/Library/Containers/net.bazzani.financecopilot.bak`
  - Restore: `rm -rf ~/Library/Containers/net.bazzani.financecopilot && mv ~/Library/Containers/net.bazzani.financecopilot.bak ~/Library/Containers/net.bazzani.financecopilot`
  - Always verify the backup exists before running tests. Always restore before committing.

- **macOS DB**: `~/Library/Containers/net.bazzani.financecopilot/Data/Library/Application Support/net.bazzani.financecopilot/finance_copilot.db`
- **macOS logs**: `tail -f ~/Library/Containers/net.bazzani.financecopilot/Data/Library/Application\ Support/net.bazzani.financecopilot/app.log`
- **macOS OS log**: `log stream --predicate 'subsystem == "net.bazzani.financecopilot"' --level debug`
- **Windows DB**: `C:\Users\marco\AppData\Roaming\net.bazzani.financecopilot\finance_copilot.db`
- **Windows logs**: `Get-Content C:\Users\marco\AppData\Roaming\net.bazzani.financecopilot\app.log -Wait`
- **Android logs**: `adb logcat -s flutter`
- **Previous session log**: `previous_session.log` (same dir as app.log, for bug reports)
- Never use `assets.db` in the repo root (stale copy, gitignored).

# Architecture

- The app must be **pure Flutter/Dart**. No Python scripts or external tools for runtime functionality.
- All data fetching (prices, ETF composition, etc.) must happen inside the Dart app itself.
- The released artifact must be fully self-contained.
- For reverse engineering websites/APIs: use any tool (curl, Playwright, Python, etc.) for exploration, but the final implementation must be in Dart/Flutter.
- **Never mention external data sources** (websites, APIs, providers) by name in README, comments, commit messages, or any user-facing text. Refer to them generically (e.g. "market data provider", "composition data").
- **Date convention**: `operationDate` = when the bank processed it (used for import wipe-and-replace dedup). `valueDate` = when the money actually moved (used for display, ordering, charts, balance computation). All UI and queries must use `valueDate` for display/ordering. `operationDate` is only for the import dedup cutoff.

# Key Project Files

- `lib/main.dart` — App shell, navigation, settings dialog
- `lib/database/database.dart` — Drift DB definition, migrations
- `lib/database/tables.dart` — All table definitions
- `lib/database/providers.dart` — Database provider
- `lib/services/providers/providers.dart` — Riverpod providers (split into service/stream/computed/app_state)
- `lib/services/file_parser_service.dart` — CSV/Excel file parsing (isolate-based)
- `lib/services/market_price_service.dart` — Abstract market price service
- `lib/services/investing_com_service.dart` — Market price/search/composition provider (WebView + Dio)
- `lib/services/composition_service.dart` — ETF/stock composition fetcher
- `lib/services/asset_service.dart` — Asset CRUD
- `lib/services/asset_event_service.dart` — Asset events (buy/sell/revalue)
- `lib/services/exchange_rate_service.dart` — FX rates
- `lib/services/intermediary_service.dart` — Broker/institution grouping
- `lib/services/income_service.dart` — Income tracking
- `lib/services/income_adjustment_service.dart` — Income adjustments
- `lib/services/capex_service.dart` — Depreciation/adjustment schedules
- `lib/services/buffer_service.dart` — Buffer management
- `lib/services/google_drive_sync_service.dart` — Google Drive auto-sync with conflict detection
- `lib/services/db_transfer_service.dart` — Import/export DB file
- `lib/ui/screens/dashboard/dashboard_screen.dart` — Charts (net worth + investment, split into 15 part files)
- `lib/ui/screens/dashboard/health_tab.dart` — Financial Health KPIs
- `lib/ui/screens/dashboard/totals_table.dart` — Totals with drill-down
- `lib/ui/screens/allocation_tab.dart` — Portfolio allocation donuts
- `lib/ui/screens/assets_screen.dart` — Asset list + create dialog
- `lib/ui/screens/accounts_screen.dart` — Account list
- `lib/ui/screens/capex_screen.dart` — Adjustments screen
- `lib/ui/screens/import/import_screen.dart` — CSV import (split into 4 part files)
- `lib/utils/date_parser.dart` — Comprehensive multi-format date parser
- `lib/version.dart` — Version number
