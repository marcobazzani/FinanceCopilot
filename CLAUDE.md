# Build & Deploy

- When needed, Always build first, then kill the running app, then start the new build. Never kill before the build completes.
  ```
  flutter build macos --release && pkill -f "FinanceCopilot" 2>/dev/null; open build/macos/Build/Products/Release/FinanceCopilot.app
  ```

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

- Commit into git when detecting the user is starting a new task (not iterating on a previous task).
- Use concise, meaningful commit messages.
- After every commit bump the version number at the first code change
- NEVER add `Co-Authored-By:` lines to commits. Not under any circumstances, not for any reason. No exceptions.
- **Use `develop` branch for testing/exchanging code** (e.g. syncing with Windows VM). Never push to `main` unless the user explicitly confirms. Push to `develop` freely for testing.

# Code Quality

- Never duplicate code. Extract shared logic into utilities or service methods.
- Single source of truth: queries, parsing, business logic must be defined once and reused.

# Localization

- Always translate every string the user sees in the UI (use `AppStrings` / l10n).
- Always localize dates (both input parsing and output formatting) based on the application's locale configuration.



# Navigation

- Do NOT run `find` or exploratory commands to locate files — check the code directly.

# Python

- NEVER use `--break-system-packages` with pip. Use `python3 -m venv` for virtual environments instead.

# Database

- To find the DB path, check the app's stdout/stderr logs (it prints the path on startup). Do NOT search the filesystem with `find`.
- The DB filename may vary (not always `asset_manager.db`) — look for any `.db` file at the logged path.
- Never use `assets.db` in the repo root (stale copy, gitignored).

# Architecture

- The app must be **pure Flutter/Dart**. No Python scripts or external tools for runtime functionality.
- All data fetching (prices, ETF composition, etc.) must happen inside the Dart app itself.
- The released artifact must be fully self-contained.
- For reverse engineering websites/APIs: use any tool (curl, Playwright, Python, etc.) for exploration, but the final implementation must be in Dart/Flutter.

# Key Project Files

- `lib/main.dart` — App shell, navigation, settings dialog
- `lib/database/database.dart` — Drift DB definition, migrations
- `lib/database/tables.dart` — All table definitions
- `lib/database/providers.dart` — Database provider
- `lib/services/providers/providers.dart` — Riverpod providers (split into service/stream/computed/app_state)
- `lib/services/file_parser_service.dart` — CSV/Excel file parsing (isolate-based)
- `lib/services/market_price_service.dart` — Abstract market price service
- `lib/services/google_sheets_price_service.dart` — Google Sheets price impl (CSV)
- `lib/services/asset_service.dart` — Asset CRUD
- `lib/services/asset_event_service.dart` — Asset events (buy/sell/dividend)
- `lib/services/exchange_rate_service.dart` — FX rates
- `lib/services/capex_service.dart` — Depreciation/adjustment schedules
- `lib/services/buffer_service.dart` — Buffer management
- `lib/ui/screens/dashboard/dashboard_screen.dart` — Charts (net worth + investment, split into 13 part files)
- `lib/ui/screens/assets_screen.dart` — Asset list + create dialog
- `lib/ui/screens/accounts_screen.dart` — Account list
- `lib/ui/screens/capex_screen.dart` — Adjustments screen
- `lib/ui/screens/import/import_screen.dart` — CSV import (split into 4 part files)
- `lib/utils/date_parser.dart` — Comprehensive multi-format date parser
- `lib/version.dart` — Version number