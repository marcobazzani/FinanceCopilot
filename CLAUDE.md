# Build & Deploy

- Always build first, then kill the running app, then start the new build. Never kill before the build completes.
  ```
  flutter build macos --release && pkill -f "FinanceCopilot" 2>/dev/null; open build/macos/Build/Products/Release/FinanceCopilot.app
  ```

# Git Workflow

- Commit into git when detecting the user is starting a new task (not iterating on a previous task).
- Use concise, meaningful commit messages.
- After every commit bump the version number at the first code change

# Code Quality

- Never duplicate code. Extract shared logic into utilities or service methods.
- Single source of truth: queries, parsing, business logic must be defined once and reused.



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
- `lib/services/providers.dart` — All Riverpod service/stream providers
- `lib/services/market_price_service.dart` — Abstract market price service
- `lib/services/google_sheets_price_service.dart` — Google Sheets price impl (CSV)
- `lib/services/asset_service.dart` — Asset CRUD
- `lib/services/asset_event_service.dart` — Asset events (buy/sell/dividend)
- `lib/services/exchange_rate_service.dart` — FX rates
- `lib/services/capex_service.dart` — Depreciation/adjustment schedules
- `lib/services/buffer_service.dart` — Buffer management
- `lib/ui/screens/dashboard_screen.dart` — Charts (net worth + investment)
- `lib/ui/screens/assets_screen.dart` — Asset list + create dialog
- `lib/ui/screens/accounts_screen.dart` — Account list
- `lib/ui/screens/capex_screen.dart` — Adjustments screen
- `lib/ui/screens/import_screen.dart` — CSV import
- `lib/version.dart` — Version number