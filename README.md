# FinanceCopilot

A personal wealth management app built with Flutter. Track your entire financial picture — bank accounts, investments, ETFs, bonds, commodities, pension funds — in one place with automatic price sync and no cloud dependency.

Runs on **macOS**, **Windows**, and **Android**. All data stays local in SQLite.

## Screenshots

### Financial Health Dashboard
KPI scoring across Liquidity, Wealth, and Diversification categories with overall health gauge. Each indicator has an info button showing the formula with actual values. Performance tracking with price changes across multiple periods.

![Health](docs/screenshots/health.png)

### Portfolio Allocation
Geographic, sector, asset class, instrument type, currency exposure, top holdings, and concentration risk (HHI). All aggregated from composition data fetched automatically from justETF and stockanalysis.com. Click any slice to drill down. Investment costs table with weighted TER tracking.

![Allocation](docs/screenshots/allocation.png)

### Assets
All your holdings in one view — grouped by intermediary, with live prices, event counts, and performance indicators.

![Assets](docs/screenshots/assets.png)

### Asset Detail
Per-asset view with ticker, ISIN, exchange, and full event history (buy, sell, revalue). Composition breakdown by geography, sector, and top holdings with source attribution.

![Asset Detail](docs/screenshots/asset_detail.png)

### Import
Flexible column mapping for any bank or broker CSV/Excel export. Map columns once, save the config per account — every future import just works. ISIN-based exchange picker with per-asset exclude checkbox. Supports balance-diff mode, multi-column amounts, and status filtering.

![Import](docs/screenshots/import.png)

## Features

### Net Worth Dashboard
- **Financial Health tab** with KPI scoring: Liquidity (Net Worth Ratio, Expense Coverage, Savings Rate), Wealth (Investment Weight, Liquid Asset Ratio, Income-to-Wealth), Performance & Diversification (Price Changes, HHI, TER)
- **History tab** combining all accounts, assets, and adjustments into one chart
- **Cash Flow tab** with income vs expenses, YoY changes, and EOY prediction
- **Assets Overview** with allocation donuts, top holdings, concentration risk, and investment costs
- **Price Changes table** with 1D/1W/1M/3M/6M/1Y/YTD/All performance per asset
- Toggle privacy mode to blur all amounts

### Portfolio Allocation
- **6 donut charts**: Geographic, Sector, Asset Class, Instrument Type, Currency, Top Holdings
- Drill-down on any slice to see which assets contribute
- **Concentration risk**: Top 1/3/5 percentages and Herfindahl-Hirschman Index (HHI)
- **Investment costs**: Weighted average TER with per-asset cost breakdown
- Composition data auto-fetched from justETF (ETFs) and stockanalysis.com (stocks)

### Asset Tracking
- Stocks, ETFs, ETCs, bonds, pension funds — all in one model
- Buy, sell, and revalue events with full audit trail
- Market prices sync automatically from Investing.com (Cloudflare-aware)
- **ISIN-first search** — resolves any ISIN to the correct exchange listing
- Bond pricing handles per-nominal quoting (/100)
- Auto-classification from Investing.com API (instrument type + asset class)
- TER and composition auto-fetched from justETF

### Account Management
- Unlimited bank accounts, brokers, wallets
- Balances derived from imported transactions — fully auditable history
- Group accounts and assets by **Intermediary** (broker/institution)

### Smart Adjustments
- **Spread Expenses** — Amortise a large purchase over time (e.g. spread a car over 36 months)
- **Donations / Inheritance** — Track and adjust for lump-sum income events

### CSV & Excel Import
- Import from any bank or broker (CSV, XLSX, clipboard)
- Flexible column mapping with saved configs per account
- ISIN-based exchange picker with auto-lookup via Investing.com
- **Exclude checkbox** per ISIN to skip unwanted assets
- Supports: Fineco, Directa, N26, Revolut, Interactive Brokers, and any custom format
- Multi-column amounts, balance-diff mode, formula builder, status filtering
- Import transactions, asset events, or income records
- Correct XLSX numeric parsing (handles 3-decimal values like 260.437)

### Multi-Currency
- 13 currencies: EUR, USD, GBP, CHF, JPY, SEK, NOK, DKK, PLN, CZK, HUF, CAD, AUD
- FX rates synced from Investing.com with historical backfill
- Everything converts to your chosen base currency automatically
- Per-event exchange rate tracking for accurate cost basis

### Income Tracking
- Track income sources with type classification
- Rolling 12-month income for Income-to-Wealth ratio
- YoY income changes with end-of-year prediction
- Monthly expense tracking for health KPI calculations

### Bilingual
- Full Italian and English support (auto-detected from system locale)
- All UI strings, chart labels, KPI descriptions, and ratings localized

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter / Dart |
| Platforms | macOS, Windows, Android |
| State management | Riverpod (reactive streams) |
| Database | Drift (SQLite) |
| Charts | fl_chart |
| Market data | Investing.com (WebView + Dio) |
| Composition | justETF, stockanalysis.com |
| Import | csv, excel, file_picker |

## Install

### Homebrew (macOS)

```bash
brew tap marcobazzani/financecopilot
brew install --cask financecopilot
```

For the nightly build (latest from `develop`):

```bash
brew install --cask financecopilot-nightly
```

### Download

Pre-built binaries for macOS and Windows are available on the [Releases](https://github.com/marcobazzani/FinanceCopilot/releases) page. The [Nightly Build](https://github.com/marcobazzani/FinanceCopilot/releases/tag/latest) is updated automatically on every push to `develop`.

### Build from Source

Prerequisites: Flutter SDK ^3.8.1, Xcode (macOS) or Visual Studio (Windows)

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# macOS
flutter build macos --release
open build/macos/Build/Products/Release/FinanceCopilot.app

# Windows
flutter build windows --release

# Android
flutter build apk --release
```

### Run Tests

```bash
# Unit tests (353 tests, ~10s)
flutter test

# Integration tests (14 tests, ~50s, requires macOS)
flutter test integration_test/all_tests.dart -d macos

# Live data test (12 assets, real HTTP to Investing.com, ~50s)
flutter test integration_test/live_data_fetch_test.dart -d macos
```

## Architecture

- **Offline-first** — All data lives locally in SQLite. Market data and composition are cached after sync.
- **Reactive** — Riverpod stream providers watch the database and rebuild the UI automatically on any change.
- **Self-contained** — The app bundle has no runtime dependencies. No Python, no external processes.
- **Cloudflare-aware** — Uses a headless WebView to solve CF challenges, with automatic Dio/JS fetch routing based on a single startup probe.
- **ISIN-first** — All asset resolution prefers ISIN over ticker for reliable multi-exchange matching.

## License

MIT
