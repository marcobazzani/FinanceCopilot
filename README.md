# FinanceCopilot

A personal wealth management desktop app built with Flutter, replacing complex Excel-based financial tracking with a modern, reactive, offline-first platform.

Track net worth, manage multi-currency portfolios, import bank transactions, and monitor investment performance — all from a local SQLite database with no cloud dependency.

## Features

- **Dashboard** — Net worth tracking with 20+ indicators, trend charts with drag-to-zoom, customizable date ranges (1M/3M/6M/YTD/1Y/3Y/5Y/MAX)
- **Asset Management** — Unified tracker for stocks, ETFs, crypto, real estate, pensions, and liabilities via buy/sell/dividend events
- **Multi-Currency** — Automatic FX rate sync across 12+ currencies with configurable base currency
- **Market Data** — Real-time price sync from Alpha Vantage, Yahoo Finance, Investing.com, and Google Sheets
- **CSV/Excel Import** — Fineco, Revolut, and MoneyMap transaction imports with auto-categorization and deduplication
- **Tax-Aware** — Per-asset tax rates for liquidation P/L calculations
- **CAPEX Tracking** — Depreciation schedules (linear, declining balance, custom) with income adjustments
- **Account Management** — Multi-account balance tracking across banks, brokers, and crypto platforms
- **Buffer Management** — Liquid cash buffer tracking
- **Database Picker** — Switch between multiple database files (e.g., test vs production)

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart ^3.8.1) |
| State Management | Riverpod |
| Database | Drift (SQLite ORM), 20 tables, schema v14 |
| Charts | fl_chart |
| HTTP | Dio |
| Import | csv, excel |
| UI | Material 3, adaptive layout (desktop rail / mobile bottom nav) |

## Project Structure

```
lib/
├── main.dart                  # App shell, navigation
├── version.dart               # Version constant
├── database/
│   ├── database.dart          # Drift DB, migrations (v1→v14)
│   ├── tables.dart            # Table definitions & enums
│   └── providers.dart         # Database provider
├── services/                  # Business logic (16 services)
│   ├── providers.dart         # Riverpod service providers
│   ├── asset_service.dart     # Asset CRUD
│   ├── asset_event_service.dart
│   ├── exchange_rate_service.dart
│   ├── market_price_service.dart
│   ├── capex_service.dart
│   ├── buffer_service.dart
│   ├── import_service.dart    # CSV/Excel parsing
│   └── ...
├── ui/
│   ├── screens/               # Dashboard, Assets, Accounts, Adjustments, Import
│   └── widgets/               # Reusable components
├── models/                    # Data models
└── utils/                     # Logger, helpers
```

## Getting Started

### Prerequisites

- Flutter SDK (^3.8.1)
- Xcode (for macOS builds)
- Visual Studio (for Windows builds)

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
- **Reactive updates** — Riverpod providers auto-rebuild when underlying data changes
- **Offline-first** — All data stored locally in SQLite; market data cached after sync

## License

Private project. All rights reserved.
