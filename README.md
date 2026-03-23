# FinanceCopilot

A personal wealth management desktop app built with Flutter. Replaces spreadsheet-based tracking with a reactive, offline-first platform backed by a local SQLite database — no cloud accounts, no subscriptions.

Track net worth over time, manage multi-currency portfolios, import bank and broker exports, and monitor investment performance across accounts, stocks, ETFs, and funds.

## Screenshots

### Dashboard — Charts
Price changes table with period selector (1d–All), followed by a combined Totals chart and individual breakdowns: Total Assets, Cash, Saving, Invested.

![Dashboard Charts](docs/screenshots/dashboard.png)

### Dashboard — Allocation
Geographic, sector, asset-type, currency, holdings, and concentration risk — all aggregated automatically from composition data fetched from justETF and stockanalysis.com.

![Allocation](docs/screenshots/allocation.png)

### Asset Detail
Per-asset composition (asset class, geographic split, sector weights, top holdings) with full buy/sell/dividend event history.

![Asset Detail](docs/screenshots/asset_detail.png)

### CSV / Excel Import
Flexible column mapping for any bank or broker export. Saved per source so you only configure it once.

![Import](docs/screenshots/import.png)

## Features

### Net worth at a glance
The dashboard tracks your financial picture across six views — Price Changes, Totals, Total Assets, Cash, Saving, and Invested — each populated automatically from all your accounts, assets, and adjustments. No manual series configuration. Drag to zoom, toggle individual lines, resize charts.

The Allocation tab breaks down your portfolio by geography, sector, asset type, currency exposure, top holdings, and concentration risk, aggregated from live composition data across all your ETFs and stocks.

### Asset tracking
One model for everything — stocks, ETFs, ETCs, crypto, real estate, pension funds, liabilities. Record buys, sells, and dividends as timestamped events. Market prices sync automatically from Investing.com. ETF and stock composition data refreshes weekly from justETF and stockanalysis.com.

### Account management
Track balances across any number of bank accounts, brokers, and wallets. Balances are derived from imported transactions so the history is always auditable.

### Smart adjustments
Two tools for handling cash flows that don't fit neatly into transactions:

- **Spread** — Amortise a large purchase over time (e.g. spread a €12 000 car over 36 months) so your savings chart doesn't show a cliff.
- **Income adjustment** — Gradually absorb a lump-sum income event (e.g. a bonus) rather than having it spike your net worth overnight.

### CSV & Excel import
Import from any bank or broker. Map columns once, save the config, and every future import just works. SHA-256 deduplication means re-importing the same file never creates duplicates.

### Multi-currency
FX rates for 13 currencies (EUR, USD, GBP, CHF, JPY, SEK, NOK, DKK, PLN, CZK, HUF, CAD, AUD) synced from the ECB via the Frankfurter API with full daily history from 1999. Everything converts to your chosen base currency automatically.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter / Dart |
| State management | Riverpod |
| Database | Drift (SQLite) |
| Charts | fl_chart |
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

Pre-built binaries for macOS, Windows, and Linux are available on the [Releases](https://github.com/marcobazzani/FinanceCopilot/releases) page. The [Nightly Build](https://github.com/marcobazzani/FinanceCopilot/releases/tag/latest) is updated automatically on every push to `main`.

### Build from Source

Prerequisites: Flutter SDK ^3.8.1, Xcode (macOS builds)

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d macos

# Release build
flutter build macos --release
open build/macos/Build/Products/Release/FinanceCopilot.app
```

### Run Tests

```bash
flutter test
```

## Architecture

- **Offline-first** — Everything lives locally in SQLite. Market data and composition are cached after sync.
- **Reactive** — Riverpod stream providers watch the database and rebuild the UI automatically on any change.
- **Self-contained** — The `.app` bundle has no runtime dependencies. No Python, no external processes.

## License

MIT
