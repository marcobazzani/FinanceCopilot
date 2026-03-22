# FinanceCopilot

A personal wealth management desktop app built with Flutter, replacing complex Excel-based financial tracking with a modern, reactive, offline-first platform.

Track net worth, manage multi-currency portfolios, import bank transactions, and monitor investment performance — all from a local SQLite database with no cloud dependency.

## Screenshots

### Dashboard — Charts
Price changes table with period selector, followed by a Totals combined chart (Total Assets, Cash, Saving, Invested).

![Dashboard Charts](docs/screenshots/dashboard.png)

### Dashboard — Allocation
Portfolio breakdown across geographic regions, sectors, asset types, currency exposure, top holdings, and concentration risk — aggregated automatically from all ETF/stock composition data.

![Allocation](docs/screenshots/allocation.png)

### Asset Detail
Per-asset composition panel (asset class, geographic split, sector weights, top holdings) fetched from justETF or stockanalysis.com, with full buy/sell/dividend event history.

![Asset Detail](docs/screenshots/asset_detail.png)

### CSV / Excel Import
Flexible column mapping for any bank or broker export. Supports transactions, asset events, and income. Deduplicates on re-import.

![Import](docs/screenshots/import.png)

## Features

- **Dashboard charts** — Fixed set of charts (Price Changes, Totals, Total Assets, Cash, Saving, Invested) with drag-to-zoom, per-chart series toggling, resizable cards, and hide-components toggle
- **Portfolio allocation** — Automatic geographic, sector, asset-type, currency, and concentration breakdown aggregated from ETF/stock composition data
- **Asset composition** — Per-asset breakdown fetched from justETF (ETFs/ETCs) and stockanalysis.com (stocks), refreshed weekly
- **Asset Management** — Unified tracker for stocks, ETFs, crypto, real estate, pensions, and liabilities via buy/sell/dividend events
- **Multi-Currency** — Automatic FX rate sync across 12+ currencies with configurable base currency
- **Market Data** — Historical price sync with Cloudflare bypass via embedded WebView
- **CSV/Excel Import** — Flexible column mapping for any bank/broker CSV or Excel file, with deduplication
- **Adjustments** — Spread large expenses over time or subtract lump-sum income items; configurable frequency (weekly, monthly, quarterly, yearly)
- **Account Management** — Multi-account balance tracking across banks, brokers, and crypto platforms

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart ^3.8.1) |
| State Management | Riverpod |
| Database | Drift (SQLite ORM), 20 tables |
| Charts | fl_chart |
| HTTP | Dio |
| HTML Parsing | html (DOM, not regex) |
| Import | csv, excel |
| UI | Material 3, desktop navigation rail |

## Project Structure

```
lib/
├── main.dart                  # App shell, navigation, settings
├── version.dart               # Version constant
├── database/
│   ├── database.dart          # Drift DB, migrations
│   ├── tables.dart            # Table definitions & enums
│   └── providers.dart         # Database provider
├── services/
│   ├── providers.dart         # Riverpod service providers
│   ├── asset_service.dart
│   ├── asset_event_service.dart
│   ├── composition_service.dart   # ETF/stock composition fetcher
│   ├── exchange_rate_service.dart
│   ├── market_price_service.dart
│   ├── capex_service.dart
│   ├── buffer_service.dart
│   └── import_service.dart
├── ui/
│   ├── screens/               # Dashboard, Assets, Accounts, Adjustments, Import
│   └── widgets/
└── utils/
```

## Getting Started

### Prerequisites

- Flutter SDK (^3.8.1)
- Xcode (for macOS builds)

### Build & Run

```bash
# Install dependencies
flutter pub get

# Generate code (Drift, Riverpod, JSON serialization)
dart run build_runner build --delete-conflicting-outputs

# Run in debug mode
flutter run -d macos

# Build release
flutter build macos --release
open build/macos/Build/Products/Release/FinanceCopilot.app
```

### Run Tests

```bash
flutter test
```

## Architecture

- **Single source of truth** — All data flows through the Drift database; services are stateless
- **Asset-agnostic model** — No separate tables per asset type; unified event model for all holdings
- **Reactive updates** — Riverpod StreamProviders auto-rebuild when underlying data changes
- **Offline-first** — All data stored locally in SQLite; market data and composition cached after sync

## License

Private project. All rights reserved.
