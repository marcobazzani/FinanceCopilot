# Build & Deploy

- Version display: `v0.4.4` for stable releases, `v0.4.4-dev` for nightly/local builds. Controlled by `--dart-define=CHANNEL=stable|nightly` (defaults to `nightly`).
- When needed, always build first, then kill the running app, then start the new build. Never kill before the build completes.
  ```
  source .env && dart fix --apply && flutter build macos --release --dart-define=GOOGLE_CLIENT_ID=$GOOGLE_CLIENT_ID --dart-define=GOOGLE_CLIENT_SECRET=$GOOGLE_CLIENT_SECRET --dart-define=DB_FILE_NAME=$DB_FILE_NAME && pkill -f "FinanceCopilot" 2>/dev/null; open build/macos/Build/Products/Release/FinanceCopilot.app
  ```
- Android APK build:
  ```
  source .env && flutter build apk --release --dart-define=GOOGLE_CLIENT_ID=$GOOGLE_CLIENT_ID --dart-define=GOOGLE_CLIENT_SECRET=$GOOGLE_CLIENT_SECRET --dart-define=GOOGLE_WEB_CLIENT_ID=$GOOGLE_WEB_CLIENT_ID --dart-define=GOOGLE_ANDROID_CLIENT_ID=$GOOGLE_ANDROID_CLIENT_ID --dart-define=DB_FILE_NAME=$DB_FILE_NAME
  ```
- OAuth credentials are in `.env` (gitignored). Never commit secrets to git.

## Android Emulator

- Available emulators: `Medium_Phone_API_35`, `Pixel_8_Pro_API_35`
- Steps (in order):
  1. Launch emulator: `flutter emulators --launch <emulator_id>`
  2. Wait for it to appear: `flutter devices` (look for `emulator-XXXX`)
  3. Build APK: `source .env && flutter build apk --release --dart-define=GOOGLE_CLIENT_ID=$GOOGLE_CLIENT_ID --dart-define=GOOGLE_CLIENT_SECRET=$GOOGLE_CLIENT_SECRET --dart-define=GOOGLE_WEB_CLIENT_ID=$GOOGLE_WEB_CLIENT_ID --dart-define=GOOGLE_ANDROID_CLIENT_ID=$GOOGLE_ANDROID_CLIENT_ID --dart-define=DB_FILE_NAME=$DB_FILE_NAME`
  4. Install: `flutter install -d emulator-XXXX`
  5. Launch app: `adb -s emulator-XXXX shell monkey -p net.bazzani.financecopilot -c android.intent.category.LAUNCHER 1`
- Package name is `net.bazzani.financecopilot` (NOT `com.example.finance_copilot`).
- To run a second emulator alongside an existing one, just launch it — don't kill the first. They get sequential ports (5554, 5556, ...).
- If `am start` or `monkey` fails with "Activity does not exist" on a freshly launched emulator, the emulator image is likely corrupted (e.g. EdXposed or other framework mods). Fix: kill it (`adb -s emulator-XXXX emu kill`), relaunch with `flutter emulators --launch`, and reinstall.

## Windows VM (Parallels)

- A Parallels "Windows 11" VM runs on this Mac. Use `prlctl exec "Windows 11"` to run commands.
- Flutter path: `C:\Users\marco\dev\flutter\bin\flutter.bat`
- Project path: `C:\Users\marco\dev\FinanceCopilot`
- Build: the Windows project has its own `.env` copy at `C:\Users\marco\dev\FinanceCopilot\.env` — load it into the cmd session via a `for /f` loop before running flutter so Google OAuth dart-defines are populated.
  ```
  prlctl exec "Windows 11" cmd /c "cd /d C:\Users\marco\dev\FinanceCopilot && for /f \"usebackq tokens=1,* delims==\" %a in (\".env\") do set %a=%b && C:\Users\marco\dev\flutter\bin\flutter.bat build windows --release --dart-define=GOOGLE_CLIENT_ID=%GOOGLE_CLIENT_ID% --dart-define=GOOGLE_CLIENT_SECRET=%GOOGLE_CLIENT_SECRET% --dart-define=DB_FILE_NAME=%DB_FILE_NAME% 2>&1"
  ```
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
  3. `flutter test integration_test/all_tests.dart -d macos --dart-define=DB_FILE_NAME=finance_copilot_test.db` -- all integration tests must pass. ALWAYS pass `_test.db`; integration tests delete that DB file, and using `finance_copilot_dev.db` will wipe local dev data.
  4. `flutter test integration_test/live_data_fetch_test.dart -d macos --dart-define=DB_FILE_NAME=finance_copilot_test.db` -- live data fetch test must pass
  5. NEVER commit with known failing tests. NEVER skip any test suite.

## Releasing a new version

Version is derived from the git tag. Never hand-edit `lib/version.dart`.

0. **Pre-release check**: a working nightly build with `main` merged into `develop` must exist and pass CI before starting the release. Verify with `gh run list --branch develop --limit 1`.
1. Merge `develop` into `main` (via PR if protected, else direct merge).
2. Summarize changes: run `git log --oneline vPREVIOUS..HEAD` and write a user-facing summary.
3. Tag and push: `git tag vX.Y.Z && git push origin vX.Y.Z`
4. Create GitHub Release: `gh release create vX.Y.Z --title "vX.Y.Z -- short description" --notes "..."`
5. Wait for CI to complete: `gh run list --branch vX.Y.Z --limit 1` -- CI builds artifacts, attaches to release, updates Homebrew tap.
6. Sync develop from main if anything changed on main.


# Code Quality

- Never duplicate code. Extract shared logic into utilities or service methods.
- Single source of truth: queries, parsing, business logic must be defined once and reused.
- **Before writing a new widget/util/service method, grep the codebase for existing equivalents.** If one exists, REUSE it. Copy/paste is a regression. When two implementations of the same UI element exist, the older/canonical one wins; the newer collapses into it via shared code.
- **Fit into the current app.** Never start from scratch when an existing implementation can be extended. Read what's there before adding a parallel implementation.
- **Financial accuracy**: NEVER silently fallback to wrong values when data is missing. No `?? 1.0` for FX rates, no returning original amounts when conversion fails. Missing data must be surfaced (log warning, show indicator, skip the calculation) — never hidden behind a default that produces silently incorrect financial figures.
- **Per-asset price fallbacks are FORBIDDEN.** If a price is missing, the asset shows "—" and is excluded from totals with a footnote count. Never invent a value.
- **Tests are mandatory**: Every new feature, bug fix, or service method MUST include tests. Coverage must increase, never decrease. If an existing test needs to change, the change must be proven necessary (the old behavior was wrong), not blindly modified to make it pass.
- **NEVER modify or delete existing tests without explicit user consent.** If a test fails after your changes, the code is wrong — not the test. Fix the code to make the existing test pass. Only ask the user to change a test if you can prove the test itself encodes incorrect behavior.
- **Before any refactor or optimization**: Write a specific test that pins the current behavior of the code you're about to change. Run it and confirm it passes. Only then refactor. After refactoring, the same test must still pass with identical results. This is non-negotiable — no behavioral change without a test proving equivalence.

# UI Consistency

- **Delete affordance** is one canonical pattern across the app: trashcan icon in detail view + swipe-to-delete in lists. Long-press-to-delete is forbidden going forward. Three-dot menus offering delete must be reconciled to the canonical pattern.
- **Collapsible cards**: chevron + header layout MUST match the Cash Flow tab implementation (`lib/ui/screens/dashboard/cash_flow_tab.dart` part files). Header must NOT change on expand/collapse; expand must scroll smoothly, not snap. Reuse the existing widget — do not re-implement.
- **Bottom-of-screen "Next" buttons in wizards** MUST share a common navbar widget. Fix consistently across all wizards, never one-by-one.
- **Empty states** and **error toasts/snackbars** use one shared component each, with consistent placement.
- Before adding a new widget, grep for existing equivalents. Reuse > re-implement.
- **Every primary screen** plugs into the global app shell via two paired conventions, both required so new screens automatically inherit shell features:
  1. AppBar: `AppBar(actions: globalAppBarActions(context, ref, local: [...]))` — refresh, settings, import/export, privacy, network retry.
  2. Body: wrap the main scrollable in `MobilePullToRefresh(child: ListView/SingleChildScrollView(physics: AlwaysScrollableScrollPhysics(), ...))` so the same global refresh fires on a pull-down (Android/iOS only; no-op on desktop).

# Localization

- Every user-visible string MUST come from `AppStrings`/l10n. Literal `Text('...')` / `Text("...")` in `lib/ui/` is a violation — fix it immediately.
- Number parsing MUST use the active locale's decimal/group separator (`NumberFormat(localeTag).parse()`). NEVER hardcode `.` or `,` parsing logic. The Italian locale uses `,` as decimal separator — do not assume `.`.
- Date parsing AND formatting MUST be locale-aware. Route every date through `lib/utils/date_parser.dart` (single entry point). `DateFormat` instances MUST be constructed with an explicit locale tag.
- All locale bundles (en, it, …) must cover every key — no missing translations.
- When responding to GitHub issues opened by Italian-speaking users, reply in Italian.

# Branch & DB Discipline

- **Before any code edit**: confirm the current branch matches the user's stated target. If unclear, ASK. Do not assume `develop`.
- **Before launching the app or running integration tests**: confirm `DB_FILE_NAME` matches the intended dev DB. Mixing the dev container DB with the user's real `~/Documents/FinanceCopilot.db` is a top historical failure — never write to the real DB from tests/builds.
- Never commit dart-defines or env-specific config to a non-feature branch.
- When the user references a specific DB path or branch name, that overrides any default — re-confirm before acting.



# Navigation

- Prefer checking logs, existing codebase knowledge, and context first. Only use `find` or other CLI exploratory commands when the built-in tools (Glob, Grep, Read) cannot locate what you need.

# Long-Running Commands

- Never sleep longer than 10 seconds in any command. Run long tasks in background and check for progress periodically.

# Python

- NEVER use `--break-system-packages` with pip. Use `python3 -m venv` for virtual environments instead.

# Database & Sandbox

The app runs sandboxed on macOS. All internal data lives inside the container.

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
- **Never mention external data sources** (websites, APIs, providers) by name in README, comments, commit messages, CI config, screenshots, alt text, identifiers (class/file/variable names), log messages, doc strings, or user-facing strings. Refer to them generically (e.g. "market data provider", "composition data").
  - **Functional URL literals are exempt** (host strings in `lib/services/web_market_data_service.dart`, `lib/services/web_page_parser.dart`, `lib/services/composition_service.dart`, and `'Origin'`/`'Referer'` headers): these are operational data — the literal IS the integration point — and replacing them would change which provider we integrate with. Grep hits inside `https://...` URL strings, `host.endsWith(...)` validators, `Origin`/`Referer` headers, and test fixture HTML/URL files are acceptable. New occurrences in those forms are also fine.
  - **Test fixtures are exempt**: `test/fixtures/instrument_page_*.html` and URL strings inside test files are functional test data.
  - **Historical migration code is exempt**: SQL strings in `database.dart`'s `onUpgrade` migrations from earlier versions (e.g. v8/v9/v11) reference legacy provider names because they ran on past upgrades; rewriting them would not change persisted DB data and risks divergence from what shipped.
  - Outside those exemptions, the grep `Investing\.com\|InvestingCom\|InvestingPage\|InvestingComService\|investing_com\|investing_page` must return zero hits.
- **Date convention**: `operationDate` = when the bank processed it (used for import wipe-and-replace dedup). `valueDate` = when the money actually moved (used for display, ordering, charts, balance computation). All UI and queries must use `valueDate` for display/ordering. `operationDate` is only for the import dedup cutoff. Asset events and Income MUST have a populated `valueDate`.

# Pre-Release Checklist

- Before tagging a release on `main`, run `/pre-release-cleanup` on `develop`. Merge to `main` only after it reports zero findings across all phases (UI consistency, dedup, silent defaults, locale, date semantics, LoC, dead code, provider-name leaks, bug hunt, overreach).

# Key Project Files

- `lib/main.dart` — App shell, navigation, settings dialog
- `lib/database/database.dart` — Drift DB definition, migrations
- `lib/database/tables.dart` — All table definitions
- `lib/database/providers.dart` — Database provider
- `lib/services/providers/providers.dart` — Riverpod providers (split into service/stream/computed/app_state)
- `lib/services/file_parser_service.dart` — CSV/Excel/PDF file parsing (isolate-based for CSV/XLSX; main isolate for PDF via pdfrx)
- `lib/services/pdf_table_reconstructor.dart` — Anchor-based PDF table extractor (date+amount domain priors, no provider templates)
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
