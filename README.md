# FinanceCopilot

Your personal finance copilot. Track every account, asset, and cash flow in one place — fully offline, fully yours.

Built with Flutter for **macOS**, **Windows**, and **Android**. All data lives in a local SQLite file. Optional Google Drive sync if you want it across devices; nothing leaves your machine if you don't.

![History](docs/screenshots/dashboard.png)

## Why

Most personal-finance apps either lock you to a specific bank, ship your transactions to a cloud provider, or stop at simple budgeting. FinanceCopilot covers the full picture — bank accounts, ETFs, stocks, bonds, pension funds, crypto, real estate adjustments — and pulls market data on its own. No subscriptions, no servers, no telemetry.

## Screenshots

### Financial Health
KPI scoring across **Liquidity**, **Wealth**, and **Performance & Diversification**, with a single overall gauge. Each indicator opens a popover with the formula and the actual numbers behind it.

| Desktop | Mobile |
|---|---|
| ![Health](docs/screenshots/health.png) | ![Health (mobile)](docs/screenshots/health_mobile.png) |

### History & Price Changes
Period-selectable price-change table (1D/1W/1M/3M/6M/1Y/YTD/All) plus the Totals breakdown (assets, savings, invested, cash, portfolio) with vs‑ATH deltas and drill-down per row.

| Desktop | Mobile |
|---|---|
| ![History](docs/screenshots/dashboard.png) | ![History (mobile)](docs/screenshots/dashboard_mobile.png) |

### Cash Flow
Saving vs moving-average chart, expenses vs MA & cash, and velocity. Configurable MA window per chart.

| Desktop | Mobile |
|---|---|
| ![Cash Flow](docs/screenshots/cashflow.png) | ![Cash Flow (mobile)](docs/screenshots/cashflow_mobile.png) |

### Allocation
Geographic, sector, asset class, instrument type, currency, and top-holdings donuts. Composition resolved automatically for ETFs and stocks; click any slice to drill into the contributing assets.

| Desktop | Mobile |
|---|---|
| ![Allocation](docs/screenshots/allocation.png) | ![Allocation (mobile)](docs/screenshots/allocation_mobile.png) |

Below the fold: currency exposure, top holdings, **concentration risk** (Top 1 / 3 / 5 share, Herfindahl index), and a per-asset **investment costs** table with weighted-average TER.

![Allocation — concentration & costs](docs/screenshots/allocation_metrics.png)

### Assets
All holdings grouped by intermediary, with ticker, ISIN, event count, and per-asset performance. Swipe-to-delete and bulk-edit selection.

| Desktop | Mobile |
|---|---|
| ![Assets](docs/screenshots/assets.png) | ![Assets (mobile)](docs/screenshots/assets_mobile.png) |

### Asset Detail
Full event history (buy / sell / revalue), composition breakdown (asset class / geographic / sector / top holdings), and price chart. Bond pricing handles per-100 quoting; ETFs auto-fetch TER and holdings.

| Desktop | Mobile |
|---|---|
| ![Asset Detail](docs/screenshots/asset_detail.png) | ![Asset Detail (mobile)](docs/screenshots/asset_detail_mobile.png) |

### Pillars
Group assets and accounts into goal-oriented buckets (e.g. Lombard support, FIRE, Offspring) with their own value, target, and progress bar.

| Desktop | Mobile |
|---|---|
| ![Pillars](docs/screenshots/pillars.png) | ![Pillars (mobile)](docs/screenshots/pillars_mobile.png) |

Each pillar drills into its own objective, history chart, and per-asset allocation slider — set how much of every holding contributes to the bucket, with a free residual that auto-balances against the other pillars.

| Desktop | Mobile |
|---|---|
| ![Pillar Detail](docs/screenshots/pillar_detail.png) | ![Pillar Detail (mobile)](docs/screenshots/pillar_detail_mobile.png) |

### Import
Map any bank or broker CSV / Excel onto Transactions, Asset Events, or Income. ISIN-driven exchange picker, per-row exclude, formula columns, status filtering, and multi-column amount math.

![Import](docs/screenshots/import.png)

## What it does

### Wealth tracking
- Bank accounts, brokers, and wallets — unlimited, with balances derived from imported transactions (auditable history, no manual reconciliation)
- Stocks, ETFs, ETCs, bonds, pension funds, commodities — one unified asset model with buy/sell/revalue events and per-event exchange rate
- ISIN-first resolution; multi-exchange listings handled correctly
- TER and composition auto-fetched for ETFs

### Dashboards
- **Financial Health** — KPI scoring with Liquidity, Wealth, and Performance & Diversification categories (Net Worth Ratio, Expense Coverage, Savings Rate, Investment Weight, Liquid Asset Ratio, Income-to-Wealth, HHI, weighted TER, …)
- **History** — combined chart, top movers, smart Totals
- **Cash Flow** — saving / spending / velocity with configurable MA windows
- **Allocation** — six donuts + drill-down + concentration metrics (Top 1/3/5, HHI)
- **Privacy mode** — single-toggle blur on every amount, price, quantity, and target across the app

### Import
- CSV, XLSX, clipboard
- Saved column-mapping configs per account
- ISIN exchange picker with auto-lookup
- Tested against Fineco, Directa, N26, Revolut, Interactive Brokers, and arbitrary custom formats
- Handles 3-decimal XLSX numerics, locale decimal separators, and multi-column amount math

### Multi-currency
- 13 currencies (EUR, USD, GBP, CHF, JPY, SEK, NOK, DKK, PLN, CZK, HUF, CAD, AUD)
- Daily FX rates with historical backfill
- Everything reconciles to the chosen base currency, with per-event rate tracking for cost basis

### Bilingual
- Full English and Italian (auto-detected from system locale; switchable in settings)
- Every UI string, KPI label, and rating localized

## Install

### Homebrew (macOS)

```bash
brew tap marcobazzani/financecopilot
brew install --cask financecopilot          # stable
brew install --cask financecopilot-nightly  # latest develop
```

### Direct download

Pre-built binaries for macOS, Windows, and Android on the [Releases](https://github.com/marcobazzani/FinanceCopilot/releases) page. The [nightly build](https://github.com/marcobazzani/FinanceCopilot/releases/tag/latest) tracks `develop`.

> macOS and Windows binaries are not code-signed. On macOS you may need to allow the app via **System Settings → Privacy & Security** the first time. Endpoint security tools that re-sign binaries on extraction (CrowdStrike, SentinelOne, …) will break Homebrew install — use the DMG instead.

## Build from source

Prerequisites: Flutter SDK ^3.8.1, Xcode (macOS), or Visual Studio with Desktop C++ workload (Windows).

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# macOS
flutter build macos --release

# Windows
flutter build windows --release

# Android APK
flutter build apk --release
```

## Run tests

```bash
# Unit tests (~720, ~15s)
flutter test

# Integration tests (5 suites, ~3m, requires a running desktop device)
flutter test integration_test/all_tests.dart -d macos \
  --dart-define=DB_FILE_NAME=finance_copilot_test.db

# Live market-data smoke test (~1m, requires network)
flutter test integration_test/live_data_fetch_test.dart -d macos \
  --dart-define=DB_FILE_NAME=finance_copilot_test.db
```

## Architecture

- **Offline-first** — all data lives locally in SQLite; market data and composition are cached after each sync
- **Reactive** — Riverpod stream providers watch the database and rebuild the UI on every change
- **Self-contained** — no Python, no external processes, no runtime services; the bundled binary is everything
- **ISIN-first** — every asset operation prefers ISIN over ticker for reliable cross-exchange matching
- **Date semantics** — `valueDate` (when the money actually moved) drives display, ordering, charts, and balance computation; `operationDate` is only used for import dedup

| Layer | Stack |
|-------|-------|
| Framework | Flutter / Dart |
| Platforms | macOS, Windows, Android |
| State | Riverpod |
| DB | Drift (SQLite) |
| Charts | fl_chart |
| Import | csv, excel, file_picker, pdfrx |

## Privacy & terms

- [Privacy Policy](docs/privacy.md)
- [Terms of Service](docs/terms.md)

## License

MIT.
