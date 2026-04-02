# FinanceCopilot

A personal wealth management desktop app built with Flutter. Track your entire financial picture — bank accounts, investments, ETFs, bonds, crypto, pension funds — in one place with automatic price sync and no cloud dependency.

Runs on **macOS** and **Windows**. All data stays local in SQLite.

## Screenshots

### Dashboard
Price changes with period selector (1D/1W/1M/3M/6M/1Y/All), combined Totals chart, and individual breakdowns for Total Assets, Cash, Saving, Invested, and Portfolio. Totals table with drill-down per asset/account and delta vs historical max.

![Dashboard](docs/screenshots/dashboard.png)

### Financial Health
KPI scoring across Liquidity and Wealth categories with overall health gauge. Each indicator has an info button showing the formula with actual values. Investment costs table with TER tracking.

![Health](docs/screenshots/health.png)

### Allocation
Geographic, sector, asset class, instrument type, currency exposure, top holdings, and concentration risk (HHI). All aggregated from composition data fetched automatically from justETF and stockanalysis.com. Click any slice to drill down.

![Allocation](docs/screenshots/allocation.png)

### Asset Detail
Per-asset composition breakdown (asset class, geography, sector, top holdings) with source attribution. Full event history: buy, sell, dividend, split, contribute, revalue.

![Asset Detail](docs/screenshots/asset_detail.png)

### Import
Flexible column mapping for any bank or broker CSV/Excel export. Map columns once, save the config per account — every future import just works. Supports balance-diff mode, multi-column amounts, and status filtering.

![Import](docs/screenshots/import.png)

## Features

### Net Worth Dashboard
- **Totals chart** combining all accounts, assets, and adjustments into one view
- **Price Changes table** with daily/weekly/monthly/YTD/1Y performance per asset
- **Totals table** with drill-down showing each account and asset's contribution
- **Cash Flow tab** with income vs expenses, YoY changes, and EOY prediction
- **Financial Health tab** with KPI scoring across Liquidity and Wealth categories
- Toggle privacy mode to blur all amounts

### Portfolio Allocation
- **6 donut charts**: Geographic, Sector, Asset Class, Instrument Type, Currency, Top Holdings
- Drill-down on any slice to see which assets contribute
- **Concentration risk**: Top 1/3/5 percentages and Herfindahl-Hirschman Index
- Composition data auto-fetched from justETF (ETFs) and stockanalysis.com (stocks)
- Weekly refresh with 7-day cache

### Financial Health KPIs
- **Liquidity**: Net Worth Liquidity Ratio, Expense Coverage (months), Savings Rate
- **Wealth**: Investment Weight, Liquid Asset Ratio, Income-to-Wealth Ratio
- Overall score gauge (0-100) with per-category ratings (Ottimo/Buono/Sufficiente/Scarso)
- Info button on each KPI showing the formula with actual values

### Asset Tracking
- Stocks, ETFs, ETCs, bonds, crypto, pension funds — all in one model
- Buy, sell, dividend, split, contribute, interest, revalue events
- Market prices sync automatically from Investing.com (Cloudflare-aware)
- Bond pricing handles per-nominal quoting (/100)
- Auto-classification from Investing.com API (instrument type + asset class)

### Account Management
- Unlimited bank accounts, brokers, wallets
- Balances derived from imported transactions — fully auditable history
- Group accounts and assets by **Intermediary** (broker/institution)
- Drag-and-drop to reassign between intermediaries

### Smart Adjustments
- **Spread** — Amortise a large purchase over time (e.g. spread a car over 36 months)
- **Income adjustment** — Gradually absorb a lump-sum income (e.g. a bonus)

### CSV & Excel Import
- Import from any bank or broker (CSV, XLSX, clipboard)
- Flexible column mapping with saved configs per account
- Supports: Fineco, N26, Revolut, Interactive Brokers, and any custom format
- Multi-column amounts (Entrate + Uscite), balance-diff mode, status filtering
- Import transactions, asset events, or income records

### Multi-Currency
- 13 currencies: EUR, USD, GBP, CHF, JPY, SEK, NOK, DKK, PLN, CZK, HUF, CAD, AUD
- FX rates synced from Investing.com with historical backfill
- Everything converts to your chosen base currency automatically
- Per-event exchange rate tracking for accurate cost basis

### Income & Expenses
- Track income sources with type classification
- Flag transactions as income directly from the transaction list
- YoY income changes with end-of-year prediction
- Monthly expense tracking for health KPI calculations

### Bilingual
- Full Italian and English support (auto-detected from system locale)
- All UI strings, chart labels, KPI descriptions, and ratings localized

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter / Dart |
| Platforms | macOS, Windows |
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

For the nightly build (latest from `main`):

```bash
brew install --cask financecopilot-nightly
```

### Download

Pre-built binaries for macOS and Windows are available on the [Releases](https://github.com/marcobazzani/FinanceCopilot/releases) page. The [Nightly Build](https://github.com/marcobazzani/FinanceCopilot/releases/tag/latest) is updated automatically on every push to `main`.

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
```

### Run Tests

```bash
flutter test
```

## Architecture

- **Offline-first** — All data lives locally in SQLite. Market data and composition are cached after sync.
- **Reactive** — Riverpod stream providers watch the database and rebuild the UI automatically on any change.
- **Self-contained** — The app bundle has no runtime dependencies. No Python, no external processes.
- **Cloudflare-aware** — Uses a headless WebView to solve CF challenges, with automatic Dio/JS fetch routing based on a single startup probe.

## License

MIT
